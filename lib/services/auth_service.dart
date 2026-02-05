import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:TecStock/config/api_config.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthService {
  static String get baseUrl => ApiConfig.authUrl;
  static const _secureStorage = FlutterSecureStorage();

  static Future<Map<String, dynamic>> login(String nomeUsuario, String senha) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nomeUsuario': nomeUsuario,
          'senha': senha,
        }),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('userId', userData['id']);
        await prefs.setString('nomeUsuario', userData['nomeUsuario']);
        await prefs.setString('nomeCompleto', userData['nomeCompleto']);
        await prefs.setInt('nivelAcesso', userData['nivelAcesso']);
        await prefs.setBool('isLoggedIn', true);

        await _secureStorage.write(key: 'jwt_token', value: userData['token']);

        if (userData['consultor'] != null && userData['consultor']['id'] != null) {
          final consultorId = userData['consultor']['id'];
          await prefs.setInt('consultorId', consultorId);
        } else {
          await prefs.remove('consultorId');
        }

        if (userData['empresa'] != null) {
          await prefs.setInt('empresaId', userData['empresa']['id']);
          await prefs.setString('nomeEmpresa', userData['empresa']['nomeFantasia'] ?? '');
        } else {
          await prefs.remove('empresaId');
          await prefs.remove('nomeEmpresa');
        }

        return {'success': true, 'data': userData};
      } else {
        String errorMessage = 'Credenciais inválidas';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map && errorBody['message'] != null) {
            errorMessage = errorBody['message'];
          } else if (errorBody is String) {
            errorMessage = errorBody;
          }
        } catch (e) {
          if (response.body.isNotEmpty) {
            errorMessage = response.body;
          }
        }
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      print('Erro ao fazer login: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _secureStorage.delete(key: 'jwt_token');
  }

  static Future<String?> getToken() async {
    return await _secureStorage.read(key: 'jwt_token');
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    final nivelAcesso = await getNivelAcesso();
    return {
      'Content-Type': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
      'X-User-Level': nivelAcesso?.toString() ?? '',
    };
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final isLogged = prefs.getBool('isLoggedIn') ?? false;

    if (isLogged) {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        await logout();
        return false;
      }

      if (await isTokenExpired()) {
        print('Token expirado, fazendo logout automático');
        await logout();
        return false;
      }
    }

    return isLogged;
  }

  static Future<bool> isTokenExpired() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return true;
      }

      return JwtDecoder.isExpired(token);
    } catch (e) {
      print('Erro ao verificar expiração do token: $e');
      return true;
    }
  }

  static Future<bool> validateToken() async {
    final token = await getToken();
    if (token == null || token.isEmpty || await isTokenExpired()) {
      await logout();
      return false;
    }
    return true;
  }

  static Future<int?> getNivelAcesso() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('nivelAcesso');
  }

  static Future<String?> getNomeCompleto() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('nomeCompleto');
  }

  static Future<String?> getNomeUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('nomeUsuario');
  }

  static Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await getToken();
    return {
      'userId': prefs.getInt('userId'),
      'nomeUsuario': prefs.getString('nomeUsuario'),
      'nomeCompleto': prefs.getString('nomeCompleto'),
      'nivelAcesso': prefs.getInt('nivelAcesso'),
      'token': token,
      'consultorId': prefs.getInt('consultorId'),
    };
  }

  static Future<int?> getConsultorId() async {
    final prefs = await SharedPreferences.getInstance();
    final consultorId = prefs.getInt('consultorId');
    return consultorId;
  }

  static Future<String?> getNomeEmpresa() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('nomeEmpresa');
  }

  static Future<int?> getEmpresaId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('empresaId');
  }

  static Future<bool> isAdmin() async {
    final nivelAcesso = await getNivelAcesso();
    return nivelAcesso == 1;
  }

  static Future<void> printSessionDebug() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await getToken();
    print('=== DEBUG SESSÃO ===');
    print('isLoggedIn: ${prefs.getBool('isLoggedIn')}');
    print('userId: ${prefs.getInt('userId')}');
    print('nomeUsuario: ${prefs.getString('nomeUsuario')}');
    print('nivelAcesso: ${prefs.getInt('nivelAcesso')}');
    print('token exists: ${token != null && token.isNotEmpty}');
    print('==================');
  }
}
