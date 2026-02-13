import 'dart:convert';
import 'package:tecstock/services/auth_service.dart';
import 'package:tecstock/model/servico.dart';
import 'package:tecstock/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ServicoService {
  static Future<Map<String, dynamic>> salvarServico(Servico servico) async {
    String baseUrl = '${ApiConfig.servicosUrl}/salvar';

    try {
      final response = await http.post(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders(), body: jsonEncode(servico.toJson()));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': 'Serviço salvo com sucesso'};
      } else {
        String errorMessage = 'Erro ao salvar serviço';
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
        print('Erro ao salvar servico: $e');
      }
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<List<Servico>> listarServicos() async {
    String baseUrl = '${ApiConfig.servicosUrl}/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Servico.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao listar servicos: $e');
      }
      return [];
    }
  }

  static Future<List<Servico>> listarServicosPendentes() async {
    String baseUrl = '${ApiConfig.servicosUrl}/pendentes';
    try {
      final response = await http.get(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Servico.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao listar serviços pendentes: $e');
      }
      return [];
    }
  }

  static Future<bool> atualizarUnidadesUsadas() async {
    String baseUrl = '${ApiConfig.servicosUrl}/atualizar-unidades-usadas';
    try {
      final response = await http.post(Uri.parse(baseUrl));
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao atualizar unidades usadas: $e');
      }
      return false;
    }
  }

  static Future<bool> excluirServico(int id) async {
    String baseUrl = '${ApiConfig.servicosUrl}/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao excluir servico: $e');
      }
      return false;
    }
  }

  static Future<Map<String, dynamic>> atualizarServico(int id, Servico servico) async {
    String baseUrl = '${ApiConfig.servicosUrl}/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(servico.toJson()),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Serviço atualizado com sucesso'};
      } else {
        String errorMessage = 'Erro ao atualizar serviço';
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
        print('Erro ao atualizar servico: $e');
      }
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> buscarPaginado(String query, int page, {int size = 30}) async {
    String baseUrl = '${ApiConfig.servicosUrl}/buscarPaginado?query=$query&page=$page&size=$size';
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(Uri.parse(baseUrl), headers: headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        final List jsonList = jsonResponse['content'];
        final servicos = jsonList.map((e) => Servico.fromJson(e)).toList();
        return {
          'success': true,
          'content': servicos,
          'totalElements': jsonResponse['totalElements'],
          'totalPages': jsonResponse['totalPages'],
          'currentPage': jsonResponse['number'],
        };
      }
      return {'success': false, 'content': [], 'totalElements': 0, 'totalPages': 0};
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao buscar serviços paginado: $e');
      }
      return {'success': false, 'content': [], 'totalElements': 0, 'totalPages': 0};
    }
  }
}
