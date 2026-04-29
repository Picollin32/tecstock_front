import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tecstock/config/api_config.dart';
import 'package:tecstock/model/garantia.dart';
import 'package:tecstock/services/auth_service.dart';

class GarantiaService {
  static String get baseUrl => '${ApiConfig.baseUrl}/api/garantias';

  static Future<Map<String, dynamic>> buscarPaginado({
    required String query,
    required String field,
    required String status,
    required int page,
    required int size,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/buscarPaginado?query=${Uri.encodeQueryComponent(query)}&field=$field&status=$status&page=$page&size=$size',
      );

      final response = await http.get(uri, headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        final List<GarantiaResumo> content = (jsonData['content'] as List?)
                ?.map((item) => GarantiaResumo.fromJson(item))
                .toList() ??
            [];
        final GarantiaResumoTotal resumo = jsonData['resumo'] != null
            ? GarantiaResumoTotal.fromJson(jsonData['resumo'])
            : GarantiaResumoTotal(total: 0, ativas: 0, reclamadas: 0, expiradas: 0);

        return {
          'success': true,
          'content': content,
          'totalElements': jsonData['totalElements'] ?? 0,
          'totalPages': jsonData['totalPages'] ?? 0,
          'number': jsonData['number'] ?? 0,
          'resumo': resumo,
        };
      }

      return {
        'success': false,
        'message': 'Erro ao buscar garantias: ${response.body}',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao buscar garantias: $e');
      }
      return {
        'success': false,
        'message': 'Erro de conexao: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> registrarRetorno({
    required int ordemServicoId,
    required int servicoId,
    required String motivo,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$ordemServicoId/retorno'),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode({
          'servicoId': servicoId,
          'motivo': motivo,
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'garantia': GarantiaResumo.fromJson(jsonData),
        };
      }

      return {
        'success': false,
        'message': 'Erro ao registrar retorno: ${response.body}',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao registrar retorno: $e');
      }
      return {
        'success': false,
        'message': 'Erro de conexao: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> editarRetorno({
    required int retornoId,
    required String motivo,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/retorno/$retornoId'),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode({'motivo': motivo}),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'success': true,
          'garantia': GarantiaResumo.fromJson(jsonData),
        };
      }

      return {
        'success': false,
        'message': 'Erro ao editar retorno: ${response.body}',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao editar retorno: $e');
      }
      return {'success': false, 'message': 'Erro de conexao: $e'};
    }
  }

  static Future<Map<String, dynamic>> deletarRetorno({
    required int retornoId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/retorno/$retornoId'),
        headers: await AuthService.getAuthHeaders(),
      );

      if (response.statusCode == 204) {
        return {'success': true};
      }

      return {
        'success': false,
        'message': 'Erro ao excluir retorno: ${response.body}',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao excluir retorno: $e');
      }
      return {'success': false, 'message': 'Erro de conexao: $e'};
    }
  }
}
