import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String baseUrl = 'http://localhost:8081/api/auth';
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

        return {'success': true, 'data': userData};
      } else {
        String errorMessage = 'Credenciais inválidas';
        try {
          final errorBody = response.body;
          if (errorBody.isNotEmpty) {
            errorMessage = errorBody;
          }
        } catch (e) {}
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
    return {
      'Content-Type': 'application/json',
      'Authorization': token != null ? 'Bearer $token' : '',
    };
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
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

  static Future<bool> isAdmin() async {
    final nivelAcesso = await getNivelAcesso();
    return nivelAcesso == 0;
  }
}
