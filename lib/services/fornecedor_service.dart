import 'dart:convert';
import 'package:TecStock/services/auth_service.dart';
import 'package:TecStock/config/api_config.dart';
import 'package:http/http.dart' as http;
import '../model/fornecedor.dart';

class FornecedorService {
  static Future<Map<String, dynamic>> salvarFornecedor(Fornecedor fornecedor) async {
    String baseUrl = '${ApiConfig.fornecedoresUrl}/salvar';

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(fornecedor.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': 'Fornecedor salvo com sucesso'};
      } else {
        String errorMessage = 'Erro ao salvar fornecedor';
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
      print('Erro ao salvar fornecedor: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<List<Fornecedor>> listarFornecedores() async {
    String baseUrl = '${ApiConfig.fornecedoresUrl}/listarTodos';

    try {
      final response = await http.get(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        final lista = jsonList.map((json) => Fornecedor.fromJson(json)).toList();
        lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
        return lista;
      }
      return [];
    } catch (e) {
      print('Erro ao listar fornecedores: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> atualizarFornecedor(int id, Fornecedor fornecedor) async {
    String baseUrl = '${ApiConfig.fornecedoresUrl}/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(fornecedor.toJson()),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Fornecedor atualizado com sucesso'};
      } else {
        String errorMessage = 'Erro ao atualizar fornecedor';
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
      print('Erro ao atualizar fornecedor: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> excluirFornecedor(int id) async {
    String baseUrl = '${ApiConfig.fornecedoresUrl}/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'message': 'Fornecedor excluído com sucesso'};
      } else {
        String errorMessage = 'Erro ao excluir fornecedor';
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
      print('Erro ao excluir fornecedor: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }
}
