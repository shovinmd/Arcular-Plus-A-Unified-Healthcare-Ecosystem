import 'dart:async';
import 'package:flutter/material.dart';
import 'package:arcular_plus/services/notification_service.dart';

class ShakingBellNotification extends StatefulWidget {
  final String userType;
  final VoidCallback? onTap;
  final Color? iconColor;
  final double? iconSize;
  final bool showBadge;
  final Widget? child;

  const ShakingBellNotification({
    super.key,
    required this.userType,
    this.onTap,
    this.iconColor,
    this.iconSize,
    this.showBadge = true,
    this.child,
  });

  @override
  State<ShakingBellNotification> createState() =>
      _ShakingBellNotificationState();
}

class _ShakingBellNotificationState extends State<ShakingBellNotification>
    with TickerProviderStateMixin {
  late AnimationController _shakeController;
  late AnimationController _pulseController;
  late Animation<double> _shakeAnimation;
  late Animation<double> _pulseAnimation;

  int _unreadCount = 0;
  bool _hasNewNotifications = false;
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkNotifications();
    _startPeriodicCheck();
  }

  void _initializeAnimations() {
    // Shake animation
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    // Pulse animation for badge
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  void _checkNotifications() async {
    try {
      final unreadCount =
          await NotificationService.getUnreadCount(widget.userType);
      final hasNew =
          await NotificationService.hasNewNotifications(widget.userType);

      if (mounted) {
        setState(() {
          _unreadCount = unreadCount;
          _hasNewNotifications = hasNew;
        });

        // Start shake animation if there are new notifications
        if (hasNew && unreadCount > 0) {
          _startShakeAnimation();
        }

        // Start pulse animation for badge if there are unread notifications
        if (unreadCount > 0) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
        }
      }
    } catch (e) {
      print('❌ Error checking notifications: $e');
    }
  }

  void _startPeriodicCheck() {
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkNotifications();
    });
  }

  void _startShakeAnimation() {
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pulseController.dispose();
    _checkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Mark notifications as checked when tapped
        NotificationService.updateLastCheckTime(widget.userType);
        _checkNotifications();

        if (widget.onTap != null) {
          widget.onTap!();
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_shakeAnimation, _pulseAnimation]),
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              _shakeAnimation.value * 10 * (_hasNewNotifications ? 1 : 0),
              0,
            ),
            child: Stack(
              children: [
                // Main icon
                widget.child ??
                    Icon(
                      Icons.notifications,
                      color: widget.iconColor ?? Colors.white,
                      size: widget.iconSize ?? 24,
                    ),

                // Badge
                if (widget.showBadge && _unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
