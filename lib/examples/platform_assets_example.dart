import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../widgets/platform_aware_image.dart';
import '../utils/platform_helper.dart';

/// Example screen showing different ways to handle platform-specific assets
class PlatformAssetsExample extends StatelessWidget {
  const PlatformAssetsExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Assets Example'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Platform Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Platform:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Platform: ${PlatformHelper.getPlatformName()}'),
                    Text('Is Web: ${PlatformHelper.isWeb}'),
                    Text('Is Mobile: ${PlatformHelper.isMobile}'),
                    Text('Is Desktop: ${PlatformHelper.isDesktop}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Method 1: Using PlatformAwareImage Widget
            const Text(
              'Method 1: PlatformAwareImage Widget',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Intro GIF (Auto-detects platform):'),
                    SizedBox(height: 10),
                    IntroGifWidget(
                      width: 200,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Method 2: Using PlatformHelper
            const Text(
              'Method 2: PlatformHelper Class',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Using PlatformHelper.getIntroGifPath():'),
                    const SizedBox(height: 10),
                    Image.asset(
                      PlatformHelper.getIntroGifPath(),
                      width: 200,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Method 3: Direct Platform Detection
            const Text(
              'Method 3: Direct Platform Detection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Direct kIsWeb detection:'),
                    const SizedBox(height: 10),
                    Image.asset(
                      kIsWeb ? 'assets/images/introweb.gif' : 'assets/images/intro.gif',
                      width: 320,
                      height: 240,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Method 4: Conditional Asset Loading
            const Text(
              'Method 4: Conditional Asset Loading',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Conditional loading with error handling:'),
                    const SizedBox(height: 10),
                    _buildConditionalImage(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Asset Path Examples
            const Text(
              'Asset Path Examples:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Web GIF Path: ${PlatformHelper.getIntroGifPath()}'),
                    const SizedBox(height: 5),
                    Text('Platform Helper: ${PlatformHelper.getPlatformName()}'),
                    const SizedBox(height: 5),
                    Text('Is Web: ${PlatformHelper.isWeb}'),
                    const SizedBox(height: 5),
                    Text('Is Mobile: ${PlatformHelper.isMobile}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionalImage() {
    try {
      String assetPath;
      
      if (kIsWeb) {
        assetPath = 'assets/images/introweb.gif';
      } else if (Platform.isAndroid) {
        assetPath = 'assets/images/intro.gif';
      } else if (Platform.isIOS) {
        assetPath = 'assets/images/intro.gif';
      } else {
        assetPath = 'assets/images/intro.gif'; // Default
      }
      
      return Image.asset(
        assetPath,
        width: 200,
        height: 150,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 200,
            height: 150,
            color: Colors.grey[300],
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red, size: 30),
                SizedBox(height: 8),
                Text('Asset not found', style: TextStyle(color: Colors.red)),
              ],
            ),
          );
        },
      );
    } catch (e) {
      return Container(
        width: 200,
        height: 150,
        color: Colors.grey[300],
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 30),
            SizedBox(height: 8),
            Text('Error loading asset', style: TextStyle(color: Colors.red)),
          ],
        ),
      );
    }
  }
}
