import 'dart:convert';
import 'package:tecstock/services/auth_service.dart';
import 'package:tecstock/model/veiculo.dart';
import 'package:tecstock/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VeiculoService {
  static Future<Map<String, dynamic>> salvarVeiculo(Veiculo veiculo) async {
    String baseUrl = '${ApiConfig.veiculosUrl}/salvar';

    try {
      final response = await http.post(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders(), body: jsonEncode(veiculo.toJson()));

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': 'Veículo salvo com sucesso'};
      } else {
        String errorMessage = 'Erro ao salvar veículo';
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
      if (kDebugMode) {
        print('Erro ao salvar veículo: $e');
      }
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<List<Veiculo>> listarVeiculos() async {
    String baseUrl = '${ApiConfig.veiculosUrl}/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Veiculo.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao listar veículos: $e');
      }
      return [];
    }
  }

  static Future<Map<String, dynamic>> excluirVeiculo(int id) async {
    String baseUrl = '${ApiConfig.veiculosUrl}/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {'success': true, 'message': 'Veículo excluído com sucesso'};
      } else {
        String errorMessage = 'Erro ao excluir veículo';
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
      if (kDebugMode) {
        print('Erro ao excluir veículo: $e');
      }
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> atualizarVeiculo(int id, Veiculo veiculo) async {
    String baseUrl = '${ApiConfig.veiculosUrl}/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(veiculo.toJson()),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Veículo atualizado com sucesso'};
      } else {
        String errorMessage = 'Erro ao atualizar veículo';
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
      if (kDebugMode) {
        print('Erro ao atualizar veículo: $e');
      }
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }
}
