# Dilapidation Survey Inspection App

A **complete, production-ready, offline-first mobile application** built with Flutter for conducting dilapidation surveys in the field. The app runs **100% offline** without requiring internet connectivity.

## 🎯 Features

### ✅ Complete Offline Operation
- No internet connection required
- All data stored locally in SQLite
- Full functionality available offline
- Works in areas with no cellular coverage

### 🔐 Secure Authentication
- User registration and login
- SHA256 password hashing with salt
- Session persistence
- Unique username validation

### 📋 Dynamic Assessment Screen
- **Photo Capture**: Integrated camera functionality
- **Item Numbering**: Location-specific identification (e.g., "CH 165.2, LHS")
- **Location Tagging**: Site location recording
- **Defect Classification**:
  - Crack: FC1, FC2, FC3, FC4, WC1, WC2, WC3, WC4
  - Bent: B1, B2, B3, B4
  - Damage: D1, D2, D3, D4
- **Impact Categorization**: Minor, Moderate, Major
- **Inspector Comments**: Preset quick-options + custom text

### 📊 Dashboard
- Welcome message with inspector details
- Inspection statistics
- Recent inspections list
- Quick action buttons
- Profile management

### 📄 Export Engine
- **PDF Reports**: Professional formatted reports with tables
- **Excel Spreadsheets**: Standard .xlsx format for data analysis
- **File Sharing**: Direct sharing via email/messaging
- **Device Storage**: Saved to Documents folder

### 📱 Responsive Design
- **Optimized for Mobile**: Touch-friendly interfaces
- **Tablet Support**: Extended layouts for larger screens
- **High Contrast UI**: Clear visibility under sunlight
- **Material 3 Design**: Modern, intuitive interface

## 🏗️ Architecture

**Clean Architecture** with separation of concerns:
- **Core Layer**: Database, Models, State Management, Utilities
- **UI Layer**: Screens, Widgets, Navigation

**State Management**: Provider pattern for efficient state updates

**Database**: SQLite with proper indexing and foreign keys

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed documentation.

## 🛠️ Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | Flutter 3.x+ |
| Language | Dart |
| State Management | Provider 6.x |
| Database | SQLite (sqflite) |
| Export - PDF | pdf package |
| Export - Excel | excel package |
| Camera | image_picker |
| Crypto | crypto (SHA256) |
| File Sharing | share_plus |

## 📦 Project Structure

```
lib/
├── core/
│   ├── database/
│   │   └── database_helper.dart          # SQLite operations
│   ├── models/
│   │   ├── user_model.dart               # User data model
│   │   └── inspection_report_model.dart  # Inspection data model
│   ├── providers/
│   │   ├── auth_provider.dart            # Authentication state
│   │   └── inspection_provider.dart      # Inspection state
│   └── utils/
│       └── password_hasher.dart          # Password encryption
├── ui/
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── signup_screen.dart
│   │   ├── dashboard/
│   │   │   └── dashboard_screen.dart
│   │   ├── assessment/
│   │   │   └── assessment_screen.dart
│   │   ├── export/
│   │   │   └── export_screen.dart
│   │   └── splash_screen.dart
│   └── widgets/
│       └── custom_widgets.dart
└── main.dart                              # App entry point
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK (included with Flutter)
- Android Studio (for Android) or Xcode (for iOS)
- Git

### Installation

1. **Clone the repository**:
```bash
git clone https://github.com/yourusername/fieldlens.git
cd fieldlens
```

2. **Install dependencies**:
```bash
flutter pub get
```

3. **Run the app**:
```bash
flutter run
```

### Android Setup

1. Minimum SDK: Android 5.0 (API 21)
2. Target SDK: Android 14 (API 34)
3. Required permissions in `AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.CAMERA" />
   <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
   <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
   ```

### iOS Setup

1. Minimum iOS: 12.0
2. Required permissions in `Info.plist`:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Camera access is required to capture inspection photos</string>
   <key>NSPhotoLibraryUsageDescription</key>
   <string>Photo library access is required to select inspection photos</string>
   ```

## 📖 Usage Guide

### First-Time Setup

1. **Launch the app** → Splash screen
2. **Sign up**:
   - Enter Full Name
   - Create unique Username
   - Enter Email
   - Create secure Password (min 6 characters)
   - Enter Inspector ID
   - Tap "Sign Up"

