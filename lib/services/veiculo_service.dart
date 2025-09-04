import 'dart:convert';
import 'package:TecStock/model/veiculo.dart';
import 'package:http/http.dart' as http;

class VeiculoService {
  static Future<bool> salvarVeiculo(Veiculo veiculo) async {
    String baseUrl = 'http://localhost:8081/api/veiculos/salvar';

    try {
      final response =
          await http.post(Uri.parse(baseUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode(veiculo.toJson()));
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Erro ao salvar veículo: $e');
      return false;
    }
  }

  static Future<List<Veiculo>> listarVeiculos() async {
    String baseUrl = 'http://localhost:8081/api/veiculos/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Veiculo.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao listar veículos: $e');
      return [];
    }
  }

  static Future<bool> excluirVeiculo(int id) async {
    String baseUrl = 'http://localhost:8081/api/veiculos/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Erro ao excluir veículo: $e');
      return false;
    }
  }

  static Future<bool> atualizarVeiculo(int id, Veiculo veiculo) async {
    String baseUrl = 'http://localhost:8081/api/veiculos/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(veiculo.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao atualizar veículo: $e');
      return false;
    }
  }
}
