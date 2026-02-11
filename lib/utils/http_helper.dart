import 'package:tecstock/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class HttpHelper {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void _checkAuthError(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      if (kDebugMode) {
        print('Erro de autenticação detectado (${response.statusCode}), fazendo logout automático');
      }
      AuthService.logout();
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  static Future<http.Response> get(String url) async {
    if (!await AuthService.validateToken()) {
      return http.Response('Token expirado', 401);
    }

    final headers = await AuthService.getAuthHeaders();
    final response = await http.get(Uri.parse(url), headers: headers);
    _checkAuthError(response);
    return response;
  }

  static Future<http.Response> post(String url, {required String body}) async {
    if (!await AuthService.validateToken()) {
      return http.Response('Token expirado', 401);
    }

    final headers = await AuthService.getAuthHeaders();
    final response = await http.post(Uri.parse(url), headers: headers, body: body);
    _checkAuthError(response);
    return response;
  }

  static Future<http.Response> put(String url, {required String body}) async {
    if (!await AuthService.validateToken()) {
      return http.Response('Token expirado', 401);
    }

    final headers = await AuthService.getAuthHeaders();
    final response = await http.put(Uri.parse(url), headers: headers, body: body);
    _checkAuthError(response);
    return response;
  }

  static Future<http.Response> delete(String url) async {
    if (!await AuthService.validateToken()) {
      return http.Response('Token expirado', 401);
    }

    final headers = await AuthService.getAuthHeaders();
    final response = await http.delete(Uri.parse(url), headers: headers);
    _checkAuthError(response);
    return response;
  }

  static Future<http.Response> patch(String url, {required String body}) async {
    if (!await AuthService.validateToken()) {
      return http.Response('Token expirado', 401);
    }

    final headers = await AuthService.getAuthHeaders();
    final response = await http.patch(Uri.parse(url), headers: headers, body: body);
    _checkAuthError(response);
    return response;
  }
}
