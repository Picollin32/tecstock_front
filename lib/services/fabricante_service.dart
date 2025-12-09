import 'dart:convert';
import 'package:TecStock/model/fabricante.dart';
import 'package:TecStock/services/auth_service.dart';
import 'package:TecStock/config/api_config.dart';
import 'package:http/http.dart' as http;

class FabricanteService {
  static Future<Map<String, dynamic>> salvarFabricante(Fabricante fabricante) async {
    String baseUrl = '${ApiConfig.fabricantesUrl}/salvar';

    try {
      final response =
          await http.post(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders(), body: jsonEncode(fabricante.toJson()));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': 'Fabricante salvo com sucesso'};
      } else {
        String errorMessage = 'Erro ao salvar fabricante';
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
      print('Erro ao salvar fabricante: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<List<Fabricante>> listarFabricantes() async {
    String baseUrl = '${ApiConfig.fabricantesUrl}/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
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

  static Future<Map<String, dynamic>> excluirFabricante(int id) async {
    String baseUrl = '${ApiConfig.fabricantesUrl}/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'message': 'Fabricante excluído com sucesso'};
      } else {
        String errorMessage = 'Erro ao excluir fabricante';
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
      print('Erro ao excluir fabricante: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> atualizarFabricante(int id, Fabricante fabricante) async {
    String baseUrl = '${ApiConfig.fabricantesUrl}/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(fabricante.toJson()),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Fabricante atualizado com sucesso'};
      } else {
        String errorMessage = 'Erro ao atualizar fabricante';
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
      print('Erro ao atualizar fabricante: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }
}
