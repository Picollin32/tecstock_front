import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tecstock/config/api_config.dart';
import 'package:tecstock/model/conta.dart';
import 'package:tecstock/services/auth_service.dart';

class ContaService {
  static String get baseUrl => ApiConfig.contasUrl;
  static String get parcelasUrl => '${ApiConfig.baseUrl}/api/parcelas';

  static void _logHttpErro(String acao, http.Response response) {
    if (!kDebugMode) return;
    final body = utf8.decode(response.bodyBytes);
    debugPrint('[$acao] HTTP ${response.statusCode}: $body');
  }

  static Conta _normalizarContaId(Conta conta) {
    final id = conta.id;
    if (id != null && id < 0) {
      return conta.copyWith(id: id.abs());
    }
    return conta;
  }

  static Conta _contaFromParcelaJson(Map<String, dynamic> json) {
    final dataVencimento = json['dataVencimento'] != null ? DateTime.tryParse(json['dataVencimento']) : null;
    final descricaoConta = (json['descricaoConta'] ?? '').toString();
    final parcelaNumero = json['parcelaNumero'];
    final totalParcelas = json['totalParcelas'];

    String descricao = descricaoConta;
    if (parcelaNumero != null && totalParcelas != null) {
      descricao = '$descricaoConta ($parcelaNumero/$totalParcelas)';
    }

    return Conta(
      id: ((json['id'] ?? 0) as num).toInt(),
      tipo: (json['tipoConta'] ?? 'A_PAGAR').toString(),
      descricao: descricao,
      valor: (json['valor'] ?? 0).toDouble(),
      mesReferencia: dataVencimento?.month ?? DateTime.now().month,
      anoReferencia: dataVencimento?.year ?? DateTime.now().year,
      dataVencimento: dataVencimento,
      pago: json['pago'] ?? false,
      dataPagamento: json['dataPagamento'] != null ? DateTime.tryParse(json['dataPagamento']) : null,
      parcelaNumero: parcelaNumero,
      totalParcelas: totalParcelas,
      origemTipo: json['origemTipo'],
      acrescimo: json['acrescimo'] != null ? (json['acrescimo'] as num).toDouble() : null,
      desconto: json['desconto'] != null ? (json['desconto'] as num).toDouble() : null,
      categoriaId: json['categoriaId'],
      categoriaNome: json['categoriaNome'],
      fornecedorId: json['fornecedorId'],
      fornecedorNome: json['fornecedorNome'],
    );
  }

  static Map<String, dynamic> _erroComMensagemPadrao(http.Response response, String fallback) {
    String msg = fallback;
    try {
      final err = jsonDecode(utf8.decode(response.bodyBytes));
      if (err is Map<String, dynamic> && err['message'] != null) {
        msg = err['message'].toString();
      }
    } catch (_) {}
    return {'sucesso': false, 'mensagem': msg};
  }

  static String _mensagemErro(http.Response response) {
    try {
      final err = jsonDecode(utf8.decode(response.bodyBytes));
      if (err is Map<String, dynamic> && err['message'] != null) {
        return err['message'].toString().toLowerCase();
      }
    } catch (_) {}
    return '';
  }

  static bool _deveFallbackParcela(http.Response response) {
    if (response.statusCode == 404 || response.statusCode == 405 || response.statusCode == 422) {
      return true;
    }
    if (response.statusCode == 400) {
      final msg = _mensagemErro(response);
      return msg.contains('parcela') || msg.contains('id_parcela') || msg.contains('contasparcelas');
    }
    return false;
  }

