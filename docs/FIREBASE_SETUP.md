# Firebase — Nexora (`com.nexora.amazinkpeoplegroup`)

File `google-services.json` dan `GoogleService-Info.plist` di repo ini hanya **placeholder** (package/bundle sudah disesuaikan). Push notification membutuhkan app terdaftar di Firebase.

## Langkah

1. Buka [Firebase Console](https://console.firebase.google.com/) — bisa project yang sama dengan NEXIA.
2. **Tambah app Android** dengan package `com.nexora.amazinkpeoplegroup`.
3. Unduh `google-services.json` → ganti `android/app/google-services.json`.
4. **Tambah app iOS** dengan bundle `com.nexora.amazinkpeoplegroup`.
5. Unduh `GoogleService-Info.plist` → ganti `ios/Runner/GoogleService-Info.plist`.
6. Isi variabel `FIREBASE_*` di `.env` (gunakan `FIREBASE_APP_ID_ANDROID` / `FIREBASE_APP_ID_IOS` jika berbeda).

Tanpa langkah di atas, build bisa sukses tetapi FCM tidak berfungsi.
