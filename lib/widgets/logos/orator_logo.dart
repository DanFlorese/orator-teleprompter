import 'package:flutter/material.dart';

class OratorLogo extends StatelessWidget {
  final double size;

  const OratorLogo({super.key, this.size = 100.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black, // El fondo negro que acordamos
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Image.asset(
          'assets/images/logo_icon.png', // Asegúrate de que este sea el nombre de tu archivo de imagen
          width: size * 0.7,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}