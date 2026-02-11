import 'dart:convert';
import 'package:tecstock/services/auth_service.dart';
import 'package:tecstock/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../model/movimentacao_estoque.dart';

class MovimentacaoEstoqueService {
  static String get baseUrl => ApiConfig.movimentacoesUrl;

  static Future<Map<String, dynamic>> registrarEntrada({
    required String codigoPeca,
    required int fornecedorId,
    required int quantidade,
    required double precoUnitario,
    required String numeroNotaFiscal,
    String? observacoes,
    String? origem,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/entrada').replace(queryParameters: {
        'codigoPeca': codigoPeca,
        'fornecedorId': fornecedorId.toString(),
        'quantidade': quantidade.toString(),
        'precoUnitario': precoUnitario.toString(),
        'numeroNotaFiscal': numeroNotaFiscal,
        if (observacoes != null && observacoes.isNotEmpty) 'observacoes': observacoes,
        if (origem != null && origem.isNotEmpty) 'origem': origem,
      });

      final response = await http.post(uri);

      if (response.statusCode == 200) {
        return {'sucesso': true, 'mensagem': 'Entrada de estoque registrada com sucesso'};
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': false, 'mensagem': errorData['message'] ?? 'Erro ao registrar entrada'};
      }
    } catch (e) {
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> registrarSaida({
    required String codigoPeca,
    required int fornecedorId,
    required int quantidade,
    required String numeroNotaFiscal,
    String? observacoes,
    String? origem,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/saida').replace(queryParameters: {
        'codigoPeca': codigoPeca,
        'fornecedorId': fornecedorId.toString(),
        'quantidade': quantidade.toString(),
        'numeroNotaFiscal': numeroNotaFiscal,
        if (observacoes != null && observacoes.isNotEmpty) 'observacoes': observacoes,
        if (origem != null && origem.isNotEmpty) 'origem': origem,
      });

      final response = await http.post(uri);

      if (response.statusCode == 200) {
        return {'sucesso': true, 'mensagem': 'Saída de estoque registrada com sucesso'};
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': false, 'mensagem': errorData['message'] ?? 'Erro ao registrar saída'};
      }
    } catch (e) {
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> registrarEntradasMultiplas({
    required int fornecedorId,
    required String numeroNotaFiscal,
    required List<Map<String, dynamic>> pecas,
    String? observacoes,
  }) async {
    try {
      final body = {
        'fornecedorId': fornecedorId,
        'numeroNotaFiscal': numeroNotaFiscal,
        'pecas': pecas,
        if (observacoes != null && observacoes.isNotEmpty) 'observacoes': observacoes,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/entrada-multipla'),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(utf8.decode(response.bodyBytes));
        return responseData;
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': false, 'mensagem': errorData['message'] ?? 'Erro ao registrar entradas'};
      }
    } catch (e) {
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<List<MovimentacaoEstoque>> listarTodas() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/listar'), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => MovimentacaoEstoque.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao listar movimentações: $e');
      }
      return [];
    }
  }

  static Future<List<MovimentacaoEstoque>> listarPorCodigoPeca(String codigoPeca) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/por-codigo/$codigoPeca'), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => MovimentacaoEstoque.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao listar movimentações por código: $e');
      }
      return [];
    }
  }

  static Future<List<MovimentacaoEstoque>> listarPorFornecedor(int fornecedorId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/por-fornecedor/$fornecedorId'), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => MovimentacaoEstoque.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao listar movimentações por fornecedor: $e');
      }
      return [];
    }
  }
}
