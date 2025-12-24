import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:async';

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
      print('Erro ao carregar logo: $e');
      return null;
    } finally {
      _isLoading = false;
    }
  }

  static Future<pw.MemoryImage?> _loadLogoInternal() async {
    try {
      final logoBytes = await rootBundle.load('assets/images/TecStock_logo.png');
      final originalBytes = logoBytes.buffer.asUint8List();

      if (originalBytes.isEmpty) {
        print('Logo bytes is empty');
        return null;
      }

      // Retornando a imagem original sem processamento para evitar erros de decodificação em produção
      return pw.MemoryImage(originalBytes);
    } catch (e) {
      print('Falha ao carregar logo: $e');
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
