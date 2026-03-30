import 'dart:io'; // Necesario para detectar Android/iOS
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

  // IDs REALES de AdMob para Banner
  final String _adUnitIdAndroid = 'ca-app-pub-2835931777848065/2794410919';
  final String _adUnitIdiOS = 'ca-app-pub-2835931777848065/XXXXXXXXXX'; // REEMPLAZA CUANDO TENGAS EL ID DE BANNER IOS

  @override
  void initState() {
    super.initState();
    _initAdSystem();
  }

  Future<void> _initAdSystem() async {
    // Solo cargamos si el usuario no es premium
    final isPremium = await UserService().isUserPremium();
    if (!isPremium) {
      _loadBanner();
    }
  }

  void _loadBanner() {
    // Selecciona el ID correcto según el dispositivo
    final String adUnitId = Platform.isAndroid ? _adUnitIdAndroid : _adUnitIdiOS;

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('SmartAdBanner: Cargado exitosamente.');
          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('SmartAdBanner: Error al cargar: ${err.message}');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose(); // Liberar memoria
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: UserService().isUserPremium(),
      builder: (context, snapshot) {
        // 1. Mientras carga el estado premium, no mostramos nada
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        
        final isPremium = snapshot.data ?? false;
        if (isPremium) return const SizedBox.shrink();

        // 2. Si es gratuito y cargó el anuncio, mostramos el AdWidget
        if (_isLoaded && _bannerAd != null) {
          return Container(
            alignment: Alignment.center,
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            color: Colors.black, // Estética oscura de Orator
            child: AdWidget(ad: _bannerAd!),
          );
        }

        // 3. Fallback: espacio vacío
        return const SizedBox.shrink();
      },
    );
  }
}