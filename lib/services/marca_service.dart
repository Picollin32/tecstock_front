import 'dart:convert';
import 'package:TecStock/model/marca.dart';
import 'package:http/http.dart' as http;

class MarcaService {
  static Future<bool> salvarMarca(Marca marca) async {
    String baseUrl = 'http://localhost:8081/api/marcas/salvar';

    try {
      final response = await http.post(Uri.parse(baseUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode(marca.toJson()));
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Erro ao salvar marca: $e');
      return false;
    }
  }

  static Future<List<Marca>> listarMarcas() async {
    String baseUrl = 'http://localhost:8081/api/marcas/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Marca.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao listar marcas: $e');
      return [];
    }
  }

  static Future<bool> excluirMarca(int id) async {
    String baseUrl = 'http://localhost:8081/api/marcas/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Erro ao excluir marca: $e');
      return false;
    }
  }

  static Future<bool> atualizarMarca(int id, Marca marca) async {
    String baseUrl = 'http://localhost:8081/api/marcas/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(marca.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao atualizar marca: $e');
      return false;
    }
  }
}
