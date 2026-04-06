import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    const apiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (apiUrl.isNotEmpty) {
      return apiUrl;
    }

    final fallbackBaseUrl = kReleaseMode ? 'https://tecstock.app' : 'http://localhost:8081';
    return fallbackBaseUrl;
  }

  static String get authUrl => '$baseUrl/api/auth';
  static String get agendamentosUrl => '$baseUrl/api/agendamentos';
  static String get auditoriaUrl => '$baseUrl/api/auditoria';
  static String get checklistUrl => '$baseUrl/api/checklists';
  static String get clientesUrl => '$baseUrl/api/clientes';
  static String get empresasUrl => '$baseUrl/api/empresas';
  static String get fabricantesUrl => '$baseUrl/api/fabricantes';
  static String get fornecedoresUrl => '$baseUrl/api/fornecedores';
  static String get funcionariosUrl => '$baseUrl/api/funcionarios';
  static String get marcasUrl => '$baseUrl/api/marcas';
  static String get movimentacoesUrl => '$baseUrl/api/movimentacoes';
  static String get orcamentosUrl => '$baseUrl/api/orcamentos';
  static String get ordensServicoUrl => '$baseUrl/api/ordens-servico';
  static String get pecasUrl => '$baseUrl/api/pecas';
  static String get relatoriosUrl => '$baseUrl/api/relatorios';
  static String get servicosUrl => '$baseUrl/api/servicos';
  static String get tiposPagamentoUrl => '$baseUrl/api/tipos-pagamento';
  static String get usuariosUrl => '$baseUrl/api/usuarios';
  static String get veiculosUrl => '$baseUrl/api/veiculos';
  static String get contasUrl => '$baseUrl/api/contas';
  static String get categoriasFinanceirasUrl => '$baseUrl/api/categorias-financeiras';
}
