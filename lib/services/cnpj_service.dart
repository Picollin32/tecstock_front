import 'dart:convert';
import 'package:http/http.dart' as http;

class CnpjResult {
  final String razaoSocial;
  final String nomeFantasia;
  final String email;
  final String telefone;
  final String cep;
  final String logradouro;
  final String numero;
  final String complemento;
  final String bairro;
  final String cidade;
  final String uf;
  final String codigoMunicipio;
  final String cnae;
  final String cnaeDescricao;

  final String regimeTributario;

  const CnpjResult({
    required this.razaoSocial,
    required this.nomeFantasia,
    required this.email,
    required this.telefone,
    required this.cep,
    required this.logradouro,
    required this.numero,
    required this.complemento,
    required this.bairro,
    required this.cidade,
    required this.uf,
    required this.codigoMunicipio,
    required this.cnae,
    required this.cnaeDescricao,
    required this.regimeTributario,
  });
}

class CnpjService {
  static Future<CnpjResult> buscar(String cnpj) async {
    final digits = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 14) throw Exception('CNPJ deve ter 14 dígitos');

    final uri = Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$digits');
    final response = await http.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode == 404) {
      throw Exception('CNPJ não encontrado na Receita Federal');
    }
    if (response.statusCode != 200) {
      throw Exception('Erro ao consultar CNPJ (${response.statusCode})');
    }

    final body = utf8.decode(response.bodyBytes);
    final data = jsonDecode(body) as Map<String, dynamic>;

    String s(String key) => (data[key] ?? '').toString().trim();

    final cnaeRaw = data['cnae_fiscal']?.toString() ?? '';
    final cnaeFormatado = _formatarCNAE(cnaeRaw);

    final cnaeDesc = s('cnae_fiscal_descricao');

    final cepRaw = s('cep').replaceAll(RegExp(r'[^0-9]'), '');

    final telRaw = s('ddd_telefone_1');

    String regimeTributario = '1';
    final optMei = data['opcao_pelo_mei'];
    if (optMei == true) {
      regimeTributario = '4';
    } else {
      final regimeList = data['regime_tributario'];
      if (regimeList is List && regimeList.isNotEmpty) {
        final maisRecente = regimeList.reduce((a, b) => ((a['ano'] ?? 0) as int) >= ((b['ano'] ?? 0) as int) ? a : b);
        final forma = (maisRecente['forma_de_tributacao'] ?? '').toString().toUpperCase();
        if (forma.contains('MEI')) {
          regimeTributario = '4';
        } else if (forma.contains('SIMPLES')) {
          regimeTributario = '1';
        } else if (forma.contains('PRESUMIDO')) {
          regimeTributario = '2';
        } else if (forma.contains('REAL')) {
          regimeTributario = '3';
        } else {
          regimeTributario = '3';
        }
      } else {
        final optSimples = data['opcao_pelo_simples'];
        if (optSimples == true) regimeTributario = '1';
      }
    }

    return CnpjResult(
      razaoSocial: s('razao_social'),
      nomeFantasia: s('nome_fantasia'),
      email: s('email').toLowerCase(),
      telefone: telRaw.replaceAll(RegExp(r'[^0-9]'), ''),
      cep: cepRaw,
      logradouro: s('logradouro'),
      numero: s('numero'),
      complemento: s('complemento'),
      bairro: s('bairro'),
      cidade: s('municipio'),
      uf: s('uf').toUpperCase(),
      codigoMunicipio: data['codigo_municipio_ibge']?.toString() ?? '',
      cnae: cnaeFormatado,
      cnaeDescricao: cnaeDesc,
      regimeTributario: regimeTributario,
    );
  }

  static String _formatarCNAE(String raw) {
    final d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length != 7) return '';
    return '${d.substring(0, 4)}-${d.substring(4, 5)}/${d.substring(5, 7)}';
  }
}
