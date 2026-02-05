import 'dart:convert';
import 'package:TecStock/model/cliente.dart';
import 'package:TecStock/services/auth_service.dart';
import 'package:TecStock/config/api_config.dart';
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
      print('Erro ao salvar cliente: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<List<Cliente>> listarClientes() async {
    String baseUrl = '${ApiConfig.clientesUrl}/listarTodos';
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(Uri.parse(baseUrl), headers: headers);
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        print('JSON List length: ${jsonList.length}');
        print('JSON List: $jsonList');

        final clientes = jsonList.map((e) => Cliente.fromJson(e)).toList();
        print('Clientes parsed: ${clientes.length}');
        return clientes;
      }
      return [];
    } catch (e) {
      print('Erro ao listar clientes: $e');
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
      print('Erro ao excluir cliente: $e');
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
      print('Erro ao atualizar cliente: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }
}
