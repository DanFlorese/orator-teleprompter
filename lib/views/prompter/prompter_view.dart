import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:gal/gal.dart';
import 'package:orator_teleprompter/core/theme.dart';

class PrompterView extends StatefulWidget {
  final String title;
  final String content;

  const PrompterView({super.key, required this.title, required this.content});

  @override
  State<PrompterView> createState() => _PrompterViewState();
}

class _PrompterViewState extends State<PrompterView> {
  CameraController? _cameraController;
  final ScrollController _scrollController = ScrollController();
  InterstitialAd? _interstitialAd;
  
  bool _isRecording = false;
  bool _isLoading = false;
  double _scrollSpeed = 20.0;
  double _fontSize = 28.0;
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadInterstitialAd();
  }

  // --- LÓGICA DE NEGOCIO ---

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
    _cameraController = CameraController(front, ResolutionPreset.high, enableAudio: true);
    await _cameraController!.initialize();
    if (mounted) setState(() {});
  }

  void _startScrolling() {
    if (_scrollController.hasClients) {
      double maxScroll = _scrollController.position.maxScrollExtent;
      double duration = (maxScroll / _scrollSpeed) * 1000;
      _scrollController.animateTo(maxScroll, 
        duration: Duration(milliseconds: duration.toInt()), curve: Curves.linear);
    }
  }

  void _cancelRecording() async {
    if (_isRecording) {
      await _cameraController!.stopVideoRecording();
      _scrollController.jumpTo(0);
      setState(() => _isRecording = false);
      _showToast('Recording cancelled');
    }
  }

  void _finishAndShowAd() async {
    final XFile video = await _cameraController!.stopVideoRecording();
    setState(() { _isRecording = false; _videoPath = video.path; });

    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) { ad.dispose(); _saveVideoInHD(); },
        onAdFailedToShowFullScreenContent: (ad, error) { ad.dispose(); _saveVideoInHD(); }
      );
      _interstitialAd!.show();
    } else {
      _saveVideoInHD();
    }
  }

  Future<void> _saveVideoInHD() async {
    if (_videoPath == null) return;
    setState(() => _isLoading = true);
    try {
      await Gal.putVideo(_videoPath!);
      _showToast('✨ Professional HD Video Saved!');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) => _interstitialAd = null,
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- COMPONENTES DE VISTA (UI) ---

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: redOrator)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildCameraPreview(),
          _buildOverlayShadow(),
          _buildTeleprompterText(),
          _buildTopNavigation(),
          _buildBottomControls(),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Center(
      child: AspectRatio(
        aspectRatio: _cameraController!.value.aspectRatio,
        child: CameraPreview(_cameraController!),
      ),
    );
  }

  Widget _buildOverlayShadow() {
    return Container(color: Colors.black.withValues(alpha:0.4));
  }

  Widget _buildTopNavigation() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            !_isRecording 
              ? IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context))
              : TextButton.icon(
                  onPressed: _cancelRecording,
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  label: const Text('CANCEL', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(backgroundColor: Colors.black38),
                ),
            if (_isRecording)
              const Row(
                children: [
                  Icon(Icons.circle, color: Colors.red, size: 12),
                  SizedBox(width: 8),
                  Text('REC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeleprompterText() {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 120),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 35),
              children: [
                Text(
                  widget.content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _fontSize,
                    fontWeight: FontWeight.bold,
                    shadows: const [Shadow(blurRadius: 15, color: Colors.black)],
                  ),
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha:0.9), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isRecording) ...[
              _buildSlider(Icons.format_size, _fontSize, 18, 60, (v) => setState(() => _fontSize = v), "pt"),
              const SizedBox(height: 10),
              _buildSlider(Icons.speed, _scrollSpeed, 10, 100, (v) => setState(() => _scrollSpeed = v), "x"),
            ],
            const SizedBox(height: 25),
            _buildRecordButton(),
            const SizedBox(height: 15),
            Text(
              _isRecording ? 'TAP TO STOP & SAVE' : 'START RECORDING',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(IconData icon, double value, double min, double max, Function(double) onChanged, String unit) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        Expanded(
          child: Slider(
            value: value, min: min, max: max,
            activeColor: icon == Icons.speed ? redOrator : Colors.blueAccent,
            onChanged: onChanged,
          ),
        ),
        Text("${value.toInt()}$unit", style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: () {
        if (!_isRecording) {
          _cameraController!.startVideoRecording();
          _startScrolling();
          setState(() => _isRecording = true);
        } else {
          _finishAndShowAd();
        }
      },
      child: CircleAvatar(
        radius: 42,
        backgroundColor: Colors.white,
        child: CircleAvatar(
          radius: 38,
          backgroundColor: _isRecording ? Colors.white : redOrator,
          child: Icon(
            _isRecording ? Icons.stop_rounded : Icons.videocam_rounded,
            color: _isRecording ? redOrator : Colors.white,
            size: 45,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: redOrator),
            SizedBox(height: 20),
            Text("Saving in High Quality...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}