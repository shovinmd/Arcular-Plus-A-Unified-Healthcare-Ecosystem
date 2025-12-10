import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for handling platform-specific web navigation
class PlatformWebNavigationService {
  
  /// Navigate to admin web page with platform-specific handling
  static Future<void> navigateToAdminWebPage(BuildContext context) async {
    const String adminUrl = 'https://arcular-plus-sup-admin-staffs.vercel.app/';
    
    if (kIsWeb) {
      // On web, open in new tab
      await _openInNewTab(adminUrl);
    } else {
      // On mobile, use WebView
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlatformWebViewScreen(
            title: 'Admin Panel',
            url: adminUrl,
            backgroundColor: const Color(0xFF667eea),
          ),
        ),
      );
    }
  }
  
  /// Navigate to staff web page with platform-specific handling
  static Future<void> navigateToStaffWebPage(BuildContext context) async {
    const String staffUrl = 'https://arcular-plus-staffs.vercel.app';
    
    if (kIsWeb) {
      // On web, open in new tab
      await _openInNewTab(staffUrl);
    } else {
      // On mobile, use WebView
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlatformWebViewScreen(
            title: 'Staff Panel',
            url: staffUrl,
            backgroundColor: const Color(0xFF764ba2),
          ),
        ),
      );
    }
  }
  
  /// Open URL in new tab (web only)
  static Future<void> _openInNewTab(String url) async {
    if (kIsWeb) {
      try {
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        print('Error opening URL: $e');
      }
    }
  }
  
  /// Check if running on web platform
  static bool get isWeb => kIsWeb;
  
  /// Check if running on mobile platform
  static bool get isMobile => !kIsWeb;
}

/// Platform-aware WebView screen that only works on mobile
class PlatformWebViewScreen extends StatefulWidget {
  final String title;
  final String url;
  final Color backgroundColor;
  
  const PlatformWebViewScreen({
    Key? key,
    required this.title,
    required this.url,
    required this.backgroundColor,
  }) : super(key: key);

  @override
  State<PlatformWebViewScreen> createState() => _PlatformWebViewScreenState();
}

class _PlatformWebViewScreenState extends State<PlatformWebViewScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Only initialize WebView on mobile platforms
    if (!kIsWeb) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
            },
            onNavigationRequest: (NavigationRequest request) {
              // Allow all navigation
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    // If on web, show a message and redirect
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: widget.backgroundColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.open_in_new,
                size: 64,
                color: widget.backgroundColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Opening ${widget.title} in new tab...',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'If the page doesn\'t open automatically, click the button below:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await PlatformWebNavigationService._openInNewTab(widget.url);
                },
                icon: const Icon(Icons.open_in_new),
                label: Text('Open ${widget.title}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.backgroundColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Mobile WebView implementation
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _webViewController.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(widget.backgroundColor),
              ),
            ),
        ],
      ),
    );
  }
}
