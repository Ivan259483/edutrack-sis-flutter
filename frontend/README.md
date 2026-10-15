# EduTrack SIS — Flutter app

The mobile version of EduTrack SIS: the Student Portal and the Admin Portal
in one app, on the same Express API and MongoDB database as the web portals.
One sign-in screen; after sign-in each role only reaches its own screens.

## Run

Start the backend first (`../backend`, `npm start`, port 5001). Then:

```bash
flutter run
```

The app calls `http://10.0.2.2:5001/api` on the Android emulator (the host
computer's localhost) and `http://localhost:5001/api` elsewhere. To use another
API, pass it at build time:

```bash
flutter build apk --dart-define=API_URL=https://edutrack-sis-api.vercel.app/api
```

Debug builds show the web's "Quick Demo Fill" buttons for the seeded demo
accounts; profile and release builds don't include them.

## Test

```bash
flutter test
```

`test/screens_test.dart` renders every student and admin screen on a phone-sized
window against real API responses (`test/fixtures/api.json`, captured from a
backend seeded with the demo data), and checks that admin changes send the full
record, as the API's PUT validation requires.

## Structure

- `lib/core` — API client (Dio, JWT header, sign-out on 401), session, router
  guards, theme, PDF printouts.
- `lib/features/auth` — sign-in and registration (email code).
- `lib/features/student` — the Student Portal screens.
- `lib/features/admin` — the Admin Portal: `data/admin_store.dart` loads
  `GET /api/admin/bootstrap` and saves each change through the REST API (full
  records on PUT, plus the activity log entry the web writes);
  `data/admin_rules.dart` holds the web portal's validation rules.
