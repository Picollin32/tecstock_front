// Helper para adicionar headers JWT automaticamente em todos os services
import 'package:TecStock/services/auth_service.dart';
import 'package:http/http.dart' as http;

class HttpHelper {
  // GET com autenticação
  static Future<http.Response> get(String url) async {
    final headers = await AuthService.getAuthHeaders();
    return await http.get(Uri.parse(url), headers: headers);
  }

  // POST com autenticação
  static Future<http.Response> post(String url, {required String body}) async {
    final headers = await AuthService.getAuthHeaders();
    return await http.post(Uri.parse(url), headers: headers, body: body);
  }

  // PUT com autenticação
  static Future<http.Response> put(String url, {required String body}) async {
    final headers = await AuthService.getAuthHeaders();
    return await http.put(Uri.parse(url), headers: headers, body: body);
  }

  // DELETE com autenticação
  static Future<http.Response> delete(String url) async {
    final headers = await AuthService.getAuthHeaders();
    return await http.delete(Uri.parse(url), headers: headers);
  }

  // PATCH com autenticação
  static Future<http.Response> patch(String url, {required String body}) async {
    final headers = await AuthService.getAuthHeaders();
    return await http.patch(Uri.parse(url), headers: headers, body: body);
  }
}
