# Patwari — Chauhaddi App (चतुर्सीमा)

A Flutter mobile application that digitises the *Chaturseema* (चतुर्सीमा) document workflow for Indian land revenue officers (Patwaris). Instead of hand-written boundary certificates, Patwaris can create, store, and instantly share official PDF records from their phone.

---

## What is a Chaturseema?

A *Chaturseema* is an official land-boundary certificate issued by a Patwari. It records the four cardinal boundaries (North / South / East / West) of a plot — identified by its Khasra number — along with the landowner's details and area in Hectares or Acres.

---

## Features

| Feature | Description |
|---|---|
| **Authentication** | Phone OTP (Indian +91) or Google Sign-In via Firebase Auth |
| **Profile setup** | One-time setup of jurisdiction — District, Tehsil, RI Circle, Halka numbers, and assigned Villages |
| **Create Chaturseema** | Form-based data entry for applicant details, Khasra number, area, and four boundaries |
| **Farmer autocomplete** | TypeAhead search against a per-Patwari farmer directory stored in Firestore |
| **PDF generation** | Generates a Devanagari (Hindi) PDF using Syncfusion Flutter PDF with a QR code for verification |
| **Cloud upload** | PDF is uploaded to Firebase Storage; a shareable download URL is saved in Firestore |
| **History log** | Real-time list of all generated records, sorted by date, searchable by name, Khasra number, or date |
| **Clone form** | Pre-fill the creation form from any past record for faster repeat entries |
| **Share** | Share the generated PDF via any installed app (WhatsApp, Email, etc.) using the native OS share sheet |

---

## Tech Stack

### Framework
- **Flutter** (Dart SDK `^3.11.5`) — cross-platform UI toolkit targeting Android and iOS

### State Management
- **Provider** (`^6.1.1`) — lightweight `ChangeNotifier`-based state management

### Backend — Firebase
| Service | Package | Purpose |
|---|---|---|
| Firebase Core | `firebase_core ^2.32.0` | Initialises the Firebase app |
| Firebase Auth | `firebase_auth ^4.15.3` | Phone OTP & credential sign-in |
| Cloud Firestore | `cloud_firestore ^4.17.2` | Stores Patwari profiles, farmer directories, and generated form metadata |
| Firebase Storage | `firebase_storage ^11.7.0` | Hosts the generated PDF files |

### Authentication
- **Google Sign-In** (`google_sign_in ^6.2.1`) — OAuth 2.0 login on Android

### PDF & Documents
- **Syncfusion Flutter PDF** (`syncfusion_flutter_pdf ^24.1.41`) — programmatic PDF creation with full Devanagari (Unicode) text support
- **QR Flutter** (`qr_flutter ^4.1.0`) — embedded QR code in each certificate for verification

### File Handling & Sharing
- **Share Plus** (`share_plus ^9.0.0`) — invokes the native OS share sheet
- **Path Provider** (`path_provider ^2.1.3`) — resolves local device file paths for PDF caching

### UI Utilities
- **Flutter TypeAhead** (`flutter_typeahead ^5.0.0`) — live farmer-name autocomplete backed by Firestore
- **URL Launcher** (`url_launcher ^6.2.5`) — opens PDF download links in an external browser or viewer
- **Google Fonts / Noto Sans Devanagari** (`google_fonts ^6.2.1`) — renders Hindi text correctly throughout the UI
- **intl** (`intl ^0.19.0`) — date formatting for the history log

---

## Project Structure

```
lib/
├── main.dart                        # App entry point, Firebase init, routing
├── firebase_options.dart            # Auto-generated Firebase config
├── model/
│   └── patwari_model.dart           # PatwariProfile data class
├── providers/
│   └── patwari_provider.dart        # ChangeNotifier: profile fetch & save
├── screens/
│   ├── auth_screen.dart             # Phone OTP + Google Sign-In
│   ├── profile_setup_screen.dart    # One-time jurisdiction setup
│   ├── history_screen.dart          # Real-time record list with search
│   └── create_chaturseema_screen.dart # Form to create & generate a record
└── utils/
    └── pdf_generator.dart           # PDF generation and Firebase Storage upload
```

---

## App Flow

```
Launch
  └─► Auth Screen
        ├─ New user  ──► Profile Setup ──► History Screen
        └─ Existing  ──────────────────►  History Screen
                                               │
                                    [+ New Chaturseema]
                                               │
                                    Create Chaturseema Screen
                                               │
                                    Generate PDF ► Upload to Storage
                                               │
                                    Share / Download link
```

---

## Getting Started

### Prerequisites
- Flutter SDK `>=3.11.5`
- A Firebase project with **Authentication** (Phone & Google providers), **Firestore** (database ID: `patwari`), and **Storage** enabled
- `google-services.json` (Android) / `GoogleService-Info.plist` (iOS) placed in the correct platform directories

### Run

```bash
flutter pub get
flutter run
```

### Build

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ipa --release
```

---

## Notes

- The app is pre-configured for **Korba district, Chhattisgarh** (default district/tehsil values in the profile setup) but can be used for any jurisdiction by changing those fields during profile setup.
- The Noto Sans Devanagari font is bundled locally (`assets/fonts/`) to ensure correct Hindi rendering in both the UI and generated PDFs even without an internet connection.
