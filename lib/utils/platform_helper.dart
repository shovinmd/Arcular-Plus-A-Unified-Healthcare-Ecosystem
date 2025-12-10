import 'package:flutter/foundation.dart';
import 'dart:io';

class PlatformHelper {
  static bool get isWeb => kIsWeb;
  
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  
  static bool get isDesktop => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  
  /// Get platform-specific asset path for intro GIF
  static String getIntroGifPath() {
    if (isWeb) {
      return 'assets/images/introweb.gif';
    } else if (isAndroid) {
      return 'assets/images/intro.gif';
    } else if (isIOS) {
      return 'assets/images/intro.gif';
    } else {
      // Default for other platforms
      return 'assets/images/intro.gif';
    }
  }
  
  /// Get platform-specific asset path for any asset
  static String getAssetPath(String basePath, {String? webSuffix, String? mobileSuffix}) {
    if (isWeb) {
      return webSuffix != null ? '$basePath$webSuffix' : basePath;
    } else {
      return mobileSuffix != null ? '$basePath$mobileSuffix' : basePath;
    }
  }
  
  /// Get platform name for debugging
  static String getPlatformName() {
    if (isWeb) return 'Web';
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isMacOS) return 'macOS';
    if (isLinux) return 'Linux';
    return 'Unknown';
  }
}
