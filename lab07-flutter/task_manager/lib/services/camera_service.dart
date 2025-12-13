import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../screens/camera_screen.dart';

class CameraService {
  CameraService._init();

  static final CameraService instance = CameraService._init();

  List<CameraDescription>? _cameras;

  Future<void> initialize() async {
    try {
      if (kIsWeb || Platform.isMacOS) {
        // Web and macOS will not use the native camera plugin here.
        // macOS fallback is handled at capture time (file picker).
        _cameras = [];
      } else {
        _cameras = await availableCameras();
      }
      debugPrint(
        'CameraService: ${_cameras?.length ?? 0} câmera(s) encontrada(s)',
      );
    } catch (error) {
      debugPrint('Erro ao inicializar câmera: $error');
      _cameras = [];
    }
  }

  bool get hasCameras => _cameras != null && _cameras!.isNotEmpty;

  Future<bool> _ensureCameraPermission(BuildContext context) async {
    // On macOS (and web) we fallback to a file selector and don't request
    // camera permission here. For platforms that support the camera plugin
    // request/check permission as normal.
    if (kIsWeb || Platform.isMacOS) return true;

    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    final result = await Permission.camera.request();
    if (result.isGranted) return true;

    if (context.mounted) {
      final message = result.isPermanentlyDenied
          ? 'Permissão de câmera negada permanentemente. Habilite nas configurações.'
          : 'Permissão de câmera negada.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
  }

  Future<String?> takePicture(BuildContext context) async {
    // On macOS and web, fallback to a file picker (ImagePicker) since the
    // `camera` plugin may not provide an implementation.
    if (kIsWeb || Platform.isMacOS) {
      try {
        final picker = ImagePicker();
        final XFile? image =
            await picker.pickImage(source: ImageSource.gallery);
        if (image == null) return null;

        final savedPath = await savePicture(image);
        return savedPath;
      } catch (error) {
        debugPrint('Erro ao selecionar imagem (fallback macOS): $error');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao selecionar imagem: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }
    }

    if (!hasCameras) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhuma câmera disponível'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }

    final allowed = await _ensureCameraPermission(context);
    if (!allowed) return null;

    final camera = _cameras!.first;
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await controller.initialize();

      if (!context.mounted) return null;

      final imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(controller: controller),
          fullscreenDialog: true,
        ),
      );

      return imagePath;
    } catch (error) {
      debugPrint('Erro ao abrir câmera: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir câmera: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } finally {
      await controller.dispose();
    }
  }

  Future<String> savePicture(XFile image) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(path.join(appDir.path, 'images'));

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final fileName = 'task_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savePath = path.join(imagesDir.path, fileName);

    final savedFile = await File(image.path).copy(savePath);
    debugPrint('Foto salva em ${savedFile.path}');
    return savedFile.path;
  }

  Future<bool> deletePhoto(String photoPath) async {
    try {
      final file = File(photoPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (error) {
      debugPrint('Erro ao deletar foto: $error');
      return false;
    }
  }
}
