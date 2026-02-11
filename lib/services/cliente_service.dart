import 'dart:convert';
import 'package:tecstock/model/cliente.dart';
import 'package:tecstock/services/auth_service.dart';
import 'package:tecstock/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ClienteService {
  static Future<Map<String, dynamic>> salvarCliente(Cliente cliente) async {
    String baseUrl = '${ApiConfig.clientesUrl}/salvar';

    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.post(Uri.parse(baseUrl), headers: headers, body: jsonEncode(cliente.toJson()));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': 'Cliente salvo com sucesso'};
      } else {
        String errorMessage = 'Erro ao salvar cliente';
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
        print('Erro ao salvar cliente: $e');
      }
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<List<Cliente>> listarClientes() async {
    String baseUrl = '${ApiConfig.clientesUrl}/listarTodos';
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(Uri.parse(baseUrl), headers: headers);
      if (kDebugMode) {
        print('Response status: ${response.statusCode}');
      }
      if (kDebugMode) {
        print('Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        if (kDebugMode) {
          print('JSON List length: ${jsonList.length}');
        }
        if (kDebugMode) {
          print('JSON List: $jsonList');
        }

        final clientes = jsonList.map((e) => Cliente.fromJson(e)).toList();
        if (kDebugMode) {
          print('Clientes parsed: ${clientes.length}');
        }
        return clientes;
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao listar clientes: $e');
      }
      return [];
    }
  }

  static Future<Map<String, dynamic>> excluirCliente(int id) async {
    String baseUrl = '${ApiConfig.clientesUrl}/deletar/$id';

    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.delete(Uri.parse(baseUrl), headers: headers);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'message': 'Cliente excluído com sucesso'};
      } else {
        String errorMessage = 'Erro ao excluir cliente';
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
        print('Erro ao excluir cliente: $e');
      }
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> atualizarCliente(int id, Cliente cliente) async {
    String baseUrl = '${ApiConfig.clientesUrl}/atualizar/$id';

    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode(cliente.toJson()),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Cliente atualizado com sucesso'};
      } else {
        String errorMessage = 'Erro ao atualizar cliente';
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
        print('Erro ao atualizar cliente: $e');
      }
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }
}
