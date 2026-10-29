# Contributing

Terima kasih atas kontribusi pada **Nexora** (`nexora_mobile`) milik **HR Amazink People Group**.

## Setup

1. Clone monorepo / folder `nexora_mobile`.
2. Di root `nexora_mobile`:

```bash
cp .env.example .env
flutter pub get
```

3. Isi `.env` (API, OAuth, Firebase). Redirect OAuth sama NEXIA: `amazink-absensi://login-callback`.

Perubahan fitur besar sebaiknya di-port dari/ke `hris_mobile` secara disiplin agar tidak drift.
