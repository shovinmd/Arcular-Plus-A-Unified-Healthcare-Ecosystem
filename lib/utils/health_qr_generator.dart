import 'dart:math';

class HealthQrGenerator {
  static const String _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static final Random _random = Random();

  /// Generate a unique Health QR ID
  /// Format: ARC-XXXX-XXXX-XXXX (where X is alphanumeric)
  static String generateHealthQrId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomPart = _generateRandomString(8);
    final lastFourDigits = timestamp.substring(timestamp.length - 4);
    
    return 'ARC-$randomPart-$lastFourDigits';
  }

  /// Generate a random string of specified length
  static String _generateRandomString(int length) {
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => _chars.codeUnitAt(_random.nextInt(_chars.length)),
      ),
    );
  }

  /// Validate if a Health QR ID is in correct format
  static bool isValidHealthQrId(String qrId) {
    if (qrId == null || qrId.isEmpty) return false;
    
    // Check format: ARC-XXXX-XXXX-XXXX
    final pattern = RegExp(r'^ARC-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$');
    return pattern.hasMatch(qrId);
  }

  /// Extract timestamp from Health QR ID
  static DateTime? extractTimestamp(String qrId) {
    if (!isValidHealthQrId(qrId)) return null;
    
    try {
      final parts = qrId.split('-');
      if (parts.length != 4) return null;
      
      final lastFourDigits = parts[3];
      final currentTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final baseTimestamp = currentTimestamp.substring(0, currentTimestamp.length - 4) + lastFourDigits;
      
      return DateTime.fromMillisecondsSinceEpoch(int.parse(baseTimestamp));
    } catch (e) {
      return null;
    }
  }
} 