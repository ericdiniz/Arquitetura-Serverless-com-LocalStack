import 'dart:io';

import 'package:http/http.dart' as http;

class UploadService {
  UploadService._();
  static const backendUrl = String.fromEnvironment('UPLOAD_BACKEND',
      defaultValue: 'http://localhost:3000');

  /// Upload a local file to the backend `/upload` endpoint as multipart/form-data.
  static Future<bool> uploadFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final uri = Uri.parse('$backendUrl/upload');
      final request = http.MultipartRequest('POST', uri);

      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      // ignore: avoid_print
      print('Upload failed: $e');
      return false;
    }
  }
}
