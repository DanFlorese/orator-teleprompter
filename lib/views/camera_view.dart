import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:gal/gal.dart';
import 'package:orator_teleprompter/core/theme.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class CameraView extends StatefulWidget {
  final String scriptTitle;
  final String scriptContent;

  const CameraView({
    super.key, 
    required this.scriptTitle, 
    required this.scriptContent
  });

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0; 
  bool _isCameraInitialized = false;

  bool _isLoading = false;
  bool _isRecording = false;
  bool _isPaused = false;
  String? _lastVideoPath;
  
  Timer? _audioTimer;
  int _countdownSeconds = 0;
  int _recordingSeconds = 0;
  Timer? _countdownTimer;
  Timer? _recordingTimer;

  final ScrollController _scrollController = ScrollController();
  double _scrollSpeed = 30.0;
  double _fontSize = 28.0;
  
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSafeCamera();
    _loadInterstitialAd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioTimer?.cancel();
    _controller?.dispose();
    _scrollController.dispose();
    _interstitialAd?.dispose();
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(_selectedCameraIndex);
    }
  }

  Future<void> _initializeSafeCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      _selectedCameraIndex = _cameras.length > 1 ? 1 : 0;
      await _initializeCamera(_selectedCameraIndex);
    }
  }

  Future<void> _initializeCamera(int index) async {
    try {
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      if (_controller != null) await _controller!.dispose();

      _controller = CameraController(
        _cameras[index],
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
        _startAudioMonitoring();
      }
    } catch (e) {
      debugPrint("Error cámara: $e");
    }
  }

  void _startAudioMonitoring() {
    _audioTimer?.cancel();
    _audioTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted && _isRecording && !_isPaused) setState(() {});
    });
  }

  void _switchCamera() async {
    if (_isRecording || _cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    setState(() => _isCameraInitialized = false);
    await _initializeCamera(_selectedCameraIndex);
  }

  Future<void> _restartTake() async {
    try {
      await _controller!.stopVideoRecording();
    } catch (e) {
      debugPrint("Error al detener para reiniciar: $e");
    }

    _recordingTimer?.cancel();
    _scrollController.position.hold(() {}); 
    
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordingSeconds = 0;
      _lastVideoPath = null;
    });

    await _scrollController.animateTo(0, 
      duration: const Duration(milliseconds: 500), 
      curve: Curves.easeOut
    );

    _startCountdown();
  }

  void _startCountdown() {
    setState(() => _countdownSeconds = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdownSeconds > 1) {
          _countdownSeconds--;
        } else {
          _countdownSeconds = 0;
          _countdownTimer?.cancel();
          _startRecording();
        }
      });
    });
  }

  Future<void> _startRecording() async {
    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordingSeconds = 0;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!_isPaused) setState(() => _recordingSeconds++);
      });
      _runAutoScroll();
    } catch (e) { debugPrint(e.toString()); }
  }

  Future<void> _stopRecording() async {
    try {
      final file = await _controller!.stopVideoRecording();
      _recordingTimer?.cancel();
      _scrollController.position.hold(() {});
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _lastVideoPath = file.path;
      });
      _scrollController.jumpTo(0);
    } catch (e) { debugPrint(e.toString()); }
  }

  void _runAutoScroll() {
    if (!_isRecording || _isPaused) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;
        final remainingDistance = maxScroll - currentScroll;
        if (remainingDistance > 0) {
          final durationInSeconds = remainingDistance / _scrollSpeed;
          _scrollController.animateTo(
            maxScroll, 
            duration: Duration(milliseconds: (durationInSeconds * 1000).toInt()), 
            curve: Curves.linear
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: redOrator)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Center(child: CameraPreview(_controller!))),
          _buildTeleprompterOverlay(),
          Center(
            child: Container(
              height: 60, width: double.infinity, 
              decoration: BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: Colors.white.withValues(alpha: 0.2))), 
                color: Colors.white.withValues(alpha: 0.05)
              )
            )
          ),
          if (_isRecording) Positioned(top: 50, left: 20, child: _buildRECIndicator()),
          if (!_isRecording && _lastVideoPath == null) _buildTopTools(),
          if (_countdownSeconds > 0) _buildCountdownOverlay(),
          
          // --- SLIDERS VISIBLES SIEMPRE (Menos en pantalla de guardar) ---
          if (_lastVideoPath == null) ...[
            _buildSlider(true), 
            _buildSlider(false), 
          ],

          if (_isRecording) _buildVisualizerOverlay(),

          Align(
            alignment: Alignment.bottomCenter, 
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40), 
              child: _isLoading ? const CircularProgressIndicator(color: redOrator) : _buildControlBar()
            )
          ),
        ],
      ),
    );
  }

  Widget _buildRECIndicator() {
    final mins = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(5)),
      child: Text("REC $mins:$secs", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildTopTools() {
    return Positioned(
      top: 50, right: 15,
      child: Column(
        children: [
          // Se eliminó el botón de flip de aquí para moverlo abajo
          _toolButton(Icons.close, () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
      child: IconButton(icon: Icon(icon, color: Colors.white), onPressed: onTap),
    );
  }

  Widget _buildSlider(bool isFontSize) {
    return Positioned(
      left: isFontSize ? 15 : null, right: isFontSize ? null : 15,
      top: 200, bottom: 200, // Ajustado el top para no encimar con el botón cerrar
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isFontSize ? Icons.text_fields : Icons.speed, color: Colors.white70, size: 20),
          const SizedBox(height: 10),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3, 
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                ),
                child: Slider(
                  value: isFontSize ? _fontSize : _scrollSpeed,
                  min: isFontSize ? 18 : 10, max: isFontSize ? 50 : 100,
                  activeColor: isFontSize ? Colors.blue : redOrator,
                  inactiveColor: Colors.white24,
                  onChanged: (v) => setState(() {
                    if(isFontSize) {
                      _fontSize = v;
                    } else { 
                      _scrollSpeed = v; 
                      if(!_isPaused && _isRecording) _runAutoScroll(); 
                    }
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizerOverlay() {
    return Positioned(
      bottom: 140, left: 0, right: 0,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(10, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 3,
                height: _isPaused ? 4 : (index % 3 == 0 ? 15 : 25) * (0.5 + (DateTime.now().millisecond % 500) / 1000),
                decoration: BoxDecoration(color: redOrator.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(2)),
              );
            }),
          ),
          const SizedBox(height: 4),
          const Text("MIC ACTIVE", style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTeleprompterOverlay() {
    return Positioned.fill(
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter, 
          colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent], 
          stops: [0.0, 0.3, 0.6, 1.0]
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          controller: _scrollController, 
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.45, 
            bottom: MediaQuery.of(context).size.height * 0.5, 
            left: 50, right: 50
          ),
          child: Text(
            widget.scriptContent, textAlign: TextAlign.center, 
            style: TextStyle(
              fontSize: _fontSize, fontWeight: FontWeight.bold, 
              color: Colors.white, shadows: const [Shadow(blurRadius: 10, color: Colors.black)]
            )
          ),
        ),
      )
    );
  }

  Widget _buildCountdownOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5), 
      child: Center(
        child: Text('$_countdownSeconds', 
        style: const TextStyle(fontSize: 150, color: Colors.white, fontWeight: FontWeight.bold))
      )
    );
  }

  Widget _buildControlBar() {
    if (!_isRecording && _lastVideoPath != null) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green, 
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
        ),
        onPressed: _showAdAndSave, 
        icon: const Icon(Icons.download, color: Colors.white),
        label: const Text("SAVE VIDEO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // BOTÓN IZQUIERDO: DINÁMICO (Flip Camera o Restart)
        SizedBox(
          width: 60,
          child: _isRecording 
            ? (_isPaused 
                ? IconButton(onPressed: _restartTake, icon: const Icon(Icons.replay_rounded, size: 40, color: Colors.white70)) 
                : null)
            : (_cameras.length > 1 
                ? IconButton(onPressed: _switchCamera, icon: const Icon(Icons.flip_camera_ios_rounded, size: 35, color: Colors.white70)) 
                : null),
        ),
          
        const SizedBox(width: 20),

        // BOTÓN CENTRAL: PAUSA/RESUME (Solo durante grabación)
        if (_isRecording) IconButton(
          onPressed: () { 
            if(_isPaused) { 
              _controller?.resumeVideoRecording(); 
              setState(() => _isPaused = false);
              _runAutoScroll(); 
            } else { 
              _controller?.pauseVideoRecording(); 
              setState(() => _isPaused = true);
              _scrollController.animateTo(_scrollController.offset, duration: const Duration(milliseconds: 1), curve: Curves.linear); 
            }
          }, 
          icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, size: 50, color: Colors.white)
        ),

        const SizedBox(width: 20),

        // BOTÓN DERECHO: GRABAR / STOP
        GestureDetector(
          onTap: _isRecording ? _stopRecording : (_countdownSeconds > 0 ? null : _startCountdown),
          child: Container(
            height: 80, width: 80, 
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), 
            child: Center(
              child: Container(
                height: _isRecording ? 30 : 60, 
                width: _isRecording ? 30 : 60, 
                decoration: BoxDecoration(
                  color: redOrator, 
                  borderRadius: BorderRadius.circular(_isRecording ? 5 : 40)
                )
              )
            )
          ),
        ),
        
        // Espacio para equilibrar visualmente si no estamos grabando
        if (!_isRecording) const SizedBox(width: 60),
        if (_isRecording) const SizedBox(width: 20), 
      ],
    );
  }

  void _loadInterstitialAd() { 
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712', 
      request: const AdRequest(), 
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad, 
        onAdFailedToLoad: (e) => _interstitialAd = null
      )
    ); 
  }

  void _showAdAndSave() {
    if (_interstitialAd != null) { 
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) { 
          ad.dispose(); 
          _loadInterstitialAd(); 
          _saveVideoToGallery(_lastVideoPath!); 
        }
      ); 
      _interstitialAd!.show(); 
    } else { 
      _saveVideoToGallery(_lastVideoPath!); 
    }
  }

  Future<void> _saveVideoToGallery(String path) async {
    setState(() => _isLoading = true);
    try {
      final String dest = '${(await getApplicationDocumentsDirectory()).path}/rec_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await File(path).copy(dest);
      await Gal.putVideo(dest);
      if (mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✨ Saved to Gallery!'), backgroundColor: Colors.green)); 
        Navigator.pop(context); 
      }
    } catch (e) { 
      debugPrint(e.toString()); 
    } finally { 
      if (mounted) setState(() => _isLoading = false); 
    }
  }
}