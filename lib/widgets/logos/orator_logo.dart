import 'package:flutter/material.dart';
import 'package:orator_teleprompter/core/theme.dart';

class OratorLogo extends StatefulWidget {
  final double size;
  const OratorLogo({super.key, this.size = 130});

  @override
  State<OratorLogo> createState() => _OratorLogoState();
}

class _OratorLogoState extends State<OratorLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 25.0, end: 55.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Capa de resplandor animada
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              width: widget.size * 0.6,
              height: widget.size * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: redOrator.withAlpha(128),
                    blurRadius: _glowAnimation.value,
                    spreadRadius: _glowAnimation.value / 4,
                  ),
                ],
              ),
            );
          },
        ),
        // Imagen del logo desde la carpeta correcta
        Image.asset(
          'assets/images/logo_icon.png',
          height: widget.size,
          errorBuilder: (context, error, stackTrace) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 40),
              Text(
                'Check assets/images/',
                style: TextStyle(
                  color: Colors.white.withAlpha(128),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}