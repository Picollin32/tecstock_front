import 'dart:convert';
import 'package:TecStock/model/ordem_servico.dart';
import 'package:TecStock/services/auth_service.dart';
import 'package:http/http.dart' as http;

class OrdemServicoService {
  static const String baseUrl = 'http://localhost:8081/api/ordens-servico';

  static Future<Map<String, dynamic>> salvarOrdemServico(OrdemServico ordemServico) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/salvar'),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(ordemServico.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'sucesso': true, 'mensagem': 'OS salva com sucesso'};
      } else {
        String errorMessage = 'Erro ao salvar ordem de serviço';
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // Se não conseguir decodificar, usa a mensagem padrão
        }
        return {'sucesso': false, 'mensagem': errorMessage};
      }
    } catch (e) {
      print('Erro ao salvar ordem de serviço: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<OrdemServico?> buscarOrdemServicoPorId(int id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/buscar/$id'), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        return OrdemServico.fromJson(jsonData);
      }
      return null;
    } catch (e) {
      print('Erro ao buscar ordem de serviço: $e');
      return null;
    }
  }

  static Future<List<OrdemServico>> listarOrdensServico() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/listarTodos'), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => OrdemServico.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao listar ordens de serviço: $e');
      return [];
    }
  }

  static Future<bool> excluirOrdemServico(int id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/deletar/$id'), headers: await AuthService.getAuthHeaders());
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Erro ao excluir ordem de serviço: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> atualizarOrdemServico(int id, OrdemServico ordemServico) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/atualizar/$id'),
        headers: await AuthService.getAuthHeaders(),
        body: jsonEncode(ordemServico.toJson()),
      );

      if (response.statusCode == 200) {
        return {'sucesso': true, 'mensagem': 'OS atualizada com sucesso'};
      } else {
        String errorMessage = 'Erro ao atualizar ordem de serviço';
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorData['message'] != null) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // Se não conseguir decodificar, usa a mensagem padrão
        }
        return {'sucesso': false, 'mensagem': errorMessage};
      }
    } catch (e) {
      print('Erro ao atualizar ordem de serviço: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
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
      print('Erro ao atualizar status da ordem de serviço: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> fecharOrdemServico(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$id/fechar'),
        headers: await AuthService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': true, 'mensagem': 'Ordem de serviço encerrada com sucesso', 'ordemServico': OrdemServico.fromJson(jsonData)};
      } else {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': false, 'mensagem': errorData['message'] ?? 'Erro ao fechar ordem de serviço'};
      }
    } catch (e) {
      print('Erro ao fechar ordem de serviço: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<Map<String, dynamic>> reabrirOrdemServico(int id) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/$id/reabrir'),
        headers: await AuthService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        return {'sucesso': true, 'mensagem': 'Ordem de serviço reaberta com sucesso', 'ordemServico': OrdemServico.fromJson(jsonData)};
      } else {
        String errorMessage = 'Erro ao reabrir ordem de serviço';
        try {
          if (response.body.isNotEmpty) {
            errorMessage = response.body;
          }
        } catch (e) {}
        return {'sucesso': false, 'mensagem': errorMessage};
      }
    } catch (e) {
      print('Erro ao reabrir ordem de serviço: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }

  static Future<List<OrdemServico>> buscarPorCliente(String cpf) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/buscar-por-cliente/$cpf'), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => OrdemServico.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao buscar ordens de serviço por cliente: $e');
      return [];
    }
  }

  static Future<List<OrdemServico>> buscarPorVeiculo(String placa) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/buscar-por-veiculo/$placa'), headers: await AuthService.getAuthHeaders());
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => OrdemServico.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao buscar ordens de serviço por veículo: $e');
      return [];
    }
  }

  static Future<List<OrdemServico>> buscarPorStatus(String status) async {
    final url = Uri.parse('$baseUrl/status/$status');

    try {
      final response = await http.get(url, headers: await AuthService.getAuthHeaders());

      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        List<OrdemServico> ordens = jsonList.map((e) => OrdemServico.fromJson(e)).toList();
        return ordens;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  static Future<int> buscarQuantidadePecaEmOSAbertas(String codigoPeca) async {
    try {
      final ordensAbertas = await buscarPorStatus('Aberta');

      double quantidadeTotal = 0;

      for (final os in ordensAbertas) {
        for (final pecaOS in os.pecasUtilizadas) {
          if (pecaOS.peca.codigoFabricante == codigoPeca) {
            quantidadeTotal += pecaOS.quantidade;
          }
        }
      }

      return quantidadeTotal.round();
    } catch (e) {
      print('Erro ao buscar quantidade de peça em OS abertas: $e');
      return 0;
    }
  }

  static Future<Map<String, Map<String, dynamic>>> buscarPecasEmOSAbertas() async {
    try {
      final ordensAbertas = await buscarPorStatus('Aberta');

      Map<String, Map<String, dynamic>> pecasInfo = {};

      for (final os in ordensAbertas) {
        for (final pecaOS in os.pecasUtilizadas) {
          final codigo = pecaOS.peca.codigoFabricante;

          if (!pecasInfo.containsKey(codigo)) {
            pecasInfo[codigo] = {
              'nome': pecaOS.peca.nome,
              'quantidade': 0,
              'ordens': <String>[],
            };
          }

          pecasInfo[codigo]!['quantidade'] = (pecasInfo[codigo]!['quantidade'] as num) + pecaOS.quantidade;

          if (!pecasInfo[codigo]!['ordens'].contains(os.numeroOS)) {
            pecasInfo[codigo]!['ordens'].add(os.numeroOS);
          }
        }
      }

      return pecasInfo;
    } catch (e) {
      print('Erro ao buscar peças em OS abertas: $e');
      return {};
    }
  }

  static Future<Map<int, Map<String, dynamic>>> buscarServicosEmOSAbertas() async {
    try {
      final ordensAbertas = await buscarPorStatus('Aberta');

      Map<int, Map<String, dynamic>> servicosInfo = {};

      for (final os in ordensAbertas) {
        if (os.servicosRealizados.isEmpty) {
          continue;
        }

        for (final servico in os.servicosRealizados) {
          if (servico.id == null) {
            continue;
          }

          final servicoId = servico.id!;

          if (!servicosInfo.containsKey(servicoId)) {
            servicosInfo[servicoId] = {
              'nome': servico.nome,
              'quantidade': 0,
              'ordens': <String>[],
            };
          }

          servicosInfo[servicoId]!['quantidade'] = (servicosInfo[servicoId]!['quantidade'] as num) + 1;

          if (!servicosInfo[servicoId]!['ordens'].contains(os.numeroOS)) {
            servicosInfo[servicoId]!['ordens'].add(os.numeroOS);
          }
        }
      }

      return servicosInfo;
    } catch (e) {
      print('Erro ao buscar serviços em OS abertas: $e');
      return {};
    }
  }

  Future<List<OrdemServico>> getFiadosEmAberto() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/fiados-em-aberto'),
        headers: await AuthService.getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => OrdemServico.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao buscar fiados em aberto: $e');
      throw Exception('Erro ao buscar fiados em aberto: $e');
    }
  }

  Future<bool> marcarFiadoComoPago(int id, bool pago) async {
    try {
      final headers = await AuthService.getAuthHeaders();
      headers['Content-Type'] = 'application/json';

      final response = await http.patch(
        Uri.parse('$baseUrl/$id/fiado-pago?pago=$pago'),
        headers: headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao marcar fiado como pago: $e');
      throw Exception('Erro ao marcar fiado como pago: $e');
    }
  }

  static Future<Map<String, dynamic>> desbloquearOS(int id) async {
    try {
      final nivelAcesso = await AuthService.getNivelAcesso();
      final headers = await AuthService.getAuthHeaders();
      headers['X-User-Level'] = nivelAcesso?.toString() ?? '1';

      final response = await http.post(
        Uri.parse('$baseUrl/$id/desbloquear'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'sucesso': true, 'mensagem': 'OS desbloqueada com sucesso'};
      } else if (response.statusCode == 403) {
        return {'sucesso': false, 'mensagem': 'Acesso negado. Apenas administradores podem desbloquear OSs.'};
      } else {
        return {'sucesso': false, 'mensagem': 'Erro ao desbloquear OS'};
      }
    } catch (e) {
      print('Erro ao desbloquear OS: $e');
      return {'sucesso': false, 'mensagem': 'Erro de conexão: $e'};
    }
  }
}
