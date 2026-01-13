import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:orator_teleprompter/core/theme.dart';
import 'package:gal/gal.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:screen_protector/screen_protector.dart'; // ¡No olvides agregarla al pubspec.yaml!

class VideoPlayerView extends StatefulWidget {
  final String videoPath;
  const VideoPlayerView({super.key, required this.videoPath});

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  late VideoPlayerController _controller;
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    _enableProtections(); // Activamos el escudo antitrampa
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) => setState(() => _controller.play()));
    _loadAd();
  }

  // --- ESCUDO ANTITRAMPA ---
  Future<void> _enableProtections() async {
    // Evita que se graben videos o se tomen fotos de la pantalla
    await ScreenProtector.preventScreenshotOn();
  }

  Future<void> _disableProtections() async {
    await ScreenProtector.preventScreenshotOff();
  }

  void _loadAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', 
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) => _interstitialAd = null,
      ),
    );
  }

  Future<void> _saveToPhone() async {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) async {
          await Gal.putVideo(widget.videoPath);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved to Gallery!'), backgroundColor: Colors.green)
          );
          _loadAd(); 
        },
      );
      _interstitialAd!.show();
    } else {
      await Gal.putVideo(widget.videoPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved!')));
      _loadAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70), 
            onPressed: () async {
              final confirm = await _showDeleteDialog();
              if (confirm == true) {
                await File(widget.videoPath).delete();
                if (!mounted) return;
              }
            }
          ),
          // Botón de descarga con color resaltado
          IconButton(
            icon: const Icon(Icons.download_rounded, color: redOrator), 
            onPressed: _saveToPhone
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. EL VIDEO
          Center(
            child: _controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio, 
                    child: VideoPlayer(_controller)
                  )
                : const CircularProgressIndicator(color: redOrator),
          ),
          
          // 2. MARCA DE AGUA (Segunda capa antitrampa)
          Positioned(
            bottom: 20,
            right: 20,
            child: Opacity(
              opacity: 0.3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ORATOR PRO',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: redOrator,
        mini: true,
        onPressed: () => setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play()),
        child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Future<bool?> _showDeleteDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: graySurface,
        title: const Text('Delete Recording?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: redOrator))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _disableProtections(); // Liberamos el bloqueo al salir
    _controller.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }
}