import 'dart:convert';
import 'package:tecstock/services/auth_service.dart';
import 'package:tecstock/model/checklist.dart';
import 'package:tecstock/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ChecklistService {
  static Future<bool> salvarChecklist(Checklist checklist) async {
    String baseUrl = '${ApiConfig.checklistUrl}/salvar';

    try {
      final response =
          await http.post(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders(), body: jsonEncode(checklist.toJson()));
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao salvar checklist: $e');
      }
      return false;
    }
  }

  static Future<Checklist?> buscarChecklistPorId(int id) async {
    String baseUrl = '${ApiConfig.checklistUrl}/buscar/$id';

    try {
      final response = await http.get(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        return Checklist.fromJson(jsonData);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao buscar checklist: $e');
      }
      return null;
    }
  }

  static Future<List<Checklist>> listarChecklists() async {
    String baseUrl = '${ApiConfig.checklistUrl}/listarTodos';
    try {
      final response = await http.get(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Checklist.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao listar checklists: $e');
      }
      return [];
    }
  }

  static Future<bool> excluirChecklist(int id) async {
    String baseUrl = '${ApiConfig.checklistUrl}/deletar/$id';

    try {
      final response = await http.delete(Uri.parse(baseUrl), headers: await AuthService.getAuthHeaders());
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao excluir checklist: $e');
      }
      return false;
    }
  }

  static Future<bool> atualizarChecklist(int id, Checklist checklist) async {
    String baseUrl = '${ApiConfig.checklistUrl}/atualizar/$id';

    try {
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(checklist.toJson()),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao atualizar checklist: $e');
      }
      return false;
    }
  }

  static Future<bool> fecharChecklist(int id) async {
    String baseUrl = '${ApiConfig.checklistUrl}/fechar/$id';

    try {
      final response = await http.put(Uri.parse(baseUrl));
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao fechar checklist: $e');
      }
      return false;
    }
  }
}
