# TaskPoint

**A localized peer-to-peer labour marketplace for Pakistan's Tier‑2 cities.**

TaskPoint connects daily-wage workers — plumbers, electricians, carpenters, masons — directly with customers nearby, replacing the street-corner *adda* where workers wait hours for work and customers have no price transparency or identity verification.

Built with Flutter for **Android and Web**, on a shared Firebase backend.

<p>
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.44-02569B?logo=flutter&logoColor=white">
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart&logoColor=white">
  <img alt="Firebase" src="https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore%20%7C%20Storage-FFCA28?logo=firebase&logoColor=black">
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-Android%20%7C%20Web-success">
</p>

---

## The problem

In cities like Gujranwala, the informal labour market runs entirely offline. Workers lose 3–5 hours a day waiting for jobs, and residents get no price transparency, no identity verification, and no safety guarantees.

TaskPoint digitises that market **without removing what makes it work** — workers keep their autonomy, and the local bargaining culture (*mol tol*) is preserved through a constrained bid-and-counter-offer flow rather than fixed corporate pricing.

## Features

### For customers (Service Seekers)
- **Phone + OTP sign-in** — no passwords, no email required
- **Post a job by category** or by **Roman Urdu voice search** (*"mujhe plumber chahiye"*, *"nal se paani leak ho raha hai"*)
- **Nearby provider discovery** on a live Google Map, filtered by service radius
- **Review bids and negotiate** — accept a price or send one counter-offer
- **Live tracking** of the provider en route, with distance updates
- **Emergency SOS** during an active job, with saved emergency contacts
- **Rate and review** on completion

### For workers (Service Providers)
- **Go online/offline** to control availability
- **Real-time job alerts** for open jobs within your service radius
- **Bid or counter-offer** on jobs
- **Navigate to the customer** with live location sharing
- **Complete jobs with before/after photos**
- **Digital wallet** — earnings, transaction history, manual top-ups
- **Performance insights** — weekly earnings, ratings, completed jobs

### Trust & safety
- **CNIC identity verification** — front/back capture, reviewed by an admin before a user can take or post work
- **Emergency SOS** logging with GPS coordinates
- **Report and block** users; privacy controls for profile visibility and live location
- **Remote device management** — see and revoke signed-in sessions

## Tech stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) — single codebase for Android + Web |
| Auth | Firebase Authentication (Phone / OTP) |
| Database | Cloud Firestore (real-time listeners) |
| File storage | Firebase Storage (CNIC photos, job photos, payment proofs) |
| Maps | `google_maps_flutter` — live tracking and nearby discovery |
| Voice | `speech_to_text` — on-device speech recognition |
| Location | `geolocator` — GPS, distance, live position streaming |
| Media | `camera`, `image_picker` |
| Design | `google_fonts` (Be Vietnam Pro), `material_symbols_icons` |

> **Note on the voice feature:** speech recognition runs **on-device**, and the transcript is matched to a service category with a keyword/synonym matcher covering both English and Roman Urdu vocabulary. It does not call an external LLM, so it needs no API key and no audio leaves the device.

## Project structure

```
lib/
├── main.dart                 # App entry, route table, Firebase init
├── firebase_options.dart     # Generated Firebase config
├── models/                   # Firestore document models (User, Job, Review, …)
├── screens/                  # 45 screens — onboarding, seeker flow, provider flow
├── services/                 # 20 service classes — one per domain concern
├── theme/                    # Design system: colours, typography, spacing
└── widgets/                  # Shared UI (bottom nav, drawer, live map, …)
```

**Architecture:** screens never touch Firestore directly — every read/write goes through a service class in `lib/services/`. Session state is held in a singleton `ChangeNotifier` (`SessionController`) that streams the signed-in user's document, so any screen can read live profile data without re-fetching.

## Data model

Firestore collections, secured by [`firestore.rules`](firestore.rules):

| Collection | Purpose |
|---|---|
| `users/{uid}` | Profile, role, CNIC status, wallet balance, location |
| `jobs/{jobId}` | Job posting, status, accepted worker and price |
| `jobs/{jobId}/bids` | Worker bids and counter-offers |
| `jobs/{jobId}/messages` | In-job chat |
| `categories` | Service taxonomy shown on the home grid |
| `reviews` | Ratings, append-only |
| `transactions` | Wallet ledger |
| `wallet_topups` | Manual top-up requests awaiting confirmation |
| `sos_logs` | Emergency alerts with coordinates |
| `reports` | User reports and disputes |
| `admins/{uid}` | Admin allow-list (console-managed, never client-writable) |

## Getting started

### Prerequisites
- Flutter SDK **3.44+** (Dart 3.11+)
- A Firebase project with **Authentication (Phone)**, **Firestore**, and **Storage** enabled
- A Google Maps API key

### Setup

**1. Install dependencies**
```bash
flutter pub get
```

**2. Connect your Firebase project**
```bash
dart pub global activate flutterfire_cli
firebase login
flutterfire configure
```
This regenerates `lib/firebase_options.dart` and `android/app/google-services.json`.

**3. Add your Google Maps API key**

| Platform | File | Key needs |
|---|---|---|
| Android | `android/app/src/main/AndroidManifest.xml` | Maps SDK for Android |
| Web | `web/index.html` | Maps JavaScript API |

> ⚠️ **Restrict your key** in the Google Cloud Console (Application + API restrictions). An unrestricted key committed to a public repo can be used by anyone and billed to your account.

**4. Deploy security rules**
```bash
firebase deploy --only firestore:rules,storage:rules
```

### Run

```bash
flutter run                # Android device or emulator
flutter run -d chrome      # Web
```

### Test

```bash
flutter test
```

## Admin dashboard

Moderation happens in a **separate Flutter Web app** (`taskpoint_admin`), which shares this Firebase project. Several flows here are inert without it — CNIC submissions stay `pending`, and wallet top-ups are never credited — because both require human review.

The dashboard provides: live metrics, CNIC verification queue, wallet top-up approval, reports moderation, SOS alerts, user management, job oversight, and category management.

## Platform support

| Platform | Status |
|---|---|
| Android | ✅ Supported |
| Web | ✅ Supported |
| iOS | ❌ Not configured |

## Known limitations

Stated plainly, since this is an academic project:

- **Payments are not automated.** Wallet top-ups are manual EasyPaisa/JazzCash transfers with a proof screenshot, confirmed by an admin. There is no payment-gateway integration.
- **CNIC verification is manual.** Photos are uploaded and reviewed by a human; there is no automated OCR or NADRA API check.
- **SOS does not dial out.** Sending SMS or placing calls automatically is a device/carrier capability outside the app's scope; SOS logs the alert with GPS and surfaces the user's emergency contacts for one-tap calling.
- **Geo-queries are client-side.** Firestore has no native radius query, so nearby matching pulls a bounded page and filters by Haversine distance — appropriate at this scale, not at city-wide volume.

## License

Released under the MIT License — see [LICENSE](LICENSE).

## Author

**TaskPoint** — BSCS Final Year Project
[@taskpointdot](https://github.com/taskpointdot)
