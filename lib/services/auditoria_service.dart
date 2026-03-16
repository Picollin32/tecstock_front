import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tecstock/config/api_config.dart';
import '../model/auditoria_log.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

class AuditoriaService {
  static String get baseUrl => ApiConfig.auditoriaUrl;

  static Map<String, String> _getHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> buscarTodosLogs(String token, int page, int size,
      {String sortBy = 'dataHora', String sortDir = 'desc'}) async {
    final response = await http.get(
      Uri.parse('$baseUrl?page=$page&size=$size&sortBy=$sortBy&sortDir=$sortDir'),
      headers: _getHeaders(token),
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return {
        'content': (data['content'] as List).map((item) => AuditoriaLog.fromJson(item)).toList(),
        'totalElements': data['totalElements'],
        'totalPages': data['totalPages'],
        'currentPage': data['number'],
      };
    } else {
      throw Exception('Erro ao buscar logs de auditoria');
    }
  }

  static Future<Map<String, dynamic>> buscarLogsPorUsuario(String token, String usuario, int page, int size) async {
    final response = await http.get(
      Uri.parse('$baseUrl/usuario/$usuario?page=$page&size=$size'),
      headers: _getHeaders(token),
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return {
        'content': (data['content'] as List).map((item) => AuditoriaLog.fromJson(item)).toList(),
        'totalElements': data['totalElements'],
        'totalPages': data['totalPages'],
        'currentPage': data['number'],
      };
    } else {
      throw Exception('Erro ao buscar logs do usuário');
    }
  }

  static Future<Map<String, dynamic>> buscarLogsPorEntidade(String token, String entidade, int page, int size) async {
    final response = await http.get(
      Uri.parse('$baseUrl/entidade/$entidade?page=$page&size=$size'),
      headers: _getHeaders(token),
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return {
        'content': (data['content'] as List).map((item) => AuditoriaLog.fromJson(item)).toList(),
        'totalElements': data['totalElements'],
        'totalPages': data['totalPages'],
        'currentPage': data['number'],
      };
    } else {
      throw Exception('Erro ao buscar logs da entidade');
    }
  }

