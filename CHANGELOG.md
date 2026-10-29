# Changelog

Perubahan penting pada **Nexora** (`nexora_mobile`).

## [1.0.1] — 2026-10-28

### Changed

- OAuth redirect disamakan dengan NEXIA: `amazink-absensi://login-callback`.
- Palet UI violet (`HomeTokens`, login/splash, dynamic sky siang).
- Logo `nexora.png` di-recolor dari sumber nexia (`dart run tool/recolor_brand_logo.dart`).

## [1.0.0] — 2026-10-27

### Added

- Clone awal dari `hris_mobile` (NEXIA) dengan identitas app terpisah.
- Package Dart `nexora_mobile`, Android/iOS `com.nexora.amazinkpeoplegroup`.
- OAuth redirect sama NEXIA: `amazink-absensi://login-callback`.
- Palet UI violet + logo brand di-recolor.
- Branding Nexora, launcher `lib/assets/logo/nexora.png`.

### Notes

- Backend & OAuth client sama dengan NEXIA; tambahkan redirect URI Nexora di APG OneId sebelum UAT login.
- Lihat [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) untuk konfigurasi FCM.
