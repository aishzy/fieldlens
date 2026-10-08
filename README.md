# FieldLens

[![Flutter](https://img.shields.io/badge/Flutter-3.5%2B-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Android%20%7C%20iOS-Ready-3A7CA5)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

FieldLens is an offline-first Flutter application for conducting dilapidation surveys in the field. It allows inspectors to capture defect details, attach photos, log condition issues, and export professional reports without requiring internet access.

Built for mobile use in real-world site conditions, FieldLens focuses on speed, reliability, and usability in environments with limited connectivity, poor lighting, or high-glare conditions.

## Table of contents

- [Overview](#overview)
- [Key features](#key-features)
- [Architecture](#architecture)
- [Project structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
- [Usage guide](#usage-guide)
- [Database schema](#database-schema)
- [Exporting reports](#exporting-reports)
- [Security and offline-first design](#security-and-offline-first-design)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

## Overview

FieldLens helps inspectors record dilapidation defects efficiently and consistently. The app keeps all inspection data locally on the device and supports quick workflows for:

- creating a user profile and signing in
- starting a new inspection
- adding defect information with code, category, and notes
- attaching photos from the camera or gallery
- exporting reports in PDF or Excel format

This is designed for field teams that need dependable reporting even when connectivity is unavailable.

## Key features

### Offline-first inspection workflow
- Full inspection workflow works without internet connectivity
- Local SQLite storage for inspection data and user records
- No server dependency for day-to-day inspection work

### Secure authentication
- Local signup and login flow
- Secure password hashing with SHA-256 and salt
- Session persistence for returning users

### Defect recording
- Photo capture or attachment
- Item numbering and location tagging
- Defect classification such as crack, bent, and damage
- Impact category selection: Minor, Moderate, Major
- Quick-comment presets and free-text notes

### Dashboard and management
- Inspector dashboard with summary data
- Recent inspection history
- Quick actions for new inspections and exports
- Profile access and logout support

### Report generation
- PDF report output with structured inspection tables
- Excel export for sharing and spreadsheet analysis
- Device-friendly export flow for email, messaging, and local storage

### Field usability
- Mobile-first responsive layout
- Material 3 design
- High-contrast, touch-friendly interface for outdoor use

## Architecture

The application follows a lightweight Clean Architecture structure:

- Core layer: database logic, models, providers, and utilities
- UI layer: screens, widgets, and navigation
- State management: Provider

This separation helps keep the app easier to maintain and easier to extend as the inspection workflow grows.

## Project structure

```text
fieldlens/
├── android/                  # Android project files
├── ios/                      # iOS project files
├── lib/
│   ├── core/
│   │   ├── database/         # SQLite operations
│   │   ├── models/            # User and inspection data models
│   │   ├── providers/         # Provider-based state management
│   │   └── utils/             # Helpers and hashing utilities
│   ├── ui/
│   │   ├── screens/           # Auth, dashboard, assessment, export screens
│   │   └── widgets/           # Reusable UI widgets
│   ├── main.dart              # App entry point
│   └── ...
├── test/                     # Test suite
├── analysis_options.yaml
├── LICENSE
├── pubspec.yaml
├── README.md
├── ARCHITECTURE.md
├── QUICKSTART.md
└── ...
```

## Prerequisites

Before running the project, make sure you have:

- Flutter SDK 3.5.0 or newer
- Android Studio for Android development, or Xcode for iOS development
- Git
- An Android or iOS emulator, or a physical device

## Getting started

### 1. Clone the repository

```bash
git clone https://github.com/aishzy/fieldlens.git
cd fieldlens
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run the app

```bash
flutter run
```

### Platform notes

Android:
- Minimum SDK: Android 5.0 (API 21)
- Target SDK: Android 14 (API 34)
- Ensure required runtime permissions are granted for camera and storage

iOS:
- Minimum iOS: 12.0
- Add camera and photo usage descriptions in `Info.plist`

## Usage guide

### First-time setup
1. Launch the app.
2. Create an account with your name, username, email, password, and inspector ID.
3. Sign in and open the dashboard.

### Creating an inspection
1. Tap New Inspection.
2. Capture or attach a photo.
3. Add the item number and location.
4. Select the defect type and code.
5. Choose the impact category.
6. Add notes or quick comments.
7. Save the inspection record.

### Exporting a report
1. Open the dashboard.
2. Select Export Report.
3. Choose PDF or Excel.
4. Save or share the generated file.

## Database schema

The app stores critical data in local SQLite tables.

### Users table

```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  username TEXT NOT NULL UNIQUE,
  inspector_id TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TEXT NOT NULL
);
```

### Inspection reports table

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
);
```

## Exporting reports

FieldLens supports generating both PDF and Excel exports.

### PDF
- professional table-based inspection layout
- inspector details included in header
- suitable for handover and formal reporting

### Excel
- `.xlsx` output for spreadsheet workflows
- compatible with Excel, Google Sheets, and LibreOffice
- useful for data analysis and archive purposes

## Security and offline-first design

FieldLens is designed to store inspection data securely on-device.

- Passwords are hashed using SHA-256 with salt
- User credentials are not stored in plaintext
- Inspection records stay local to the device by default
- No cloud sync is required for core inspection tasks
- All essential workflows remain available without network access

## Testing

Run the unit tests with:

```bash
flutter test
```

For app-level tests or device testing, use the Flutter driver flow if required by your setup.

## Deployment

### Android

```bash
flutter build apk --release
```

or

```bash
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## Contributing

Contributions are welcome.

1. Fork the repository.
2. Create a feature branch.
3. Make your changes.
4. Add or update tests if relevant.
5. Open a pull request with a clear summary.

Please keep changes focused, follow Dart style conventions, and document meaningful behavior changes.

## License

This project is licensed under the MIT License.

See [LICENSE](LICENSE) for the full text.

## Contact

- Email: amalirfanshaha@gmail.com
- GitHub: https://github.com/aishzy/fieldlens
- Issues: open an issue in this repository for bugs, feature requests, or support questions

---

Built for reliable field inspections, even without connectivity.
