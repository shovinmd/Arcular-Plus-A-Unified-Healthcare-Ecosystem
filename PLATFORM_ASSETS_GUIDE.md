# Platform-Specific Assets Guide

This guide shows you how to use different GIFs/assets for different platforms in Flutter.

## 🎯 Overview

You can have different assets for:
- **Mobile (Android/iOS)**: `intro.gif`
- **Web**: `introweb.gif`
- **Desktop**: `introdesktop.gif` (optional)

## 📁 File Structure

```
assets/
├── images/
│   ├── intro.gif          # Mobile/Android GIF
│   ├── introweb.gif       # Web GIF
│   ├── introdesktop.gif   # Desktop GIF (optional)
│   └── logo.png
```

## 🔧 Implementation Methods

### Method 1: Simple Platform Detection (Recommended)

```dart
import 'package:flutter/foundation.dart';

String getIntroGifPath() {
  if (kIsWeb) {
    return 'assets/images/introweb.gif';
  } else {
    return 'assets/images/intro.gif';
  }
}

// Usage
Image.asset(getIntroGifPath())
```

### Method 2: Using PlatformHelper Class

```dart
import 'package:flutter/foundation.dart';
import 'dart:io';

class PlatformHelper {
  static bool get isWeb => kIsWeb;
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  
  static String getIntroGifPath() {
    if (isWeb) {
      return 'assets/images/introweb.gif';
    } else if (isAndroid) {
      return 'assets/images/intro.gif';
    } else if (isIOS) {
      return 'assets/images/intro.gif';
    } else {
      return 'assets/images/intro.gif';
    }
  }
}

// Usage
Image.asset(PlatformHelper.getIntroGifPath())
```

### Method 3: PlatformAwareImage Widget

```dart
class PlatformAwareImage extends StatelessWidget {
  final String baseAssetPath;
  final String? webAssetPath;
  final String? mobileAssetPath;

  const PlatformAwareImage({
    super.key,
    required this.baseAssetPath,
    this.webAssetPath,
    this.mobileAssetPath,
  });

  @override
  Widget build(BuildContext context) {
    String assetPath = kIsWeb 
        ? (webAssetPath ?? baseAssetPath)
        : (mobileAssetPath ?? baseAssetPath);
    
    return Image.asset(assetPath);
  }
}

// Usage
PlatformAwareImage(
  baseAssetPath: 'assets/images/intro.gif',
  webAssetPath: 'assets/images/introweb.gif',
  mobileAssetPath: 'assets/images/intro.gif',
)
```

### Method 4: IntroGifWidget (Specialized)

```dart
class IntroGifWidget extends StatelessWidget {
  const IntroGifWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformAwareImage(
      baseAssetPath: 'assets/images/intro.gif',
      webAssetPath: 'assets/images/introweb.gif',
      mobileAssetPath: 'assets/images/intro.gif',
    );
  }
}

// Usage
IntroGifWidget()
```

## 📝 pubspec.yaml Configuration

```yaml
flutter:
  assets:
    - assets/images/intro.gif      # Mobile/Android GIF
    - assets/images/introweb.gif   # Web GIF
    - assets/images/logo.png
```

## 🚀 Build Commands

### For Android APK:
```bash
flutter build apk
# Uses: assets/images/intro.gif
```

### For Web:
```bash
flutter build web
# Uses: assets/images/introweb.gif
```

### For iOS:
```bash
flutter build ios
# Uses: assets/images/intro.gif
```

## 💡 Best Practices

### 1. **File Naming Convention**
- Mobile: `intro.gif`
- Web: `introweb.gif`
- Desktop: `introdesktop.gif`

### 2. **Performance Considerations**
- **Web**: Use smaller, optimized GIFs for faster loading
- **Mobile**: Can use larger, higher quality GIFs
- **Desktop**: Can use highest quality GIFs

### 3. **Error Handling**
```dart
Image.asset(
  PlatformHelper.getIntroGifPath(),
  errorBuilder: (context, error, stackTrace) {
    return Container(
      color: Colors.grey[300],
      child: const Icon(Icons.error),
    );
  },
)
```

### 4. **Loading States**
```dart
Image.asset(
  PlatformHelper.getIntroGifPath(),
  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
    if (wasSynchronouslyLoaded) return child;
    return const CircularProgressIndicator();
  },
)
```

## 🔍 Platform Detection

### Available Platform Checks:
```dart
kIsWeb                    // true if running on web
Platform.isAndroid        // true if Android
Platform.isIOS           // true if iOS
Platform.isWindows       // true if Windows
Platform.isMacOS         // true if macOS
Platform.isLinux         // true if Linux
```

### Platform Helper Methods:
```dart
PlatformHelper.isWeb      // Web platform
PlatformHelper.isMobile   // Android or iOS
PlatformHelper.isDesktop  // Windows, macOS, or Linux
PlatformHelper.isAndroid  // Android only
PlatformHelper.isIOS      // iOS only
```

## 📱 Example Usage in Intro Screen

```dart
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: IntroGifWidget(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.6,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
```

## 🎨 Customization Options

### Different GIFs for Different Platforms:
```dart
String getIntroGifPath() {
  if (kIsWeb) {
    return 'assets/images/introweb.gif';      // Web-optimized
  } else if (Platform.isAndroid) {
    return 'assets/images/intro.gif';          // Android
  } else if (Platform.isIOS) {
    return 'assets/images/introios.gif';       // iOS-specific
  } else if (Platform.isWindows) {
    return 'assets/images/introdesktop.gif';   // Desktop
  } else {
    return 'assets/images/intro.gif';          // Default
  }
}
```

### Conditional Loading with Fallbacks:
```dart
Widget buildIntroImage() {
  try {
    String assetPath = PlatformHelper.getIntroGifPath();
    return Image.asset(assetPath);
  } catch (e) {
    // Fallback to default image
    return Image.asset('assets/images/logo.png');
  }
}
```

## ✅ Testing

### Test on Different Platforms:
1. **Web**: `flutter run -d chrome`
2. **Android**: `flutter run -d android`
3. **iOS**: `flutter run -d ios`

### Verify Assets:
- Check that correct GIF loads on each platform
- Verify error handling works
- Test loading states

## 🐛 Troubleshooting

### Common Issues:

1. **Asset not found**: Check `pubspec.yaml` includes both GIFs
2. **Wrong GIF loads**: Verify platform detection logic
3. **Performance issues**: Optimize GIF file sizes
4. **Build errors**: Run `flutter clean` and rebuild

### Debug Platform Detection:
```dart
print('Platform: ${PlatformHelper.getPlatformName()}');
print('Is Web: ${PlatformHelper.isWeb}');
print('Asset Path: ${PlatformHelper.getIntroGifPath()}');
```

## 🎯 Summary

- ✅ **Simple**: Use `kIsWeb` for basic web vs mobile detection
- ✅ **Advanced**: Use `PlatformHelper` class for comprehensive platform detection
- ✅ **Reusable**: Use `PlatformAwareImage` widget for multiple assets
- ✅ **Specialized**: Use `IntroGifWidget` for intro GIFs specifically
- ✅ **Error Handling**: Always include error builders
- ✅ **Performance**: Optimize GIFs for each platform

This setup allows you to have different GIFs for different platforms while maintaining clean, maintainable code!
