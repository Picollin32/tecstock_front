import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:async';
import 'package:image/image.dart' as img;

class PdfLogoHelper {
  static pw.MemoryImage? _cachedLogoImage;
  static bool _loadAttempted = false;
  static bool _isLoading = false;

  static Future<pw.MemoryImage?> loadLogo() async {
    if (_cachedLogoImage != null) {
      return _cachedLogoImage;
    }

    if (_loadAttempted) {
      return null;
    }

    if (_isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
      return _cachedLogoImage;
    }

    _loadAttempted = true;
    _isLoading = true;

    try {
      final result = await Future.any([
        _loadLogoInternal(),
        Future.delayed(const Duration(seconds: 3), () => null),
      ]);

      _cachedLogoImage = result;
      return _cachedLogoImage;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao carregar logo: $e');
      }
      return null;
    } finally {
      _isLoading = false;
    }
  }

  static Future<pw.MemoryImage?> _loadLogoInternal() async {
    try {
      final logoBytes = await rootBundle.load('assets/images/TecStock_logo.png');
      final originalBytes = logoBytes.buffer.asUint8List();

      if (originalBytes.isEmpty || originalBytes.length < 100) {
        return null;
      }

      final image = img.decodeImage(originalBytes);
      if (image == null) {
        if (kDebugMode) {
          print('Não foi possível decodificar a imagem');
        }
        return null;
      }

      final resized = img.copyResize(
        image,
        width: 120,
        height: 120,
        interpolation: img.Interpolation.linear,
      );

      final optimizedBytes = img.encodePng(resized, level: 6);

      if (kDebugMode) {
        print(
            'Logo otimizado: ${originalBytes.length} bytes → ${optimizedBytes.length} bytes (${((1 - optimizedBytes.length / originalBytes.length) * 100).toStringAsFixed(1)}% redução)');
      }

      return pw.MemoryImage(Uint8List.fromList(optimizedBytes));
    } catch (e) {
      if (kDebugMode) {
        print('Falha ao carregar logo: $e');
      }
    }
    return null;
  }

  static void clearCache() {
    _cachedLogoImage = null;
    _loadAttempted = false;
  }

  static Future<void> preloadLogo() async {
    await loadLogo();
  }

  static pw.MemoryImage? getCachedLogo() {
    return _cachedLogoImage;
  }
}
