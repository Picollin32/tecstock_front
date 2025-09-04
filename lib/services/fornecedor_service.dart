import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/fornecedor.dart';

class FornecedorService {
  static Future<bool> salvarFornecedor(Fornecedor fornecedor) async {
    String baseUrl = 'http://localhost:8081/api/fornecedores/salvar';

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(fornecedor.toJson()),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Erro ao salvar fornecedor: $e');
      return false;
    }
  }

  static Future<List<Fornecedor>> listarFornecedores() async {
    String baseUrl = 'http://localhost:8081/api/fornecedores/listarTodos';

    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((json) => Fornecedor.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao listar fornecedores: $e');
      return [];
    }
  }

  static Future<bool> atualizarFornecedor(int id, Fornecedor fornecedor) async {
    String baseUrl = 'http://localhost:8081/api/fornecedores/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(fornecedor.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao atualizar fornecedor: $e');
      return false;
    }
  }

  static Future<bool> excluirFornecedor(int id) async {
    String baseUrl = 'http://localhost:8081/api/fornecedores/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Erro ao excluir fornecedor: $e');
      return false;
    }
  }
}
