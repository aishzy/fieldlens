# Dilapidation Survey App - Architecture & Implementation

## Overview

This is a complete, production-ready offline-first Flutter mobile application for conducting dilapidation surveys in the field. The app runs 100% offline without requiring any internet connection and supports both mobile phones and tablets.

## Architecture

### Clean Architecture Layers

```
lib/
├── core/
│   ├── database/         # SQLite database layer
│   ├── models/          # Data models
│   ├── providers/       # State management (Provider)
│   └── utils/           # Utilities (password hashing)
├── ui/
│   ├── screens/         # UI screens
│   │   ├── auth/        # Authentication screens
│   │   ├── dashboard/   # Main dashboard
│   │   ├── assessment/  # Inspection assessment
│   │   └── export/      # Report export
│   └── widgets/         # Reusable widgets
└── main.dart            # App entry point
```

## Tech Stack

- **Framework**: Flutter 3.x+
- **State Management**: Provider 6.x
- **Local Database**: SQLite (sqflite)
- **Export Formats**: PDF (pdf package) & Excel (excel package)
- **Camera**: image_picker
- **Crypto**: SHA256 password hashing
- **File Sharing**: share_plus

## Core Features

### 1. Authentication System (100% Offline)

**Sign Up Screen**:
- Full Name, Email/Username, Password, Inspector ID
- Passwords hashed using SHA256 with salt
- Stored in local SQLite database
- Username uniqueness validation

**Login Screen**:
- Username and password authentication
- Secure password verification
- Session persistence
- Error handling with user feedback

**Models**:
- `UserModel`: Stores user credentials locally

### 2. Database Schema

**Users Table**:
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

**Inspection Reports Table**:
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

### 3. Assessment Screen

**Features**:
- **Photo Capture**: Camera integration using image_picker
- **Item Number Input**: Text field for identification (e.g., "CH 165.2, LHS")
- **Location Input**: Text field for site location
- **Defect Type Selection**: Radio-like chip buttons
  - Crack (FC1-FC4, WC1-WC4)
  - Bent (B1-B4)
  - Damage (D1-D4)
- **Impact Category Toggle**:
  - Minor (Green)
  - Moderate (Orange)
  - Major (Red)
- **Inspector Comments**:
  - Preset quick-tap buttons
  - Manual text editing capability
  - Customizable comments

**Data Flow**:
1. User captures photo
2. Enters item details and location
3. Selects defect type and code
4. Chooses impact category
5. Adds comments (preset or custom)
6. Saves to local SQLite database

### 4. Dashboard

**Features**:
- Welcome message with inspector name
- Statistics cards (total inspections, today's count)
- Quick action buttons (New Inspection, Export Report)
- Recent inspections list
- Profile information display
- Logout functionality

### 5. Export Engine

**PDF Export**:
- Professional formatted report
- Header with inspector details
- Table with all inspection data
- Columns: Item No, Location, Defect Code, Type, Impact, Comments
- Saved to device Documents folder
- Shareable via email/messaging

**Excel Export**:
- Standard .xlsx format
- Headers: Item Number, Location, Defect Type, Defect Code, Impact Category, Comments, Date
- Suitable for data analysis and further processing
- Compatible with Microsoft Excel, Google Sheets, etc.

### 6. Responsive UI Design

**Mobile (< 600px)**:
- Optimized single-column layout
- Touch-friendly button sizes (48-60px)
- Scrollable content with proper spacing

**Tablet (600-1200px)**:
- Extended layouts
- Multi-column cards
- Larger text and icons

**Desktop (> 1200px)**:
- Full-width layouts
- Side-by-side components
- Optimized for landscape orientation

## State Management

### Provider Pattern

**AuthProvider**:
- Manages user authentication state
- Handles signup and login operations
- Maintains current user session
- Provides loading and error states

**InspectionProvider**:
- Manages inspection reports
- CRUD operations for inspections
- Filters by user ID
- Notifies listeners on data changes

## Offline Capabilities

All data is stored locally in SQLite:
- ✅ User credentials
- ✅ Inspection reports with photos
- ✅ Defect codes and comments
- ✅ Impact categorization
- ✅ Timestamps for tracking

No internet connection required for:
- User registration and login
- Creating inspections
- Capturing photos
- Exporting reports
- Browsing inspection history

## Security Features

1. **Password Security**:
   - SHA256 hashing with salt
   - Never stored in plaintext
   - Salt: "dilapidation_survey_salt_2024"

2. **Local Storage**:
   - All data encrypted at rest by device OS
   - No cloud storage required
   - User has full control over data

3. **Session Management**:
   - Local session persistence
   - Auto-logout on app close
   - User context maintained

## File Structure

```
lib/
├── core/
│   ├── database/
│   │   └── database_helper.dart        # SQLite operations
│   ├── models/
│   │   ├── user_model.dart
│   │   └── inspection_report_model.dart
│   ├── providers/
│   │   ├── auth_provider.dart          # Authentication state
│   │   └── inspection_provider.dart    # Inspection state
│   └── utils/
│       └── password_hasher.dart        # Password encryption
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
└── main.dart                           # App entry point
```

## Usage Flow

### First Time User
1. Launch app → Splash screen
2. Sign up with credentials
3. Create first inspection
4. Capture photo and fill details
5. Save inspection

### Returning User
1. Launch app → Splash screen
2. Login with credentials
3. View dashboard with inspection history
4. Create new inspection or export existing data

### Export Workflow
1. Navigate to Export screen
2. Choose format (PDF or Excel)
3. File saved to Documents folder
4. Optional: Share via email/messaging

## Performance Considerations

1. **Database Indexing**:
   - Index on `user_id` for fast filtering

2. **Image Optimization**:
   - Images resized to max 1200x1200
   - Quality set to 80% for smaller file sizes

3. **UI Rendering**:
   - ListView with `shrinkWrap: true` for nested lists
   - Material 3 for optimized rendering

## Testing Recommendations

1. **Unit Tests**:
   - Database operations
   - Authentication logic
   - Password hashing

2. **Widget Tests**:
   - Form validation
   - Navigation flows
   - State changes

3. **Integration Tests**:
   - Complete signup → inspection → export flow
   - Photo capture and storage
   - Offline functionality

## Future Enhancements

1. **Data Synchronization**:
   - Cloud backup option
   - Sync when internet available

2. **Advanced Features**:
   - Offline map integration
   - GPS location tagging
   - Signature capture
   - Multi-language support

3. **Analytics**:
   - Inspection statistics
   - Trend analysis
   - Performance metrics

## Deployment

### Android
- Target SDK: 34+
- Min SDK: 21+
- Permissions: CAMERA, WRITE_EXTERNAL_STORAGE

### iOS
- Target iOS 12.0+
- Permissions: NSCameraUsageDescription, NSPhotoLibraryUsageDescription

## Known Limitations

- Photos stored locally (consider cloud backup for production)
- No built-in data validation for defect codes (can be enhanced)
- Export requires sufficient device storage
- No multi-user workspace (designed for single inspector per device)

## Dependencies

See `pubspec.yaml` for complete dependency list. Key packages:
- provider: 6.x
- sqflite: 2.x
- camera/image_picker: latest
- pdf/excel: latest
- crypto: 3.x
- path_provider: 2.x
