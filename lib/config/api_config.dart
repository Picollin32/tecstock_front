class ApiConfig {
  // Por padrão, usa localhost para desenvolvimento
  // Em produção, você deve definir a variável de ambiente API_BASE_URL no Dokploy
  static const String _defaultBaseUrl = 'http://localhost:8081';

  // Obtém a URL base da API
  static String get baseUrl {
    // Em Flutter Web, você pode usar const String.fromEnvironment
    // que é definida em tempo de compilação
    const apiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: _defaultBaseUrl);
    return apiUrl;
  }

  // URLs completas para os diferentes endpoints
  static String get authUrl => '$baseUrl/api/auth';
  static String get agendamentosUrl => '$baseUrl/api/agendamentos';
  static String get auditoriaUrl => '$baseUrl/api/auditoria';
  static String get checklistUrl => '$baseUrl/api/checklists';
  static String get clientesUrl => '$baseUrl/api/clientes';
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
}
