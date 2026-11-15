# ViMai Photo

ID photos that meet Japanese document standards (在留カード, 履歴書, マイナンバー, パスポート, 運転免許証…), saved as an L-size sheet and printed at a convenience store for about ¥40.

Part of the [ViMai](https://vimai.jp) ecosystem. UI languages: Tiếng Việt, English, 日本語.

## Development

```bash
flutter pub get
flutter gen-l10n        # generates lib/l10n/app_localizations*.dart (gitignored)
flutter analyze
flutter test
flutter run
```

iOS release builds are made in Xcode on the iMac (not GitHub Actions). CI runs `analyze` + `test` on Linux for every PR.

## Structure

```
lib/
  core/specs/      PhotoSpec model + loader for assets/specs/photo_specs.json
  core/layout/     L-size print sheet layout (pure Dart, unit tested)
  core/locale/     language setting (device default, or vi/en/ja)
  features/        home (pick a document), spec_detail, settings
  l10n/            app_en.arb (template), app_vi.arb, app_ja.arb
assets/specs/      photo standards as data — change rules here, not in code
docs/              plan, sources for every standard
```

## Photo standards

Every spec in `assets/specs/photo_specs.json` has `verified` and `sourceUrl`. Specs with `verified: false` are hidden in release builds. See [docs/photo-spec-sources.md](docs/photo-spec-sources.md).

## Branches

- `main` — production. Changes land only through pull requests.
- `feature/*`, `fix/*` — work branches.
- `bootstrap/*` — one-time: CI generates `ios/` and `android/` with `flutter create`.
