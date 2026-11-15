# ViMai Photo — notes for Claude

- Talk to the owner in Vietnamese; keep code, file names and commands in English.
- Plan doc: https://claude.ai/artifact/APpwQxzefravkjU82uz5HL (phases 0–5, Free vs Pro ¥700).
- Photo standards live in `assets/specs/photo_specs.json`. Never enable a spec (`verified: true`) without a source in `docs/photo-spec-sources.md`.
- Image processing stays on device. Nothing is uploaded except the later AI-outfit feature, behind explicit consent.
- Beauty / AI outfit must stay locked for passport, 在留カード and other official documents (rule `noEdit` or official spec).
- Branches: `main` = production, merge via PR only. Do not delete or weaken tests.
- iOS builds: Xcode on the owner's iMac. CI (Linux) runs analyze + test only.
- Before any App Store submit with IAP: production Worker must answer POST `/v1/apple/verify` with 401/400 (not 404), and both app and Worker IAP code must be merged to `main` and deployed.
- Never commit secrets (`.env`, keystores, Worker secrets).
