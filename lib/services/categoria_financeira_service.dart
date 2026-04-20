import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tecstock/config/api_config.dart';
import 'package:tecstock/model/categoria_financeira.dart';
import 'package:tecstock/services/auth_service.dart';

class CategoriaFinanceiraService {
  static String get baseUrl => ApiConfig.categoriasFinanceirasUrl;

  static Future<Map<String, dynamic>> buscarPaginado(String query, int page, {int size = 30}) async {
    final url = '$baseUrl/buscarPaginado?query=$query&page=$page&size=$size';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: await AuthService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        final List jsonList = jsonResponse['content'] as List;
        final categorias = jsonList.map((e) => CategoriaFinanceira.fromJson(e)).toList();
        return {
          'success': true,
          'content': categorias,
          'totalElements': jsonResponse['totalElements'] ?? 0,
          'totalPages': jsonResponse['totalPages'] ?? 0,
          'currentPage': jsonResponse['number'] ?? 0,
        };
      }

      return {
        'success': false,
        'content': <CategoriaFinanceira>[],
        'totalElements': 0,
        'totalPages': 0,
        'currentPage': page,
      };
    } catch (e) {
      if (kDebugMode) print('Erro ao buscar categorias financeiras paginado: $e');
      return {
        'success': false,
        'content': <CategoriaFinanceira>[],
        'totalElements': 0,
        'totalPages': 0,
        'currentPage': page,
      };
    }
  }

  static Future<List<CategoriaFinanceira>> listar() async {
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: await AuthService.getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((e) => CategoriaFinanceira.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('Erro ao listar categorias financeiras: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> criar(String nome, {String? descricao}) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode({'nome': nome, 'descricao': descricao}),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': true, 'categoria': CategoriaFinanceira.fromJson(data)};
      }
      return {'sucesso': false, 'mensagem': _extrairMensagemErro(response.bodyBytes, 'Erro ao criar categoria')};
    } catch (e) {
      if (kDebugMode) print('Erro ao criar categoria financeira: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> atualizar(
    int id,
    String nome, {
    String? descricao,
    bool ativo = true,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode({'nome': nome, 'descricao': descricao, 'ativo': ativo}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': true, 'categoria': CategoriaFinanceira.fromJson(data)};
      }
      return {'sucesso': false, 'mensagem': _extrairMensagemErro(response.bodyBytes, 'Erro ao atualizar categoria')};
    } catch (e) {
      if (kDebugMode) print('Erro ao atualizar categoria financeira: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> deletar(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: await AuthService.getAuthHeaders(),
      );
      if (response.statusCode == 204 || response.statusCode == 200) {
        return {'sucesso': true};
      }
      return {'sucesso': false, 'mensagem': _extrairMensagemErro(response.bodyBytes, 'Erro ao excluir categoria')};
    } catch (e) {
      if (kDebugMode) print('Erro ao excluir categoria financeira: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static String _extrairMensagemErro(List<int> bodyBytes, String fallback) {
    try {
      final body = jsonDecode(utf8.decode(bodyBytes));
      if (body is Map<String, dynamic> && body['message'] != null) {
        return body['message'].toString();
      }
    } catch (_) {
      // ignora parse e retorna fallback
    }
    return fallback;
  }
}
