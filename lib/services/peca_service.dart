import 'dart:convert';
import 'package:TecStock/services/auth_service.dart';
import 'package:http/http.dart' as http;
import '../model/peca.dart';

class PecaService {
  static const String baseUrl = 'http://localhost:8081/api/pecas';

  static Future<List<Peca>> listarPecas() async {
    String baseUrl = 'http://localhost:8081/api/pecas/listarTodas';
    try {
      final response = await http.get(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Peca.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao listar peças: $e');
      return [];
    }
  }

  static Future<List<Peca>> listarPecasEmUso() async {
    String baseUrl = 'http://localhost:8081/api/pecas/em-uso';
    try {
      final response = await http.get(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Peca.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao listar peças em uso: $e');
      return [];
    }
  }

  static Future<bool> atualizarUnidadesUsadas() async {
    String baseUrl = 'http://localhost:8081/api/pecas/atualizar-unidades-usadas';
    try {
      final response = await http.post(Uri.parse(baseUrl));
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao atualizar unidades usadas: $e');
      return false;
    }
  }

  static Future<Peca?> buscarPecaPorCodigo(String codigo) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/buscarPorCodigo/$codigo'), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        return Peca.fromJson(jsonData);
      }
      return null;
    } catch (e) {
      print('Erro ao buscar peça por código: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> salvarPeca(Peca peca) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/salvar'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(peca.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'sucesso': true, 'mensagem': 'Peça salva com sucesso'};
      } else if (response.statusCode == 409) {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': false, 'mensagem': errorData['message'] ?? 'Código de peça duplicado para o mesmo fornecedor'};
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': false, 'mensagem': errorData['message'] ?? 'Erro ao salvar peça'};
      }
    } catch (e) {
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<bool> salvarPecaComDesconto({
    required Peca peca,
    required int fornecedorId,
    required double desconto,
  }) async {
    final url = Uri.parse('http://localhost:8081/api/descontos/aplicar');
    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        'peca': peca.toJson(),
        'fornecedorId': fornecedorId,
        'desconto': desconto,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<Map<String, dynamic>> atualizarPeca(int id, Peca peca) async {
    try {
      final headers = await AuthService.getAuthHeaders();

      final response = await http.put(
        Uri.parse('$baseUrl/atualizar/$id'),
        headers: headers,
        body: jsonEncode(peca.toJson()),
      );

      if (response.statusCode == 200) {
        return {'sucesso': true, 'mensagem': 'Peça atualizada com sucesso'};
      } else if (response.statusCode == 403) {
        return {'sucesso': false, 'mensagem': 'Acesso negado. Apenas administradores podem editar peças.'};
      } else if (response.statusCode == 409) {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': false, 'mensagem': errorData['message'] ?? 'Código de peça duplicado para o mesmo fornecedor'};
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': false, 'mensagem': errorData['message'] ?? 'Erro ao atualizar peça'};
      }
    } catch (e) {
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> excluirPeca(int id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/deletar/$id'), headers: await AuthService.getAuthHeaders());

      if (response.statusCode == 200) {
        return {'sucesso': true, 'mensagem': 'Peça excluída com sucesso'};
      } else if (response.statusCode == 409) {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': false, 'mensagem': errorData['message'] ?? 'Não é possível excluir a peça'};
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': false, 'mensagem': errorData['message'] ?? 'Erro ao excluir peça'};
      }
    } catch (e) {
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> ajustarEstoque({
    required int pecaId,
    required int ajuste,
    String? observacoes,
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();

      final response = await http.post(
        Uri.parse('$baseUrl/ajustar-estoque'),
        headers: headers,
        body: jsonEncode({
          'pecaId': pecaId,
          'ajuste': ajuste,
          'observacoes': observacoes,
        }),
      );

      if (response.statusCode == 200) {
        return {'sucesso': true, 'mensagem': 'Estoque ajustado com sucesso'};
      } else if (response.statusCode == 403) {
        return {'sucesso': false, 'mensagem': 'Acesso negado. Apenas administradores podem ajustar estoque.'};
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': false, 'mensagem': errorData['message'] ?? 'Erro ao ajustar estoque'};
      }
    } catch (e) {
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }
}
