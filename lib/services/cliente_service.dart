import 'dart:convert';
import 'package:TecStock/model/cliente.dart';
import 'package:http/http.dart' as http;

class ClienteService {
  static Future<bool> salvarCliente(Cliente cliente) async {
    String baseUrl = 'http://localhost:8081/api/clientes/salvar';

    try {
      final response =
          await http.post(Uri.parse(baseUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode(cliente.toJson()));
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Erro ao salvar cliente: $e');
      return false;
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

  static Future<bool> atualizarCliente(int id, Cliente cliente) async {
    String baseUrl = 'http://localhost:8081/api/clientes/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(cliente.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao atualizar cliente: $e');
      return false;
    }
  }
}
