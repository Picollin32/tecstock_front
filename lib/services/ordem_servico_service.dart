import 'dart:convert';
import 'package:TecStock/model/ordem_servico.dart';
import 'package:http/http.dart' as http;

class OrdemServicoService {
  static const String baseUrl = 'http://localhost:8081/api/ordens-servico';

  static Future<bool> salvarOrdemServico(OrdemServico ordemServico) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/salvar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(ordemServico.toJson()),
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Erro ao salvar ordem de serviço: $e');
      return false;
    }
  }

  static Future<OrdemServico?> buscarOrdemServicoPorId(int id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/buscar/$id'));
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
      final response = await http.get(Uri.parse('$baseUrl/listarTodos'));
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
      final response = await http.delete(Uri.parse('$baseUrl/deletar/$id'));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Erro ao excluir ordem de serviço: $e');
      return false;
    }
  }

  static Future<bool> atualizarOrdemServico(int id, OrdemServico ordemServico) async {
    try {
      print('Tentando atualizar OS $id...');
      print('JSON enviado: ${jsonEncode(ordemServico.toJson())}');

      final response = await http.put(
        Uri.parse('$baseUrl/atualizar/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(ordemServico.toJson()),
      );

      print('Resposta do servidor: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('Corpo da resposta de erro: ${response.body}');
      }

      return response.statusCode == 200;
    } catch (e) {
      print('Erro ao atualizar ordem de serviço: $e');
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
      print('Erro ao atualizar status da ordem de serviço: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> fecharOrdemServico(int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/$id/fechar'),
        headers: {'Content-Type': 'application/json'},
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

  static Future<List<OrdemServico>> buscarPorCliente(String cpf) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/buscar-por-cliente/$cpf'));
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
      final response = await http.get(Uri.parse('$baseUrl/buscar-por-veiculo/$placa'));
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
    print('🌐 Fazendo requisição para: $url');

    try {
      final response = await http.get(url);
      print('📡 Status da resposta: ${response.statusCode}');
      print(
          '📄 Corpo da resposta (primeiros 200 chars): ${response.body.length > 200 ? "${response.body.substring(0, 200)}..." : response.body}');

      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        print('📊 Dados decodificados: ${jsonList.length} ordens encontradas');
        List<OrdemServico> ordens = jsonList.map((e) => OrdemServico.fromJson(e)).toList();
        print('✅ Ordens convertidas com sucesso');
        return ordens;
      } else {
        print('❌ Erro HTTP: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Erro na requisição: $e');
      return [];
    }
  }

  static Future<int> buscarQuantidadePecaEmOSAbertas(String codigoPeca) async {
    try {
      final ordensAbertas = await buscarPorStatus('ABERTA');

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
      print('🔍 Buscando peças em OS abertas...');
      final ordensAbertas = await buscarPorStatus('ABERTA');
      print('📋 Encontradas ${ordensAbertas.length} ordens abertas');

      Map<String, Map<String, dynamic>> pecasInfo = {};

      for (final os in ordensAbertas) {
        print('📋 Processando OS ${os.numeroOS} com ${os.pecasUtilizadas.length} peças');
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

      print('📦 Total de peças diferentes em OS: ${pecasInfo.length}');
      return pecasInfo;
    } catch (e) {
      print('❌ Erro ao buscar peças em OS abertas: $e');
      return {};
    }
  }
}
