import 'dart:convert';
import 'package:TecStock/services/auth_service.dart';
import 'package:TecStock/model/servico.dart';
import 'package:http/http.dart' as http;

class ServicoService {
  static Future<Map<String, dynamic>> salvarServico(Servico servico) async {
    String baseUrl = 'http://localhost:8081/api/servicos/salvar';

    try {
      final response =
          await http.post(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders(), body: jsonEncode(servico.toJson()));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': 'Serviço salvo com sucesso'};
      } else {
        String errorMessage = 'Erro ao salvar serviço';
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
      print('Erro ao salvar servico: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<List<Servico>> listarServicos() async {
    String baseUrl = 'http://localhost:8081/api/servicos/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
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

  static Future<List<Servico>> listarServicosPendentes() async {
    String baseUrl = 'http://localhost:8081/api/servicos/pendentes';
    try {
      final response = await http.get(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Servico.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao listar serviços pendentes: $e');
      return [];
    }
  }

  static Future<bool> atualizarUnidadesUsadas() async {
    String baseUrl = 'http://localhost:8081/api/servicos/atualizar-unidades-usadas';
    try {
      final response = await http.post(Uri.parse(baseUrl));
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao atualizar unidades usadas: $e');
      return false;
    }
  }

  static Future<bool> excluirServico(int id) async {
    String baseUrl = 'http://localhost:8081/api/servicos/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Erro ao excluir servico: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> atualizarServico(int id, Servico servico) async {
    String baseUrl = 'http://localhost:8081/api/servicos/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(servico.toJson()),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Serviço atualizado com sucesso'};
      } else {
        String errorMessage = 'Erro ao atualizar serviço';
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
      print('Erro ao atualizar servico: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }
}
