import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

/// A widget that automatically selects the correct asset based on platform
class PlatformAwareImage extends StatelessWidget {
  final String baseAssetPath;
  final String? webAssetPath;
  final String? mobileAssetPath;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? errorWidget;
  final Widget? loadingWidget;

  const PlatformAwareImage({
    super.key,
    required this.baseAssetPath,
    this.webAssetPath,
    this.mobileAssetPath,
    this.width,
    this.height,
    this.fit,
    this.errorWidget,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    String assetPath = _getAssetPath();
    
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? 
          Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.error, color: Colors.red),
          );
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return loadingWidget ?? child;
      },
    );
  }

  String _getAssetPath() {
    if (kIsWeb) {
      return webAssetPath ?? baseAssetPath;
    } else {
      return mobileAssetPath ?? baseAssetPath;
    }
  }
}

/// Specific widget for intro GIFs
class IntroGifWidget extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit? fit;

  const IntroGifWidget({
    super.key,
    this.width,
    this.height,
    this.fit,
  });

  @override
  Widget build(BuildContext context) {
    return PlatformAwareImage(
      baseAssetPath: 'assets/images/intro.gif',
      webAssetPath: 'assets/images/introweb.gif',
      mobileAssetPath: 'assets/images/intro.gif',
      width: width,
      height: height,
      fit: fit,
      errorWidget: Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
            SizedBox(height: 8),
            Text('Image not available', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

/// Widget for platform-specific logos
class PlatformLogoWidget extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit? fit;

  const PlatformLogoWidget({
    super.key,
    this.width,
    this.height,
    this.fit,
  });

  @override
  Widget build(BuildContext context) {
    return PlatformAwareImage(
      baseAssetPath: 'assets/images/logo.png',
      webAssetPath: 'assets/images/logoweb.png',    // Optional web-specific logo
      mobileAssetPath: 'assets/images/logo.png',     // Mobile logo
      width: width,
      height: height,
      fit: fit,
    );
  }
}
