import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:orator_teleprompter/core/theme.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:orator_teleprompter/views/prompter/save_video_view.dart';

class CameraView extends StatefulWidget {
  final String scriptTitle;
  final String scriptContent;

  const CameraView(
      {super.key, required this.scriptTitle, required this.scriptContent});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;

  bool _isRecording = false;
  bool _isPaused = false;

  Timer? _audioTimer;
  int _countdownSeconds = 0;
  int _recordingSeconds = 0;
  Timer? _countdownTimer;
  Timer? _recordingTimer;

  final ScrollController _scrollController = ScrollController();
  double _scrollSpeed = 30.0;
  double _fontSize = 28.0;

  // Estados para mostrar los números solo al tocar
  bool _showFontValue = false;
  bool _showSpeedValue = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSafeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioTimer?.cancel();
    _controller?.dispose();
    _scrollController.dispose();
    _countdownTimer?.cancel();
    _recordingTimer?.cancel();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized)
      return;
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
      debugPrint("Camera Error: $e");
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
      debugPrint("Error stopping recording: $e");
    }
    _recordingTimer?.cancel();
    _scrollController.position.hold(() {});
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordingSeconds = 0;
    });
    await _scrollController.animateTo(0,
        duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
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
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _stopRecording() async {
    try {
      final file = await _controller!.stopVideoRecording();
      _recordingTimer?.cancel();
      _scrollController.position.hold(() {});
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
      if (mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => SaveVideoView(videoPath: file.path)));
      }
      _scrollController.jumpTo(0);
    } catch (e) {
      debugPrint(e.toString());
    }
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
          _scrollController.animateTo(maxScroll,
              duration:
                  Duration(milliseconds: (durationInSeconds * 1000).toInt()),
              curve: Curves.linear);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: redOrator)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),

          _buildUpperTeleprompter(),

          // Reading Line Indicator
          Positioned(
              top: 160,
              left: 0,
              right: 0,
              child: Container(
                  height: 1, color: Colors.white.withValues(alpha: 0.2))),

          // REC Indicator
          if (_isRecording)
            Positioned(
                bottom: 140,
                left: 0,
                right: 0,
                child: Center(child: _buildRECIndicator())),

          if (_countdownSeconds == 0) _buildTopTools(),
          if (_countdownSeconds > 0) _buildCountdownOverlay(),

          _buildSlider(true),
          _buildSlider(false),

          if (_isRecording && !_isPaused) _buildVisualizerOverlay(),

          Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: _buildControlBar())),
        ],
      ),
    );
  }

  Widget _buildUpperTeleprompter() {
    return Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: MediaQuery.of(context).size.height * 0.45,
        child: ShaderMask(
          shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: [0.0, 0.6, 1.0]).createShader(r),
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
                top: 110, left: 80, right: 80, bottom: 150),
            child: Text(widget.scriptContent,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: _fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.4,
                    shadows: const [
                      Shadow(blurRadius: 12, color: Colors.black)
                    ])),
          ),
        ));
  }

  Widget _buildRECIndicator() {
    final mins = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 1.0, end: 0.0),
            duration: const Duration(milliseconds: 500),
            builder: (context, double opacity, child) {
              return Opacity(
                opacity: _isPaused ? 1.0 : opacity,
                child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle)),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(_isPaused ? "PAUSED" : "REC $mins:$secs",
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildTopTools() {
    return Positioned(
      top: 50,
      right: 15,
      child: Column(
        children: [
          _toolButton(Icons.close, () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration:
          const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
      child:
          IconButton(icon: Icon(icon, color: Colors.white), onPressed: onTap),
    );
  }

  Widget _buildSlider(bool isFontSize) {
    final bool isVisible = isFontSize ? _showFontValue : _showSpeedValue;
    final double currentValue = isFontSize ? _fontSize : _scrollSpeed;

    return Positioned(
      left: isFontSize ? 15 : null,
      right: isFontSize ? null : 15,
      top: 250,
      bottom: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Número dinámico que aparece/desaparece
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isVisible ? 1.0 : 0.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isFontSize ? Colors.blue : redOrator,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                currentValue.round().toString(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Icon(isFontSize ? Icons.text_fields : Icons.speed,
              color: Colors.white70, size: 20),
          const SizedBox(height: 10),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: Listener(
                // Detecta el inicio y fin del toque
                onPointerDown: (_) => setState(() {
                  if (isFontSize) {
                    _showFontValue = true;
                  } else {
                    _showSpeedValue = true;
                  }
                }),
                onPointerUp: (_) => setState(() {
                  if (isFontSize)
                    _showFontValue = false;
                  else
                    _showSpeedValue = false;
                }),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 15),
                  ),
                  child: Slider(
                    value: currentValue,
                    min: isFontSize ? 18 : 10,
                    max: isFontSize ? 50 : 100,
                    activeColor: isFontSize ? Colors.blue : redOrator,
                    inactiveColor: Colors.white24,
                    onChanged: (v) => setState(() {
                      if (isFontSize) {
                        _fontSize = v;
                      } else {
                        _scrollSpeed = v;
                        if (!_isPaused && _isRecording) _runAutoScroll();
                      }
                    }),
                  ),
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
      bottom: 185,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(12, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 3,
                height: (index % 3 == 0 ? 12 : 20) *
                    (0.5 + (DateTime.now().millisecond % 500) / 1000),
                decoration: BoxDecoration(
                    color: redOrator.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(2)),
              );
            }),
          ),
          const SizedBox(height: 4),
          const Text("MIC ACTIVE",
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
            child: Text('$_countdownSeconds',
                style: const TextStyle(
                    fontSize: 150,
                    color: Colors.white,
                    fontWeight: FontWeight.bold))));
  }

  Widget _buildControlBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 60,
          child: _isRecording
              ? (_isPaused
                  ? IconButton(
                      onPressed: _restartTake,
                      icon: const Icon(Icons.replay_rounded,
                          size: 40, color: Colors.white70))
                  : null)
              : (_cameras.length > 1
                  ? IconButton(
                      onPressed: _switchCamera,
                      icon: const Icon(Icons.flip_camera_ios_rounded,
                          size: 35, color: Colors.white70))
                  : null),
        ),
        const SizedBox(width: 20),
        if (_isRecording)
          IconButton(
              onPressed: () {
                if (_isPaused) {
                  _controller?.resumeVideoRecording();
                  setState(() => _isPaused = false);
                  _runAutoScroll();
                } else {
                  _controller?.pauseVideoRecording();
                  setState(() => _isPaused = true);
                  _scrollController.jumpTo(_scrollController.offset);
                }
              },
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause,
                  size: 50, color: Colors.white)),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: _isRecording
              ? _stopRecording
              : (_countdownSeconds > 0 ? null : _startCountdown),
          child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4)),
              child: Center(
                  child: Container(
                      height: _isRecording ? 30 : 60,
                      width: _isRecording ? 30 : 60,
                      decoration: BoxDecoration(
                          color: redOrator,
                          borderRadius:
                              BorderRadius.circular(_isRecording ? 5 : 40))))),
        ),
        if (!_isRecording) const SizedBox(width: 60),
        if (_isRecording) const SizedBox(width: 20),
      ],
    );
  }
}
