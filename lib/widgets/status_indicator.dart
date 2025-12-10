import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatusIndicator extends StatelessWidget {
  final String message;
  final bool isLoading;
  final bool isSuccess;
  final bool isError;
  final Color? color;

  const StatusIndicator({
    super.key,
    required this.message,
    this.isLoading = false,
    this.isSuccess = false,
    this.isError = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    IconData icon;
    
    if (isError) {
      backgroundColor = Colors.red;
      icon = Icons.error;
    } else if (isSuccess) {
      backgroundColor = Colors.green;
      icon = Icons.check_circle;
    } else {
      backgroundColor = color ?? const Color(0xFF2196F3);
      icon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
