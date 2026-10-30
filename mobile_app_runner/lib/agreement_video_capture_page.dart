import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

const _agreementGreen = Color(0xFF88B44A);
const _agreementSky = Color(0xFF43B5D4);

class AgreementVideoCapturePage extends StatefulWidget {
  const AgreementVideoCapturePage({super.key});

  @override
  State<AgreementVideoCapturePage> createState() =>
      _AgreementVideoCapturePageState();
}

class _AgreementVideoCapturePageState extends State<AgreementVideoCapturePage> {
  CameraController? _camera;
  XFile? _recordedVideo;
  Timer? _durationTimer;
  bool _initializing = true;
  bool _recording = false;
  bool _busy = false;
  int _seconds = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
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
      if (cameras.isEmpty) throw Exception('No camera was found.');
      final frontCameras = cameras
          .where((camera) => camera.lensDirection == CameraLensDirection.front)
          .toList();
      controller = CameraController(
        frontCameras.isEmpty ? cameras.first : frontCameras.first,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      if (controller != null) await controller.dispose();
    } finally {
      if (mounted) {
        setState(() {
          _initializing = false;
          _busy = false;
        });
      }
    }
  }

  Future<void> _startRecording() async {
    final camera = _camera;
    if (camera == null || _busy || _recording || _recordedVideo != null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await camera.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _recording = true;
        _busy = false;
        _seconds = 0;
      });
      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= 20) unawaited(_stopRecording());
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not start recording: $error';
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    final camera = _camera;
    if (camera == null || !_recording || _busy) return;
    _durationTimer?.cancel();
    _durationTimer = null;
    setState(() => _busy = true);
    try {
      final clip = await camera.stopVideoRecording();
      if (mounted) {
        setState(() {
          _recordedVideo = clip;
          _recording = false;
          _busy = false;
          _seconds = 0;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _recording = false;
          _busy = false;
          _error = 'Could not finish recording: $error';
        });
      }
    }
  }

  void _recordAgain() {
    setState(() {
      _recordedVideo = null;
      _error = null;
    });
  }

  void _useVideo() {
    final clip = _recordedVideo;
    if (clip != null) Navigator.of(context).pop(clip);
  }

  Future<void> _cancel() async {
    _durationTimer?.cancel();
    final camera = _camera;
    if (camera != null && _recording) {
      try {
        await camera.stopVideoRecording();
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    final camera = _camera;
    _camera = null;
    if (camera != null) unawaited(camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FA),
      appBar: AppBar(
        title: const Text('Record agreement video'),
        leading: IconButton(
          onPressed: _busy ? null : _cancel,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF111B19),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_initializing)
                      const Center(
                        child: CircularProgressIndicator(
                          color: _agreementGreen,
                        ),
                      )
                    else if (_error != null && camera == null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.videocam_off_outlined,
                                size: 44,
                                color: _agreementSky,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Could not open the in-app camera. $_error',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: _busy ? null : _initializeCamera,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (camera != null && camera.value.isInitialized)
                      CameraPreview(camera)
                    else
                      const ColoredBox(color: Color(0xFF111B19)),
                    if (camera != null && camera.value.isInitialized)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(150),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _recording
                                    ? Icons.fiber_manual_record_rounded
                                    : Icons.mic_none_rounded,
                                color: _recording
                                    ? Colors.redAccent
                                    : _agreementGreen,
                                size: 16,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                _recording
                                    ? 'RECORDING 00:${_seconds.toString().padLeft(2, '0')}'
                                    : _recordedVideo == null
                                    ? 'IN-APP CAMERA'
                                    : 'VIDEO RECORDED',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!_recording && _recordedVideo == null && !_initializing)
                      const Align(
                        alignment: Alignment.center,
                        child: IgnorePointer(
                          child: Icon(
                            Icons.face_retouching_natural_rounded,
                            size: 70,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE3EBEE)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120B3A45),
                    blurRadius: 18,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Say one of these statements clearly:',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  const Text('“I Agree by Mekenet Ekub Rules.”'),
                  const SizedBox(height: 3),
                  const Text('“በመቀነት እቁበ ህግ እና ደንብ ተስማምቻልው፡፡”'),
                  const SizedBox(height: 10),
                  Text(
                    'Record here in the app. The separate live face check is not recorded. Maximum 20 seconds.',
                    style: TextStyle(
                      color: Colors.blueGrey.shade600,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  if (_error != null && camera != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (_recordedVideo != null)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _recordAgain,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Record again'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _useVideo,
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Use this video'),
                          ),
                        ),
                      ],
                    )
                  else if (_recording)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFD84A4A),
                        ),
                        onPressed: _busy ? null : _stopRecording,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Stop recording'),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _agreementGreen,
                          foregroundColor: const Color(0xFF172415),
                        ),
                        onPressed: _busy || _initializing || camera == null
                            ? null
                            : _startRecording,
                        icon: const Icon(Icons.fiber_manual_record_rounded),
                        label: const Text('Start recording'),
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
