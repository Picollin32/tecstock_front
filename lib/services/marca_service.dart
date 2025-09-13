import 'dart:convert';
import 'package:TecStock/model/marca.dart';
import 'package:http/http.dart' as http;

class MarcaService {
  static Future<Map<String, dynamic>> salvarMarca(Marca marca) async {
    String baseUrl = 'http://localhost:8081/api/marcas/salvar';

    try {
      final response = await http.post(Uri.parse(baseUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode(marca.toJson()));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': 'Marca salva com sucesso'};
      } else {
        String errorMessage = 'Erro ao salvar marca';
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
      print('Erro ao salvar marca: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<List<Marca>> listarMarcas() async {
    String baseUrl = 'http://localhost:8081/api/marcas/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        final listas = jsonList.map((e) => Marca.fromJson(e)).toList();
        // Ordena alfabeticamente pelo nome da marca (case-insensitive)
        listas.sort((a, b) => a.marca.toLowerCase().compareTo(b.marca.toLowerCase()));
        return listas;
      }
      return [];
    } catch (e) {
      print('Erro ao listar marcas: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> excluirMarca(int id) async {
    String baseUrl = 'http://localhost:8081/api/marcas/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'message': 'Marca excluída com sucesso'};
      } else {
        String errorMessage = 'Erro ao excluir marca';
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
      print('Erro ao excluir marca: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> atualizarMarca(int id, Marca marca) async {
    String baseUrl = 'http://localhost:8081/api/marcas/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(marca.toJson()),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Marca atualizada com sucesso'};
      } else {
        String errorMessage = 'Erro ao atualizar marca';
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
      print('Erro ao atualizar marca: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }
}
