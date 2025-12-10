# Arcular+ Build Versions

This project supports two different build versions:

## 1. Mobile Version (Default)
- **Full features** including all user types
- **Admin & ARC Staff** functionality
- **All stakeholder registrations** (Hospital, Doctor, Nurse, Lab, Pharmacy)
- **Complete user experience**

## 2. Web Version (Simplified)
- **Limited features** for web deployment
- **Only Patient registration** and login
- **Simplified user interface**
- **Optimized for web browsers**

## How to Build Different Versions

### Mobile Version (Default)
```bash
# Build APK for mobile
flutter build apk --release

# Or use the script
chmod +x build_mobile.sh
./build_mobile.sh
```

### Web Version
```bash
# Build for web
flutter build web --release

# Or use the script
chmod +x build_web.sh
./build_web.sh
```

## Version Differences

### Mobile Version Features:
- ✅ Login for all user types
- ✅ Patient registration
- ✅ Hospital registration
- ✅ Doctor registration
- ✅ Nurse registration
- ✅ Lab registration
- ✅ Pharmacy registration
- ✅ Admin & ARC Staff login
- ✅ Full dashboard features
- ✅ All app functionality

### Web Version Features:
- ✅ Patient login only
- ✅ Patient registration only
- ✅ Simplified interface
- ✅ Web-optimized UI
- ❌ No Admin/ARC Staff features
- ❌ No stakeholder registrations

## Code Structure

The version switching is handled in:
- `lib/app.dart` - Main app configuration
- `lib/screens/auth/select_user_type.dart` - User type selection screen
- `lib/main_web.dart` - Web version entry point

## Deployment

### Mobile APK
- Deploy to Google Play Store
- Share APK file directly
- Use for internal testing

### Web Version
- Deploy to Vercel, Netlify, or any web hosting
- Upload `build/web/` folder contents
- Access via web browser

## Configuration

To switch between versions, the app uses:
- `isWebVersion` parameter in `ArcularPlusApp`
- Different UI components based on version
- Conditional rendering of features

This allows you to maintain one codebase while building different versions for different platforms! 