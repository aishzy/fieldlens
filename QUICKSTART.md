# Quick Start Guide

## 1️⃣ Installation (2 minutes)

```bash
# Navigate to project
cd fieldlens

# Install dependencies
flutter pub get

# Run the app
flutter run
```

## 2️⃣ First Run

1. **Splash Screen** appears (2 seconds)
2. **Sign Up Screen** - Create your account:
   - Full Name: "John Inspector"
   - Username: "johninspector"
   - Email: "john@example.com"
   - Password: "secure123"
   - Inspector ID: "INS-001"
   - Tap "Sign Up"

3. **Dashboard Screen** appears (empty state)

## 3️⃣ Create Your First Inspection

1. Tap **"New Inspection"** button
2. **Capture Photo**: Tap camera icon
3. **Fill Details**:
   - Item Number: "CH 165.2"
   - Location: "Main Building"
   - Assessment Type: Select "Crack"
   - Defect Code: Select "FC1"
   - Impact Category: Select "Minor"
4. **Add Comments**: 
   - Tap preset or type custom
   - Example: "Fine crack noticed at curb"
5. Tap **"Save to Worksheet"**

## 4️⃣ View Your Inspection

- Dashboard shows 1 total inspection
- Recent Inspections list displays your entry
- Shows defect code, location, and impact category

## 5️⃣ Export Your Report

1. Tap **"Export Report"** button
2. Choose format:
   - **PDF**: Click "Export as PDF"
   - **Excel**: Click "Export as Excel"
3. File saves to Documents folder
4. Optional: Tap "Share" to email

## Key Features

### Assessment Types
- **Crack**: FC1, FC2, FC3, FC4, WC1, WC2, WC3, WC4
- **Bent**: B1, B2, B3, B4
- **Damage**: D1, D2, D3, D4

### Impact Categories
- **Minor** (Green) - Small issues
- **Moderate** (Orange) - Medium issues
- **Major** (Red) - Critical issues

### Preset Comments
- "Fine crack noticed at the road curb."
- "Sinkhole observed under the concrete walkway."
- "Distribution Box (DB) found in good, stable condition."
- "Surface deterioration detected."
- "Minor spalling observed on concrete surface."
- "Significant settlement noted."
- "Water pooling in depression area."

## 📚 Next Steps

- **Multiple Inspections**: Create as many as needed
- **Offline Access**: Works without internet
- **Easy Export**: Generate PDF/Excel reports
- **Profile Management**: View inspector details

## 🐛 Troubleshooting

| Issue | Solution |
|-------|----------|
| App won't start | Run `flutter clean && flutter pub get` |
| Camera not working | Check phone camera permissions |
| Can't export | Verify device storage space |
| Photos not saving | Check storage permissions |

## 📖 Full Documentation

- **README.md** - Complete feature guide
- **ARCHITECTURE.md** - Technical details
- **SETUP_GUIDE.md** - Development setup

## 🎯 Tips

1. **Batch Inspections**: Create multiple in field, export later
2. **Photos**: Keep well-lit and clear
3. **Comments**: Use presets for speed, edit if needed
4. **Export**: Schedule for end of day
5. **Sharing**: Export then share via email/messaging

---

**Ready to start surveying?** 🚀

Next: Tap "New Inspection" on Dashboard!
