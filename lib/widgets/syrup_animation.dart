import 'package:flutter/material.dart';
import 'dart:math';

class SyrupAnimation extends StatefulWidget {
  final double size;
  final Color color;
  
  const SyrupAnimation({
    super.key,
    this.size = 60,
    this.color = const Color(0xFF32CCBC),
  });

  @override
  State<SyrupAnimation> createState() => _SyrupAnimationState();
}

class _SyrupAnimationState extends State<SyrupAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _waveAnimation;
  late Animation<double> _bubbleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * 3.14159,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _bubbleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: SyrupPainter(
              waveValue: _waveAnimation.value,
              bubbleValue: _bubbleAnimation.value,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

class SyrupPainter extends CustomPainter {
  final double waveValue;
  final double bubbleValue;
  final Color color;

  SyrupPainter({
    required this.waveValue,
    required this.bubbleValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Main bottle shape
    final bottleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.2, size.height * 0.1, 
                     size.width * 0.6, size.height * 0.8),
      const Radius.circular(8),
    );
    canvas.drawRRect(bottleRect, paint);

    // Liquid level with wave effect
    final liquidHeight = size.height * 0.6;
    final liquidPath = Path();
    liquidPath.moveTo(size.width * 0.2, size.height * 0.1 + liquidHeight);
    
    for (double x = 0; x <= size.width * 0.6; x += 2) {
      final y = size.height * 0.1 + liquidHeight + 
                sin(waveValue + x * 0.1) * 3;
      liquidPath.lineTo(size.width * 0.2 + x, y);
    }
    
    liquidPath.lineTo(size.width * 0.8, size.height * 0.1 + liquidHeight);
    liquidPath.lineTo(size.width * 0.8, size.height * 0.9);
    liquidPath.lineTo(size.width * 0.2, size.height * 0.9);
    liquidPath.close();
    
    canvas.drawPath(liquidPath, paint);

    // Bubbles
    final bubblePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      final bubbleX = size.width * 0.3 + (i * size.width * 0.15);
      final bubbleY = size.height * 0.3 + (i * size.height * 0.1);
      final bubbleSize = 4 + sin(bubbleValue + i) * 2;
      
      canvas.drawCircle(
        Offset(bubbleX, bubbleY),
        bubbleSize,
        bubblePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 