  static Future<List<Conta>> listarPorMesAno(int mes, int ano) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/mes/$mes/ano/$ano'),
        headers: await AuthService.getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => _normalizarContaId(Conta.fromJson(e))).toList();
      }
      _logHttpErro('listarPorMesAno', response);
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
        return jsonList.map((e) => _normalizarContaId(Conta.fromJson(e))).toList();
      }
      _logHttpErro('listarAPagarPorMesAno', response);
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
        return jsonList.map((e) => _normalizarContaId(Conta.fromJson(e))).toList();
      }
      _logHttpErro('listarAReceberPorMesAno', response);
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
        return jsonList.map((e) => _normalizarContaId(Conta.fromJson(e))).toList();
      }
      _logHttpErro('listarAtrasadas', response);
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
    bool isParcela = false,
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

      final String endpoint = isParcela ? '$parcelasUrl/$id/pagar' : '$baseUrl/$id/pagar';

      http.Response response = await http.patch(
        Uri.parse(endpoint),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(body),
      );

      if (!isParcela && _deveFallbackParcela(response)) {
        response = await http.patch(
          Uri.parse('$parcelasUrl/$id/pagar'),
          headers: await AuthService.getAuthHeaders(),
          body: jsonEncode(body),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          return {'sucesso': true, 'conta': _contaFromParcelaJson(data)};
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (isParcela) {
          return {'sucesso': true, 'conta': _contaFromParcelaJson(data)};
        }
        return {'sucesso': true, 'conta': Conta.fromJson(data)};
      }
      return _erroComMensagemPadrao(response, 'Erro ao marcar como pago');
    } catch (e) {
      if (kDebugMode) print('Erro ao marcar conta como paga: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> desmarcarPagamento(int id, {bool isParcela = false}) async {
    try {
      final String endpoint = isParcela ? '$parcelasUrl/$id/desmarcar-pagamento' : '$baseUrl/$id/desmarcar-pagamento';

      http.Response response = await http.patch(
        Uri.parse(endpoint),
        headers: await AuthService.getAuthHeaders(),
      );

      if (!isParcela && _deveFallbackParcela(response)) {
        response = await http.patch(
          Uri.parse('$parcelasUrl/$id/desmarcar-pagamento'),
          headers: await AuthService.getAuthHeaders(),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          return {'sucesso': true, 'conta': _contaFromParcelaJson(data)};
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (isParcela) {
          return {'sucesso': true, 'conta': _contaFromParcelaJson(data)};
        }
        return {'sucesso': true, 'conta': Conta.fromJson(data)};
      }
      return _erroComMensagemPadrao(response, 'Erro ao desmarcar pagamento');
    } catch (e) {
      if (kDebugMode) print('Erro ao desmarcar pagamento: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<bool> deletarConta(int id, {bool isParcela = false}) async {
    try {
      final String endpoint = isParcela ? '$parcelasUrl/$id' : '$baseUrl/$id';

      http.Response response = await http.delete(
        Uri.parse(endpoint),
        headers: await AuthService.getAuthHeaders(),
      );

      if (!isParcela && _deveFallbackParcela(response)) {
        response = await http.delete(
          Uri.parse('$parcelasUrl/$id'),
          headers: await AuthService.getAuthHeaders(),
        );
      }

      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao deletar conta: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> editarConta(
    int id,
    String descricao,
    double valor,
    DateTime dataVencimento, {
    bool isParcela = false,
  }) async {
    try {
      final body = {
        'descricao': descricao,
        'valor': valor,
        'dataVencimento': dataVencimento.toIso8601String().substring(0, 10),
      };

      final String endpoint = isParcela ? '$parcelasUrl/$id' : '$baseUrl/$id';

      final dynamic bodyFinal = isParcela
          ? {
              'valor': valor,
              'dataVencimento': dataVencimento.toIso8601String().substring(0, 10),
            }
          : body;

      http.Response response = await http.put(
        Uri.parse(endpoint),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(bodyFinal),
      );

      if (!isParcela && _deveFallbackParcela(response)) {
        response = await http.put(
          Uri.parse('$parcelasUrl/$id'),
          headers: await AuthService.getAuthHeaders(),
          body: jsonEncode({
            'valor': valor,
            'dataVencimento': dataVencimento.toIso8601String().substring(0, 10),
          }),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          return {'sucesso': true, 'conta': _contaFromParcelaJson(data)};
        }
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (isParcela) {
          return {'sucesso': true, 'conta': _contaFromParcelaJson(data)};
        }
        return {'sucesso': true, 'conta': Conta.fromJson(data)};
      }
      return _erroComMensagemPadrao(response, 'Erro ao editar conta');
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
