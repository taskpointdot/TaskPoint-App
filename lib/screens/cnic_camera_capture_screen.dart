import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../theme/app_theme.dart';

/// Full-screen live camera capture used by [CnicVerificationScreen]'s
/// "Capture" buttons.
///
/// `image_picker`'s `ImageSource.camera` only reliably opens a live camera
/// on Android. On desktop web (Chrome/Edge on a laptop) the browser
/// ignores the `capture` attribute on the underlying `<input type=file>`
/// and just falls back to the regular file/storage picker — which is why
/// both "Capture" and "Upload" looked identical from storage. This screen
/// uses the `camera` plugin instead, which talks to `getUserMedia` on web
/// and the native camera APIs on Android, so it opens a real live preview
/// with a shutter button on both laptops and phones.
///
/// Pops with the captured JPEG bytes (`Uint8List`), or `null` if the user
/// backs out without taking a photo.
class CnicCameraCaptureScreen extends StatefulWidget {
  final String label;

  const CnicCameraCaptureScreen({super.key, required this.label});

  @override
  State<CnicCameraCaptureScreen> createState() => _CnicCameraCaptureScreenState();
}

class _CnicCameraCaptureScreenState extends State<CnicCameraCaptureScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initFuture = _setUp();
  }

  Future<void> _setUp() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'No camera was found on this device.');
        return;
      }
      // Prefer the rear/back camera for document shots when available.
      _cameraIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      if (_cameraIndex < 0) _cameraIndex = 0;
      await _openCamera(_cameraIndex);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not access the camera: $e');
    }
  }

  Future<void> _openCamera(int index) async {
    final previous = _controller;
    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    await controller.initialize();
    await previous?.dispose();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _cameraIndex = index;
      _error = null;
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _capturing) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    await _openCamera(next);
  }

  Future<void> _shoot() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final XFile file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop<Uint8List>(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not capture the photo: $e');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<void>(
              future: _initFuture,
              builder: (context, snapshot) {
                if (_error != null) {
                  return _ErrorState(message: _error!, onRetry: () => setState(() => _initFuture = _setUp()));
                }
                final controller = _controller;
                if (snapshot.connectionState != ConnectionState.done || controller == null || !controller.value.isInitialized) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                return Center(child: CameraPreview(controller));
              },
            ),

            // Top bar: back button + which side we're shooting.
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Symbols.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  if (_cameras.length > 1)
                    IconButton(
                      icon: const Icon(Symbols.cameraswitch_rounded, color: Colors.white),
                      onPressed: _switchCamera,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),

            // Framing guide so the CNIC edges are easy to line up.
            if (_error == null)
              Center(
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white70, width: 2),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                ),
              ),

            // Shutter button.
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: GestureDetector(
                  onTap: _shoot,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _capturing ? Colors.white38 : Colors.white,
                      ),
                      child: _capturing
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.no_photography_rounded, color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
