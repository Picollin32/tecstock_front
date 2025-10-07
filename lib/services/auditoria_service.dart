import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/auditoria_log.dart';

class AuditoriaService {
  static const String baseUrl = 'http://localhost:8081/api/auditoria';

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
        Uri.parse('$baseUrl?page=0&size=1&sortBy=dataHora&sortDir=desc'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final totalElements = data['totalElements'] as int;

        if (totalElements == 0) {
          return [];
        }

        final logRecente = AuditoriaLog.fromJson(data['content'][0]);

        final responseAntigo = await http.get(
          Uri.parse('$baseUrl?page=0&size=1&sortBy=dataHora&sortDir=asc'),
          headers: _getHeaders(token),
        );

        if (responseAntigo.statusCode == 200) {
          final dataAntiga = json.decode(utf8.decode(responseAntigo.bodyBytes));
          final logAntigo = AuditoriaLog.fromJson(dataAntiga['content'][0]);

          final meses = <DateTime>[];
          var mesAtual = DateTime(logAntigo.dataHora.year, logAntigo.dataHora.month, 1);
          final mesRecente = DateTime(logRecente.dataHora.year, logRecente.dataHora.month, 1);

          while (mesAtual.isBefore(mesRecente) || mesAtual.isAtSameMomentAs(mesRecente)) {
            meses.add(mesAtual);

            mesAtual = DateTime(mesAtual.year, mesAtual.month + 1, 1);
          }

          return meses.reversed.toList();
        }
      }

      return [];
    } catch (e) {
      print('Erro ao buscar meses disponíveis: $e');
      return [];
    }
  }
}
