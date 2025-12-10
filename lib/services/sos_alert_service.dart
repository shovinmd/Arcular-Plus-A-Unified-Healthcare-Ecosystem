import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class SOSAlertService {
  static final SOSAlertService _instance = SOSAlertService._internal();
  factory SOSAlertService() => _instance;
  SOSAlertService._internal();

  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  bool _isVibrating = false;
  Timer? _audioTimer;
  Timer? _vibrationTimer;

  // Initialize the service
  Future<void> initialize() async {
    try {
      _audioPlayer = AudioPlayer();

      // Set audio player mode for better performance
      await _audioPlayer?.setPlayerMode(PlayerMode.lowLatency);

      // Set release mode to loop
      await _audioPlayer?.setReleaseMode(ReleaseMode.loop);

      print('🔊 SOS Alert Service initialized with custom audio');
    } catch (e) {
      print('❌ Error initializing SOS Alert Service: $e');
    }
  }

  // Trigger SOS vibration pattern using vibration package
  Future<void> triggerSOSVibration() async {
    try {
      _isVibrating = true;

      // Check if device can vibrate
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) {
        print('⚠️ Device does not support vibration');
        return;
      }

      // SOS pattern: three short vibrations, pause, three short vibrations
      // This creates the classic SOS pattern: ... --- ...
      await Vibration.vibrate(duration: 200); // Short vibration
      await Future.delayed(const Duration(milliseconds: 100));
      await Vibration.vibrate(duration: 200); // Short vibration
      await Future.delayed(const Duration(milliseconds: 100));
      await Vibration.vibrate(duration: 200); // Short vibration
      await Future.delayed(const Duration(milliseconds: 300)); // Pause
      await Vibration.vibrate(duration: 500); // Long vibration
      await Future.delayed(const Duration(milliseconds: 100));
      await Vibration.vibrate(duration: 500); // Long vibration
      await Future.delayed(const Duration(milliseconds: 100));
      await Vibration.vibrate(duration: 500); // Long vibration
      await Future.delayed(const Duration(milliseconds: 300)); // Pause
      await Vibration.vibrate(duration: 200); // Short vibration
      await Future.delayed(const Duration(milliseconds: 100));
      await Vibration.vibrate(duration: 200); // Short vibration
      await Future.delayed(const Duration(milliseconds: 100));
      await Vibration.vibrate(duration: 200); // Short vibration

      // Create a repeating SOS pattern
      _vibrationTimer =
          Timer.periodic(const Duration(seconds: 3), (timer) async {
        if (_isVibrating) {
          // Repeat the SOS pattern
          await Vibration.vibrate(duration: 200);
          await Future.delayed(const Duration(milliseconds: 100));
          await Vibration.vibrate(duration: 200);
          await Future.delayed(const Duration(milliseconds: 100));
          await Vibration.vibrate(duration: 200);
          await Future.delayed(const Duration(milliseconds: 300));
          await Vibration.vibrate(duration: 500);
          await Future.delayed(const Duration(milliseconds: 100));
          await Vibration.vibrate(duration: 500);
          await Future.delayed(const Duration(milliseconds: 100));
          await Vibration.vibrate(duration: 500);
          await Future.delayed(const Duration(milliseconds: 300));
          await Vibration.vibrate(duration: 200);
          await Future.delayed(const Duration(milliseconds: 100));
          await Vibration.vibrate(duration: 200);
          await Future.delayed(const Duration(milliseconds: 100));
          await Vibration.vibrate(duration: 200);
        } else {
          timer.cancel();
        }
      });

      print('🚨 SOS Vibration started with SOS pattern');
    } catch (e) {
      print('❌ Error triggering SOS vibration: $e');
    }
  }

  // Play SOS alarm sound using custom audio file from assets
  Future<void> playSOSAlarm() async {
    try {
      if (_audioPlayer == null) {
        await initialize();
      }

      if (_isPlaying) {
        print('🔊 SOS alarm already playing');
        return;
      }

      _isPlaying = true;

      // Play the custom SOS alarm sound from assets
      await _audioPlayer?.play(AssetSource('images/audio/SOS.mp3'));

      print('🚨 SOS Alarm sound started with custom audio file');
    } catch (e) {
      print('❌ Error playing SOS alarm: $e');
      _isPlaying = false;
    }
  }

  // Stop SOS alarm sound
  Future<void> stopSOSAlarm() async {
    try {
      if (_audioPlayer != null && _isPlaying) {
        await _audioPlayer?.stop();
        _isPlaying = false;
        print('🔇 SOS Alarm sound stopped');
      }
    } catch (e) {
      print('❌ Error stopping SOS alarm: $e');
    }
  }

  // Stop SOS vibration
  Future<void> stopSOSVibration() async {
    try {
      if (_isVibrating) {
        _vibrationTimer?.cancel();
        _vibrationTimer = null;
        _isVibrating = false;
        print('🔇 SOS Vibration stopped');
      }
    } catch (e) {
      print('❌ Error stopping SOS vibration: $e');
    }
  }

  // Start complete SOS alert (both vibration and sound)
  Future<void> startSOSAlert() async {
    print('🚨 Starting complete SOS alert system');

    // Start both vibration and sound simultaneously
    await Future.wait([
      triggerSOSVibration(),
      playSOSAlarm(),
    ]);
  }

  // Stop complete SOS alert (both vibration and sound)
  Future<void> stopSOSAlert() async {
    print('🔇 Stopping complete SOS alert system');

    // Stop both vibration and sound
    await Future.wait([
      stopSOSVibration(),
      stopSOSAlarm(),
    ]);
  }

  // Check if SOS alert is currently active
  bool get isAlertActive => _isPlaying || _isVibrating;

  // Dispose resources
  Future<void> dispose() async {
    await stopSOSAlert();
    await _audioPlayer?.dispose();
    _audioPlayer = null;
    _audioTimer?.cancel();
    _vibrationTimer?.cancel();
    _audioTimer = null;
    _vibrationTimer = null;
  }

  // Set volume for alarm sound
  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer?.setVolume(volume.clamp(0.0, 1.0));
      print('🔊 Volume set to ${(volume * 100).toInt()}%');
    } catch (e) {
      print('❌ Error setting volume: $e');
    }
  }

  // Set alarm to loop continuously
  Future<void> setLoopMode(bool loop) async {
    try {
      await _audioPlayer
          ?.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      print('🔄 Loop mode set to: $loop');
    } catch (e) {
      print('❌ Error setting loop mode: $e');
    }
  }
}
