import CoreImage
import Flutter
import ImageIO
import Photos
import PhotosUI
import UIKit
import UniformTypeIdentifiers
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var photoNative: PhotoNative?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VimaiPhotoNative") {
      photoNative = PhotoNative(messenger: registrar.messenger())
    }
  }
}

/// On-device photo work for ViMai Photo: person segmentation, face box,
/// exact-size rendering, print sheets, saving and sharing.
/// Nothing here touches the network.
final class PhotoNative: NSObject, PHPickerViewControllerDelegate {
  private let channel: FlutterMethodChannel
  private let context = CIContext(options: [.useSoftwareRenderer: false])
  private let queue = DispatchQueue(label: "vimai.photo", qos: .userInitiated)

  /// Upright image and person mask per source path, so sliders re-render fast.
  private var cache: [String: (image: CIImage, mask: CIImage?)] = [:]
  private var pickResult: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "vimai/photo", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "analyze":
      run(result) { try self.analyze(path: args["path"] as! String) }
    case "render":
      run(result) { try self.render(args) }
    case "renderSheet":
      run(result) { try self.renderSheet(args) }
    case "saveToPhotos":
      saveToPhotos(path: args["path"] as! String, result: result)
    case "share":
      share(path: args["path"] as! String, result: result)
    case "pickPhoto":
      pickPhoto(result: result)
    case "clearCache":
      queue.async { self.cache.removeAll() }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func run(_ result: @escaping FlutterResult, _ work: @escaping () throws -> Any?) {
    queue.async {
      do {
        let value = try work()
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "photo", message: "\(error)", details: nil))
        }
      }
    }
  }

  // MARK: analyze

  private func load(path: String) throws -> (image: CIImage, mask: CIImage?) {
    if let hit = cache[path] { return hit }
    let url = URL(fileURLWithPath: path)
    guard let raw = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else {
      throw NSError(domain: "photo", code: 1, userInfo: [NSLocalizedDescriptionKey: "cannot read image"])
    }
    // Move the extent to the origin so pixel maths below stays simple.
    let image = raw.transformed(by: CGAffineTransform(translationX: -raw.extent.minX, y: -raw.extent.minY))
    let mask = try segment(image)
    let entry = (image: image, mask: mask)
    if cache.count > 4 { cache.removeAll() }
    cache[path] = entry
    return entry
  }

  private func segment(_ image: CIImage) throws -> CIImage? {
    let request = VNGeneratePersonSegmentationRequest()
    request.qualityLevel = .accurate
    request.outputPixelFormat = kCVPixelFormatType_OneComponent8
    let handler = VNImageRequestHandler(ciImage: image, options: [:])
    try handler.perform([request])
    guard let buffer = request.results?.first?.pixelBuffer else { return nil }
    let small = CIImage(cvPixelBuffer: buffer)
    let sx = image.extent.width / small.extent.width
    let sy = image.extent.height / small.extent.height
    return small.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
  }

  private func analyze(path: String) throws -> [String: Any] {
    let (image, mask) = try load(path: path)
    let w = image.extent.width
    let h = image.extent.height

    let faces = VNDetectFaceRectanglesRequest()
    faces.revision = VNDetectFaceRectanglesRequestRevision3
    try VNImageRequestHandler(ciImage: image, options: [:]).perform([faces])
    let found = (faces.results ?? []).sorted { $0.boundingBox.width > $1.boundingBox.width }

    var out: [String: Any] = [
      "width": Double(w), "height": Double(h),
      "faceCount": found.count, "hasMask": mask != nil,
    ]
    guard let face = found.first else { return out }

    // Vision boxes are normalised with the origin at the bottom left.
    let box = face.boundingBox
    let left = box.minX * w
    let top = (1 - box.maxY) * h
    let fw = box.width * w
    let fh = box.height * h
    out["face"] = ["left": Double(left), "top": Double(top), "width": Double(fw), "height": Double(fh)]
    if let roll = face.roll { out["roll"] = roll.doubleValue * 180 / .pi }
    if let yaw = face.yaw { out["yaw"] = yaw.doubleValue * 180 / .pi }
    if let pitch = face.pitch { out["pitch"] = pitch.doubleValue * 180 / .pi }

    if let mask = mask, let crown = crownY(mask: mask, faceLeft: left, faceWidth: fw, faceTop: top, height: h) {
      out["crownY"] = Double(crown)
    }
    out["faceLuma"] = luma(of: image, rect: CGRect(x: left, y: h - top - fh, width: fw, height: fh))
    return out
  }

  /// Highest row (from the top) where the person mask covers the middle of
  /// the face column. That is the top of the hair.
  private func crownY(mask: CIImage, faceLeft: CGFloat, faceWidth: CGFloat, faceTop: CGFloat, height: CGFloat) -> CGFloat? {
    let colX = faceLeft + faceWidth * 0.3
    let colW = max(faceWidth * 0.4, 1)
    // Everything above the face box, in CI coordinates (origin bottom left).
    let stripBottom = max(height - faceTop, 0)
    let strip = CGRect(x: colX, y: stripBottom, width: colW, height: max(height - stripBottom, 1))
    let rows = 256
    let column = mask.cropped(to: strip)
      .transformed(by: CGAffineTransform(translationX: -strip.minX, y: -strip.minY))
      .transformed(by: CGAffineTransform(scaleX: 1 / strip.width, y: CGFloat(rows) / strip.height))
    var pixels = [UInt8](repeating: 0, count: rows * 4)
    context.render(column, toBitmap: &pixels, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: rows),
                   format: .RGBA8, colorSpace: nil)
    // The mask is solid from the face up to the crown and empty above it,
    // so the share of covered samples gives the hair height whichever way
    // the bitmap rows run.
    let covered = stride(from: 0, to: rows, by: 1).filter { pixels[$0 * 4] > 128 }.count
    guard covered > 0 else { return nil }
    return faceTop - CGFloat(covered) / CGFloat(rows) * strip.height
  }

  private func luma(of image: CIImage, rect: CGRect) -> Double {
    guard let filter = CIFilter(name: "CIAreaAverage",
                                parameters: [kCIInputImageKey: image, kCIInputExtentKey: CIVector(cgRect: rect)]),
          let output = filter.outputImage else { return 128 }
    var px = [UInt8](repeating: 0, count: 4)
    context.render(output, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                   format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))
    return 0.299 * Double(px[0]) + 0.587 * Double(px[1]) + 0.114 * Double(px[2])
  }

  // MARK: render one photo

  private func render(_ args: [String: Any]) throws -> String {
    let path = args["path"] as! String
    let crop = args["crop"] as! [String: Double]
    let outW = args["outWidth"] as! Int
    let outH = args["outHeight"] as! Int
    let argb = args["background"] as! Int
    let replace = args["replaceBackground"] as? Bool ?? true
    let exposure = args["exposure"] as? Double ?? 0
    let dpi = args["dpi"] as? Int ?? 300

    let (image, mask) = try load(path: path)
    let h = image.extent.height
    let color = CIColor(red: CGFloat((argb >> 16) & 0xFF) / 255,
                        green: CGFloat((argb >> 8) & 0xFF) / 255,
                        blue: CGFloat(argb & 0xFF) / 255)
    let background = CIImage(color: color)

    var subject = image
    if exposure != 0 {
      subject = subject.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: exposure])
    }
    var composed: CIImage
    if replace, let mask = mask {
      // Soften the cut-out edge a little so hair does not look pasted on.
      let soft = mask.clampedToExtent()
        .applyingGaussianBlur(sigma: max(image.extent.width / 1500, 1))
        .cropped(to: image.extent)
      composed = subject.applyingFilter("CIBlendWithMask", parameters: [
        kCIInputBackgroundImageKey: background.cropped(to: image.extent),
        kCIInputMaskImageKey: soft,
      ])
      composed = composed.composited(over: background)
    } else {
      composed = subject.clampedToExtent()
    }

    let left = CGFloat(crop["left"]!)
    let top = CGFloat(crop["top"]!)
    let cw = CGFloat(crop["width"]!)
    let ch = CGFloat(crop["height"]!)
    let ciY = h - top - ch
    let scale = CGFloat(outW) / cw
    let final = composed
      .transformed(by: CGAffineTransform(translationX: -left, y: -ciY))
      .transformed(by: CGAffineTransform(scaleX: scale, y: CGFloat(outH) / ch))
      .cropped(to: CGRect(x: 0, y: 0, width: outW, height: outH))

    guard let cg = context.createCGImage(final, from: final.extent,
                                         format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)) else {
      throw NSError(domain: "photo", code: 2, userInfo: [NSLocalizedDescriptionKey: "render failed"])
    }
    return try writeJPEG(cg, dpi: dpi, prefix: "photo")
  }

  // MARK: print sheet

  private func renderSheet(_ args: [String: Any]) throws -> String {
    let path = args["photoPath"] as! String
    let sheetW = args["sheetWidth"] as! Int
    let sheetH = args["sheetHeight"] as! Int
    let photoW = args["photoWidth"] as! Int
    let photoH = args["photoHeight"] as! Int
    let slots = args["slots"] as! [[Double]]
    let guides = args["cutGuides"] as? Bool ?? true
    let dpi = args["dpi"] as? Int ?? 300

    guard let photo = UIImage(contentsOfFile: path)?.cgImage else {
      throw NSError(domain: "photo", code: 3, userInfo: [NSLocalizedDescriptionKey: "cannot read photo"])
    }
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: sheetW, height: sheetH), format: format)
    let sheet = renderer.image { ctx in
      UIColor.white.setFill()
      ctx.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))
      for slot in slots {
        let rect = CGRect(x: slot[0], y: slot[1], width: Double(photoW), height: Double(photoH))
        UIImage(cgImage: photo).draw(in: rect)
        if guides {
          ctx.cgContext.setStrokeColor(UIColor(white: 0.78, alpha: 1).cgColor)
          ctx.cgContext.setLineWidth(1)
          ctx.cgContext.stroke(rect.insetBy(dx: -0.5, dy: -0.5))
        }
      }
    }
    guard let cg = sheet.cgImage else {
      throw NSError(domain: "photo", code: 4, userInfo: [NSLocalizedDescriptionKey: "sheet failed"])
    }
    return try writeJPEG(cg, dpi: dpi, prefix: "sheet")
  }

  private func writeJPEG(_ image: CGImage, dpi: Int, prefix: String) throws -> String {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vimai", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("\(prefix)-\(UUID().uuidString).jpg")
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
      throw NSError(domain: "photo", code: 5, userInfo: [NSLocalizedDescriptionKey: "cannot write"])
    }
    let props: [CFString: Any] = [
      kCGImageDestinationLossyCompressionQuality: 0.95,
      kCGImagePropertyDPIWidth: dpi,
      kCGImagePropertyDPIHeight: dpi,
    ]
    CGImageDestinationAddImage(dest, image, props as CFDictionary)
    guard CGImageDestinationFinalize(dest) else {
      throw NSError(domain: "photo", code: 6, userInfo: [NSLocalizedDescriptionKey: "cannot finalize"])
    }
    return url.path
  }

  // MARK: save, share, pick

  private func saveToPhotos(path: String, result: @escaping FlutterResult) {
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      guard status == .authorized || status == .limited else {
        DispatchQueue.main.async { result(false) }
        return
      }
      PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: URL(fileURLWithPath: path))
      }) { ok, _ in
        DispatchQueue.main.async { result(ok) }
      }
    }
  }

  private func topController() -> UIViewController? {
    let window = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
    var top = window?.rootViewController
    while let next = top?.presentedViewController { top = next }
    return top
  }

  private func share(path: String, result: @escaping FlutterResult) {
    guard let top = topController() else { result(false); return }
    let sheet = UIActivityViewController(activityItems: [URL(fileURLWithPath: path)], applicationActivities: nil)
    sheet.popoverPresentationController?.sourceView = top.view
    sheet.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 80, width: 1, height: 1)
    top.present(sheet, animated: true)
    result(true)
  }

  private func pickPhoto(result: @escaping FlutterResult) {
    guard let top = topController() else { result(nil); return }
    var config = PHPickerConfiguration()
    config.filter = .images
    config.selectionLimit = 1
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = self
    pickResult = result
    top.present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let done = pickResult else { return }
    pickResult = nil
    guard let provider = results.first?.itemProvider,
          provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
      done(nil)
      return
    }
    provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
      var copied: String?
      if let url = url {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vimai", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        let dest = dir.appendingPathComponent("picked-\(UUID().uuidString).\(ext)")
        if (try? FileManager.default.copyItem(at: url, to: dest)) != nil { copied = dest.path }
      }
      DispatchQueue.main.async { done(copied) }
    }
  }
}
