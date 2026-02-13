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
  // Cambiado de InterstitialAd a RewardedAd para el intercambio por recompensa
  RewardedAd? _rewardedAd;

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  // Carga el anuncio recompensado usando el ID de prueba de Android
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/5224354917', 
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() => _rewardedAd = ad);
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('RewardedAd failed to load: $error');
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Muestra un diálogo de advertencia antes de salir
  Future<bool> _showExitWarning() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "DISCARD VIDEO?",
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.w900, 
            letterSpacing: 1.2
          ),
        ),
        content: const Text(
          "If you leave now, your recording will be lost forever. Are you sure?",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DISCARD", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: redOrator,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text("KEEP & SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;
  }

  // Lógica principal: Muestra anuncio y al terminar guarda el video
  void _showAdAndSave() {
    if (_rewardedAd != null) {
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadRewardedAd(); // Preparamos el siguiente
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadRewardedAd();
          _saveVideoToGallery(); // Si falla, guardamos de todos modos
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          // El usuario terminó de ver el anuncio: Recompensa activada
          _saveVideoToGallery();
        },
      );
      _rewardedAd = null;
    } else {
      // Si por alguna razón el anuncio no está listo, no bloqueamos al usuario
      _saveVideoToGallery();
    }
  }

  Future<void> _saveVideoToGallery() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final String dest = '${(await getApplicationDocumentsDirectory()).path}/rec_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await File(widget.videoPath).copy(dest);
      await Gal.putVideo(dest);

      if (mounted) {
        _showSuccessMagic();
      }
    } catch (e) {
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
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, 
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showExitWarning();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1E1E1E), Colors.black],
                ),
              ),
            ),
            
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: redOrator.withValues(alpha: .1),
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
                                  color: Colors.white.withValues(alpha: .05),
                                  boxShadow: [
                                    BoxShadow(
                                      color: redOrator.withValues(alpha: 0.5 * value),
                                      blurRadius: 50 * value,
                                      spreadRadius: 5 * value,
                                    )
                                  ],
                                ),
                                child: const Icon(Icons.check_circle_rounded, size: 90, color: Colors.white),
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
                                color: redOrator.withValues(alpha: 0.4),
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
                          onPressed: () async {
                            final shouldPop = await _showExitWarning();
                            if (shouldPop && context.mounted) Navigator.pop(context);
                          },
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
            
            Positioned(
              top: 20,
              left: 15,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white24, size: 22),
                onPressed: () async {
                  final shouldPop = await _showExitWarning();
                  if (shouldPop && context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}