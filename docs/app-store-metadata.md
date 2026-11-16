# App Store metadata (approved name set, 2026-11-16)

Paste into App Store Connect → App Information / version page. Limits: name 30,
subtitle 30, keywords 100, promotional text 170 characters. All values below fit.

The Japan storefront indexes the **Japanese** and **English (U.S.)** metadata,
so Vietnamese search words for users in Japan go in the en-US keyword field.
The Vietnamese localization serves the Vietnam storefront.
Keywords never repeat words already in the name or subtitle (they are indexed
anyway) and never name other apps.

Home-screen name (CFBundleDisplayName, `ios/Runner/*.lproj/InfoPlist.strings`):
ja 証明写真 · en ID Photo · vi Ảnh Thẻ.

## Shared

| Field | Value |
|---|---|
| Primary category | Photo & Video |
| Secondary category | Utilities |
| Price | Free, no in-app purchases |
| Age rating | 4+ |
| Privacy policy URL | https://vimai.jp/products/vimai-photo/privacy |
| Marketing URL | https://vimai.jp/products/vimai-photo |
| Support URL | https://vimai.jp/products/vimai-photo |
| App Privacy | Data Not Collected (photos are processed on the device; no analytics, no account) |
| Copyright | 2026 ViMai |

Review notes (all locales): "All photo processing (Apple Vision segmentation
and face landmarks, Google ML Kit face detection running on the device) happens
on the iPhone. Nothing is uploaded. No login. The app does not retouch faces
for official documents; only the background and light are corrected."

## Japanese (ja)

- **Name:** 証明写真 ViMai - 在留カード・履歴書
- **Subtitle:** パスポート・マイナンバーもコンビニ印刷
- **Keywords:** 運転免許,ビザ,就活,申請,プリント,L判,背景,白背景,自宅,スマホ,外国人,ベトナム,写真,ID
- **Promotional text:** 在留カード・履歴書・パスポートの証明写真を自宅で。背景を無地にしてサイズを実測、コンビニでL判に印刷できます。無料・登録不要。
- **Description:**

```
ViMaiの証明写真アプリは、日本の書類の規格に合う証明写真をiPhoneで撮れる無料アプリです。

■ 書類ごとの規格
在留カード（在留申請）、履歴書、マイナンバーカード、パスポート、運転免許証。写真サイズ・顔の大きさ・背景を書類ごとに設定済みです。

■ 撮影をガイド
規格どおりの撮影枠と6つのチェック、ベトナム語・英語・日本語の音声ガイド。条件がそろうと自動で撮影します。

■ 仕上げは自動
背景を白・薄い青の無地に置き換え、髪の輪郭は自然なまま。明るさと色を整え、mm単位で正しいサイズに切り抜きます。仕上がりの顔の大きさ（mm）・左右の明るさ・背景の均一さを実測してチェックします。

■ 顔は修整しません
目の拡大・美白・ほくろ消しなどは行いません。パスポートなどの公的書類は補正を最小限にしています。

■ 保存と印刷
L判・2L判の印刷シート（300 dpi、カットガイド付き）をコンビニのマルチコピー機で印刷。オンライン申請用のデータ写真も保存できます。「マイ写真」から再印刷や別の書類用の作り直しができ、期限が近づくとお知らせします。

■ プライバシー
写真はすべてiPhone内で処理し、サーバーには送りません。アカウント不要。

※ 写真を受け付けるかどうかは提出先が判断します。本アプリは行政機関とは関係ありません。
```

## English (en-US)

- **Name:** ID Photo Japan: Visa & Resume
- **Subtitle:** Passport photo & konbini print
- **Keywords:** anh the,ảnh thẻ,thẻ cư trú,ho chieu,rirekisho,residence card,my number,driver license,cv,id card
- **Promotional text:** ID photos at home for the residence card, rirekisho and passport: plain background, measured in mm, printed on an L sheet at any konbini. Free, no account.
- **Description:**

