import 'dart:convert';
import 'package:TecStock/model/tipo_pagamento.dart';
import 'package:TecStock/services/auth_service.dart';
import 'package:http/http.dart' as http;

class TipoPagamentoService {
  static Future<Map<String, dynamic>> salvarTipoPagamento(TipoPagamento tipoPagamento) async {
    String baseUrl = 'http://localhost:8081/api/tipos-pagamento/salvar';

    try {
      final nivelAcesso = await AuthService.getNivelAcesso();
      final headers = await AuthService.getAuthHeaders();
      headers['X-User-Level'] = nivelAcesso?.toString() ?? '1';

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode(tipoPagamento.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': 'Tipo de pagamento salvo com sucesso'};
      } else if (response.statusCode == 403) {
        return {'success': false, 'message': 'Acesso negado. Apenas administradores podem gerenciar tipos de pagamento.'};
      } else {
        String errorMessage = 'Erro ao salvar tipo de pagamento';
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
      print('Erro ao salvar tipo de pagamento: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<List<TipoPagamento>> listarTiposPagamento() async {
    String baseUrl = 'http://localhost:8081/api/tipos-pagamento/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => TipoPagamento.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao listar tipos de pagamento: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> excluirTipoPagamento(int id) async {
    String baseUrl = 'http://localhost:8081/api/tipos-pagamento/deletar/$id';

    try {
      final nivelAcesso = await AuthService.getNivelAcesso();
      final headers = await AuthService.getAuthHeaders();
      headers['X-User-Level'] = nivelAcesso?.toString() ?? '1';

      final response = await http.delete(
        Uri.parse(baseUrl),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'message': 'Tipo de pagamento excluído com sucesso'};
      } else if (response.statusCode == 403) {
        return {'success': false, 'message': 'Acesso negado. Apenas administradores podem gerenciar tipos de pagamento.'};
      } else {
        String errorMessage = 'Erro ao excluir tipo de pagamento';
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
      print('Erro ao excluir tipo de pagamento: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> atualizarTipoPagamento(int id, TipoPagamento tipoPagamento) async {
    String baseUrl = 'http://localhost:8081/api/tipos-pagamento/atualizar/$id';

    try {
      final nivelAcesso = await AuthService.getNivelAcesso();
      final headers = await AuthService.getAuthHeaders();
      headers['X-User-Level'] = nivelAcesso?.toString() ?? '1';

      final response = await http.put(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode(tipoPagamento.toJson()),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Tipo de pagamento atualizado com sucesso'};
      } else if (response.statusCode == 403) {
        return {'success': false, 'message': 'Acesso negado. Apenas administradores podem gerenciar tipos de pagamento.'};
      } else {
        String errorMessage = 'Erro ao atualizar tipo de pagamento';
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
      print('Erro ao atualizar tipo de pagamento: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<TipoPagamento?> buscarTipoPagamentoPorId(int id) async {
    String baseUrl = 'http://localhost:8081/api/tipos-pagamento/buscar/$id';
    try {
      final response = await http.get(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        return TipoPagamento.fromJson(json);
      }
      return null;
    } catch (e) {
      print('Erro ao buscar tipo de pagamento: $e');
      return null;
    }
  }
}
