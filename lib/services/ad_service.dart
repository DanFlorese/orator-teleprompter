import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';
import 'dart:io'; // Necesario para detectar si es Android o iOS

class AdService {
  InterstitialAd? _interstitialAd;
  
  // ID REAL de AdMob (Android)
  final String _adUnitIdAndroid = 'ca-app-pub-2835931777848065/5170397430';
  // ID REAL de AdMob (iOS) - Reemplázalo cuando tengas el ID de unidad de iOS
  final String _adUnitIdiOS = 'ca-app-pub-2835931777848065/XXXXXXXXXX'; 

  void loadAd() {
    // Detecta automáticamente qué ID usar
    String adUnitId = Platform.isAndroid ? _adUnitIdAndroid : _adUnitIdiOS;

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null; // Limpiar referencia
              loadAd(); 
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              loadAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          // Reintento silencioso tras 30 segundos
          Future.delayed(const Duration(seconds: 30), () => loadAd());
        },
      ),
    );
  }

  Future<void> showAdIfAvailable() async {
    if (_interstitialAd != null) {
      final completer = Completer<void>();
      
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          loadAd();
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
          loadAd();
          if (!completer.isCompleted) completer.complete();
        },
      );

      await _interstitialAd!.show();
      return completer.future;
    } else {
      loadAd(); 
      return; 
    }
  }
}