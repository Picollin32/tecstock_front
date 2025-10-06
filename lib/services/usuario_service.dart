import 'dart:convert';
import 'package:TecStock/model/usuario.dart';
import 'package:TecStock/services/auth_service.dart';
import 'package:http/http.dart' as http;

class UsuarioService {
  static Future<Map<String, dynamic>> salvarUsuario(Usuario usuario) async {
    String baseUrl = 'http://localhost:8081/api/usuarios/salvar';

    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode(usuario.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'message': 'Usuário salvo com sucesso'};
      } else if (response.statusCode == 403) {
        return {'success': false, 'message': 'Acesso negado. Apenas administradores podem gerenciar usuários.'};
      } else {
        String errorMessage = 'Erro ao salvar usuário';
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
      print('Erro ao salvar usuario: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  static Future<List<Usuario>> listarUsuarios() async {
    String baseUrl = 'http://localhost:8081/api/usuarios/listarTodos';
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: await AuthService.getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        print('Usuarios recebidos: ${jsonList.length}');
        return jsonList.map((e) => Usuario.fromJson(e)).toList();
      }
      print('Erro na resposta: ${response.statusCode}');
      return [];
    } catch (e) {
      print('Erro ao listar usuarios: $e');
      return [];
    }
  }

  static Future<bool> excluirUsuario(int id) async {
    String baseUrl = 'http://localhost:8081/api/usuarios/deletar/$id';

    try {
      final response = await http.delete(
        Uri.parse(baseUrl),
        headers: await AuthService.getAuthHeaders(),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Erro ao excluir usuario: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> atualizarUsuario(int id, Usuario usuario) async {
    String baseUrl = 'http://localhost:8081/api/usuarios/atualizar/$id';

    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.put(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode(usuario.toJson()),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Usuário atualizado com sucesso'};
      } else if (response.statusCode == 403) {
        return {'success': false, 'message': 'Acesso negado. Apenas administradores podem gerenciar usuários.'};
      } else {
        String errorMessage = 'Erro ao atualizar usuário';
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
      print('Erro ao atualizar usuario: $e');
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }
}
