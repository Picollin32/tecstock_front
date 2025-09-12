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
    try {
      final response = await http.get(Uri.parse('$baseUrl/buscar-por-status/$status'));
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        return jsonList.map((e) => OrdemServico.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Erro ao buscar ordens de serviço por status: $e');
      return [];
    }
  }
}
