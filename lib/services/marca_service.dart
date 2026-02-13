import 'dart:convert';
import 'package:tecstock/services/auth_service.dart';
import 'package:tecstock/model/marca.dart';
import 'package:tecstock/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MarcaService {
  static Future<Map<String, dynamic>> salvarMarca(Marca marca) async {
    String baseUrl = '${ApiConfig.marcasUrl}/salvar';

    try {
      final response = await http.post(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders(), body: jsonEncode(marca.toJson()));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': 'Marca salva com sucesso'};
      } else {
        String errorMessage = 'Erro ao salvar marca';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody['message'] != null) {
            errorMessage = errorBody['message'];
          } else if (errorBody['error'] != null) {
            errorMessage = errorBody['error'];
          }
        } catch (e) {
          if (response.body.isNotEmpty) {
            errorMessage = response.body;
          }
        }
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao salvar marca: $e');
      }
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<List<Marca>> listarMarcas() async {
    String baseUrl = '${ApiConfig.marcasUrl}/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Marca.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao listar marcas: $e');
      }
      return [];
    }
  }

  static Future<Map<String, dynamic>> excluirMarca(int id) async {
    String baseUrl = '${ApiConfig.marcasUrl}/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'message': 'Marca excluída com sucesso'};
      } else {
        String errorMessage = 'Erro ao excluir marca';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody['message'] != null) {
            errorMessage = errorBody['message'];
          } else if (errorBody['error'] != null) {
            errorMessage = errorBody['error'];
          }
        } catch (e) {
          if (response.body.isNotEmpty) {
            errorMessage = response.body;
          }
        }
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao excluir marca: $e');
      }
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> atualizarMarca(int id, Marca marca) async {
    String baseUrl = '${ApiConfig.marcasUrl}/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(marca.toJson()),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Marca atualizada com sucesso'};
      } else {
        String errorMessage = 'Erro ao atualizar marca';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody['message'] != null) {
            errorMessage = errorBody['message'];
          } else if (errorBody['error'] != null) {
            errorMessage = errorBody['error'];
          }
        } catch (e) {
          if (response.body.isNotEmpty) {
            errorMessage = response.body;
          }
        }
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao atualizar marca: $e');
      }
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> buscarPaginado(String query, int page, {int size = 30}) async {
    String baseUrl = '${ApiConfig.marcasUrl}/buscarPaginado?query=$query&page=$page&size=$size';
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(Uri.parse(baseUrl), headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        final List jsonList = jsonResponse['content'];
        final marcas = jsonList.map((e) => Marca.fromJson(e)).toList();
        return {
          'success': true,
          'content': marcas,
          'totalElements': jsonResponse['totalElements'],
          'totalPages': jsonResponse['totalPages'],
          'currentPage': jsonResponse['number'],
        };
      }
      return {'success': false, 'content': [], 'totalElements': 0, 'totalPages': 0};
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao buscar marcas paginado: $e');
      }
      return {'success': false, 'content': [], 'totalElements': 0, 'totalPages': 0};
    }
  }
}
