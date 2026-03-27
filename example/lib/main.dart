import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_usbcamera/flutter_usbcamera.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AUSBC Flutter',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6200EE),
          secondary: Color(0xFF03DAC5),
        ),
      ),
      home: const DemoPage(),
    );
  }
}

// ============================================================
// DemoPage — matches DemoFragment layout (fragment_demo.xml)
// ============================================================
class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final _controller = UsbCameraController();
  StreamSubscription<CameraEvent>? _eventSub;
  int _textureId = -1; // legacy, kept for compatibility
  bool _isCameraOpened = false;
  bool _isCapturing = false;
  bool _isPlayingMic = false;
  String _frameRateText = '';
  List<PreviewSize> _previewSizes = [];
  int? _currentDeviceId;
  int _brightnessMax = 100;
  int _brightnessValue = 0;

  // Capture mode: 0=photo, 1=video, 2=audio
  int _captureMode = 0;

  // Recording timer
  Timer? _recTimer;
  int _recSeconds = 0;
  bool _recDotVisible = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _eventSub = UsbCameraController.events.listen(_handleEvent);
    await _controller.registerUsb();
  }
  void _handleEvent(CameraEvent event) {
    switch (event.type) {
      case CameraEventType.onAttachDev:
        if (event.deviceId != null) {
          _controller.requestPermission(event.deviceId!);
        }
        break;
      case CameraEventType.onDetachDev:
        setState(() {
          _isCameraOpened = false;
          _currentDeviceId = null;
        });
        break;
      case CameraEventType.onConnectDev:
        _openCamera(event.deviceId!);
        break;
      case CameraEventType.onDisConnectDev:
        setState(() {
          _isCameraOpened = false;
        });
        break;
      case CameraEventType.onCameraState:
        if (event.state == 'opened') {
          setState(() => _isCameraOpened = true);
          _loadPreviewSizes();
        } else if (event.state == 'closed') {
          setState(() => _isCameraOpened = false);
        } else if (event.state == 'error') {
          setState(() => _isCameraOpened = false);
          _showSnackBar('Camera error: ${event.message}');
        }
        break;
      case CameraEventType.onCaptureBegin:
        if (event.captureType == 'video' || event.captureType == 'audio') {
          setState(() => _isCapturing = true);
          _startRecTimer();
        }
        break;
      case CameraEventType.onCaptureComplete:
        if (event.captureType == 'video' || event.captureType == 'audio') {
          setState(() => _isCapturing = false);
          _stopRecTimer();
        }
        _showSnackBar('Saved: ${event.path}');
        break;
      case CameraEventType.onCaptureError:
        setState(() => _isCapturing = false);
        _stopRecTimer();
        _showSnackBar('Error: ${event.error}');
        break;
      case CameraEventType.onPlayMicBegin:
        setState(() => _isPlayingMic = true);
        break;
      case CameraEventType.onPlayMicComplete:
      case CameraEventType.onPlayMicError:
        setState(() => _isPlayingMic = false);
        break;
      default:
        break;
    }
  }

  Future<void> _openCamera(int deviceId) async {
    await _controller.openCamera(
      deviceId,
      request: const CameraRequest(
        previewWidth: 640,
        previewHeight: 480,
        renderMode: RenderMode.opengl,
        previewFormat: PreviewFormat.mjpeg,
      ),
    );
    setState(() {
      _currentDeviceId = deviceId;
    });
  }

  Future<void> _loadPreviewSizes() async {
    // Wait a moment for camera to fully initialize
    await Future.delayed(const Duration(milliseconds: 500));
    final sizes = await _controller.getAllPreviewSizes();
    final brightness = await _controller.getBrightness();
    setState(() {
      _previewSizes = sizes;
      _brightnessValue = brightness ?? 0;
    });
  }

  void _startRecTimer() {
    _recSeconds = 0;
    _recDotVisible = true;
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _recSeconds++;
        _recDotVisible = _recSeconds % 2 == 0;
      });
    });
  }

  void _stopRecTimer() {
    _recTimer?.cancel();
    _recTimer = null;
    _recSeconds = 0;
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _recTimer?.cancel();
    _eventSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // === Top toolbar (matches toolbarBg, 52dp) ===
            _buildToolbar(),
            // === Camera preview area ===
            Expanded(child: _buildPreviewArea()),
            // === Brightness SeekBar ===
            if (_isCameraOpened) _buildBrightnessBar(),
            // === Mode switch + capture area (matches controlPanelLayout, 180dp) ===
            _buildControlPanel(),
          ],
        ),
      ),
    );
  }

  // --- Top toolbar: settings | effects | type | voice | resolution ---
  Widget _buildToolbar() {
    if (_isCapturing) return const SizedBox.shrink();
    return Container(
      height: 52,
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _toolbarIcon('assets/icons/more.png', Icons.more_horiz, _showMoreMenu),
          _toolbarIcon('assets/icons/filter.png', Icons.auto_awesome, _showEffectsDialog),
          _toolbarIcon('assets/icons/type.png', Icons.camera, null),
          _toolbarIcon(
            'assets/icons/voice.png',
            _isPlayingMic ? Icons.mic : Icons.mic_off,
            _toggleMic,
          ),
          _toolbarIcon('assets/icons/resolution.png', Icons.aspect_ratio, _showResolutionDialog),
        ],
      ),
    );
  }

  Widget _toolbarIcon(String assetPath, IconData fallbackIcon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(fallbackIcon, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  // --- Camera preview area with UVC logo placeholder ---
  Widget _buildPreviewArea() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Always show the PlatformView — it's a real Android TextureView
          // Camera will render to it when opened, black when not
          const Positioned.fill(child: UsbCameraPreview()),
          // UVC logo overlay when camera not opened
          if (!_isCameraOpened)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.usb, size: 80, color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  Text(
                    'Waiting for USB camera...',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                  ),
                ],
              ),
            ),
          // Frame rate text (top-left)
          if (_isCameraOpened && _frameRateText.isNotEmpty)
            Positioned(
              top: 12,
              left: 12,
              child: Text(_frameRateText, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // --- Brightness SeekBar (matches brightnessSb) ---
  Widget _buildBrightnessBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          const Icon(Icons.brightness_low, color: Colors.white54, size: 18),
          Expanded(
            child: Slider(
              value: _brightnessValue.toDouble(),
              min: 0,
              max: _brightnessMax.toDouble(),
              onChanged: (v) {
                setState(() => _brightnessValue = v.toInt());
                _controller.setBrightness(v.toInt());
              },
            ),
          ),
          const Icon(Icons.brightness_high, color: Colors.white54, size: 18),
        ],
      ),
    );
  }

  // --- Control panel: mode switch + capture button + album/switch ---
  Widget _buildControlPanel() {
    return Container(
      height: 180,
      color: Colors.black,
      child: Column(
        children: [
          // Recording timer (shown when capturing)
          if (_isCapturing) _buildRecTimer() else _buildModeSwitch(),
          const Spacer(),
          // Capture button row: album | capture | switch camera
          _buildCaptureRow(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- Recording timer (matches recTimerLayout) ---
  Widget _buildRecTimer() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _recDotVisible ? Colors.red : Colors.transparent,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _formatTime(_recSeconds),
            style: const TextStyle(color: Colors.white, fontSize: 20),
          ),
        ],
      ),
    );
  }

  // --- Mode switch: photo | video | audio (matches modeSwitchLayout) ---
  Widget _buildModeSwitch() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _modeTab('photo', 0),
          const SizedBox(width: 20),
          _modeTab('video', 1),
          const SizedBox(width: 20),
          _modeTab('audio', 2),
        ],
      ),
    );
  }

  Widget _modeTab(String label, int mode) {
    final isSelected = _captureMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _captureMode = mode),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFFD7DAE1),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
              shadows: const [Shadow(blurRadius: 1, color: Color(0xBF000000))],
            ),
          ),
          const SizedBox(height: 1),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFF2E5BFF) : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  // --- Capture row: album preview | capture button | switch camera ---
  Widget _buildCaptureRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Album preview (left, 38x38, matches albumPreviewIv)
        if (!_isCapturing)
          SizedBox(
            width: 80,
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(Icons.photo_library, color: Colors.white, size: 20),
              ),
            ),
          )
        else
          const SizedBox(width: 80),
        // Capture button (center, 76x76, matches captureBtn)
        _buildCaptureButton(),
        // Switch camera (right, 48x48, matches lensFacingBtn1)
        if (!_isCapturing)
          SizedBox(
            width: 80,
            child: Center(
              child: GestureDetector(
                onTap: _showSwitchDialog,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.cameraswitch, color: Colors.white, size: 32),
                ),
              ),
            ),
          )
        else
          const SizedBox(width: 80),
      ],
    );
  }

  // --- Capture button (matches CaptureMediaView) ---
  Widget _buildCaptureButton() {
    final isRecording = _isCapturing;
    // Photo mode: white circle; Video/Audio mode: red square when recording
    final bool isPhotoMode = _captureMode == 0;
    return GestureDetector(
      onTap: _onCapture,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Center(
          child: isPhotoMode
              ? Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                )
              : isRecording
                  ? Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
        ),
      ),
    );
  }

  // === Actions ===

  void _onCapture() {
    if (!_isCameraOpened) {
      _showSnackBar('camera not worked!');
      return;
    }
    switch (_captureMode) {
      case 0:
        _controller.captureImage();
        break;
      case 1:
        if (_isCapturing) {
          _controller.captureVideoStop();
        } else {
          _controller.captureVideoStart();
        }
        break;
      case 2:
        if (_isCapturing) {
          _controller.captureAudioStop();
        } else {
          _controller.captureAudioStart();
        }
        break;
    }
  }

  void _toggleMic() {
    if (_isPlayingMic) {
      _controller.stopPlayMic();
    } else {
      _controller.startPlayMic();
    }
  }

  void _showSwitchDialog() async {
    final devices = await _controller.getDeviceList();
    if (!mounted || devices.isEmpty) {
      _showSnackBar('Get usb device failed');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          title: const Text('Switch Camera'),
          children: devices.map((dev) {
            final isCurrent = dev.deviceId == _currentDeviceId;
            final name = dev.productName.isNotEmpty
                ? '${dev.productName}(${dev.deviceId})'
                : dev.deviceName;
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx);
                if (!isCurrent) _controller.switchCamera(dev.deviceId);
              },
              child: Text(
                '$name${isCurrent ? " ✓" : ""}',
                style: TextStyle(color: isCurrent ? const Color(0xFF2E5BFF) : null),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showEffectsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Effects'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              _controller.updateRenderEffect(EffectClassifyId.filter);
              Navigator.pop(ctx);
            },
            child: const Text('None'),
          ),
          SimpleDialogOption(
            onPressed: () {
              _controller.updateRenderEffect(EffectClassifyId.filter, effectId: EffectId.blackWhite);
              Navigator.pop(ctx);
            },
            child: const Text('BlackWhite'),
          ),
          SimpleDialogOption(
            onPressed: () {
              _controller.updateRenderEffect(EffectClassifyId.animation, effectId: EffectId.zoom);
              Navigator.pop(ctx);
            },
            child: const Text('Zoom'),
          ),
          SimpleDialogOption(
            onPressed: () {
              _controller.updateRenderEffect(EffectClassifyId.animation, effectId: EffectId.soul);
              Navigator.pop(ctx);
            },
            child: const Text('Soul'),
          ),
        ],
      ),
    );
  }

  void _showResolutionDialog() {
    if (_previewSizes.isEmpty) {
      _showSnackBar('Get camera preview size failed');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Resolution'),
        children: _previewSizes.map((size) {
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _controller.updateResolution(size.width, size.height);
            },
            child: Text('${size.width} x ${size.height}'),
          );
        }).toList(),
      ),
    );
  }

  void _showMoreMenu() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('More'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MultiCameraPage()));
            },
            child: const Text('Multi Camera'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _controller.setRotateType(RotateType.angle0);
            },
            child: const Text('Rotate 0°'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _controller.setRotateType(RotateType.angle90);
            },
            child: const Text('Rotate 90°'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _controller.setRotateType(RotateType.angle180);
            },
            child: const Text('Rotate 180°'),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _controller.setRotateType(RotateType.angle270);
            },
            child: const Text('Rotate 270°'),
          ),
        ],
      ),
    );
  }
}


