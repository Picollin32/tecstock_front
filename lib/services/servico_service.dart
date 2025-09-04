import 'dart:convert';
import 'package:TecStock/model/servico.dart';
import 'package:http/http.dart' as http;

class ServicoService {
  static Future<bool> salvarServico(Servico servico) async {
    String baseUrl = 'http://localhost:8081/api/servicos/salvar';

    try {
      final response =
          await http.post(Uri.parse(baseUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode(servico.toJson()));
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Erro ao salvar servico: $e');
      return false;
    }
  }

  static Future<List<Servico>> listarServicos() async {
    String baseUrl = 'http://localhost:8081/api/servicos/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Servico.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao listar servicos: $e');
      return [];
    }
  }

  static Future<bool> excluirServico(int id) async {
    String baseUrl = 'http://localhost:8081/api/servicos/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Erro ao excluir servico: $e');
      return false;
    }
  }

  static Future<bool> atualizarServico(int id, Servico servico) async {
    String baseUrl = 'http://localhost:8081/api/servicos/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(servico.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao atualizar servico: $e');
      return false;
    }
  }
}