```
ViMai ID Photo takes ID photos that meet Japanese document rules, on your iPhone, for free.

DOCUMENTS
Residence card (visa applications), rirekisho CV, My Number card, passport, driving licence. Photo size, head size and background are set for each one.

GUIDED CAPTURE
A frame drawn to scale, six live checks and a voice guide in Vietnamese, English and Japanese. The app shoots by itself when everything is right.

AUTOMATIC FINISH
The background becomes plain white or light blue with natural hair edges. Light and colour are balanced and the photo is cut to the exact millimetre. Head size in mm, light on both sides of the face and background evenness are measured on the finished photo.

NO FACE RETOUCHING
No bigger eyes, whitening or removed moles. Official documents get only the minimum correction.

SAVE AND PRINT
L and 2L print sheets at 300 dpi with cutting guides, for the multi-function copiers at convenience stores, plus a digital photo for online applications. My photos keeps every photo for reprints or for another document, and reminds you before a photo gets too old.

PRIVACY
Everything is processed on your iPhone. Nothing is uploaded. No account.

The receiving office decides whether to accept a photo. This app is not affiliated with any government office.
```

## Vietnamese (vi)

- **Name:** Ảnh Thẻ Chuẩn Nhật - ViMai
- **Subtitle:** Thẻ cư trú, CV, in ở konbini
- **Keywords:** hộ chiếu,visa,xin việc,in ảnh,Nhật Bản,my number,bằng lái,nền trắng,người Việt,gia hạn,zairyu
- **Promotional text:** Chụp ảnh thẻ ở nhà đúng chuẩn thẻ cư trú, CV 履歴書, hộ chiếu: nền trơn, đo cỡ bằng mm, in tờ cỡ L ở konbini. Miễn phí, không cần tài khoản.
- **Description:**

```
ViMai Ảnh Thẻ giúp bạn chụp ảnh thẻ đúng quy định giấy tờ Nhật ngay trên iPhone, miễn phí.

GIẤY TỜ
Thẻ cư trú (gia hạn, đổi visa), CV 履歴書, thẻ My Number, hộ chiếu, bằng lái. Cỡ ảnh, cỡ đầu và màu nền đã cài sẵn cho từng loại.

HƯỚNG DẪN KHI CHỤP
Khung chụp đúng tỉ lệ, 6 đèn kiểm tra, giọng nói tiếng Việt, Anh, Nhật. App tự chụp khi đủ điều kiện.

TỰ HOÀN THIỆN
Thay nền trắng hoặc xanh nhạt, giữ viền tóc tự nhiên. Cân sáng, cân màu, cắt đúng từng mm. Đo lại cỡ đầu (mm), độ sáng hai bên mặt và độ trơn của nền trên ảnh đã xuất.

KHÔNG CHỈNH KHUÔN MẶT
Không phóng mắt, làm trắng da hay xoá nốt ruồi. Giấy tờ nhà nước chỉ được chỉnh ở mức tối thiểu.

LƯU VÀ IN
Tờ in cỡ L, 2L (300 dpi, có viền cắt) để in ở máy đa năng của konbini, và ảnh số để nộp hồ sơ online. Mục Ảnh của tôi giữ lại mọi ảnh để in lại hoặc làm lại cho giấy tờ khác, và nhắc bạn khi ảnh sắp quá hạn.

RIÊNG TƯ
Ảnh xử lý ngay trên iPhone, không gửi lên máy chủ. Không cần tài khoản.

Việc chấp nhận ảnh do nơi nhận hồ sơ quyết định. App không thuộc cơ quan nhà nước nào.
```

## Screenshots

6.9" (1320×2868) and 6.5" (1284×2778) per locale, in this order: Home, Capture
guide, Review with measured checks, Before/after, Print sheet, Done (konbini
steps). The FB set in `vimai-ecosystem/public/products/vimai-photo/` is the
reference; App Store screenshots must come from the real build, without the
vimai.jp watermark.
