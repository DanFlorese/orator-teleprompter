import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:orator_teleprompter/services/user_service.dart';

class SmartAdBanner extends StatefulWidget {
  const SmartAdBanner({super.key});

  @override
  State<SmartAdBanner> createState() => _SmartAdBannerState();
}

class _SmartAdBannerState extends State<SmartAdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  // IMPORTANTE: Este es un ID de prueba oficial de Google para Android.
  // Cuando verifiques que funciona, reemplázalo por tu "ID de bloque de anuncios" de AdMob.
  final String adUnitId = 'ca-app-pub-2835931777848065/2794410919';

  @override
  void initState() {
    super.initState();
    _initAdSystem();
  }

  Future<void> _initAdSystem() async {
    // Solo intentamos cargar el anuncio si el usuario NO es premium
    final isPremium = await UserService().isUserPremium();
    if (!isPremium) {
      _loadBanner();
    }
  }

  void _loadBanner() {
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('BannerAd cargado exitosamente.');
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('Error al cargar BannerAd: ${err.message}');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose(); // Muy importante para no gastar memoria
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: UserService().isUserPremium(),
      builder: (context, snapshot) {
        // 1. Mientras decide si es premium o si el usuario es VIP, no mostramos nada
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        
        final isPremium = snapshot.data ?? false;
        if (isPremium) return const SizedBox.shrink();

        // 2. Si es usuario gratuito y el anuncio cargó, mostramos el AdWidget
        if (_isLoaded && _bannerAd != null) {
          return Container(
            alignment: Alignment.center,
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            color: Colors.black, // Mantiene la estética de tu app
            child: AdWidget(ad: _bannerAd!),
          );
        }

        // 3. Si no ha cargado aún, no mostramos nada para no dejar huecos negros feos
        return const SizedBox.shrink();
      },
    );
  }
}