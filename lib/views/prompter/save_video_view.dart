import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:gal/gal.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:orator_teleprompter/core/theme.dart'; 

class SaveVideoView extends StatefulWidget {
  final String videoPath;

  const SaveVideoView({super.key, required this.videoPath});

  @override
  State<SaveVideoView> createState() => _SaveVideoViewState();
}

class _SaveVideoViewState extends State<SaveVideoView> {
  bool _isLoading = false;
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
  }

  @override
  void dispose() {
    // Es vital liberar el anuncio para evitar fugas de memoria
    _interstitialAd?.dispose();
    super.dispose();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      // NOTA: Usa este ID de prueba durante el desarrollo.
      // Cámbialo por tu Ad Unit ID real de la consola de AdMob al publicar.
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', 
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdMob: Anuncio cargado con éxito.');
          setState(() => _interstitialAd = ad);
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('AdMob: Error al cargar anuncio: $error');
          _interstitialAd = null;
        },
      ),
    );
  }

  void _showAdAndSave() {
    // Si el anuncio ya está cargado, lo mostramos
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd(); // Preparamos el siguiente anuncio
          _saveVideoToGallery();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadInterstitialAd(); // Intentamos recargar tras el error
          _saveVideoToGallery(); // No castigamos al usuario; guardamos igual
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null; // Eliminamos la referencia tras el show
    } else {
      // Si el anuncio no ha cargado (por mala conexión, etc.), guardamos directo
      debugPrint('AdMob: Anuncio no disponible, procediendo a guardar.');
      _saveVideoToGallery();
    }
  }

  Future<void> _saveVideoToGallery() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final String dest = '${(await getApplicationDocumentsDirectory()).path}/rec_${DateTime.now().millisecondsSinceEpoch}.mp4';
      
      // Copiamos el archivo temporal a una ubicación segura y guardamos en galería
      await File(widget.videoPath).copy(dest);
      await Gal.putVideo(dest);

      if (mounted) {
        _showSuccessMagic();
      }
    } catch (e) {
      debugPrint("Save error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving video. Please try again.'))
        );
      }
    }
  }

  void _showSuccessMagic() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✨ Video saved successfully!', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)), 
        backgroundColor: redOrator,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      )
    );

    // Regresa al usuario al inicio
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Elegant dark gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E1E1E), Colors.black],
              ),
            ),
          ),
          
          // Background glow effect
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: redOrator.withOpacity(0.1),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: _isLoading 
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: redOrator),
                      SizedBox(height: 25),
                      Text("Saving your masterpiece...", 
                        style: TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 1.2)),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Checkmark icon with Magic Glow
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.elasticOut,
                        builder: (context, double value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              padding: const EdgeInsets.all(25),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                                boxShadow: [
                                  BoxShadow(
                                    color: redOrator.withOpacity(0.5 * value),
                                    blurRadius: 50 * value,
                                    spreadRadius: 5 * value,
                                  )
                                ],
                              ),
                              child: const Icon(
                                Icons.check_circle_rounded, 
                                size: 90, 
                                color: Colors.white
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 45),
                      
                      const Text(
                        "GREAT TAKE!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.5,
                        ),
                      ),
                      
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                        child: Text(
                          "Your recording is ready to be shared with the world.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 16, height: 1.4),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Premium SAVE Button
                      Container(
                        width: 280,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          gradient: const LinearGradient(
                            colors: [redOrator, Color(0xFFFF4D4D)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: redOrator.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          // Mejora: Desactivamos el botón mientras carga para evitar clicks dobles
                          onPressed: _isLoading ? null : _showAdAndSave,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save_alt_rounded, color: Colors.white),
                              SizedBox(width: 15),
                              Text(
                                "SAVE VIDEO",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Try again",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
            ),
          ),
          
          // Subtle back button
          Positioned(
            top: 20,
            left: 15,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white24, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}