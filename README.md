# Nexora

Build aplikasi **[nexora_mobile](../nexora_mobile)** dengan UI dan navigasi yang sama, untuk distribusi internal / peninjauan toko.

## Menjalankan

```bash
cd nexora
cp .env.example .env
flutter pub get
flutter run
```

- `LOCAL_LOGIN_MODE=true` (default): Splash → Login → **Masuk dengan APG OneId** → beranda (data contoh, tanpa backend).
- `LOCAL_LOGIN_MODE=false`: OAuth & API seperti `nexora_mobile` (isi `API_BASE_URL`, OAuth, Firebase).

Android / iOS: `com.nexora.amazinkpeoplegroup` · redirect OAuth: `amazink-absensi://login-callback`

## Repo terkait

| Folder | Peran |
|--------|--------|
| `hris_mobile` | NEXIA production |
| `nexora_mobile` | Nexora + API production |
| `nexora` | Nexora build peninjauan (repo ini) |
