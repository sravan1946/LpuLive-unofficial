import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message_model.dart';

class SwipeToReplyMessage extends StatefulWidget {
  final ChatMessage message;
  final bool isReadOnly;
  final VoidCallback onReply;
  final VoidCallback onLongPress;
  final Widget child;

  const SwipeToReplyMessage({
    super.key,
    required this.message,
    required this.isReadOnly,
    required this.onReply,
    required this.onLongPress,
    required this.child,
  });

  @override
  State<SwipeToReplyMessage> createState() => _SwipeToReplyMessageState();
}

class _SwipeToReplyMessageState extends State<SwipeToReplyMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  
  double _dragOffset = 0.0;
  bool _isDragging = false;
  static const double _swipeThreshold = 100.0;
  static const double _maxSwipeDistance = 150.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (widget.isReadOnly) return;
    _isDragging = true;
    _animationController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || widget.isReadOnly) return;
    
    setState(() {
      _dragOffset = (details.delta.dx + _dragOffset).clamp(0.0, _maxSwipeDistance);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging || widget.isReadOnly) return;
    
    _isDragging = false;
    
    if (_dragOffset > _swipeThreshold) {
      // Trigger reply
      HapticFeedback.lightImpact();
      widget.onReply();
      _resetAnimation();
    } else {
      // Snap back
      _resetAnimation();
    }
  }

  void _resetAnimation() {
    _animationController.forward().then((_) {
      setState(() {
        _dragOffset = 0.0;
      });
      _animationController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onLongPressStart: (details) {
        HapticFeedback.mediumImpact();
        widget.onLongPress();
      },
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Stack(
        children: [
          // Reply indicator background
          if (_dragOffset > 20)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: _dragOffset,
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(
                    Icons.reply,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
          // Main content
          AnimatedBuilder(
            animation: _slideAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_dragOffset, 0),
                child: Transform.scale(
                  scale: _isDragging ? 0.98 : 1.0,
                  child: widget.child,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
