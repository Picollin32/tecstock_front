import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../model/empresa.dart';

class EmpresaService {
  static const _secureStorage = FlutterSecureStorage();

  static Future<String?> _getToken() async {
    return await _secureStorage.read(key: 'jwt_token');
  }

  static Future<List<Empresa>> listarEmpresas() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/empresas/listarTodas'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(utf8.decode(response.bodyBytes));
      return body.map((item) => Empresa.fromJson(item)).toList();
    } else {
      throw Exception('Erro ao listar empresas');
    }
  }

  static Future<Empresa> buscarEmpresaPorId(int id) async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/empresas/buscar/$id'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return Empresa.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw Exception('Erro ao buscar empresa');
    }
  }

  static Future<Map<String, dynamic>> salvarEmpresa(Empresa empresa) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/empresas/salvar'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(empresa.toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': responseData['success'] ?? true,
          'message': responseData['message'] ?? 'Empresa cadastrada com sucesso',
          'data': responseData['data'] != null ? Empresa.fromJson(responseData['data']) : null,
        };
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'message': errorData['message'] ?? 'Erro ao salvar empresa',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao salvar empresa: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> atualizarEmpresa(int id, Empresa empresa) async {
    final token = await _getToken();
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/empresas/atualizar/$id'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(empresa.toJson()),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': responseData['success'] ?? true,
          'message': responseData['message'] ?? 'Empresa atualizada com sucesso',
          'data': responseData['data'] != null ? Empresa.fromJson(responseData['data']) : null,
        };
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'message': errorData['message'] ?? 'Erro ao atualizar empresa',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao atualizar empresa: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> deletarEmpresa(int id) async {
    final token = await _getToken();
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/empresas/deletar/$id'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': responseData['success'] ?? true,
          'message': responseData['message'] ?? 'Empresa deletada com sucesso',
        };
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'message': errorData['message'] ?? 'Erro ao deletar empresa',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao deletar empresa: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> ativarDesativarEmpresa(int id, bool ativa) async {
    final token = await _getToken();
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/empresas/ativar-desativar/$id?ativa=$ativa'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': responseData['success'] ?? true,
          'message': responseData['message'] ?? 'Status alterado com sucesso',
        };
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': false,
          'message': errorData['message'] ?? 'Erro ao alterar status',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro ao alterar status: $e',
      };
    }
  }
}
