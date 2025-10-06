import 'dart:convert';
import 'package:TecStock/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../model/relatorio.dart';
import '../utils/api_config.dart';

class RelatorioService {
  final String baseUrl = ApiConfig.baseUrl;

  Future<RelatorioAgendamentos> getRelatorioAgendamentos(DateTime dataInicio, DateTime dataFim) async {
    try {
      final inicio = DateFormat('yyyy-MM-dd').format(dataInicio);
      final fim = DateFormat('yyyy-MM-dd').format(dataFim);

      final response = await http.get(
        Uri.parse('$baseUrl/relatorios/agendamentos?dataInicio=$inicio&dataFim=$fim'),
        headers: await AuthService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return RelatorioAgendamentos.fromJson(json.decode(response.body));
      } else {
        throw Exception('Erro ao buscar relatório de agendamentos: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erro ao conectar com o servidor: $e');
    }
  }

  Future<RelatorioServicos> getRelatorioServicos(DateTime dataInicio, DateTime dataFim) async {
    try {
      final inicio = DateFormat('yyyy-MM-dd').format(dataInicio);
      final fim = DateFormat('yyyy-MM-dd').format(dataFim);

      final response = await http.get(
        Uri.parse('$baseUrl/relatorios/servicos?dataInicio=$inicio&dataFim=$fim'),
        headers: await AuthService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return RelatorioServicos.fromJson(json.decode(response.body));
      } else {
        throw Exception('Erro ao buscar relatório de serviços: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erro ao conectar com o servidor: $e');
    }
  }

  Future<RelatorioEstoque> getRelatorioEstoque(DateTime dataInicio, DateTime dataFim) async {
    try {
      final inicio = DateFormat('yyyy-MM-dd').format(dataInicio);
      final fim = DateFormat('yyyy-MM-dd').format(dataFim);

      final response = await http.get(
        Uri.parse('$baseUrl/relatorios/estoque?dataInicio=$inicio&dataFim=$fim'),
        headers: await AuthService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return RelatorioEstoque.fromJson(json.decode(response.body));
      } else {
        throw Exception('Erro ao buscar relatório de estoque: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erro ao conectar com o servidor: $e');
    }
  }

  Future<RelatorioFinanceiro> getRelatorioFinanceiro(DateTime dataInicio, DateTime dataFim) async {
    try {
      final inicio = DateFormat('yyyy-MM-dd').format(dataInicio);
      final fim = DateFormat('yyyy-MM-dd').format(dataFim);

      final response = await http.get(
        Uri.parse('$baseUrl/relatorios/financeiro?dataInicio=$inicio&dataFim=$fim'),
        headers: await AuthService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return RelatorioFinanceiro.fromJson(json.decode(response.body));
      } else {
        throw Exception('Erro ao buscar relatório financeiro: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erro ao conectar com o servidor: $e');
    }
  }

  Future<RelatorioComissao> getRelatorioComissao(DateTime dataInicio, DateTime dataFim, int mecanicoId) async {
    try {
      final inicio = DateFormat('yyyy-MM-dd').format(dataInicio);
      final fim = DateFormat('yyyy-MM-dd').format(dataFim);

      final response = await http.get(
        Uri.parse('$baseUrl/relatorios/comissao?dataInicio=$inicio&dataFim=$fim&mecanicoId=$mecanicoId'),
        headers: await AuthService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return RelatorioComissao.fromJson(json.decode(response.body));
      } else {
        throw Exception('Erro ao buscar relatório de comissão: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erro ao conectar com o servidor: $e');
    }
  }

  Future<RelatorioGarantias> getRelatorioGarantias(DateTime dataInicio, DateTime dataFim) async {
    try {
      final inicio = DateFormat('yyyy-MM-dd').format(dataInicio);
      final fim = DateFormat('yyyy-MM-dd').format(dataFim);

      final response = await http.get(
        Uri.parse('$baseUrl/relatorios/garantias?dataInicio=$inicio&dataFim=$fim'),
        headers: await AuthService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return RelatorioGarantias.fromJson(json.decode(response.body));
      } else {
        throw Exception('Erro ao buscar relatório de garantias: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erro ao conectar com o servidor: $e');
    }
  }

  Future<RelatorioFiado> getRelatorioFiado(DateTime dataInicio, DateTime dataFim) async {
    try {
      final inicio = DateFormat('yyyy-MM-dd').format(dataInicio);
      final fim = DateFormat('yyyy-MM-dd').format(dataFim);

      final response = await http.get(
        Uri.parse('$baseUrl/relatorios/fiado?dataInicio=$inicio&dataFim=$fim'),
        headers: await AuthService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return RelatorioFiado.fromJson(json.decode(response.body));
      } else {
        throw Exception('Erro ao buscar relatório de fiado: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erro ao conectar com o servidor: $e');
    }
  }

  Future<RelatorioConsultores> getRelatorioConsultores(DateTime dataInicio, DateTime dataFim) async {
    try {
      final inicio = DateFormat('yyyy-MM-dd').format(dataInicio);
      final fim = DateFormat('yyyy-MM-dd').format(dataFim);

      final response = await http.get(
        Uri.parse('$baseUrl/relatorios/consultores?dataInicio=$inicio&dataFim=$fim'),
        headers: await AuthService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        return RelatorioConsultores.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else {
        throw Exception('Erro ao buscar relatório de consultores: ${response.body}');
      }
    } catch (e) {
      throw Exception('Erro ao conectar com o servidor: $e');
    }
  }
}
