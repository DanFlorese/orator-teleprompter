import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:orator_teleprompter/core/theme.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:orator_teleprompter/views/prompter/save_video_view.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class CameraView extends StatefulWidget {
  final String scriptTitle;
  final String scriptContent;

  const CameraView({
    super.key,
    required this.scriptTitle,
    required this.scriptContent,
  });

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

  bool _showFontValue = false;
  bool _showSpeedValue = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _initializeSafeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
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

    // 1. Cuando la app se va a segundo plano o se bloquea
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_isRecording && !_isPaused) {
        _pauseRecordingAndScroll();
      }
    } 
    // 2. Cuando el usuario desbloquea y regresa
    else if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable();
      
      if (cameraController != null && cameraController.value.isInitialized) {
        // Obliga a la cámara a reconectar el flujo de imagen (evita botones muertos)
        cameraController.resumePreview();

        // Sincronización de seguridad de estados
        if (_isRecording) {
          bool isActuallyRecording = cameraController.value.isRecordingVideo;

          setState(() {
            // Si el hardware ya no reporta grabación, el SO la detuvo
            if (!isActuallyRecording) {
              _isRecording = false;
              _isPaused = false;
            }
          });
        }
      }
    }
  }

  // --- LÓGICA DE CÁMARA MEJORADA ---

  Future<void> _initializeSafeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        _selectedCameraIndex = _cameras.length > 1 ? 1 : 0;
        await _initializeCamera(_selectedCameraIndex);
      }
    } catch (e) {
      debugPrint("Error fetching cameras: $e");
    }
  }

  Future<void> _initializeCamera(int index) async {
    try {
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.isEmpty) return;
      
      if (_controller != null) {
        await _controller!.dispose();
      }

      _controller = CameraController(
        _cameras[index],
        ResolutionPreset.high,
        enableAudio: true,
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

  Future<void> _startRecording() async {
    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordingSeconds = 0;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!_isPaused && mounted) setState(() => _recordingSeconds++);
      });
      _runAutoScroll();
    } catch (e) {
      debugPrint("Start recording error: $e");
    }
  }

  Future<void> _pauseRecordingAndScroll() async {
    if (_controller != null && _controller!.value.isRecordingVideo && !_isPaused) {
      try {
        await _controller?.pauseVideoRecording();
      } catch (e) {
        debugPrint("Error pausing camera: $e");
      }
    }
    if (_scrollController.hasClients) _scrollController.position.hold(() {}); 
    if (mounted) setState(() => _isPaused = true);
  }

  Future<void> _resumeRecordingAndScroll() async {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        await _controller?.resumePreview();
        if (_isPaused) {
          try {
            await _controller?.resumeVideoRecording();
          } catch (_) {
            // ignore: best-effort resume; some platforms may not support pause/resume
          }
        }
      } catch (e) {
        debugPrint("Error resuming camera: $e");
      }
    }
    setState(() => _isPaused = false);
    _runAutoScroll();
  }

  Future<void> _stopRecording() async {
    try {
      XFile? file;
      if (_controller != null && _controller!.value.isInitialized) {
        // Detenemos intentando cubrir cualquier estado del hardware
        if (_controller!.value.isRecordingVideo || _isPaused) {
          file = await _controller!.stopVideoRecording();
        }
      }
      
      _recordingTimer?.cancel();
      if (_scrollController.hasClients) _scrollController.position.hold(() {});
      
      if (file != null && mounted) {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => SaveVideoView(videoPath: file!.path))
        ).then((_) {
          if (mounted) {
            setState(() {
              _isRecording = false;
              _isPaused = false;
              _recordingSeconds = 0;
            });
            _scrollController.jumpTo(0);
          }
        });
      }
    } catch (e) {
      debugPrint("Stop recording error: $e");
      // Si falla, desbloqueamos la UI para que el usuario no se quede atrapado
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
    }
  }

  Future<void> _restartTake() async {
    try {
      if (_controller != null && (_controller!.value.isRecordingVideo || _isPaused)) {
        await _controller!.stopVideoRecording();
      }
    } catch (e) {
      debugPrint("Error stopping for restart: $e");
    }
    _recordingTimer?.cancel();
    if (_scrollController.hasClients) _scrollController.position.hold(() {});
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordingSeconds = 0;
    });
    await _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
    _startCountdown();
  }

  // --- LÓGICA DE INTERFAZ ---

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
            curve: Curves.linear,
          );
        }
      }
    });
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

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: redOrator)));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),
          _buildUpperTeleprompter(),
          Positioned(top: 160, left: 0, right: 0, child: Container(height: 1, color: Colors.white.withValues(alpha: 0.2))),
          if (_isRecording) Positioned(bottom: 140, left: 0, right: 0, child: Center(child: _buildRECIndicator())),
          if (_countdownSeconds == 0) _buildTopTools(),
          if (_countdownSeconds > 0) _buildCountdownOverlay(),
          _buildSlider(true),
          _buildSlider(false),
          if (_isRecording && !_isPaused) _buildVisualizerOverlay(),
          Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.only(bottom: 40), child: _buildControlBar())),
        ],
      ),
    );
  }

  // (Todos los widgets de construcción buildUpperTeleprompter, buildSlider, buildControlBar, etc., se mantienen igual que en la versión anterior para conservar el diseño)

  Widget _buildUpperTeleprompter() {
    return Positioned(
      top: 0, left: 0, right: 0,
      height: MediaQuery.of(context).size.height * 0.45,
      child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.black, Colors.transparent],
          stops: [0.0, 0.6, 1.0],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: (!_isRecording || _isPaused) ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 110, left: 80, right: 80, bottom: 300),
          child: Text(
            widget.scriptContent,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _fontSize, fontWeight: FontWeight.bold,
              color: Colors.white, height: 1.4,
              shadows: const [Shadow(blurRadius: 12, color: Colors.black)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRECIndicator() {
    final mins = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_recordingSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, color: Colors.red, size: 8),
          const SizedBox(width: 8),
          Text(_isPaused ? "PAUSED" : "REC $mins:$secs", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildTopTools() {
    return Positioned(top: 50, right: 15, child: _toolButton(Icons.close, () => Navigator.pop(context)));
  }

  Widget _toolButton(IconData icon, VoidCallback onTap) {
    return Container(decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: IconButton(icon: Icon(icon, color: Colors.white), onPressed: onTap));
  }

  Widget _buildSlider(bool isFontSize) {
    final bool isVisible = isFontSize ? _showFontValue : _showSpeedValue;
    final double currentValue = isFontSize ? _fontSize : _scrollSpeed;
    return Positioned(
      left: isFontSize ? 15 : null, right: isFontSize ? null : 15,
      top: 250, bottom: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isVisible ? 1.0 : 0.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: isFontSize ? Colors.blue : redOrator, borderRadius: BorderRadius.circular(8)),
              child: Text(currentValue.round().toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 10),
          Icon(isFontSize ? Icons.text_fields : Icons.speed, color: Colors.white70, size: 20),
          const SizedBox(height: 10),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: Listener(
                onPointerDown: (_) => setState(() => isFontSize ? _showFontValue = true : _showSpeedValue = true),
                onPointerUp: (_) => setState(() => isFontSize ? _showFontValue = false : _showSpeedValue = false),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
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
      bottom: 185, left: 0, right: 0,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(12, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 3,
                height: (index % 3 == 0 ? 12 : 20) * (0.5 + (DateTime.now().millisecond % 500) / 1000),
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

  Widget _buildCountdownOverlay() {
    return Container(color: Colors.black.withValues(alpha: 0.5), child: Center(child: Text('$_countdownSeconds', style: const TextStyle(fontSize: 150, color: Colors.white, fontWeight: FontWeight.bold))));
  }

  Widget _buildControlBar() {
    bool canFinish = !_isRecording || (_isRecording && _isPaused);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 60,
          child: _isRecording
              ? (_isPaused ? IconButton(onPressed: _restartTake, icon: const Icon(Icons.replay_rounded, size: 40, color: Colors.white70)) : null)
              : (_cameras.length > 1 ? IconButton(onPressed: _switchCamera, icon: const Icon(Icons.flip_camera_ios_rounded, size: 35, color: Colors.white70)) : null),
        ),
        const SizedBox(width: 20),
        if (_isRecording)
          IconButton(
            onPressed: () => _isPaused ? _resumeRecordingAndScroll() : _pauseRecordingAndScroll(),
            icon: Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 60, color: Colors.white),
          ),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: () {
            if (!_isRecording) {
              if (_countdownSeconds == 0) _startCountdown();
            } else {
              if (_isPaused) {
                _stopRecording();
              } else {
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("Pause video before finishing", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                    backgroundColor: redOrator.withValues(alpha: 0.9),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.only(bottom: 200, left: 60, right: 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                );
              }
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 80, width: 80,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: canFinish ? Colors.white : Colors.white24, width: 4)),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _isRecording ? (canFinish ? 30 : 20) : 60,
                width: _isRecording ? (canFinish ? 30 : 20) : 60,
                decoration: BoxDecoration(
                  color: canFinish ? redOrator : redOrator.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(_isRecording ? 5 : 40)
                ),
              ),
            ),
          ),
        ),
        if (!_isRecording) const SizedBox(width: 60),
        if (_isRecording) const SizedBox(width: 20),
      ],
    );
  }
}