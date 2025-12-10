import 'package:flutter/material.dart';
import 'package:arcular_plus/screens/user/ai_chatbot_screen.dart';

class ChatArcFloatingButton extends StatefulWidget {
  final String userType;
  
  const ChatArcFloatingButton({
    super.key,
    this.userType = 'user',
  });

  @override
  State<ChatArcFloatingButton> createState() => _ChatArcFloatingButtonState();
}

class _ChatArcFloatingButtonState extends State<ChatArcFloatingButton>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseScaleAnimation;
  
  // Draggable functionality
  Offset _position = const Offset(16, 0); // Default position (left side)
  bool _isDragging = false; // used to tweak pulse while dragging

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Subtle idle pulse (zoom in/out)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );
    _pulseScaleAnimation = Tween<double>(
      begin: 0.98,
      end: 1.04,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
    
    // Set initial position to bottom right
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final screenSize = MediaQuery.of(context).size;
        setState(() {
          _position = Offset(screenSize.width - 76, screenSize.height - 200); // Bottom right
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _openChatArc() async {
    // Animate button press
    _animationController.forward();
    
    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 150));
    
    // Navigate to chat screen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AIChatbotScreen(userType: widget.userType),
      ),
    );
    
    // Reset animation when returning from chat
    _animationController.reverse();
  }

  // Removed unused helper methods to satisfy linter

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final pulse = _isDragging ? 1.0 : _pulseScaleAnimation.value;
          return Transform.scale(
            scale: _scaleAnimation.value * pulse,
            child: Transform.rotate(
              angle: _rotateAnimation.value,
              child: GestureDetector(
                onTap: _openChatArc,
                onPanStart: (details) {
                  setState(() {
                    _isDragging = true;
                  });
                },
                onPanUpdate: (details) {
                  final screenSize = MediaQuery.of(context).size;
                  setState(() {
                    _position = Offset(
                      (_position.dx + details.delta.dx).clamp(0.0, screenSize.width - 60),
                      (_position.dy + details.delta.dy).clamp(0.0, screenSize.height - 200),
                    );
                  });
                },
                onPanEnd: (details) {
                  final screenSize = MediaQuery.of(context).size;
                  setState(() {
                    _isDragging = false;
                    // Snap to edges
                    if (_position.dx < screenSize.width / 2) {
                      _position = Offset(16, _position.dy);
                    } else {
                      _position = Offset(screenSize.width - 76, _position.dy);
                    }
                  });
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)], // Indigo gradient
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.3), // Indigo gradient color
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.asset(
                          'assets/images/ChatArc.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.smart_toy,
                              color: Color(0xFF667eea), // Indigo gradient color
                              size: 30,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 