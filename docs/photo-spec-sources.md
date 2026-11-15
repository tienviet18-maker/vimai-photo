# Photo standard sources

Checked 2026-11-15. Re-check before each store release.

| Spec id | Size (H×W mm) | Validity | Source | Status |
| --- | --- | --- | --- | --- |
| jp_residence | 40 × 30 | 6 months | [出入国在留管理庁 提出写真の規格](https://www.moj.go.jp/isa/applications/status/photo_info_00002.html) | Verified. Head size is only in the page's figure → fill `headHeightMm` / `topMarginMm` from it. Since 2026-06-14 a photo is required from age 1 ([ISA](https://www.moj.go.jp/isa/applications/procedures/nyuukokukanri10_00013.html)). |
| jp_resume | 40 × 30 | 3 months (convention) | No legal standard | De-facto size; companies may differ. |
| jp_mynumber | 45 × 35 | 6 months | [J-LIS / 総務省 leaflet](https://www.soumu.go.jp/main_content/000691750.pdf) | Verified. Online applications take a 480–6000 px JPEG instead. |
| jp_passport | 45 × 35, head 34±2, top 4±2 | 6 months | [外務省](https://www.mofa.go.jp/mofaj/toko/passport/ic_photo.html), [宮城県](https://www.pref.miyagi.jp/site/passport/photo.html) | Verified. |
| jp_driver_license | 30 × 24 | 6 months | [島根県警察](https://www.pref.shimane.lg.jp/police/03_drivers_license/various_fees/oshirase/shinsei_photo.html), [香川県警察](https://www.pref.kagawa.lg.jp/police/menkyo/tetsuzuki/index.html) | Verified. Upper third of body; no retouching. International licence uses a different size by prefecture (45×35 or 50×40) — not included. |
| vn_passport | 60 × 40 (?) | ? | — | **Unverified.** Confirm with the Embassy of Viet Nam in Japan / Consulate General in Osaka. |
| us_visa | 51 × 51 | 6 months | [travel.state.gov](https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos.html) | **Unverified.** Confirm head size range. |
