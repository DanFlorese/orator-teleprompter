import 'package:flutter/material.dart';
import 'package:orator_teleprompter/services/user_service.dart';

class SmartAdBanner extends StatelessWidget {
  const SmartAdBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: UserService().isUserPremium(),
      builder: (context, snapshot) {
        // 1. Si está cargando o es premium, no mostramos nada (SizedBox vacío)
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        
        final isPremium = snapshot.data ?? false;
        
        if (isPremium) {
          return const SizedBox.shrink(); // 0 píxeles de altura para usuarios VIP
        }

        // 2. Si NO es premium, mostramos el anuncio
        return Container(
          width: double.infinity,
          height: 60,
          color: Colors.black, // O el color de fondo de tu app
          child: const Center(
            child: Text(
              "ANUNCIO DE PRUEBA AQUÍ", 
              style: TextStyle(color: Colors.white24, fontSize: 10),
            ),
            // Aquí irá tu AdWidget de Google AdMob más adelante
          ),
        );
      },
    );
  }
}