3. **Dashboard**: View empty inspection list

### Creating an Inspection

1. **Tap "New Inspection"** button
2. **Capture Photo**: Tap camera button to take a photo
3. **Enter Details**:
   - Item Number: e.g., "CH 165.2, LHS"
   - Location: e.g., "Pusat Pengajian Maktab PAT"
4. **Select Assessment Type**:
   - Choose from Crack, Bent, or Damage
   - Select specific code (e.g., FC1, B2, D3)
5. **Choose Impact Category**:
   - Minor (Green)
   - Moderate (Orange)
   - Major (Red)
6. **Add Comments**:
   - Tap preset comments OR
   - Type custom comments
7. **Tap "Save to Worksheet"**

### Exporting Reports

1. **Tap "Export Report"** on Dashboard
2. **Choose Format**:
   - **PDF**: Professional formatted report with table layout
   - **Excel**: Spreadsheet format for analysis
3. **Review Summary**: Total items and report info
4. **Export**: Tap export button
5. **Share**: Optional - share via email or messaging

### Managing Profile

1. **Tap menu icon** (top right)
2. **View Profile**: See inspector details
3. **Logout**: Tap logout and confirm

## 🔒 Security Features

### Password Protection
- Passwords hashed using SHA256 algorithm
- Salt-based hashing to prevent rainbow table attacks
- Never stored in plaintext
- Secure verification during login

### Local Storage
- All data encrypted at device OS level
- No cloud storage or external servers
- User has complete data control
- No telemetry or tracking

### Session Management
- Session maintained locally
- User context preserved
- Secure logout functionality

## 🗄️ Database Schema

### Users Table
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

### Inspection Reports Table
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

## 📊 Data Export Formats

### PDF Report
- Professional table layout
- Inspector details in header
- Columns: Item No, Location, Defect Code, Type, Impact, Comments
- Page-aware formatting
- Ready for printing

### Excel Spreadsheet
- Standard .xlsx format
- Compatible with Excel, Google Sheets, LibreOffice
- Columns: Item Number, Location, Defect Type, Defect Code, Impact Category, Comments, Date
- Suitable for further analysis and reporting

## 📱 Responsive UI

### Mobile Devices (< 600px width)
- Single-column layout
- Touch-optimized buttons (48x48 minimum)
- Scrollable content
- Compact spacing

### Tablets (600-1200px width)
- Multi-column layouts
- Extended card views
- Larger typography
- Optimized touch targets

### Landscape Mode
- Horizontal scrolling where needed
- Full-width utilization
- Landscape-optimized navigation

## 🧪 Testing

### Unit Tests
```bash
flutter test
```

Test coverage for:
- Database operations
- Authentication logic
- Password hashing
- State management

### Integration Tests
```bash
flutter drive --target=test_driver/app.dart
```

Test scenarios:
- Complete signup → inspection → export flow
- Photo capture and storage
- Offline functionality
- Navigation flows

## 🐛 Troubleshooting

### App won't start
- Clear app data: `flutter clean`
- Rebuild: `flutter pub get && flutter run`

### Camera not working
- Check permissions in system settings
- Ensure camera app isn't already open
- Try restarting the app

### Export fails
- Verify sufficient storage space
- Check write permissions
- Ensure database isn't corrupted

### Photos not saving
- Check external storage permission
- Verify available disk space
- Review app cache settings

## 📈 Performance

- Lightweight SQLite database (~5MB per 1000 inspections)
- Image optimization (max 1200x1200, 80% quality)
- Efficient state management with Provider
- Minimal UI rebuild overhead
- Fast export generation

## 🚢 Deployment

### Android
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## 📝 License

This project is provided as-is for survey inspection purposes.

## 👨‍💻 Development

### Code Style
- Follow Dart style guide
- Use meaningful variable names
- Add comments for complex logic
- Keep functions focused and small

### Contributions
- Create feature branches
- Submit pull requests with clear descriptions
- Include test coverage
- Update documentation

## 🤝 Support

For issues or questions:
1. Check existing GitHub issues
2. Create new issue with details
3. Include app version and device info
4. Describe steps to reproduce

## 📞 Contact

- Email: amalirfanshaha@gmail.com
- Issue Tracker: GitHub Issues

---

Built to work offline, everywhere.
