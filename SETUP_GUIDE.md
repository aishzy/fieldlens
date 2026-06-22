# Setup and Deployment Guide

## Prerequisites

Before you begin, ensure you have the following installed:

### Required Software
- **Flutter**: 3.0.0 or higher
- **Dart**: Included with Flutter
- **Git**: For version control
- **Android SDK**: For Android development (API level 21+)
- **Xcode**: For iOS development (iOS 12.0+)

### Verify Installation
```bash
flutter --version
dart --version
```

## Development Environment Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/fieldlens.git
cd fieldlens
```

### Step 2: Install Dependencies

```bash
flutter pub get
```

This will download and install all required packages listed in `pubspec.yaml`.

### Step 3: Generate Missing Files

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Step 4: Format and Analyze Code

```bash
flutter format lib/
flutter analyze
```

## Running the App

### Development Mode (Hot Reload)

```bash
flutter run
```

For specific device:
```bash
flutter run -d <device_id>
```

List available devices:
```bash
flutter devices
```

### Release Mode

**Android**:
```bash
flutter run --release
```

**iOS**:
```bash
flutter run --release
```

## Android Configuration

### Update build.gradle

File: `android/app/build.gradle`

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        applicationId "com.example.fieldlens"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
    }
}
```

### Configure Permissions

File: `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### Build APK

```bash
flutter build apk --release
```

Output location: `build/app/outputs/flutter-apk/app-release.apk`

### Build App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

Output location: `build/app/outputs/bundle/release/app-release.aab`

## iOS Configuration

### Update podfile

File: `ios/Podfile`

Ensure iOS deployment target is 12.0 or higher:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
      ]
    end
  end
end
```

### Configure Permissions

File: `ios/Runner/Info.plist`

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to capture inspection photos</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Photo library access is required to select inspection photos</string>
```

### Build for iOS

```bash
flutter build ios --release
```

### Generate IPA

```bash
flutter build ipa --release
```

## Testing

### Run Unit Tests

```bash
flutter test
```

Run specific test file:
```bash
flutter test test/core/utils/password_hasher_test.dart
```

### Run Widget Tests

```bash
flutter test test/ui/screens
```

### Generate Coverage Report

```bash
flutter test --coverage
```

View coverage:
```bash
lcov --list coverage/lcov.info
```

## Debugging

### Enable Debug Logging

```bash
flutter run -v
```

### Chrome DevTools Debugging

```bash
flutter run -d chrome
```

### Android Studio Debugger

1. Open project in Android Studio
2. Add breakpoints in code
3. Run in debug mode: `flutter run`
4. Step through code using Android Studio debugger

## Build and Release

### Version Management

Update version in `pubspec.yaml`:
```yaml
version: 1.0.0+1
```

Format: `<major>.<minor>.<patch>+<build>`

### Pre-release Checklist

- [ ] Update version number
- [ ] Run `flutter analyze` - no errors
- [ ] Run all tests - all passing
- [ ] Test on physical device
- [ ] Update CHANGELOG
- [ ] Create git tag
- [ ] Generate release notes

### Create Release Build

```bash
# For Android
flutter build apk --release 
flutter build appbundle --release

# For iOS
flutter build ipa --release
```

## Deployment

### Google Play Store (Android)

1. Create Google Play Console account
2. Create application
3. Generate signing key:
   ```bash
   keytool -genkey -v -keystore ~/key.jks -keyalg RSA -keysize 2048 -validity 10000
   ```
4. Create `android/key.properties`:
   ```properties
   storePassword=<password>
   keyPassword=<password>
   keyAlias=key
   storeFile=<path-to-key.jks>
   ```
5. Build signed APK/AAB
6. Upload to Play Console
7. Review and publish

### Apple App Store (iOS)

1. Create Apple Developer account
2. Create App ID and certificates
3. Configure provisioning profiles
4. Build archive in Xcode
5. Sign and upload to App Store Connect
6. Review and submit for approval

### Internal Testing

Both stores support internal testing:
- Google Play: Internal testing tracks
- Apple App Store: TestFlight

## Continuous Integration (Optional)

### GitHub Actions Example

File: `.github/workflows/build.yml`

```yaml
name: Build

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: flutter build apk --release
```

## Troubleshooting

### Dependency Issues

Clear pub cache:
```bash
flutter pub cache clean
flutter pub get
```

### Build Failures

Clean build:
```bash
flutter clean
flutter pub get
flutter run
```

### Permission Errors

For Linux/Mac, ensure execute permissions:
```bash
chmod +x ios/Runner/Runner.app/Contents/MacOS/Runner
```

### Xcode Build Issues

```bash
cd ios
rm -rf Pods
rm Podfile.lock
cd ..
flutter pub get
flutter run
```

## Performance Optimization

### Dart AOT Compilation

Already enabled in release builds. For development:
```bash
flutter build appbundle --profile
```

### Image Optimization

Images in assessment screen are automatically:
- Resized to max 1200x1200
- Compressed to 80% quality
- Stored locally in app cache

### Database Optimization

Database indexes are created automatically:
- `idx_user_id` on inspection_reports(user_id)

## Monitoring

### Debug Console Output

Check logs:
```bash
flutter logs
```

Filter by app:
```bash
flutter logs -f fieldlens
```

### Device Logs

Android:
```bash
adb logcat
```

iOS:
```bash
xcrun simctl spawn booted log stream --predicate 'processImagePath contains "fieldlens"'
```

## Maintenance

### Update Dependencies

Check for updates:
```bash
flutter pub outdated
```

Update to latest:
```bash
flutter pub upgrade
```

Update specific package:
```bash
flutter pub upgrade package_name
```

### Security Updates

Keep Flutter updated:
```bash
flutter upgrade
```

Regularly check for security vulnerabilities:
```bash
flutter pub outdated
flutter pub audit
```

## Support and Resources

- **Flutter Docs**: https://flutter.dev/docs
- **Dart Docs**: https://dart.dev/guides
- **Package Documentation**: https://pub.dev
- **Stack Overflow**: Tag with `flutter`

