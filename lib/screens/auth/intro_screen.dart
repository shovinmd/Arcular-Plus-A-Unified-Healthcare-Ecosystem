import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../utils/platform_helper.dart';
import '../../widgets/platform_aware_image.dart';
import 'select_user_type.dart';
import 'auth_gate_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthGateScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: IntroGifWidget(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.8,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
} 