import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:arcular_plus/firebase_options.dart';
import 'package:arcular_plus/app.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/services/fcm_service.dart';
import 'package:arcular_plus/utils/constants.dart';
import 'package:arcular_plus/utils/user_type_enum.dart';
import 'package:arcular_plus/screens/auth/intro_screen.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

final String backendUrl = 'https://arcular-plus-backend.onrender.com';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize FCM service
  await FCMService().initialize();

  runApp(const MyApp());
}

Future<void> registerFcmToken() async {
  try {
    final fcmToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    print('FCM Token: ' + (fcmToken ?? 'null'));
    // TODO: Send this token to your backend and associate with the user
  } catch (e) {
    print('Error getting FCM token: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Arcular Plus',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const IntroScreen(),
    );
  }
}

Future<Map<String, dynamic>?> fetchUserProfile() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final idToken = await user.getIdToken();
  final response = await http.get(
    Uri.parse('$backendUrl/api/users/profile'),
    headers: {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    // Handle error
    return null;
  }
}

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: fetchUserProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return Center(child: Text('Failed to load profile'));
        }
        final profile = snapshot.data!;
        return Column(
          children: [
            Text('Name: ${profile['name'] ?? ''}'),
            Text('Arc ID: ${profile['arcId'] ?? ''}'),
            // If QR code is a URL:
            if (profile['qrCodeUrl'] != null)
              Image.network(profile['qrCodeUrl']),
            // If QR code is base64:
            // if (profile['qrCode'] != null)
            //   Image.memory(base64Decode(profile['qrCode'])),
            // ... other profile fields
          ],
        );
      },
    );
  }
}

Future<String?> uploadReport(File file) async {
  final uri = Uri.parse('http://<YOUR_BACKEND_URL>/api/reports/upload');
  var request = http.MultipartRequest('POST', uri)
    ..files.add(await http.MultipartFile.fromPath('file', file.path));
  var response = await request.send();
  if (response.statusCode == 200) {
    final respStr = await response.stream.bytesToString();
    final url = jsonDecode(respStr)['url'];
    return url;
  }
  return null;
}

Future<void> verifyOtpAndSendToBackend(String smsCode, String verificationId) async {
  PhoneAuthCredential credential = PhoneAuthProvider.credential(
    verificationId: verificationId,
    smsCode: smsCode,
  );
  UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
  String? idToken = await userCredential.user?.getIdToken();
  // Send idToken to your backend for verification
  final response = await http.post(
    Uri.parse('http://<YOUR_BACKEND_URL>/api/auth/verify-otp'),
    body: {'idToken': idToken},
  );
  // Handle backend response
}

Future<bool> verifyOtpWithBackend(String idToken) async {
  final response = await http.post(
    Uri.parse('https://arcular-plus-backend.onrender.com/api/notifications/verify-otp'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'idToken': idToken}),
  );
  if (response.statusCode == 200) {
    return true;
  } else {
    print('OTP verification failed: ${response.body}');
    return false;
  }
}

Future<void> sendFcmTokenToBackend(String userId, String token) async {
  try {
    final response = await http.post(
      Uri.parse('$backendUrl/api/notifications/register-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'token': token}),
    );
    if (response.statusCode == 200) {
      print('FCM token registered with backend');
    } else {
      print('Failed to register FCM token: ${response.body}');
    }
  } catch (e) {
    print('Error sending FCM token to backend: $e');
  }
}

Future<void> registerFcmTokenAndSendToBackend() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final fcmToken = await user.getIdToken();
    if (fcmToken != null) {
      await sendFcmTokenToBackend(user.uid, fcmToken);
    }
  } catch (e) {
    print('Error in registerFcmTokenAndSendToBackend: $e');
  }
}
