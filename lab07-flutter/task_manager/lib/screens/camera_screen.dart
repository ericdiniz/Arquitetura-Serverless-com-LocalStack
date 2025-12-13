import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../services/camera_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({
    super.key,
    required this.controller,
  });

  final CameraController controller;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    if (!widget.controller.value.isInitialized) {
      widget.controller.initialize().then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  Future<void> _takePicture() async {
    if (_isCapturing || !widget.controller.value.isInitialized) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final image = await widget.controller.takePicture();
      final savedPath = await CameraService.instance.savePicture(image);

      if (mounted) {
        Navigator.pop(context, savedPath);
      }
    } catch (error) {
      debugPrint('Erro ao capturar foto: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao capturar: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: CameraPreview(widget.controller)),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                    GestureDetector(
                      onTap: _isCapturing ? null : _takePicture,
                      child: Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                _isCapturing ? Colors.redAccent : Colors.white,
                            width: 4,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: _isCapturing
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.redAccent,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 28,
                              ),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _isCapturing ? null : () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.photo_library_outlined,
                        color: Colors.white24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
