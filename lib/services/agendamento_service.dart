import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tecstock/services/auth_service.dart';
import 'package:tecstock/config/api_config.dart';
import '../model/agendamento.dart';

class AgendamentoService {
  static Future<bool> salvarAgendamento(Agendamento agendamento) async {
    String baseUrl = '${ApiConfig.agendamentosUrl}/salvar';

    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode(agendamento.toJson()),
      );
      if (response.statusCode == 201 || response.statusCode == 200) return true;
      if (kDebugMode) {
        print('Falha ao salvar agendamento. Status: ${response.statusCode}. Body: ${response.body}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao salvar agendamento: $e');
      }
      return false;
    }
  }

  static Future<bool> atualizarAgendamento(int id, Agendamento agendamento) async {
    String baseUrl = '${ApiConfig.agendamentosUrl}/atualizar/$id';

    try {
      final jsonData = agendamento.toJson();

      final headers = await AuthService.getAuthHeaders();
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode(jsonData),
      );
      if (response.statusCode == 200) {
        return true;
      }
      if (kDebugMode) {
        print('Falha ao atualizar agendamento. Status: ${response.statusCode}. Body: ${response.body}');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao atualizar agendamento: $e');
      }
      return false;
    }
  }

  static Future<List<Agendamento>> listarAgendamentos() async {
    String baseUrl = '${ApiConfig.agendamentosUrl}/listarTodos';
    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(Uri.parse(baseUrl), headers: headers);
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Agendamento.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao listar agendamentos: $e');
      }
      return [];
    }
  }

  static Future<bool> excluirAgendamento(int id) async {
    String baseUrl = '${ApiConfig.agendamentosUrl}/deletar/$id';

    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.delete(Uri.parse(baseUrl), headers: headers);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao excluir agendamento: $e');
      }
      return false;
    }
  }
}
