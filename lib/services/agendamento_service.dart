import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/agendamento.dart';

class AgendamentoService {
  static Future<bool> salvarAgendamento(Agendamento agendamento) async {
    String baseUrl = 'http://localhost:8081/api/agendamentos/salvar';

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(agendamento.toJson()),
      );
      if (response.statusCode == 201 || response.statusCode == 200) return true;
      print('Falha ao salvar agendamento. Status: ${response.statusCode}. Body: ${response.body}');
      return false;
    } catch (e) {
      print('Erro ao salvar agendamento: $e');
      return false;
    }
  }

  static Future<bool> atualizarAgendamento(int id, Agendamento agendamento) async {
    String baseUrl = 'http://localhost:8081/api/agendamentos/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(agendamento.toJson()),
      );
      if (response.statusCode == 200) {
        print('Agendamento atualizado com sucesso.');
        return true;
      }
      print('Falha ao atualizar agendamento. Status: ${response.statusCode}. Body: ${response.body}');
      return false;
    } catch (e) {
      print('Erro ao atualizar agendamento: $e');
      return false;
    }
  }

  static Future<List<Agendamento>> listarAgendamentos() async {
    String baseUrl = 'http://localhost:8081/api/agendamentos/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Agendamento.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao listar agendamentos: $e');
      return [];
    }
  }

  static Future<bool> excluirAgendamento(int id) async {
    String baseUrl = 'http://localhost:8081/api/agendamentos/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Erro ao excluir agendamento: $e');
      return false;
    }
  }
}
