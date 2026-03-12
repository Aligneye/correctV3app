# correctv1

Flutter app for AlignEye posture tracking and BLE device control.

## App overview

- `lib/home`: main dashboard with posture analytics and BLE controls
- `lib/bluetooth`: device connection manager + telemetry parsing
- `lib/calibration`: calibration flow for the connected device
- `lib/auth`: Supabase auth flow (login, signup, forgot password, Google login)

## Supabase auth setup

This app expects Supabase keys through dart-define flags.

### 1) Create Supabase project

- Copy your project URL
- Copy your anon key

### 2) Run app with keys

```bash
flutter run --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

If keys are missing, app shows a configuration screen and can still continue without login.

### 3) Enable providers in Supabase

- `Authentication -> Providers -> Email` (for login/signup/reset)
- `Authentication -> Providers -> Google` (for Google OAuth)

For Google OAuth, add your redirect URL in Supabase allowed redirects. This code uses:

`io.supabase.flutter://login-callback/`
