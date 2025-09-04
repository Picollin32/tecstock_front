import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/fornecedor_peca.dart';

class DescontoService {
  static Future<bool> associarDesconto({
    required int fornecedorId,
    required int pecaId,
    required double desconto,
  }) async {
    String baseUrl = 'http://localhost:8081/api/descontos/associar';

    try {
      final body = jsonEncode({
        'fornecedorId': fornecedorId,
        'pecaId': pecaId,
        'desconto': desconto,
      });

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print("Erro ao associar desconto: $e");
      return false;
    }
  }

  static Future<List<FornecedorPeca>> listarTodosDescontos() async {
    String baseUrl = 'http://localhost:8081/api/descontos/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((json) => FornecedorPeca.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print("Erro ao listar descontos: $e");
      return [];
    }
  }

  static Future<bool> removerDesconto(int fornecedorId, int pecaId) async {
    String baseUrl = 'http://localhost:8081/api/descontos/remover/$fornecedorId/$pecaId';
    try {
      final response = await http.delete(Uri.parse(baseUrl));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print("Erro ao remover desconto: $e");
      return false;
    }
  }
}
