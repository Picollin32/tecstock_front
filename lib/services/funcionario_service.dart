import 'dart:convert';
import 'package:tecstock/services/auth_service.dart';
import 'package:tecstock/model/funcionario.dart';
import 'package:tecstock/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Funcionarioservice {
  static Future<Map<String, dynamic>> salvarFuncionario(Funcionario funcionario) async {
    String baseUrl = '${ApiConfig.funcionariosUrl}/salvar';

    try {
      final response = await http
          .post(
        Uri.parse(baseUrl),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(funcionario.toJson()),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout: A requisição demorou muito para responder');
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': 'Funcionário salvo com sucesso'};
      } else {
        String errorMessage = 'Erro ao salvar funcionário';
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
        print('Erro ao salvar funcionario: $e');
      }
      String errorMessage = 'Erro de conexão';
      if (e.toString().contains('Timeout')) {
        errorMessage = 'Tempo de espera excedido. Tente novamente.';
      }
      return {'success': false, 'message': errorMessage};
    }
  }

  static Future<List<Funcionario>> listarFuncionarios() async {
    String baseUrl = '${ApiConfig.funcionariosUrl}/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());

      if (response.statusCode == 401 || response.statusCode == 403) {
        if (kDebugMode) {
          print('Erro de autenticação ao listar funcionários');
        }
        await AuthService.logout();
        throw Exception('Unauthorized');
      }

      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Funcionario.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao listar funcionarios: $e');
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> excluirFuncionario(int id) async {
    String baseUrl = '${ApiConfig.funcionariosUrl}/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'message': 'Funcionário excluído com sucesso'};
      } else {
        String errorMessage = 'Erro ao excluir funcionário';
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
        print('Erro ao excluir funcionario: $e');
      }
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> atualizarFuncionario(int id, Funcionario funcionario) async {
    String baseUrl = '${ApiConfig.funcionariosUrl}/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(funcionario.toJson()),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Funcionário atualizado com sucesso'};
      } else {
        String errorMessage = 'Erro ao atualizar funcionário';
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
        print('Erro ao atualizar funcionario: $e');
      }
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }
}
