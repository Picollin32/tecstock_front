import 'dart:convert';
import 'package:TecStock/model/funcionario.dart';
import 'package:http/http.dart' as http;

class Funcionarioservice {
  static Future<bool> salvarFuncionario(Funcionario funcionario) async {
    String baseUrl = 'http://localhost:8081/api/funcionarios/salvar';

    try {
      final response =
          await http.post(Uri.parse(baseUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode(funcionario.toJson()));
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Erro ao salvar funcionario: $e');
      return false;
    }
  }

  static Future<List<Funcionario>> listarFuncionarios() async {
    String baseUrl = 'http://localhost:8081/api/funcionarios/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Funcionario.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao listar funcionarios: $e');
      return [];
    }
  }

  static Future<bool> excluirFuncionario(int id) async {
    String baseUrl = 'http://localhost:8081/api/funcionarios/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Erro ao excluir funcionario: $e');
      return false;
    }
  }

  static Future<bool> atualizarFuncionario(int id, Funcionario funcionario) async {
    String baseUrl = 'http://localhost:8081/api/funcionarios/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(funcionario.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao atualizar funcionario: $e');
      return false;
    }
  }
}
