# FieldLens — Dilapidation Survey Inspection App

[![Flutter](https://img.shields.io/badge/Flutter-3.x+-02569B?logo=flutter&logoColor=white)](https://flutter.dev) [![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey)](#)

FieldLens is a complete, production-ready, offline-first mobile application built with Flutter for conducting dilapidation surveys in the field. The app is designed to work entirely offline, storing all inspection data locally and allowing inspectors to capture photos, classify defects, and produce professional PDF and Excel reports for sharing or archiving.

Key goals:
- Work 100% offline — no server or internet required for core functionality.
- Provide a compact, touch-friendly interface optimized for field conditions (including sunlight/high-contrast scenarios).
- Produce printable/exportable reports (PDF / XLSX) for handover and analysis.

## Table of contents

- Features
- Architecture & Tech Stack
- Project structure
- Getting started
- Usage guide
- Database schema
- Export formats
- Testing
- Troubleshooting
- Deployment
- Contributing & License
- Contact

## 🎯 Features

### ✅ Offline-first
- All data stored locally in SQLite
- Full functionality available without network connectivity
- Designed to work in areas with no cellular coverage

### 🔐 Secure authentication
- Local user registration and login
- Passwords hashed with SHA256 + salt
- Session persistence and secure logout

### 📋 Dynamic assessment
- Photo capture (camera integration)
- Item numbering and location tagging
- Defect classification (Crack, Bent, Damage with specific codes)
- Impact categories (Minor / Moderate / Major)
- Preset comments + free-text notes

### 📊 Dashboard
- Inspector welcome and statistics
- Recent inspections and quick actions
- Profile management

### 📄 Export
- PDF reports with table layout and inspector header
- Excel (.xlsx) spreadsheets compatible with Excel/Sheets/LibreOffice
- Share via email/messaging or save to device storage

### 📱 Responsive UI
- Mobile-first layouts, tablet support, and Material 3 design
- High-contrast options for field visibility

## 🏗️ Architecture

This project follows a Clean Architecture approach with separation of concerns:
- Core layer: database, models, providers, and utilities
- UI layer: screens, widgets, and navigation

State management uses the Provider pattern for lightweight, predictable updates.

See ARCHITECTURE.md for more details.

## 🛠️ Tech stack

- Framework: Flutter 3.x+
- Language: Dart
- State management: Provider
- Database: SQLite (sqflite)
- PDF export: pdf package
- Excel export: excel package
- Camera: image_picker
- Crypto: crypto (SHA256)
- File sharing: share_plus

## 📦 Project structure (high level)

lib/
├── core/
│   ├── database/              # SQLite helpers
│   ├── models/                # Data models (User, InspectionReport)
│   ├── providers/             # State management providers
│   └── utils/                 # Utilities (e.g. password hasher)
├── ui/
│   ├── screens/               # App screens (auth, dashboard, assessment, export)
│   └── widgets/               # Reusable widgets
└── main.dart                  # App entry point

## 🚀 Getting started

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Android Studio (for Android) or Xcode (for iOS)
- Git

### Install & run

1. Clone the repository

```bash
git clone https://github.com/aishzy/fieldlens.git
cd fieldlens
```

2. Install dependencies

```bash
flutter pub get
```

3. Run the app (connected device or simulator)

```bash
flutter run
```

### Platform setup notes

Android:
- Minimum SDK: Android 5.0 (API 21)
- Target SDK: Android 14 (API 34)
- Ensure appropriate runtime permissions are requested for camera and storage on newer Android versions.

iOS:
- Minimum iOS: 12.0
- Add camera/photo usage descriptions to Info.plist (NSCameraUsageDescription, NSPhotoLibraryUsageDescription)

## 📖 Usage (quick guide)

First-time setup:
1. Launch app → splash screen
2. Sign up: full name, username (unique), email, password, inspector ID
3. Open dashboard and create your first inspection

Creating an inspection:
1. Tap New Inspection
2. Capture or attach a photo
3. Enter item number and location
4. Select defect type/code and impact category
5. Add comments and Save to worksheet

Exporting reports:
1. From Dashboard tap Export Report
2. Choose PDF or Excel and export/share

## 🔒 Security & data
- Passwords are hashed (SHA256) with salt and never stored in plaintext
- All data lives locally on the device — no cloud syncing by default
- Users control their data; there is no telemetry or tracking

## 🗄️ Database (examples)

Users table

```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  username TEXT NOT NULL UNIQUE,
  inspector_id TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TEXT NOT NULL
)
```

Inspection reports table

```sql
CREATE TABLE inspection_reports (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  item_number TEXT NOT NULL,
  photo_path TEXT NOT NULL,
  defect_type TEXT NOT NULL,
  defect_code TEXT NOT NULL,
  location TEXT NOT NULL,
  inspector_comments TEXT NOT NULL,
  impact_category TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  is_synced INTEGER DEFAULT 0,
  FOREIGN KEY(user_id) REFERENCES users(id)
)
```

## 📊 Export formats

PDF: printable, page-aware table layout with inspector header and item rows.

Excel: .xlsx with columns suitable for analysis (Item No, Location, Defect Type, Defect Code, Impact, Comments, Date).

## 🧪 Testing

Unit tests:

```bash
flutter test
```

Integration tests:

```bash
flutter drive --target=test_driver/app.dart
```

## 🐛 Troubleshooting
- App won't start: run `flutter clean` and `flutter pub get`, then `flutter run`
- Camera issues: check OS permissions and ensure no other app is using the camera
- Export fails: verify storage space and write permissions

## 🚢 Deployment

Android:

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

iOS:

```bash
flutter build ios --release
```

## 📝 License
This project is provided as-is for survey inspection purposes. If you want to add an open-source license, add a LICENSE file (MIT/Apache/etc.) and update this section.

## 🤝 Contributing
- Create a feature branch
- Open a pull request with a clear description and tests
- Follow Dart style guidelines and keep changes focused

## 📞 Contact
- Email: amalirfanshaha@gmail.com
- Issues: use GitHub Issues in this repository — include app version and device information when reporting bugs

---

Built to work offline, everywhere.
