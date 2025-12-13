import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

enum PhotoFilterType { original, grayscale, sepia }

class PhotoFilterService {
  PhotoFilterService._();

  static final PhotoFilterService instance = PhotoFilterService._();

  Future<String> applyFilter(String filePath, PhotoFilterType filter) async {
    if (filter == PhotoFilterType.original) {
      return filePath;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return filePath;
    }

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return filePath;
    }

    img.Image processed;
    switch (filter) {
      case PhotoFilterType.grayscale:
        processed = img.grayscale(decoded);
        break;
      case PhotoFilterType.sepia:
        processed = img.sepia(decoded);
        break;
      case PhotoFilterType.original:
        processed = decoded;
        break;
    }

    final filteredBytes = img.encodeJpg(processed, quality: 90);
    final directory = file.parent;
    final baseName = p.basenameWithoutExtension(filePath);
    final extension =
        p.extension(filePath).isEmpty ? '.jpg' : p.extension(filePath);
    final suffix = filter == PhotoFilterType.grayscale ? 'pb' : 'sepia';
    final newPath = p.join(
      directory.path,
      '${baseName}_$suffix${extension.toLowerCase() == '.jpeg' ? '.jpg' : extension}',
    );

    final filteredFile = File(newPath);
    await filteredFile.writeAsBytes(filteredBytes, flush: true);

    if (newPath != filePath) {
      try {
        await file.delete();
      } catch (_) {
        // Ignored: best effort cleanup when replacing the original file.
      }
    }

    return filteredFile.path;
  }
}