  static Future<List<AuditoriaLog>> buscarHistoricoEntidade(String token, String entidade, int entidadeId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/historico/$entidade/$entidadeId'),
      headers: _getHeaders(token),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((item) => AuditoriaLog.fromJson(item)).toList();
    } else {
      throw Exception('Erro ao buscar histórico da entidade');
    }
  }

  static Future<Map<String, dynamic>> buscarLogsPorOperacao(String token, String operacao, int page, int size) async {
    final response = await http.get(
      Uri.parse('$baseUrl/operacao/$operacao?page=$page&size=$size'),
      headers: _getHeaders(token),
    );

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return {
        'content': (data['content'] as List).map((item) => AuditoriaLog.fromJson(item)).toList(),
        'totalElements': data['totalElements'],
        'totalPages': data['totalPages'],
        'currentPage': data['number'],
      };
    } else {
      throw Exception('Erro ao buscar logs por operação');
    }
  }

  static Future<Map<String, dynamic>> buscarLogsComFiltros(String token,
      {String? usuario,
      String? entidade,
      String? operacao,
      int? entidadeId,
      DateTime? dataInicio,
      DateTime? dataFim,
      int page = 0,
      int size = 50,
      String sortBy = 'dataHora',
      String sortDir = 'desc'}) async {
    if ((usuario == null || usuario.isEmpty) &&
        (entidade == null || entidade.isEmpty) &&
        (operacao == null || operacao.isEmpty) &&
        entidadeId == null &&
        dataInicio == null &&
        dataFim == null) {
      return buscarTodosLogs(token, page, size, sortBy: sortBy, sortDir: sortDir);
    }

    final queryParams = <String, String>{
      'page': page.toString(),
      'size': size.toString(),
      'sortBy': sortBy,
      'sortDir': sortDir,
    };

    if (usuario != null && usuario.isNotEmpty) {
      queryParams['usuario'] = usuario;
    }
    if (entidade != null && entidade.isNotEmpty) {
      queryParams['entidade'] = entidade;
    }
    if (operacao != null && operacao.isNotEmpty) {
      queryParams['operacao'] = operacao;
    }
    if (entidadeId != null) {
      queryParams['entidadeId'] = entidadeId.toString();
    }
    if (dataInicio != null) {
      queryParams['dataInicio'] = dataInicio.toIso8601String();
    }
    if (dataFim != null) {
      queryParams['dataFim'] = dataFim.toIso8601String();
    }

    final uri = Uri.parse('$baseUrl/filtros').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _getHeaders(token));

    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      return {
        'content': (data['content'] as List).map((item) => AuditoriaLog.fromJson(item)).toList(),
        'totalElements': data['totalElements'],
        'totalPages': data['totalPages'],
        'currentPage': data['number'],
      };
    } else {
      throw Exception('Erro ao buscar logs com filtros');
    }
  }

  static Future<List<AuditoriaLog>> buscarAtividadesRecentes(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/recentes'),
      headers: _getHeaders(token),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.map((item) => AuditoriaLog.fromJson(item)).toList();
    } else {
      throw Exception('Erro ao buscar atividades recentes');
    }
  }

  static Future<Map<String, dynamic>> gerarRelatorioUsuario(String token, String usuario) async {
    final response = await http.get(
      Uri.parse('$baseUrl/relatorio/usuario/$usuario'),
      headers: _getHeaders(token),
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Erro ao gerar relatório do usuário');
    }
  }

  static Future<Map<String, dynamic>> gerarRelatorioGeral(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/relatorio/geral'),
      headers: _getHeaders(token),
    );

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Erro ao gerar relatório geral');
    }
  }

  static Future<List<String>> listarEntidadesAuditadas(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/entidades'),
      headers: _getHeaders(token),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.cast<String>();
    } else {
      throw Exception('Erro ao listar entidades auditadas');
    }
  }

  static Future<List<String>> listarUsuariosAtivos(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/usuarios'),
      headers: _getHeaders(token),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      return data.cast<String>();
    } else {
      throw Exception('Erro ao listar usuários ativos');
    }
  }

  static Future<List<DateTime>> buscarMesesDisponiveis(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/meses'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        final meses = data.map((item) => _parseMesAno(item.toString())).whereType<DateTime>().toList()..sort((a, b) => b.compareTo(a));

        return meses;
      }

      return await _buscarMesesDisponiveisPorPaginacao(token);
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao buscar meses disponíveis: $e');
      }
      return await _buscarMesesDisponiveisPorPaginacao(token);
    }
  }

  static DateTime? _parseMesAno(String valor) {
    final partes = valor.split('-');
    if (partes.length < 2) return null;

    final ano = int.tryParse(partes[0]);
    final mes = int.tryParse(partes[1]);
    if (ano == null || mes == null || mes < 1 || mes > 12) return null;

    return DateTime(ano, mes, 1);
  }

  static Future<List<DateTime>> _buscarMesesDisponiveisPorPaginacao(String token) async {
    const int pageSize = 200;
    const int maxPages = 200;
    final mesesUnicos = <DateTime>{};
    int page = 0;
    int totalPages = 1;

    while (page < totalPages && page < maxPages) {
      final response = await http.get(
        Uri.parse('$baseUrl?page=$page&size=$pageSize&sortBy=dataHora&sortDir=desc'),
        headers: _getHeaders(token),
      );

      if (response.statusCode != 200) {
        break;
      }

      final data = json.decode(utf8.decode(response.bodyBytes));
      final content = data['content'] as List<dynamic>? ?? [];

      for (final item in content) {
        final log = AuditoriaLog.fromJson(item);
        mesesUnicos.add(DateTime(log.dataHora.year, log.dataHora.month, 1));
      }

      totalPages = data['totalPages'] as int? ?? 0;
      if (totalPages == 0 || content.isEmpty) {
        break;
      }

      page++;
    }

    final mesesOrdenados = mesesUnicos.toList()..sort((a, b) => b.compareTo(a));
    return mesesOrdenados;
  }

  static Future<void> exportarRegistrosCSV(
    String token, {
    required String tipoFiltro,
    DateTime? dia,
    DateTime? dataInicio,
    DateTime? dataFim,
    int? ano,
    int? mes,
    String? usuario,
    String? entidade,
    String? operacao,
    int? entidadeId,
  }) async {
    final queryParams = <String, String>{};

    if (tipoFiltro == 'dia' && dia != null) {
      queryParams['dia'] = '${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';
    } else if (tipoFiltro == 'intervalo' && dataInicio != null && dataFim != null) {
      queryParams['dataInicio'] = dataInicio.toIso8601String();
      queryParams['dataFim'] = dataFim.toIso8601String();
    } else if (tipoFiltro == 'mes' && ano != null && mes != null) {
      queryParams['ano'] = ano.toString();
      queryParams['mes'] = mes.toString();
    }

    if (usuario != null && usuario.isNotEmpty) queryParams['usuario'] = usuario;
    if (entidade != null && entidade.isNotEmpty) queryParams['entidade'] = entidade;
    if (operacao != null && operacao.isNotEmpty) queryParams['operacao'] = operacao;
    if (entidadeId != null) queryParams['entidadeId'] = entidadeId.toString();

    final uri = Uri.parse('$baseUrl/exportar-csv').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _getHeaders(token));

    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;

      final blob = web.Blob([bytes.toJS].toJS);
      final url = web.URL.createObjectURL(blob);
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;

      String nomeArquivo = 'auditoria';
      if (tipoFiltro == 'dia' && dia != null) {
        nomeArquivo += '_${dia.year}-${dia.month.toString().padLeft(2, '0')}-${dia.day.toString().padLeft(2, '0')}';
      } else if (tipoFiltro == 'mes' && ano != null && mes != null) {
        nomeArquivo += '_${ano}_${mes.toString().padLeft(2, '0')}';
      } else {
        nomeArquivo += '_export';
      }
      anchor.download = '$nomeArquivo.csv';
      anchor.click();
      web.URL.revokeObjectURL(url);
    } else {
      throw Exception('Erro ao exportar registros para CSV');
    }
  }
}
