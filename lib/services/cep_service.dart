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

    String codigoIbge = '';
    if (data.containsKey('city_ibge_code')) {
      codigoIbge = data['city_ibge_code']?.toString() ?? '';
    } else if (data.containsKey('ibge')) {
      codigoIbge = data['ibge']?.toString() ?? '';
    } else if (data.containsKey('city') && data['city'] is Map && data['city'].containsKey('ibge')) {
      codigoIbge = data['city']['ibge']?.toString() ?? '';
    }

    if (codigoIbge.isEmpty) {
      try {
        final viaCepUri = Uri.parse('https://viacep.com.br/ws/$digits/json/');
        final viaResp = await http.get(viaCepUri).timeout(const Duration(seconds: 8));
        if (viaResp.statusCode == 200) {
          final viaData = jsonDecode(utf8.decode(viaResp.bodyBytes)) as Map<String, dynamic>;
          if (viaData.containsKey('ibge')) {
            codigoIbge = viaData['ibge']?.toString() ?? '';
          }
        }
      } catch (_) {}

      if (codigoIbge.isEmpty) {
        try {
          final state = data['state']?.toString() ?? '';
          final city = data['city']?.toString() ?? '';
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
      cidade: data['city'] as String? ?? '',
      uf: data['state'] as String? ?? '',
      codigoIBGE: codigoIbge,
    );
  }
}
