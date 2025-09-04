import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/peca.dart';

class PecaService {
  static const String baseUrl = 'http://localhost:8081/api/pecas';

  static Future<List<Peca>> listarPecas() async {
    String baseUrl = 'http://localhost:8081/api/pecas/listarTodas';
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Peca.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao listar peças: $e');
      return [];
    }
  }

  static Future<bool> salvarPeca(Peca peca) async {
    final response = await http.post(
      Uri.parse('$baseUrl/salvar'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(peca.toJson()),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> salvarPecaComDesconto({
    required Peca peca,
    required int fornecedorId,
    required double desconto,
  }) async {
    final url = Uri.parse('http://localhost:8081/api/descontos/aplicar');
    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        'peca': peca.toJson(),
        'fornecedorId': fornecedorId,
        'desconto': desconto,
      }),
    );
    return response.statusCode == 200;
  }

  static Future<bool> atualizarPeca(int id, Peca peca) async {
    final response = await http.put(
      Uri.parse('$baseUrl/atualizar/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(peca.toJson()),
    );
    return response.statusCode == 200;
  }

  static Future<bool> excluirPeca(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/deletar/$id'));
    return response.statusCode == 200;
  }
}
