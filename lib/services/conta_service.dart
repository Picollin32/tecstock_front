import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tecstock/config/api_config.dart';
import 'package:tecstock/model/conta.dart';
import 'package:tecstock/services/auth_service.dart';

class ContaService {
  static String get baseUrl => ApiConfig.contasUrl;

  static Future<List<Conta>> listarPorMesAno(int mes, int ano) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mes/$mes/ano/$ano'),
        headers: await AuthService.getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Conta.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('Erro ao listar contas: $e');
      return [];
    }
  }

  static Future<List<Conta>> listarAPagarPorMesAno(int mes, int ano) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/a-pagar/mes/$mes/ano/$ano'),
        headers: await AuthService.getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Conta.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('Erro ao listar contas a pagar: $e');
      return [];
    }
  }

  static Future<List<Conta>> listarAReceberPorMesAno(int mes, int ano) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/a-receber/mes/$mes/ano/$ano'),
        headers: await AuthService.getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Conta.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('Erro ao listar contas a receber: $e');
      return [];
    }
  }

  static Future<List<Conta>> listarAtrasadas() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/atrasadas'),
        headers: await AuthService.getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Conta.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('Erro ao listar contas atrasadas: $e');
      return [];
    }
  }

  static Future<Map<String, double>> resumoMes(int mes, int ano) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/resumo/mes/$mes/ano/$ano'),
        headers: await AuthService.getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(utf8.decode(response.bodyBytes));
        return json.map((k, v) => MapEntry(k, (v ?? 0.0).toDouble()));
      }
      return {};
    } catch (e) {
      if (kDebugMode) print('Erro ao buscar resumo mensal: $e');
      return {};
    }
  }

  static Future<Map<String, dynamic>> adicionarContaPagar(Conta conta) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/a-pagar'),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(conta.toJson()),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': true, 'conta': Conta.fromJson(data)};
      }
      String msg = 'Erro ao adicionar conta';
      try {
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        if (err['message'] != null) msg = err['message'];
      } catch (_) {}
      return {'sucesso': false, 'mensagem': msg};
    } catch (e) {
      if (kDebugMode) print('Erro ao adicionar conta: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> adicionarFrete({
    required String descricao,
    required double valor,
    required Map<String, dynamic> pagamento,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/a-pagar/frete'),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode({'descricao': descricao, 'valor': valor, 'pagamento': pagamento}),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'sucesso': true};
      }
      String msg = 'Erro ao adicionar frete';
      try {
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        if (err['message'] != null) msg = err['message'];
      } catch (_) {}
      return {'sucesso': false, 'mensagem': msg};
    } catch (e) {
      if (kDebugMode) print('Erro ao adicionar frete: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> adicionarLancamentoAPagar({
    required String descricao,
    required double valor,
    required String origem,
    required Map<String, dynamic> pagamento,
    int? categoriaFinanceiraId,
    int? fornecedorId,
  }) async {
    try {
      final body = <String, dynamic>{
        'descricao': descricao,
        'valor': valor,
        'origem': origem,
        'pagamento': pagamento,
      };
      if (categoriaFinanceiraId != null) {
        body['categoriaFinanceiraId'] = categoriaFinanceiraId;
      }
      if (fornecedorId != null) {
        body['fornecedorId'] = fornecedorId;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/a-pagar/lancamento'),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'sucesso': true};
      }
      String msg = 'Erro ao adicionar lançamento';
      try {
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        if (err['message'] != null) msg = err['message'];
      } catch (_) {}
      return {'sucesso': false, 'mensagem': msg};
    } catch (e) {
      if (kDebugMode) print('Erro ao adicionar lançamento: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> marcarComoPago(
    int id, {
    required DateTime dataPagamento,
    double? acrescimo,
    double? desconto,
  }) async {
    try {
      final body = <String, dynamic>{
        'dataPagamento': dataPagamento.toIso8601String().substring(0, 10),
      };
      if (acrescimo != null && acrescimo > 0) {
        body['acrescimo'] = acrescimo;
      }
      if (desconto != null && desconto > 0) {
        body['desconto'] = desconto;
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/$id/pagar'),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': true, 'conta': Conta.fromJson(data)};
      }
      String msg = 'Erro ao marcar como pago';
      try {
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        if (err['message'] != null) msg = err['message'];
      } catch (_) {}
      return {'sucesso': false, 'mensagem': msg};
    } catch (e) {
      if (kDebugMode) print('Erro ao marcar conta como paga: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> desmarcarPagamento(int id) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/$id/desmarcar-pagamento'),
        headers: await AuthService.getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': true, 'conta': Conta.fromJson(data)};
      }
      return {'sucesso': false, 'mensagem': 'Erro ao desmarcar pagamento'};
    } catch (e) {
      if (kDebugMode) print('Erro ao desmarcar pagamento: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<bool> deletarConta(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: await AuthService.getAuthHeaders(),
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao deletar conta: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> editarConta(int id, String descricao, double valor, DateTime dataVencimento) async {
    try {
      final body = {
        'descricao': descricao,
        'valor': valor,
        'dataVencimento': dataVencimento.toIso8601String().substring(0, 10),
      };
      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': true, 'conta': Conta.fromJson(data)};
      }
      return {'sucesso': false, 'mensagem': 'Erro ao editar conta'};
    } catch (e) {
      if (kDebugMode) print('Erro ao editar conta: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> registrarPagamentoParcial(int id, double valor) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/$id/pagamento-parcial'),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode({'valor': valor}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': true, 'conta': Conta.fromJson(data)};
      }
      String msg = 'Erro ao registrar pagamento parcial';
      try {
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        if (err['message'] != null) msg = err['message'];
      } catch (_) {}
      return {'sucesso': false, 'mensagem': msg};
    } catch (e) {
      if (kDebugMode) print('Erro ao registrar pagamento parcial: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }
}