// ============================================================
// MultiCameraPage — matches DemoMultiCameraFragment / layout_item_camera.xml
// ============================================================
class MultiCameraPage extends StatefulWidget {
  const MultiCameraPage({super.key});

  @override
  State<MultiCameraPage> createState() => _MultiCameraPageState();
}

class _MultiCameraPageState extends State<MultiCameraPage> {
  final _controller = MultiCameraController();
  StreamSubscription<CameraEvent>? _eventSub;
  final Map<int, int> _cameraTextures = {};
  final Map<int, String> _cameraNames = {};
  final Map<int, bool> _cameraOpened = {};
  final Map<int, bool> _cameraRecording = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _eventSub = _controller.events.listen(_handleEvent);
    await _controller.registerUsb();
  }

  void _handleEvent(CameraEvent event) {
    switch (event.type) {
      case CameraEventType.onAttachDev:
        final deviceId = event.deviceId!;
        setState(() {
          _cameraNames[deviceId] = event.raw['deviceName'] as String? ?? '';
          _cameraOpened[deviceId] = false;
          _cameraRecording[deviceId] = false;
        });
        _controller.requestPermission(deviceId);
        break;
      case CameraEventType.onDetachDev:
        final deviceId = event.deviceId!;
        setState(() {
          _cameraTextures.remove(deviceId);
          _cameraNames.remove(deviceId);
          _cameraOpened.remove(deviceId);
          _cameraRecording.remove(deviceId);
        });
        break;
      case CameraEventType.onConnectDev:
        _openMultiCamera(event.deviceId!);
        break;
      case CameraEventType.onMultiCameraState:
        final deviceId = event.deviceId!;
        if (event.state == 'opened') {
          setState(() => _cameraOpened[deviceId] = true);
        } else if (event.state == 'closed' || event.state == 'error') {
          setState(() => _cameraOpened[deviceId] = false);
        }
        break;
      case CameraEventType.onCameraState:
        final deviceId = event.deviceId;
        if (deviceId != null && event.state == 'opened') {
          setState(() => _cameraOpened[deviceId] = true);
        }
        break;
      case CameraEventType.onCaptureBegin:
        final deviceId = event.deviceId;
        if (deviceId != null && event.captureType == 'video') {
          setState(() => _cameraRecording[deviceId] = true);
        }
        break;
      case CameraEventType.onCaptureComplete:
        final deviceId = event.deviceId;
        if (deviceId != null && event.captureType == 'video') {
          setState(() => _cameraRecording[deviceId] = false);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved: ${event.path}')),
          );
        }
        break;
      case CameraEventType.onCaptureError:
        final deviceId = event.deviceId;
        if (deviceId != null) setState(() => _cameraRecording[deviceId] = false);
        break;
      default:
        break;
    }
  }

  Future<void> _openMultiCamera(int deviceId) async {
    // Multi-camera with PlatformView requires separate views per camera
    // For now, use the single camera approach
    setState(() => _cameraTextures[deviceId] = 0);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceIds = _cameraTextures.keys.toList();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Multi Camera'),
      ),
      body: deviceIds.isEmpty
          ? Center(
              child: Text(
                'NO UVC CAMERAS',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : ListView.builder(
              itemCount: deviceIds.length,
              itemBuilder: (context, index) {
                final deviceId = deviceIds[index];
                return _buildCameraItem(deviceId);
              },
            ),
    );
  }

  // Matches layout_item_camera.xml (300dp height, rounded bg, texture + controls)
  Widget _buildCameraItem(int deviceId) {
    final textureId = _cameraTextures[deviceId] ?? -1;
    final name = _cameraNames[deviceId] ?? '';
    final isOpened = _cameraOpened[deviceId] ?? false;
    final isRecording = _cameraRecording[deviceId] ?? false;

    return Container(
      height: 300,
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: textureId >= 0
                  ? const UsbCameraPreview()
                  : const Center(
                      child: Icon(Icons.videocam_off, color: Colors.white24, size: 48),
                    ),
            ),
          ),
          // Camera name (top-left)
          Positioned(
            top: 10,
            left: 10,
            child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          // Switch icon (top-right)
          Positioned(
            top: 10,
            right: 10,
            child: Icon(
              isOpened ? Icons.toggle_on : Icons.toggle_off,
              color: isOpened ? Colors.green : Colors.grey,
              size: 32,
            ),
          ),
          // Capture controls (bottom-left)
          Positioned(
            bottom: 10,
            left: 20,
            child: Row(
              children: [
                GestureDetector(
                  onTap: isOpened ? () => _controller.captureImage(deviceId) : null,
                  child: Icon(Icons.camera_alt, color: isOpened ? Colors.white : Colors.white24, size: 22),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: isOpened
                      ? () {
                          if (isRecording) {
                            _controller.captureVideoStop(deviceId);
                          } else {
                            _controller.captureVideoStart(deviceId);
                          }
                        }
                      : null,
                  child: Icon(
                    isRecording ? Icons.stop_circle : Icons.videocam,
                    color: isRecording ? Colors.red : (isOpened ? Colors.white : Colors.white24),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
