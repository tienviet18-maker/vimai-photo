import CoreImage
import Flutter
import ImageIO
import Photos
import PhotosUI
import UIKit
import StoreKit
import UniformTypeIdentifiers
import UserNotifications
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

/// On-device photo work for ViMai Photo: person segmentation, face
/// landmarks, exact-size rendering with background and light correction,
/// print sheets, saving and sharing. Nothing here touches the network.
final class PhotoNative: NSObject, PHPickerViewControllerDelegate {
  private let channel: FlutterMethodChannel
  private let context = CIContext(options: [.useSoftwareRenderer: false])
  private let queue = DispatchQueue(label: "vimai.photo", qos: .userInitiated)
  private let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

  private struct Source {
    let image: CIImage
    /// Low-resolution person mask straight from Vision, nil without a person.
    let smallMask: CIImage?
  }

  /// Upright image and person mask per source path, so sliders re-render fast.
  private var cache: [String: Source] = [:]
  /// Lip outlines from `analyze`, in source pixels (origin top left):
  /// outer edge, and the open mouth inside it to leave teeth alone.
  private var lipsCache: [String: (outer: [CGPoint], inner: [CGPoint])] = [:]
  private var pickResult: FlutterResult?
  private var pickLimit = 1

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
      pickPhoto(limit: args["limit"] as? Int ?? 1, result: result)
    case "requestReview":
      DispatchQueue.main.async {
        let scene = UIApplication.shared.connectedScenes
          .first { $0.activationState == .foregroundActive } as? UIWindowScene
        if let scene { SKStoreReviewController.requestReview(in: scene) }
        result(nil)
      }
    case "appDir":
      result(appDir())
    case "scheduleReminder":
      scheduleReminder(args, result: result)
    case "cancelReminder":
      UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [args["id"] as! String])
      result(nil)
    case "clearCache":
      queue.async { self.cache.removeAll(); self.lipsCache.removeAll() }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func run(_ result: @escaping FlutterResult, _ work: @escaping () throws -> Any?) {
    queue.async {
      do {
        let value = try autoreleasepool { try work() }
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "photo", message: "\(error)", details: nil))
        }
      }
    }
  }

  private func fail(_ code: Int, _ message: String) -> NSError {
    NSError(domain: "photo", code: code, userInfo: [NSLocalizedDescriptionKey: message])
  }

  // MARK: load and analyze

  private func load(path: String) throws -> Source {
    if let hit = cache[path] { return hit }
    let url = URL(fileURLWithPath: path)
    guard let raw = CIImage(contentsOf: url, options: [.applyOrientationProperty: true]) else {
      throw fail(1, "cannot read image")
    }
    // Move the extent to the origin so the pixel maths below stays simple.
    let image = raw.transformed(by: CGAffineTransform(translationX: -raw.extent.minX, y: -raw.extent.minY))
    let source = Source(image: image, smallMask: try segment(image))
    if cache.count > 3 { cache.removeAll() }
    cache[path] = source
    return source
  }

  private func segment(_ image: CIImage) throws -> CIImage? {
    let request = VNGeneratePersonSegmentationRequest()
    request.qualityLevel = .accurate
    request.outputPixelFormat = kCVPixelFormatType_OneComponent8
    try VNImageRequestHandler(ciImage: image, options: [:]).perform([request])
    guard let buffer = request.results?.first?.pixelBuffer else { return nil }
    return CIImage(cvPixelBuffer: buffer)
  }

  /// The person mask at the photo's full size. The upsampling follows the
  /// photo's own edges, so single hairs keep their shape instead of the
  /// blocky outline of the low-resolution mask.
  private func fullMask(_ source: Source) -> CIImage? {
    guard let small = source.smallMask else { return nil }
    guard let filter = CIFilter(name: "CIEdgePreserveUpsampleFilter") else {
      let sx = source.image.extent.width / small.extent.width
      let sy = source.image.extent.height / small.extent.height
      return small.transformed(by: CGAffineTransform(scaleX: sx, y: sy))
    }
    filter.setValue(source.image, forKey: kCIInputImageKey)
    filter.setValue(small, forKey: "inputSmallImage")
    filter.setValue(4.0, forKey: "inputSpatialSigma")
    filter.setValue(0.1, forKey: "inputLumaSigma")
    return filter.outputImage?.cropped(to: source.image.extent)
  }

  private func analyze(path: String) throws -> [String: Any] {
    let source = try load(path: path)
    let image = source.image
    let w = image.extent.width
    let h = image.extent.height

    let landmarks = VNDetectFaceLandmarksRequest()
    try VNImageRequestHandler(ciImage: image, options: [:]).perform([landmarks])
    let found = (landmarks.results ?? []).sorted { $0.boundingBox.width > $1.boundingBox.width }

    var out: [String: Any] = [
      "width": Double(w), "height": Double(h),
      "faceCount": found.count, "hasMask": source.smallMask != nil,
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

    // Lips, for the optional lip colour.
    func toSource(_ r: VNFaceLandmarkRegion2D?) -> [CGPoint] {
      guard let r else { return [] }
      return r.normalizedPoints.map {
        CGPoint(x: (box.minX + $0.x * box.width) * w, y: (1 - (box.minY + $0.y * box.height)) * h)
      }
    }
    let outerLips = toSource(face.landmarks?.outerLips)
    if outerLips.count > 4 {
      lipsCache[path] = (outerLips, toSource(face.landmarks?.innerLips))
    }

    // Chin = lowest point of the face contour.
    if let contour = face.landmarks?.faceContour, contour.pointCount > 0 {
      let lowest = contour.normalizedPoints.map { $0.y }.min() ?? 0
      out["chinY"] = Double((1 - (box.minY + lowest * box.height)) * h)
    }
    if let mask = fullMask(source),
       let crown = crownY(mask: mask, faceLeft: left, faceWidth: fw, faceTop: top, height: h) {
      out["crownY"] = Double(crown)
    }
    out["faceLuma"] = luma(of: image, rect: CGRect(x: left, y: h - top - fh, width: fw, height: fh))
    return out
  }

  /// Top of the hair: the mask is solid from the face up to the crown and
  /// empty above it, so the share of covered samples in a column above the
  /// face gives the hair height whichever way the bitmap rows run.
  private func crownY(mask: CIImage, faceLeft: CGFloat, faceWidth: CGFloat, faceTop: CGFloat, height: CGFloat) -> CGFloat? {
    let colX = faceLeft + faceWidth * 0.3
    let colW = max(faceWidth * 0.4, 1)
    let stripBottom = max(height - faceTop, 0)
    let strip = CGRect(x: colX, y: stripBottom, width: colW, height: max(height - stripBottom, 1))
    let rows = 256
    let column = mask.cropped(to: strip)
      .transformed(by: CGAffineTransform(translationX: -strip.minX, y: -strip.minY))
      .transformed(by: CGAffineTransform(scaleX: 1 / strip.width, y: CGFloat(rows) / strip.height))
    var pixels = [UInt8](repeating: 0, count: rows * 4)
    context.render(column, toBitmap: &pixels, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: rows),
                   format: .RGBA8, colorSpace: nil)
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
                   format: .RGBA8, colorSpace: srgb)
    return 0.299 * Double(px[0]) + 0.587 * Double(px[1]) + 0.114 * Double(px[2])
  }

  // MARK: render one photo

  /// RGBA8 pixels of [image] inside [rect], first row = top of the picture.
  private func pixels(_ image: CIImage, _ rect: CGRect) throws -> [UInt8] {
    guard let cg = context.createCGImage(image, from: rect, format: .RGBA8, colorSpace: srgb) else {
      throw fail(2, "render failed")
    }
    let w = cg.width, h = cg.height
    var buffer = [UInt8](repeating: 0, count: w * h * 4)
    let ok = buffer.withUnsafeMutableBytes { raw -> Bool in
      guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                bytesPerRow: w * 4, space: srgb,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
      ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
      return true
    }
    if !ok { throw fail(2, "bitmap failed") }
    return buffer
  }

  private func render(_ args: [String: Any]) throws -> [String: Any] {
    let path = args["path"] as! String
    let crop = args["crop"] as! [String: Double]
    let outW = args["outWidth"] as! Int
    let outH = args["outHeight"] as! Int
    let argb = args["background"] as! Int
    let replace = args["replaceBackground"] as? Bool ?? true
    let userEV = args["exposure"] as? Double ?? 0
    let level = args["level"] as? String ?? "standard"
    let heightMm = args["heightMm"] as? Double ?? 40
    let dpi = args["dpi"] as? Int ?? 300
    let face = args["face"] as? [String: Double]
    let crownSrc = args["crownY"] as? Double
    let chinSrc = args["chinY"] as? Double

    let source = try load(path: path)
    let image = source.image
    let srcH = Double(image.extent.height)
    let left = crop["left"]!, top = crop["top"]!, cw = crop["width"]!, ch = crop["height"]!

    // Work at twice the output size, then scale down: cleaner hair edges.
    let W = outW * 2, H = outH * 2, N = W * H
    let sx = Double(W) / cw, sy = Double(H) / ch
    let toWork = CGAffineTransform(translationX: CGFloat(-left), y: CGFloat(-(srcH - top - ch)))
      .concatenating(CGAffineTransform(scaleX: CGFloat(sx), y: CGFloat(sy)))
    let rect = CGRect(x: 0, y: 0, width: W, height: H)

    let rgba = try pixels(image.clampedToExtent().transformed(by: toWork).cropped(to: rect), rect)
    var alpha = [Float](repeating: 1, count: N)
    var hasMask = false
    if let mask = fullMask(source) {
      let m = try pixels(mask.clampedToExtent().transformed(by: toWork).cropped(to: rect), rect)
      for i in 0..<N { alpha[i] = Float(m[i * 4]) / 255 }
      hasMask = true
    }

    // The untouched crop, for the before/after view.
    let beforePath = (args["before"] as? Bool ?? false)
      ? try writeJPEG(try downscale(rgba, W, H, outW, outH), dpi: dpi, prefix: "before")
      : nil

    // Linear light, so gains behave like a camera's exposure.
    var lut = [Float](repeating: 0, count: 256)
    for v in 0..<256 { lut[v] = powf(Float(v) / 255, 2.2) }
    var r = [Float](repeating: 0, count: N), g = r, b = r
    for i in 0..<N {
      r[i] = lut[Int(rgba[i * 4])]; g[i] = lut[Int(rgba[i * 4 + 1])]; b[i] = lut[Int(rgba[i * 4 + 2])]
    }

    // Face box in work pixels (inner part only, to skip hair and background).
    var fx0 = W / 4, fx1 = W * 3 / 4, fy0 = H / 4, fy1 = H * 3 / 5
    if let f = face {
      fx0 = Int(((f["left"]! + f["width"]! * 0.2) - left) * sx)
      fx1 = Int(((f["left"]! + f["width"]! * 0.8) - left) * sx)
      fy0 = Int(((f["top"]! + f["height"]! * 0.25) - top) * sy)
      fy1 = Int(((f["top"]! + f["height"]! * 0.85) - top) * sy)
    }
    fx0 = max(0, min(W - 2, fx0)); fx1 = max(fx0 + 1, min(W - 1, fx1))
    fy0 = max(0, min(H - 2, fy0)); fy1 = max(fy0 + 1, min(H - 1, fy1))
    let midX = (fx0 + fx1) / 2

    func lin(_ i: Int) -> Float { 0.2126 * r[i] + 0.7152 * g[i] + 0.0722 * b[i] }
    func faceStats() -> (all: Float, left: Float, right: Float) {
      var sl: Float = 0, sr: Float = 0, nl = 0, nr = 0
      for y in fy0...fy1 { for x in fx0...fx1 {
        let v = lin(y * W + x)
        if x < midX { sl += v; nl += 1 } else { sr += v; nr += 1 }
      } }
      let l = sl / Float(max(nl, 1)), rr = sr / Float(max(nr, 1))
      return ((sl + sr) / Float(max(nl + nr, 1)), l, rr)
    }

    // 1. White balance from a plain, light background (never from skin).
    var bgSum: (Float, Float, Float) = (0, 0, 0), bgN = 0
    if hasMask {
      for i in stride(from: 0, to: N, by: 3) where alpha[i] < 0.05 {
        bgSum.0 += r[i]; bgSum.1 += g[i]; bgSum.2 += b[i]; bgN += 1
      }
    }
    if bgN > N / 60 {
      let mr = bgSum.0 / Float(bgN), mg = bgSum.1 / Float(bgN), mb = bgSum.2 / Float(bgN)
      let hi = max(mr, mg, mb), lo = min(mr, mg, mb), grey = (mr + mg + mb) / 3
      if hi > 0.05 && (hi - lo) / hi < 0.3 {
        let gr = min(max(grey / max(mr, 1e-4), 0.88), 1.12)
        let gg = min(max(grey / max(mg, 1e-4), 0.88), 1.12)
        let gb = min(max(grey / max(mb, 1e-4), 0.88), 1.12)
        for i in 0..<N { r[i] *= gr; g[i] *= gg; b[i] *= gb }
      }
    }

    // 2. Exposure: bring the face to a studio level, like a camera would.
    let before = faceStats()
    let target: Float = powf(0.62, 2.2)
    let gain = min(max(target / max(before.all, 1e-4), 0.75), 1.8) * powf(2, Float(userEV))
    for i in 0..<N { r[i] *= gain; g[i] *= gain; b[i] *= gain }

    // 3. Soften a shadow on one side of the face (not for strict documents):
    //    a smooth fill light on the darker side, the face itself untouched.
    if level != "strict" {
      let s = faceStats()
      let dark = min(s.left, s.right), bright = max(s.left, s.right)
      let balance = dark / max(bright, 1e-4)
      if balance < 0.9 {
        let k = min(1 / max(balance, 0.3) - 1, 0.6) * 0.7
        let darkLeft = s.left < s.right
        let cx = Float(fx0 + fx1) / 2, cy = Float(fy0 + fy1) / 2
        let rx = Float(fx1 - fx0) * 1.1, ry = Float(fy1 - fy0) * 1.3
        let y0 = max(0, Int(cy - ry)), y1 = min(H - 1, Int(cy + ry))
        let x0 = max(0, Int(cx - rx)), x1 = min(W - 1, Int(cx + rx))
        for y in y0...y1 { for x in x0...x1 {
          let dx = (Float(x) - cx) / rx, dy = (Float(y) - cy) / ry
          let d = sqrtf(dx * dx + dy * dy)
          if d >= 1 { continue }
          let side = darkLeft ? max(-dx, 0) : max(dx, 0)
          let fall = 1 - smoothstep(0.6, 1, d)
          let i = y * W + x
          let gi = 1 + k * min(side * 1.6, 1) * fall * alpha[i]
          r[i] *= gi; g[i] *= gi; b[i] *= gi
        } }
      }
    }

    // 3b. Skin care the user chose (all 0 unless they ask, or a CV default).
    //     Only skin inside the face oval changes: eyes, brows, lips and
    //     hair keep their detail, and nothing changes the shape of the face.
    if let bz = args["beauty"] as? [String: Double], let f = face {
      let smooth = Float(bz["smooth"] ?? 0), bright = Float(bz["brighten"] ?? 0)
      let even = Float(bz["even"] ?? 0), shine = Float(bz["shine"] ?? 0)
      let sharp = Float(bz["sharpen"] ?? 0)
      let lipsAmount = Float(bz["lips"] ?? 0)
      if lipsAmount > 0.001, let lips = lipsCache[path] {
        tintLips(&r, &g, &b, W: W, H: H, amount: lipsAmount,
                 outer: lips.outer.map { CGPoint(x: (Double($0.x) - left) * sx, y: (Double($0.y) - top) * sy) },
                 inner: lips.inner.map { CGPoint(x: (Double($0.x) - left) * sx, y: (Double($0.y) - top) * sy) })
      }
      if smooth + bright + even + shine + sharp > 0.001 {
        applyBeauty(&r, &g, &b, alpha: alpha, W: W, H: H,
                    face: CGRect(x: (f["left"]! - left) * sx, y: (f["top"]! - top) * sy,
                                 width: f["width"]! * sx, height: f["height"]! * sy),
                    smooth: smooth, bright: bright, even: even, shine: shine, sharp: sharp)
      }
    }

    // 4. Plain background with clean hair edges. The old background colour
    //    is estimated around each pixel and swapped for the new one, which
    //    removes the halo of the old wall that a plain blend leaves in hair.
    var replaced = false
    if replace && hasMask {
      let nr = Float((argb >> 16) & 0xFF) / 255, ng = Float((argb >> 8) & 0xFF) / 255, nb = Float(argb & 0xFF) / 255
      let br = powf(nr, 2.2), bgc = powf(ng, 2.2), bb = powf(nb, 2.2)
      var wr = [Float](repeating: 0, count: N), wg = wr, wb = wr, wd = wr
      for i in 0..<N {
        let inv = 1 - alpha[i]
        wr[i] = r[i] * inv; wg[i] = g[i] * inv; wb[i] = b[i] * inv; wd[i] = inv
      }
      let radius = max(W / 28, 4)
      for _ in 0..<2 {
        boxBlur(&wr, W, H, radius); boxBlur(&wg, W, H, radius)
        boxBlur(&wb, W, H, radius); boxBlur(&wd, W, H, radius)
      }
      for i in 0..<N {
        let a = smoothstep(0.06, 0.94, alpha[i])
        let den = wd[i]
        let er = den > 1e-3 ? wr[i] / den : br
        let eg = den > 1e-3 ? wg[i] / den : bgc
        let eb = den > 1e-3 ? wb[i] / den : bb
        var orr = r[i] + (1 - a) * (br - er)
        var og = g[i] + (1 - a) * (bgc - eg)
        var ob = b[i] + (1 - a) * (bb - eb)
        let keep = smoothstep(0.03, 0.3, a)
        orr = br + keep * (orr - br); og = bgc + keep * (og - bgc); ob = bb + keep * (ob - bb)
        r[i] = orr; g[i] = og; b[i] = ob
      }
      replaced = true
    }

    // Measurements on the finished picture.
    let after = faceStats()
    let faceLuma = Double(powf(min(after.all, 1), 1 / 2.2) * 255)
    let balance = Double(min(after.left, after.right) / max(max(after.left, after.right), 1e-4))
    var spread: Double? = nil
    if hasMask {
      var s: Double = 0, s2: Double = 0, n = 0
      for i in stride(from: 0, to: N, by: 2) where alpha[i] < 0.02 {
        let v = Double(powf(min(max(lin(i), 0), 1), 1 / 2.2) * 255)
        s += v; s2 += v * v; n += 1
      }
      if n > 100 { let m = s / Double(n); spread = sqrt(max(s2 / Double(n) - m * m, 0)) }
    }

    // Back to 8-bit sRGB, then down to the print size.
    var out = [UInt8](repeating: 255, count: N * 4)
    for i in 0..<N {
      out[i * 4] = UInt8(min(max(powf(max(r[i], 0), 1 / 2.2), 0), 1) * 255 + 0.5)
      out[i * 4 + 1] = UInt8(min(max(powf(max(g[i], 0), 1 / 2.2), 0), 1) * 255 + 0.5)
      out[i * 4 + 2] = UInt8(min(max(powf(max(b[i], 0), 1 / 2.2), 0), 1) * 255 + 0.5)
    }
    let final = try downscale(out, W, H, outW, outH)

    var result: [String: Any] = [
      "path": try writeJPEG(final, dpi: dpi, prefix: "photo"),
      "faceLuma": faceLuma,
      "faceBalance": balance,
      "backgroundReplaced": replaced,
    ]
    if let s = spread { result["backgroundSpread"] = s }
    if let b = beforePath { result["beforePath"] = b }
    if let crown = crownSrc, let chin = chinSrc {
      result["headMm"] = (chin - crown) / ch * heightMm
      result["topMarginMm"] = (crown - top) / ch * heightMm
    }
    return result
  }

  /// 8-bit RGBA at twice the print size, scaled down with Lanczos.
  private func downscale(_ bytes: [UInt8], _ W: Int, _ H: Int, _ outW: Int, _ outH: Int) throws -> CGImage {
    guard let provider = CGDataProvider(data: Data(bytes) as CFData),
          let big = CGImage(width: W, height: H, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: W * 4,
                            space: srgb, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
      throw fail(3, "image failed")
    }
    let small = CIImage(cgImage: big).applyingFilter("CILanczosScaleTransform", parameters: [
      kCIInputScaleKey: Double(outH) / Double(H), kCIInputAspectRatioKey: 1.0,
    ]).cropped(to: CGRect(x: 0, y: 0, width: outW, height: outH))
    guard let image = context.createCGImage(small, from: CGRect(x: 0, y: 0, width: outW, height: outH),
                                            format: .RGBA8, colorSpace: srgb) else {
      throw fail(3, "scale failed")
    }
    return image
  }

  /// A natural rose tint on the lips, keeping their own light and texture.
  private func tintLips(_ r: inout [Float], _ g: inout [Float], _ b: inout [Float],
                        W: Int, H: Int, amount: Float, outer: [CGPoint], inner: [CGPoint]) {
    let xs = outer.map { $0.x }, ys = outer.map { $0.y }
    let pad: CGFloat = 6
    let x0 = max(0, Int((xs.min() ?? 0) - pad)), x1 = min(W - 1, Int((xs.max() ?? 0) + pad))
    let y0 = max(0, Int((ys.min() ?? 0) - pad)), y1 = min(H - 1, Int((ys.max() ?? 0) + pad))
    guard x1 > x0 + 2, y1 > y0 + 2 else { return }
    let w = x1 - x0 + 1, h = y1 - y0 + 1

    // Rasterise the lip shape (outer minus open mouth), then feather it.
    var mask = [UInt8](repeating: 0, count: w * h)
    let gray = CGColorSpaceCreateDeviceGray()
    mask.withUnsafeMutableBytes { buf in
      guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                bytesPerRow: w, space: gray, bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
      // CGContext has its origin at the bottom left; flip so rows run top down.
      ctx.translateBy(x: 0, y: CGFloat(h))
      ctx.scaleBy(x: 1, y: -1)
      func shape(_ pts: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        p.addLines(between: pts.map { CGPoint(x: $0.x - CGFloat(x0), y: $0.y - CGFloat(y0)) })
        p.closeSubpath()
        return p
      }
      ctx.setFillColor(gray: 1, alpha: 1)
      ctx.addPath(shape(outer))
      ctx.fillPath()
      if inner.count > 4 {
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.addPath(shape(inner))
        ctx.fillPath()
      }
    }
    var m = mask.map { Float($0) / 255 }
    boxBlur(&m, w, h, max(2, w / 40))

    // Target colour: a soft rose, applied as colour only (light kept).
    let tr = powf(0.78, 2.2), tg = powf(0.36, 2.2), tb = powf(0.42, 2.2)
    let tl = 0.2126 * tr + 0.7152 * tg + 0.0722 * tb
    for y in 0..<h { for x in 0..<w {
      let k = 0.55 * amount * m[y * w + x]
      if k < 0.002 { continue }
      let i = (y + y0) * W + x + x0
      let l = 0.2126 * r[i] + 0.7152 * g[i] + 0.0722 * b[i]
      let s = l / tl
      r[i] += k * (tr * s - r[i]); g[i] += k * (tg * s - g[i]); b[i] += k * (tb * s - b[i])
    } }
  }

  /// Skin smoothing, brightening, even tone, less shine and a little
  /// sharpening, limited to a soft oval around the face and to skin tones.
  private func applyBeauty(_ r: inout [Float], _ g: inout [Float], _ b: inout [Float],
                           alpha: [Float], W: Int, H: Int, face: CGRect,
                           smooth: Float, bright: Float, even: Float, shine: Float, sharp: Float) {
    // Oval a little larger than the detected face (forehead, cheeks, jaw).
    let cx = Float(face.midX), cy = Float(face.midY) - Float(face.height) * 0.02
    let rx = Float(face.width) * 0.62, ry = Float(face.height) * 0.68
    let x0 = max(0, Int(cx - rx)), x1 = min(W - 1, Int(cx + rx))
    let y0 = max(0, Int(cy - ry)), y1 = min(H - 1, Int(cy + ry))
    guard x1 > x0 + 8, y1 > y0 + 8 else { return }
    let w = x1 - x0 + 1, h = y1 - y0 + 1, n = w * h

    // Region copies, and a skin weight per pixel (0…1).
    var cr = [Float](repeating: 0, count: n), cg = cr, cb = cr, skin = cr, oval = cr
    for y in 0..<h { for x in 0..<w {
      let i = (y + y0) * W + x + x0, j = y * w + x
      cr[j] = r[i]; cg[j] = g[i]; cb[j] = b[i]
      let dx = (Float(x + x0) - cx) / rx, dy = (Float(y + y0) - cy) / ry
      let o = (1 - smoothstep(0.75, 1, sqrtf(dx * dx + dy * dy))) * alpha[i]
      oval[j] = o
      // Skin test in gamma space (YCbCr), soft edges.
      let sr = powf(min(max(r[i], 0), 1), 1 / 2.2) * 255
      let sg = powf(min(max(g[i], 0), 1), 1 / 2.2) * 255
      let sb = powf(min(max(b[i], 0), 1), 1 / 2.2) * 255
      let cbv = 128 - 0.168736 * sr - 0.331264 * sg + 0.5 * sb
      let crv = 128 + 0.5 * sr - 0.418688 * sg - 0.081312 * sb
      let inCb = smoothstep(70, 80, cbv) * (1 - smoothstep(125, 135, cbv))
      let inCr = smoothstep(128, 136, crv) * (1 - smoothstep(170, 180, crv))
      skin[j] = o * inCb * inCr
    } }
    func lum(_ r: Float, _ g: Float, _ b: Float) -> Float { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    // Even tone: pull colour (not light) toward the wide local average.
    if even > 0 {
      var mr = cr, mg = cg, mb = cb
      let rad = max(Int(face.width) / 10, 4)
      for _ in 0..<2 { boxBlur(&mr, w, h, rad); boxBlur(&mg, w, h, rad); boxBlur(&mb, w, h, rad) }
      for j in 0..<n where skin[j] > 0.01 {
        let l = lum(cr[j], cg[j], cb[j]), lm = max(lum(mr[j], mg[j], mb[j]), 1e-4)
        let k = 0.45 * even * skin[j], s = l / lm
        cr[j] += k * (mr[j] * s - cr[j]); cg[j] += k * (mg[j] * s - cg[j]); cb[j] += k * (mb[j] * s - cb[j])
      }
    }

    // Smooth: remove fine texture where it is small (pores, blemishes),
    // keep strong edges (eyes, brows, nostrils, lips).
    if smooth > 0 {
      var br = cr, bg = cg, bb = cb
      let rad = max(Int(face.width) / 55, 2)
      for _ in 0..<2 { boxBlur(&br, w, h, rad); boxBlur(&bg, w, h, rad); boxBlur(&bb, w, h, rad) }
      for j in 0..<n where skin[j] > 0.01 {
        let d = abs(lum(cr[j], cg[j], cb[j]) - lum(br[j], bg[j], bb[j]))
        let keepEdge = expf(-(d / 0.035) * (d / 0.035))
        let k = 0.85 * smooth * skin[j] * keepEdge
        cr[j] += k * (br[j] - cr[j]); cg[j] += k * (bg[j] - cg[j]); cb[j] += k * (bb[j] - cb[j])
      }
    }

    // Less shine: soften the brightest skin highlights.
    if shine > 0 {
      for j in 0..<n where skin[j] > 0.01 {
        let l = lum(cr[j], cg[j], cb[j])
        let k = 1 - 0.35 * shine * skin[j] * smoothstep(0.42, 0.85, l)
        cr[j] *= k; cg[j] *= k; cb[j] *= k
      }
    }

    // Brighter skin, mostly in the shadows so highlights do not clip.
    if bright > 0 {
      for j in 0..<n where skin[j] > 0.01 {
        let l = lum(cr[j], cg[j], cb[j])
        let k = 1 + 0.4 * bright * skin[j] * (1 - smoothstep(0.35, 0.8, l))
        cr[j] *= k; cg[j] *= k; cb[j] *= k
      }
    }

    // Sharpen eyes, brows and hair edges inside the oval (not skin).
    if sharp > 0 {
      var br = cr, bg = cg, bb = cb
      for _ in 0..<2 { boxBlur(&br, w, h, 2); boxBlur(&bg, w, h, 2); boxBlur(&bb, w, h, 2) }
      for j in 0..<n where oval[j] > 0.01 {
        let k = 0.9 * sharp * oval[j] * (1 - 0.7 * skin[j])
        cr[j] += k * (cr[j] - br[j]); cg[j] += k * (cg[j] - bg[j]); cb[j] += k * (cb[j] - bb[j])
      }
    }

    for y in 0..<h { for x in 0..<w {
      let i = (y + y0) * W + x + x0, j = y * w + x
      r[i] = cr[j]; g[i] = cg[j]; b[i] = cb[j]
    } }
  }

  private func smoothstep(_ e0: Float, _ e1: Float, _ x: Float) -> Float {
    let t = min(max((x - e0) / (e1 - e0), 0), 1)
    return t * t * (3 - 2 * t)
  }

  /// Box blur in place (running sums, rows then columns), edges clamped.
  private func boxBlur(_ v: inout [Float], _ w: Int, _ h: Int, _ r: Int) {
    var tmp = [Float](repeating: 0, count: w * h)
    let span = Float(2 * r + 1)
    v.withUnsafeMutableBufferPointer { src in
      tmp.withUnsafeMutableBufferPointer { dst in
        for y in 0..<h {
          let row = y * w
          var acc: Float = 0
          for k in -r...r { acc += src[row + min(max(k, 0), w - 1)] }
          for x in 0..<w {
            dst[row + x] = acc / span
            acc += src[row + min(x + r + 1, w - 1)] - src[row + max(x - r, 0)]
          }
        }
        for x in 0..<w {
          var acc: Float = 0
          for k in -r...r { acc += dst[min(max(k, 0), h - 1) * w + x] }
          for y in 0..<h {
            src[y * w + x] = acc / span
            acc += dst[min(y + r + 1, h - 1) * w + x] - dst[max(y - r, 0) * w + x]
          }
        }
      }
    }
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

  // MARK: storage and reminders

  /// Folder for the user's saved photos; kept out of iCloud backups' cache
  /// purge because Application Support is never cleared by the system.
  private func appDir() -> String {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let dir = base.appendingPathComponent("photos", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.path
  }

  /// A local notification at `at` (ms since epoch). Asks for permission the
  /// first time; returns false when the user declines.
  private func scheduleReminder(_ args: [String: Any], result: @escaping FlutterResult) {
    let id = args["id"] as! String
    let at = Date(timeIntervalSince1970: (args["at"] as! Double) / 1000)
    let content = UNMutableNotificationContent()
    content.title = args["title"] as? String ?? ""
    content.body = args["body"] as? String ?? ""
    content.sound = .default
    let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: at)
    let request = UNNotificationRequest(
      identifier: id, content: content,
      trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
    let center = UNUserNotificationCenter.current()
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      guard granted else {
        DispatchQueue.main.async { result(false) }
        return
      }
      center.add(request) { error in
        DispatchQueue.main.async { result(error == nil) }
      }
    }
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

  /// limit 1: returns one path or nil. limit 0 or > 1: returns a list.
  private func pickPhoto(limit: Int, result: @escaping FlutterResult) {
    guard let top = topController() else { result(nil); return }
    var config = PHPickerConfiguration()
    config.filter = .images
    config.selectionLimit = limit
    let picker = PHPickerViewController(configuration: config)
    picker.delegate = self
    pickResult = result
    pickLimit = limit
    top.present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard let done = pickResult else { return }
    pickResult = nil
    let single = pickLimit == 1
    let providers = results.map { $0.itemProvider }
      .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
    if providers.isEmpty {
      if single { done(nil) } else { done([String]()) }
      return
    }

    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vimai", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    var paths = [String?](repeating: nil, count: providers.count)
    let lock = NSLock()
    let group = DispatchGroup()
    for (i, provider) in providers.enumerated() {
      group.enter()
      provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
        if let url = url {
          let ext = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
          let dest = dir.appendingPathComponent("picked-\(UUID().uuidString).\(ext)")
          if (try? FileManager.default.copyItem(at: url, to: dest)) != nil {
            lock.lock(); paths[i] = dest.path; lock.unlock()
          }
        }
        group.leave()
      }
    }
    group.notify(queue: .main) {
      let list = paths.compactMap { $0 }
      if single { done(list.first) } else { done(list) }
    }
  }
}
