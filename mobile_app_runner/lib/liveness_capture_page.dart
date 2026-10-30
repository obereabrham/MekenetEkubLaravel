import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

const _liveGreen = Color(0xFF88B44A);
const _liveSky = Color(0xFF43B5D4);

class LivenessCapturePage extends StatefulWidget {
  const LivenessCapturePage({super.key});
  @override
  State<LivenessCapturePage> createState() => _LivenessCapturePageState();
}

class _LivenessCapturePageState extends State<LivenessCapturePage>
    with WidgetsBindingObserver {
  static const _steps = [
    'Center your face in the guide and hold still.',
    'Blink both eyes naturally two times.',
    'Turn your head left, then right, then face forward.',
  ];
  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };
  final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
      minFaceSize: 0.12,
    ),
  );
  CameraController? _camera;
  bool _initializing = true, _busy = false, _processing = false;
  bool _stepReady = false, _appActive = true;
  int _step = 0, _blinks = 0, _openFrames = 0;
  bool _eyesClosed = false, _leftTurn = false, _rightTurn = false;
  DateTime? _centerSince;
  String? _error;
  String _status = 'Position your face inside the guide.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _appActive = false;
      unawaited(_releaseCamera(resume: true));
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _appActive = true;
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_busy || _camera != null) return;
    setState(() {
      _initializing = true;
      _error = null;
      _busy = true;
    });
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty)
        throw Exception('No camera was found on this device.');
      final front = cameras
          .where((c) => c.lensDirection == CameraLensDirection.front)
          .toList();
      final description = front.isEmpty ? cameras.first : front.first;
      controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted || !_appActive) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
      await controller.startImageStream(_processFrame);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      if (controller != null) await controller.dispose();
      if (mounted) setState(() => _camera = null);
    } finally {
      if (mounted)
        setState(() {
          _initializing = false;
          _busy = false;
        });
    }
  }

  Uint8List? _androidNv21Bytes(CameraImage image) {
    if (image.planes.length == 1) return image.planes.first.bytes;
    if (image.planes.length < 3) return null;

    // CameraX may expose YUV_420_888 as three strided planes even when NV21
    // was requested. ML Kit expects one tightly packed NV21 buffer.
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final width = image.width;
    final height = image.height;
    final chromaWidth = (width + 1) ~/ 2;
    final chromaHeight = (height + 1) ~/ 2;
    final ySize = width * height;
    final bytes = Uint8List(ySize + chromaWidth * chromaHeight * 2);

    for (var row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      final pixelStride = yPlane.bytesPerPixel ?? 1;
      for (var column = 0; column < width; column++) {
        final source = rowStart + column * pixelStride;
        if (source >= yPlane.bytes.length) return null;
        bytes[row * width + column] = yPlane.bytes[source];
      }
    }

    var output = ySize;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;
    for (var row = 0; row < chromaHeight; row++) {
      for (var column = 0; column < chromaWidth; column++) {
        final uIndex = row * uPlane.bytesPerRow + column * uPixelStride;
        final vIndex = row * vPlane.bytesPerRow + column * vPixelStride;
        if (uIndex >= uPlane.bytes.length || vIndex >= vPlane.bytes.length) {
          return null;
        }
        bytes[output++] = vPlane.bytes[vIndex];
        bytes[output++] = uPlane.bytes[uIndex];
      }
    }
    return bytes;
  }

  InputImage? _toInputImage(CameraImage image, CameraController controller) {
    final plane = image.planes.firstOrNull;
    if (plane == null) return null;
    final format = Platform.isAndroid
        ? InputImageFormat.nv21
        : InputImageFormat.bgra8888;
    final bytes = Platform.isAndroid
        ? _androidNv21Bytes(image)
        : image.planes.length == 1
        ? plane.bytes
        : null;
    if (bytes == null) return null;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(
        controller.description.sensorOrientation,
      );
    } else {
      final orientation = _orientations[controller.value.deviceOrientation];
      if (orientation == null) return null;
      final sensor = controller.description.sensorOrientation;
      final degrees =
          controller.description.lensDirection == CameraLensDirection.front
          ? (sensor + orientation) % 360
          : (sensor - orientation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(degrees);
    }
    if (rotation == null) return null;
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: Platform.isAndroid ? image.width : plane.bytesPerRow,
      ),
    );
  }

  math.Point<double>? _faceCenter(Face face, CameraImage image) {
    var x = face.boundingBox.center.dx / image.width;
    final y = face.boundingBox.center.dy / image.height;
    if (_camera?.description.lensDirection == CameraLensDirection.front)
      x = 1 - x;
    if (!x.isFinite || !y.isFinite) return null;
    return math.Point(
      x.clamp(0.0, 1.0).toDouble(),
      y.clamp(0.0, 1.0).toDouble(),
    );
  }

  Future<void> _processFrame(CameraImage image) async {
    final controller = _camera;
    if (_processing ||
        controller == null ||
        _stepReady ||
        _error != null ||
        !mounted)
      return;
    _processing = true;
    try {
      final input = _toInputImage(image, controller);
      if (input == null) {
        _setStatus('Unsupported camera frame. Please retry.');
        return;
      }
      final faces = await _detector.processImage(input);
      if (!mounted || _camera != controller) return;
      if (faces.length != 1) {
        _centerSince = null;
        _setStatus(
          faces.isEmpty
              ? 'No face detected. Move into the guide.'
              : 'Only one person can be in the frame.',
        );
        return;
      }
      final center = _faceCenter(faces.first, image);
      if (center != null) _checkStep(faces.first, center);
    } catch (e) {
      _setStatus('Could not read your face. Please retry.');
      if (mounted) setState(() => _error = e.toString());
    } finally {
      _processing = false;
    }
  }

  void _checkStep(Face face, math.Point<double> center) {
    switch (_step) {
      case 0:
        final centered =
            center.x > 0.34 &&
            center.x < 0.66 &&
            center.y > 0.22 &&
            center.y < 0.78;
        if (!centered) {
          _centerSince = null;
          _setStatus('Move your face to the middle of the guide.');
          return;
        }
        _centerSince ??= DateTime.now();
        final held = DateTime.now().difference(_centerSince!);
        if (held >= const Duration(seconds: 2)) {
          _pass('Face centered and held still.');
        } else {
          _setStatus(
            'Good. Hold still for ${2 - held.inSeconds} more seconds.',
          );
        }
        return;
      case 1:
        final left = face.leftEyeOpenProbability,
            right = face.rightEyeOpenProbability;
        if (left == null || right == null) {
          _setStatus('Keep both eyes visible and look at the camera.');
          return;
        }
        final open = left > 0.68 && right > 0.68;
        final closed = left < 0.28 && right < 0.28;
        if (open) {
          _openFrames++;
          if (_eyesClosed && _openFrames >= 2) {
            _eyesClosed = false;
            _blinks++;
            if (_blinks >= 2) {
              _pass('Two blinks detected.');
            } else {
              _setStatus('Blink once more. Detected $_blinks of 2.');
            }
          }
        } else if (closed && _openFrames >= 2) {
          _eyesClosed = true;
          _openFrames = 0;
          _setStatus('Eyes closed. Open them to complete the blink.');
        }
        return;
      case 2:
        final yaw = face.headEulerAngleY;
        if (yaw == null) {
          _setStatus('Keep your whole face visible and turn your head.');
          return;
        }
        if (yaw < -14) {
          _leftTurn = true;
          _setStatus('Left turn detected. Turn your head to the other side.');
        } else if (yaw > 14) {
          _rightTurn = true;
          _setStatus('Right turn detected. Face forward to finish.');
        } else if (_leftTurn && _rightTurn && yaw.abs() < 10) {
          _pass('Left and right head turns detected.');
        } else if (!_leftTurn) {
          _setStatus('Slowly turn your head to the left.');
        } else if (!_rightTurn) {
          _setStatus('Now slowly turn your head to the right.');
        }
        return;
    }
  }

  void _setStatus(String value) {
    if (mounted && value != _status) setState(() => _status = value);
  }

  void _pass(String message) {
    if (!mounted || _stepReady) return;
    setState(() {
      _stepReady = true;
      _status = message;
    });
  }

  void _resetStep() {
    _stepReady = false;
    _centerSince = null;
    _blinks = 0;
    _openFrames = 0;
    _eyesClosed = false;
    _leftTurn = false;
    _rightTurn = false;
    _status = switch (_step) {
      0 => 'Position your face inside the guide.',
      1 => 'Look at the camera and blink naturally twice.',
      2 => 'Slowly turn your head left, then right.',
      _ => 'The live face check is complete.',
    };
  }

  Future<void> _nextStep() async {
    if (_busy || !_stepReady) return;
    if (_step == _steps.length - 1) {
      await _releaseCamera();
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _step++;
      _resetStep();
    });
  }

  Future<void> _releaseCamera({bool resume = false}) async {
    final controller = _camera;
    _camera = null;
    if (controller == null) return;
    if (mounted) setState(() => _busy = true);
    try {
      if (controller.value.isStreamingImages)
        await controller.stopImageStream();
    } catch (_) {}
    try {
      await controller.dispose();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (resume && _appActive && _camera == null) _initializeCamera();
      }
    }
  }

  Future<void> _cancel() async {
    await _releaseCamera();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appActive = false;
    final controller = _camera;
    _camera = null;
    if (controller != null) unawaited(controller.dispose());
    unawaited(_detector.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _camera;
    return Scaffold(
      backgroundColor: const Color(0xFF07110F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF07110F),
        foregroundColor: Colors.white,
        title: const Text('Live identity check'),
        leading: IconButton(
          onPressed: _busy ? null : _cancel,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: _initializing
            ? const Center(child: CircularProgressIndicator(color: _liveGreen))
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        color: _liveSky,
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Could not start the in-app live check. $_error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _initializeCamera,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                    child: Row(
                      children: List.generate(_steps.length, (index) {
                        final done = _stepReady
                            ? index <= _step
                            : index < _step;
                        return Expanded(
                          child: Container(
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: done || index == _step
                                  ? _liveGreen
                                  : Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (controller != null &&
                              controller.value.isInitialized)
                            CameraPreview(controller)
                          else
                            const ColoredBox(color: Color(0xFF111B19)),
                          Align(
                            alignment: Alignment.center,
                            child: Container(
                              width: 260,
                              height: 330,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(150),
                                border: Border.all(
                                  color: _stepReady ? _liveGreen : Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _liveGreen.withAlpha(35),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 14,
                            left: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(135),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _stepReady
                                        ? Icons.check_circle_rounded
                                        : Icons.face_retouching_natural_rounded,
                                    color: _liveGreen,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _stepReady
                                        ? 'STEP PASSED'
                                        : 'LIVE · STEP ${_step + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: .7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151D1B),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STEP ${_step + 1} OF ${_steps.length}',
                          style: const TextStyle(
                            color: _liveSky,
                            fontSize: 11,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _steps[_step],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _status,
                          style: TextStyle(
                            color: _stepReady
                                ? _liveGreen
                                : const Color(0xFFAAC0B7),
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _busy || !_stepReady ? null : _nextStep,
                            icon: Icon(
                              _step == _steps.length - 1
                                  ? Icons.verified_user_rounded
                                  : Icons.arrow_forward_rounded,
                            ),
                            label: Text(
                              _stepReady
                                  ? (_step == _steps.length - 1
                                        ? 'Finish live check'
                                        : 'Continue')
                                  : 'Complete this step to continue',
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Blink and head movement are checked live on this device. No live-check video is recorded or uploaded.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withAlpha(170),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
