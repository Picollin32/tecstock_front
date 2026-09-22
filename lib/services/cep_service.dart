import 'dart:convert';
import 'package:http/http.dart' as http;

class CepResult {
  final String logradouro;
  final String complemento;
  final String bairro;
  final String cidade;
  final String uf;
  final String codigoIBGE;

  const CepResult({
    required this.logradouro,
    required this.complemento,
    required this.bairro,
    required this.cidade,
    required this.uf,
    required this.codigoIBGE,
  });
}

class CepService {
  static Future<CepResult> buscar(String cep) async {
    final digits = cep.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 8) throw Exception('CEP deve ter 8 dígitos');

    final uri = Uri.parse('https://brasilapi.com.br/api/cep/v2/$digits');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) {
      throw Exception('CEP não encontrado');
    }
    if (response.statusCode != 200) {
      throw Exception('Erro ao consultar CEP (${response.statusCode})');
    }

    final body = utf8.decode(response.bodyBytes);
    final data = jsonDecode(body) as Map<String, dynamic>;

    String codigoIbge = _extrairCodigoIbge(data['city_ibge_code']);
    if (codigoIbge.isEmpty) codigoIbge = _extrairCodigoIbge(data['ibge']);
    if (codigoIbge.isEmpty && data['city'] is Map) {
      codigoIbge = _extrairCodigoIbge(data['city']['ibge'] ?? data['city']['city']);
    }

    if (codigoIbge.isEmpty) {
      try {
        final viaCepUri = Uri.parse('https://viacep.com.br/ws/$digits/json/');
        final viaResp = await http.get(viaCepUri).timeout(const Duration(seconds: 8));
        if (viaResp.statusCode == 200) {
          final viaData = jsonDecode(utf8.decode(viaResp.bodyBytes)) as Map<String, dynamic>;
          codigoIbge = _extrairCodigoIbge(viaData['ibge']);
        }
      } catch (_) {}

      if (codigoIbge.isEmpty) {
        try {
          final state = data['state']?.toString() ?? '';
          final cityValue = data['city'];
          final city =
              cityValue is Map ? cityValue['name']?.toString() ?? cityValue['city']?.toString() ?? '' : cityValue?.toString() ?? '';
          if (state.isNotEmpty && city.isNotEmpty) {
            final ibgeUri = Uri.parse('https://servicodados.ibge.gov.br/api/v1/localidades/estados/$state/municipios');
            final ibgeResp = await http.get(ibgeUri).timeout(const Duration(seconds: 8));
            if (ibgeResp.statusCode == 200) {
              final List<dynamic> municipios = jsonDecode(utf8.decode(ibgeResp.bodyBytes)) as List<dynamic>;
              final match = municipios.firstWhere(
                  (m) => (m is Map<String, dynamic> && (m['nome'] as String).toLowerCase() == city.toLowerCase()),
                  orElse: () => null);
              if (match != null && match is Map<String, dynamic> && match.containsKey('id')) {
                codigoIbge = match['id'].toString();
              }
            }
          }
        } catch (_) {}
      }
    }

    return CepResult(
      logradouro: data['street'] as String? ?? '',
      complemento: data['complement'] as String? ?? '',
      bairro: data['neighborhood'] as String? ?? '',
      cidade: data['city'] is Map
          ? (data['city']['name']?.toString() ?? data['city']['city']?.toString() ?? '')
          : data['city']?.toString() ?? '',
      uf: data['state'] as String? ?? '',
      codigoIBGE: codigoIbge,
    );
  }

  static String _extrairCodigoIbge(dynamic value) {
    if (value is Map) {
      return _extrairCodigoIbge(value['city'] ?? value['ibge'] ?? value['code']);
    }
    return value?.toString() ?? '';
  }
}
