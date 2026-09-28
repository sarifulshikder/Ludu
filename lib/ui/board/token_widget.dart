import 'package:flutter/material.dart';
import '../../models/ludo_color.dart';
import '../../models/token.dart';
import '../../services/haptics_service.dart';

class TokenWidget extends StatefulWidget {
  final Token token;
  final double size;
  final bool isMovable;
  final VoidCallback? onTap;

  const TokenWidget({
    super.key,
    required this.token,
    required this.size,
    this.isMovable = false,
    this.onTap,
  });

  @override
  State<TokenWidget> createState() => _TokenWidgetState();
}

class _TokenWidgetState extends State<TokenWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _pulseScale = Tween<double>(begin: 1.0, end: 1.20).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isMovable) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant TokenWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMovable != oldWidget.isMovable) {
      if (widget.isMovable) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.isMovable) return;
    HapticsService.medium();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.token.color;
    final tokenSize = widget.size;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: SizedBox(
          width: tokenSize < 44 ? 44 : tokenSize,
          height: tokenSize < 44 ? 44 : tokenSize,
          child: Center(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = widget.isMovable ? _pulseScale.value : 1.0;

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: tokenSize,
                    height: tokenSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.isMovable
                              ? color.lightGlow.withOpacity(0.9)
                              : Colors.black.withOpacity(0.45),
                          blurRadius: widget.isMovable ? 14 : 6,
                          spreadRadius: widget.isMovable ? 2.5 : 0.5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer 3D metallic/gold beveled rim
                        Container(
                          width: tokenSize,
                          height: tokenSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: widget.isMovable
                                  ? [
                                      const Color(0xFFFFF7D6),
                                      const Color(0xFFFFD700),
                                      const Color(0xFFB8860B),
                                    ]
                                  : [
                                      Colors.white,
                                      const Color(0xFFE2E8F0),
                                      const Color(0xFF94A3B8),
                                      const Color(0xFF475569),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),

                        // Inner jewel body
                        Container(
                          width: tokenSize * 0.82,
                          height: tokenSize * 0.82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                color.lightGlow,
                                color.primary,
                                color.darkShade,
                              ],
                              center: const Alignment(-0.35, -0.35),
                              radius: 0.95,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 3,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: widget.token.isHome
                                ? Icon(
                                    Icons.star_rounded,
                                    color: const Color(0xFFFFD700),
                                    size: tokenSize * 0.46,
                                  )
                                : Text(
                                    '${widget.token.id + 1}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: tokenSize * 0.42,
                                      fontWeight: FontWeight.w900,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black87,
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),

                        // Specular glass highlight reflection
                        Positioned(
                          top: tokenSize * 0.14,
                          left: tokenSize * 0.20,
                          child: Container(
                            width: tokenSize * 0.30,
                            height: tokenSize * 0.16,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(tokenSize),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
