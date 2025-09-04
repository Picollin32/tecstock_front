import 'dart:convert';
import 'package:TecStock/model/fabricante.dart';
import 'package:http/http.dart' as http;

class FabricanteService {
  static Future<bool> salvarFabricante(Fabricante fabricante) async {
    String baseUrl = 'http://localhost:8081/api/fabricantes/salvar';

    try {
      final response =
          await http.post(Uri.parse(baseUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode(fabricante.toJson()));
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Erro ao salvar fabricante: $e');
      return false;
    }
  }

  static Future<List<Fabricante>> listarFabricantes() async {
    String baseUrl = 'http://localhost:8081/api/fabricantes/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Fabricante.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao listar fabricantes: $e');
      return [];
    }
  }

  static Future<bool> excluirFabricante(int id) async {
    String baseUrl = 'http://localhost:8081/api/fabricantes/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Erro ao excluir fabricante: $e');
      return false;
    }
  }

  static Future<bool> atualizarFabricante(int id, Fabricante fabricante) async {
    String baseUrl = 'http://localhost:8081/api/fabricantes/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(fabricante.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao atualizar fabricante: $e');
      return false;
    }
  }
}
