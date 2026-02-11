import 'dart:convert';
import 'package:tecstock/services/auth_service.dart';
import 'package:tecstock/model/orcamento.dart';
import 'package:tecstock/model/ordem_servico.dart';
import 'package:tecstock/config/api_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OrcamentoService {
  static String get baseUrl => ApiConfig.orcamentosUrl;

  static Future<bool> salvarOrcamento(Orcamento orcamento) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/salvar'),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(orcamento.toJson()),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao salvar orçamento: $e');
      }
      return false;
    }
  }

  static Future<Orcamento?> buscarOrcamentoPorId(int id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/buscar/$id'), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        return Orcamento.fromJson(jsonData);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao buscar orçamento: $e');
      }
      return null;
    }
  }

  static Future<List<Orcamento>> listarOrcamentos() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/listarTodos'), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Orcamento.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao listar orçamentos: $e');
      }
      return [];
    }
  }

  static Future<bool> excluirOrcamento(int id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/deletar/$id'), headers: await AuthService.getAuthHeaders());
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao excluir orçamento: $e');
      }
      return false;
    }
  }

  static Future<bool> atualizarOrcamento(int id, Orcamento orcamento) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/atualizar/$id'),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(orcamento.toJson()),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao atualizar orçamento: $e');
      }
      return false;
    }
  }

  static Future<bool> atualizarStatus(int id, String novoStatus) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/$id/status?status=$novoStatus'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao atualizar status do orçamento: $e');
      }
      return false;
    }
  }

  static Future<List<Orcamento>> buscarPorCliente(String cpf) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/cliente/$cpf'), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Orcamento.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao buscar orçamentos por cliente: $e');
      }
      return [];
    }
  }

  static Future<List<Orcamento>> buscarPorVeiculo(String placa) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/veiculo/$placa'), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Orcamento.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao buscar orçamentos por veículo: $e');
      }
      return [];
    }
  }

  static Future<List<Orcamento>> buscarPorStatus(String status) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/status/$status'), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => Orcamento.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao buscar orçamentos por status: $e');
      }
      return [];
    }
  }

  static Future<Orcamento?> buscarPorNumeroOrcamento(String numeroOrcamento) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/buscar-numero/$numeroOrcamento'), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        return Orcamento.fromJson(jsonData);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao buscar orçamento por número: $e');
      }
      return null;
    }
  }

  static Future<bool> recalcularPrecos(int id) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/$id/recalcular-precos'),
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao recalcular preços do orçamento: $e');
      }
      return false;
    }
  }

  static Future<Map<String, double>?> calcularMaxDescontos(int id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/$id/max-descontos'), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        return {
          'maxDescontoServicos': jsonData['maxDescontoServicos'].toDouble(),
          'maxDescontoPecas': jsonData['maxDescontoPecas'].toDouble(),
        };
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao calcular máximos de desconto: $e');
      }
      return null;
    }
  }

  static Future<OrdemServico?> transformarEmOrdemServico(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$id/transformar-em-os'),
        headers: await AuthService.getAuthHeaders(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        return OrdemServico.fromJson(jsonData);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao transformar orçamento em OS: $e');
      }
      return null;
    }
  }
}
