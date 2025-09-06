import 'dart:convert';
import 'package:TecStock/model/cliente.dart';
import 'package:http/http.dart' as http;

class ClienteService {
  static Future<Map<String, dynamic>> salvarCliente(Cliente cliente) async {
    String baseUrl = 'http://localhost:8081/api/clientes/salvar';

    try {
      final response =
          await http.post(Uri.parse(baseUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode(cliente.toJson()));

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
    String baseUrl = 'http://localhost:8081/api/clientes/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Cliente.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao listar clientes: $e');
      return [];
    }
  }

  static Future<bool> excluirCliente(int id) async {
    String baseUrl = 'http://localhost:8081/api/clientes/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Erro ao excluir cliente: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> atualizarCliente(int id, Cliente cliente) async {
    String baseUrl = 'http://localhost:8081/api/clientes/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
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
