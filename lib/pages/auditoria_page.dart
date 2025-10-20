import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../model/auditoria_log.dart';
import '../services/auditoria_service.dart';
import '../services/auth_service.dart';
import 'dart:convert';

class AuditoriaPage extends StatefulWidget {
  const AuditoriaPage({super.key});

  @override
  State<AuditoriaPage> createState() => _AuditoriaPageState();
}

class _AuditoriaPageState extends State<AuditoriaPage> with TickerProviderStateMixin {
  List<AuditoriaLog> logs = [];
  List<String> entidadesDisponiveis = [];
  List<String> usuariosDisponiveis = [];
  Set<String> entidadesSelecionadas = {};
  bool isLoading = true;
  String? token;
  String? filtroUsuario;
  String? filtroOperacao;
  TextEditingController filtroIdController = TextEditingController();
  DateTime? mesSelecionado;
  List<DateTime> mesesDisponiveis = [];
  List<DateTime> todosMeses = [];
  String ordenarPor = 'dataHora';
  String direcaoOrdenacao = 'desc';
  bool filtrosExpandidos = false;
  int currentPage = 0;
  int totalPages = 0;
  int totalElements = 0;
  final int pageSize = 50;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const Color shadowColor = Color(0x1A000000);

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    mesSelecionado = DateTime(agora.year, agora.month, 1);

    _gerarListaMeses();

    _initializeAnimations();
    _carregarDados();
  }

  void _gerarListaMeses() {
    final agora = DateTime.now();
    todosMeses.clear();

    for (int i = 0; i < 12; i++) {
      final mes = DateTime(agora.year, agora.month - i, 1);
      todosMeses.add(mes);
    }
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    filtroIdController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => isLoading = true);

    try {
      token = await AuthService.getToken();

      if (token == null || token!.isEmpty) {
        if (mounted) {
          _mostrarErro('Token não encontrado. Faça login novamente.');
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      entidadesDisponiveis = await AuditoriaService.listarEntidadesAuditadas(token!);
      usuariosDisponiveis = await AuditoriaService.listarUsuariosAtivos(token!);

      await _carregarMesesDisponiveis();

      await _buscarLogs();
    } catch (e) {
      if (mounted) {
        _mostrarErro('Erro ao carregar dados: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _buscarLogs() async {
    if (token == null) return;

    try {
      final entidadeId = filtroIdController.text.isEmpty ? null : int.tryParse(filtroIdController.text);

      DateTime? dataInicio;
      DateTime? dataFim;

      if (mesSelecionado != null) {
        dataInicio = DateTime(mesSelecionado!.year, mesSelecionado!.month, 1);
        dataFim = DateTime(mesSelecionado!.year, mesSelecionado!.month + 1, 0, 23, 59, 59);
      }

      final resultado = await AuditoriaService.buscarLogsComFiltros(
        token!,
        usuario: filtroUsuario,
        entidade: entidadesSelecionadas.isEmpty ? null : entidadesSelecionadas.join(','),
        operacao: filtroOperacao,
        entidadeId: entidadeId,
        dataInicio: dataInicio,
        dataFim: dataFim,
        page: currentPage,
        size: pageSize,
        sortBy: ordenarPor,
        sortDir: direcaoOrdenacao,
      );

      if (mounted) {
        setState(() {
          logs = resultado['content'] as List<AuditoriaLog>;
          totalElements = resultado['totalElements'];
          totalPages = resultado['totalPages'];
        });
      }
    } catch (e) {
      if (mounted) {
        _mostrarErro('Erro ao buscar logs: $e');
      }
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _carregarMesesDisponiveis() async {
    if (token == null) return;

    try {
      final meses = await AuditoriaService.buscarMesesDisponiveis(token!);
      if (mounted) {
        setState(() {
          mesesDisponiveis = meses;
        });
      }
    } catch (e) {
      print('Erro ao carregar meses disponíveis: $e');
    }
  }

  void _limparFiltros() {
    setState(() {
      filtroUsuario = null;
      entidadesSelecionadas.clear();
      filtroOperacao = null;
      filtroIdController.clear();
      currentPage = 0;
    });
    _buscarLogs();
  }

  void _aplicarFiltros() {
    setState(() {
      currentPage = 0;
      filtrosExpandidos = false;
    });
    _buscarLogs();
  }

  void _proximaPagina() {
    if (currentPage < totalPages - 1) {
      setState(() => currentPage++);
      _buscarLogs();
    }
  }

  void _paginaAnterior() {
    if (currentPage > 0) {
      setState(() => currentPage--);
      _buscarLogs();
    }
  }

  void _mostrarDetalhesLog(AuditoriaLog log) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getOperacaoColor(log.operacao).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getOperacaoIcon(log.operacao),
                        color: _getOperacaoColor(log.operacao),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Log #${log.id}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getOperacaoColor(log.operacao).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              log.operacaoFormatada,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getOperacaoColor(log.operacao),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                _buildDetalheItem('Usuário', log.usuario, Icons.person),
                _buildDetalheItem('Entidade', log.entidade, Icons.category),
                _buildDetalheItem('ID Entidade', log.entidadeId.toString(), Icons.tag),
                _buildDetalheItem('Data/Hora', log.dataHoraFormatada, Icons.schedule),
                const SizedBox(height: 16),
                const Text(
                  'Descrição',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    log.descricao,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      height: 1.5,
                    ),
                  ),
                ),
                if (log.operacao == 'UPDATE' && log.valoresAntigos != null && log.valoresNovos != null) ...[
                  _buildComparacaoAlteracoes(log.valoresAntigos!, log.valoresNovos!),
                ] else ...[
                  if (log.valoresAntigos != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Valores Antigos',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          _formatarJson(log.valoresAntigos!),
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Color(0xFF7F1D1D),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (log.valoresNovos != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Valores Novos',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          _formatarJson(log.valoresNovos!),
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Color(0xFF14532D),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Fechar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComparacaoAlteracoes(String valoresAntigosJson, String valoresNovosJson) {
    try {
      final Map<String, dynamic> antigos = json.decode(valoresAntigosJson);
      final Map<String, dynamic> novos = json.decode(valoresNovosJson);

      final alteracoes = _compararValores(antigos, novos);

      if (alteracoes.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF0369A1), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nenhuma alteração significativa detectada (apenas campos de auditoria foram modificados)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.compare_arrows, color: Color(0xFF92400E), size: 20),
                const SizedBox(width: 8),
                Text(
                  '${alteracoes.length} ${alteracoes.length == 1 ? 'campo alterado' : 'campos alterados'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...alteracoes.map((alt) => _buildItemAlteracao(alt)),
        ],
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  List<Map<String, dynamic>> _compararValores(Map<String, dynamic> antigos, Map<String, dynamic> novos) {
    final List<Map<String, dynamic>> alteracoes = [];
    final todasChaves = {...antigos.keys, ...novos.keys};

    for (final chave in todasChaves) {
      final valorAntigo = antigos[chave];
      final valorNovo = novos[chave];

      if (_isCampoAuditoria(chave)) {
        continue;
      }

      if (!antigos.containsKey(chave)) {
        alteracoes.add({
          'campo': chave,
          'tipo': 'adicionado',
          'valorNovo': valorNovo,
        });
      } else if (!novos.containsKey(chave)) {
        alteracoes.add({
          'campo': chave,
          'tipo': 'removido',
          'valorAntigo': valorAntigo,
        });
      } else if (_valoresDiferentes(valorAntigo, valorNovo)) {
        alteracoes.add({
          'campo': chave,
          'tipo': 'alterado',
          'valorAntigo': valorAntigo,
          'valorNovo': valorNovo,
        });
      }
    }

    return alteracoes;
  }

  bool _isCampoAuditoria(String campo) {
    final camposIgnorados = [
      'datacriacao',
      'dataatualizacao',
      'criadopor',
      'atualizadopor',
      'versao',
    ];
    final campoNormalizado = campo.toLowerCase().replaceAll('_', '');
    return camposIgnorados.contains(campoNormalizado);
  }

  bool _valoresDiferentes(dynamic v1, dynamic v2) {
    if (v1 == null && v2 == null) return false;
    if (v1 == null || v2 == null) return true;

    if (v1 is Map && v2 is Map) {
      if (v1.length != v2.length) return true;
      for (final key in v1.keys) {
        if (!v2.containsKey(key) || _valoresDiferentes(v1[key], v2[key])) {
          return true;
        }
      }
      return false;
    }

    if (v1 is List && v2 is List) {
      if (v1.length != v2.length) return true;
      for (int i = 0; i < v1.length; i++) {
        if (_valoresDiferentes(v1[i], v2[i])) return true;
      }
      return false;
    }

    return v1.toString() != v2.toString();
  }

  Widget _buildItemAlteracao(Map<String, dynamic> alteracao) {
    final campo = alteracao['campo'] as String;
    final tipo = alteracao['tipo'] as String;
    final campoFormatado = _formatarNomeCampo(campo);

    final bool isCampoPreco = campo.toLowerCase().contains('preco') || campo.toLowerCase().contains('valor');

    Color corFundo;
    Color corBorda;
    Color corTexto;
    IconData icone;
    String titulo;

    switch (tipo) {
      case 'adicionado':
        corFundo = const Color(0xFFF0FDF4);
        corBorda = const Color(0xFFBBF7D0);
        corTexto = const Color(0xFF166534);
        icone = Icons.add_circle_outline;
        titulo = 'Adicionado';
        break;
      case 'removido':
        corFundo = const Color(0xFFFEF2F2);
        corBorda = const Color(0xFFFECACA);
        corTexto = const Color(0xFF991B1B);
        icone = Icons.remove_circle_outline;
        titulo = 'Removido';
        break;
      default:
        if (isCampoPreco) {
          corFundo = const Color(0xFFF3E8FF);
          corBorda = const Color(0xFFD8B4FE);
          corTexto = const Color(0xFF6B21A8);
          icone = Icons.monetization_on_outlined;
          titulo = 'Preço Alterado';
        } else {
          corFundo = const Color(0xFFFEF3C7);
          corBorda = const Color(0xFFFDE68A);
          corTexto = const Color(0xFF92400E);
          icone = Icons.edit_outlined;
          titulo = 'Alterado';
        }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: corBorda, width: isCampoPreco ? 2.0 : 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 18, color: corTexto),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  campoFormatado,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: corTexto,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: corTexto,
                  ),
                ),
              ),
            ],
          ),
          if (tipo == 'alterado') ...[
            const SizedBox(height: 10),
            _buildValorComparacao(
              'Valor Antigo',
              alteracao['valorAntigo'],
              campo,
              const Color(0xFFDC2626),
              Icons.remove_circle_outline,
            ),
            const SizedBox(height: 8),
            Center(
              child: Icon(Icons.arrow_downward, size: 20, color: corTexto.withOpacity(0.5)),
            ),
            const SizedBox(height: 8),
            _buildValorComparacao(
              'Valor Novo',
              alteracao['valorNovo'],
              campo,
              const Color(0xFF16A34A),
              Icons.add_circle_outline,
            ),
          ] else if (tipo == 'adicionado') ...[
            const SizedBox(height: 10),
            _buildValorComparacao(
              'Valor',
              alteracao['valorNovo'],
              campo,
              const Color(0xFF16A34A),
              Icons.add_circle_outline,
            ),
          ] else if (tipo == 'removido') ...[
            const SizedBox(height: 10),
            _buildValorComparacao(
              'Valor',
              alteracao['valorAntigo'],
              campo,
              const Color(0xFFDC2626),
              Icons.remove_circle_outline,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildValorComparacao(String label, dynamic valor, String nomeCampo, Color cor, IconData icone) {
    String valorFormatado;

    if (valor == null) {
      valorFormatado = '(vazio)';
    } else if (_isCampoData(nomeCampo) && valor is int) {
      valorFormatado = _formatarTimestamp(valor);
    } else if (valor is bool) {
      valorFormatado = valor ? 'Sim' : 'Não';
    } else if (valor is Map || valor is List) {
      valorFormatado = const JsonEncoder.withIndent('  ').convert(valor);
    } else {
      valorFormatado = valor.toString();
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 14, color: cor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valorFormatado,
                  style: TextStyle(
                    fontSize: 13,
                    color: cor.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                    fontFamily: valorFormatado.contains('{') || valorFormatado.contains('[') ? 'monospace' : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatarNomeCampo(String campo) {
    final palavras = campo.split(RegExp(r'[_\s]'));
    final formatadas = palavras.map((p) {
      if (p.isEmpty) return '';
      return p[0].toUpperCase() + p.substring(1).toLowerCase();
    });

    String resultado = formatadas.join(' ');

    final traducoes = {
      'Nome': 'Nome',
      'Email': 'E-mail',
      'Telefone': 'Telefone',
      'Cpf': 'CPF',
      'Cnpj': 'CNPJ',
      'Endereco': 'Endereço',
      'Numero': 'Número',
      'Cep': 'CEP',
      'Cidade': 'Cidade',
      'Estado': 'Estado',
      'Pais': 'País',
      'Datanascimento': 'Data de Nascimento',
      'Datacriacao': 'Data de Criação',
      'Dataatualizacao': 'Data de Atualização',
      'Preco': 'Preço',
      'Quantidade': 'Quantidade',
      'Descricao': 'Descrição',
      'Ativo': 'Ativo',
      'Status': 'Status',
    };

    final campoNormalizado = campo.toLowerCase().replaceAll('_', '');
    for (final entry in traducoes.entries) {
      if (campoNormalizado == entry.key.toLowerCase()) {
        return entry.value;
      }
    }

    return resultado;
  }

  Widget _buildDetalheItem(String label, String valor, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatarJson(String jsonString) {
    try {
      final obj = json.decode(jsonString);
      final jsonFormatado = _processarObjeto(obj);
      return const JsonEncoder.withIndent('  ').convert(jsonFormatado);
    } catch (e) {
      return jsonString;
    }
  }

  dynamic _processarObjeto(dynamic obj) {
    if (obj is Map) {
      final Map<String, dynamic> resultado = {};
      obj.forEach((key, value) {
        if (_isCampoData(key) && value is int) {
          resultado[key] = '${_formatarTimestamp(value)} (ts: $value)';
        } else if (value is Map || value is List) {
          resultado[key] = _processarObjeto(value);
        } else {
          resultado[key] = value;
        }
      });
      return resultado;
    } else if (obj is List) {
      return obj.map((item) => _processarObjeto(item)).toList();
    }
    return obj;
  }

  bool _isCampoData(String campo) {
    final camposData = [
      'datanascimento',
      'datacriacao',
      'dataatualizacao',
      'datacompra',
      'datavenda',
      'dataentrada',
      'datasaida',
      'dataagendamento',
      'datarealizacao',
      'data',
      'datainicio',
      'datafim',
      'datavalidade',
      'datavencimento',
      'dataemissao',
      'datacadastro',
      'dataexclusao',
      'dataultimaatualizacao',
      'dataultimoacesso',
      'dataregistro',
      'dataentrega',
      'datapagamento',
      'datarecebimento',
      'dataprevistaentrega',
      'dataprevistainicio',
      'dataprevistafim'
    ];
    final campoNormalizado = campo.toLowerCase().replaceAll('_', '');
    return camposData.contains(campoNormalizado);
  }

  String _formatarTimestamp(int timestamp) {
    try {
      final data = DateTime.fromMillisecondsSinceEpoch(timestamp);

      if (data.hour == 0 && data.minute == 0 && data.second == 0) {
        return '${data.day.toString().padLeft(2, '0')}/'
            '${data.month.toString().padLeft(2, '0')}/'
            '${data.year}';
      }

      return '${data.day.toString().padLeft(2, '0')}/'
          '${data.month.toString().padLeft(2, '0')}/'
          '${data.year} ${data.hour.toString().padLeft(2, '0')}:'
          '${data.minute.toString().padLeft(2, '0')}:'
          '${data.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp.toString();
    }
  }

  Color _getOperacaoColor(String operacao) {
    switch (operacao) {
      case 'CREATE':
        return Colors.green;
      case 'UPDATE':
        return Colors.orange;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getOperacaoIcon(String operacao) {
    switch (operacao) {
      case 'CREATE':
        return Icons.add_circle;
      case 'UPDATE':
        return Icons.edit;
      case 'DELETE':
        return Icons.delete;
      default:
        return Icons.info;
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (KeyEvent event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (_podeIrParaMesAnterior()) {
              _irParaMesAnterior();
            }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (_podeIrParaProximoMes()) {
              _irParaProximoMes();
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          automaticallyImplyLeading: false,
          title: const Text(
            'Auditoria do Sistema',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              color: const Color(0xFFE2E8F0),
              height: 1,
            ),
          ),
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildSeletorMes(),
                          _buildFiltros(),
                          if (logs.isNotEmpty)
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: _buildListaLogs(),
                            )
                          else
                            SizedBox(
                              height: 300,
                              child: _buildListaLogs(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (totalPages > 0) _buildPaginacao(),
                ],
              ),
      ),
    );
  }

  Widget _buildSeletorMes() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.calendar_month,
              color: Color(0xFF0EA5E9),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Período:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            iconSize: 24,
            color: _podeIrParaMesAnterior() ? const Color(0xFF0EA5E9) : const Color(0xFFCBD5E1),
            onPressed: _podeIrParaMesAnterior() ? _irParaMesAnterior : null,
            tooltip: _podeIrParaMesAnterior() ? 'Mês anterior (←)' : 'Não há meses anteriores com logs',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: todosMeses.map((mes) {
                  final isSelected = mesSelecionado?.year == mes.year && mesSelecionado?.month == mes.month;
                  final temLogs = _mesTemLogs(mes);
                  final mesNome = _getNomeMes(mes);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!temLogs) ...[
                            Icon(
                              Icons.block,
                              size: 14,
                              color: const Color(0xFFCBD5E1),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(mesNome),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: temLogs
                          ? (selected) {
                              if (selected) {
                                setState(() {
                                  mesSelecionado = mes;
                                  currentPage = 0;
                                });
                                _buscarLogs();
                              }
                            }
                          : null,
                      selectedColor: const Color(0xFF0EA5E9),
                      backgroundColor: temLogs ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
                      disabledColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : temLogs
                                ? const Color(0xFF64748B)
                                : const Color(0xFFCBD5E1),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF0EA5E9)
                              : temLogs
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFFE2E8F0).withOpacity(0.5),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            iconSize: 24,
            color: _podeIrParaProximoMes() ? const Color(0xFF0EA5E9) : const Color(0xFFCBD5E1),
            onPressed: _podeIrParaProximoMes() ? _irParaProximoMes : null,
            tooltip: _podeIrParaProximoMes() ? 'Próximo mês (→)' : 'Não há próximos meses com logs',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),
        ],
      ),
    );
  }

  String _getNomeMes(DateTime data) {
    final meses = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];

    final agora = DateTime.now();
    final mesAtual = DateTime(agora.year, agora.month, 1);

    if (data.year == mesAtual.year && data.month == mesAtual.month) {
      return '${meses[data.month - 1]} ${data.year} (Atual)';
    }

    return '${meses[data.month - 1]} ${data.year}';
  }

  bool _mesTemLogs(DateTime mes) {
    return mesesDisponiveis.any((m) => m.year == mes.year && m.month == mes.month);
  }

  bool _podeIrParaMesAnterior() {
    if (mesSelecionado == null) return false;

    for (int i = 0; i < todosMeses.length - 1; i++) {
      if (todosMeses[i].year == mesSelecionado!.year && todosMeses[i].month == mesSelecionado!.month) {
        for (int j = i + 1; j < todosMeses.length; j++) {
          if (_mesTemLogs(todosMeses[j])) {
            return true;
          }
        }
        return false;
      }
    }
    return false;
  }

  bool _podeIrParaProximoMes() {
    if (mesSelecionado == null) return false;

    for (int i = 1; i < todosMeses.length; i++) {
      if (todosMeses[i].year == mesSelecionado!.year && todosMeses[i].month == mesSelecionado!.month) {
        for (int j = i - 1; j >= 0; j--) {
          if (_mesTemLogs(todosMeses[j])) {
            return true;
          }
        }
        return false;
      }
    }
    return false;
  }

  void _irParaMesAnterior() {
    if (mesSelecionado == null) return;

    for (int i = 0; i < todosMeses.length - 1; i++) {
      if (todosMeses[i].year == mesSelecionado!.year && todosMeses[i].month == mesSelecionado!.month) {
        for (int j = i + 1; j < todosMeses.length; j++) {
          if (_mesTemLogs(todosMeses[j])) {
            setState(() {
              mesSelecionado = todosMeses[j];
              currentPage = 0;
            });
            _buscarLogs();
            return;
          }
        }
      }
    }
  }

  void _irParaProximoMes() {
    if (mesSelecionado == null) return;

    for (int i = 1; i < todosMeses.length; i++) {
      if (todosMeses[i].year == mesSelecionado!.year && todosMeses[i].month == mesSelecionado!.month) {
        for (int j = i - 1; j >= 0; j--) {
          if (_mesTemLogs(todosMeses[j])) {
            setState(() {
              mesSelecionado = todosMeses[j];
              currentPage = 0;
            });
            _buscarLogs();
            return;
          }
        }
      }
    }
  }

  Widget _buildFiltros() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => filtrosExpandidos = !filtrosExpandidos),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.filter_list,
                      color: Color(0xFF0EA5E9),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Filtros e Ordenação',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Icon(
                    filtrosExpandidos ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF64748B),
                    size: 28,
                  ),
                ],
              ),
            ),
          ),
          if (!filtrosExpandidos && _temFiltrosAtivos())
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (filtroUsuario != null) _buildFiltroAtivoBadge('Usuário: $filtroUsuario'),
                  if (entidadesSelecionadas.isNotEmpty)
                    _buildFiltroAtivoBadge(
                        'Entidades: ${entidadesSelecionadas.length} selecionada${entidadesSelecionadas.length > 1 ? 's' : ''}'),
                  if (filtroOperacao != null) _buildFiltroAtivoBadge('Operação: ${_getOperacaoTexto(filtroOperacao!)}'),
                  if (filtroIdController.text.isNotEmpty) _buildFiltroAtivoBadge('ID: ${filtroIdController.text}'),
                  if (ordenarPor != 'dataHora' || direcaoOrdenacao != 'desc')
                    _buildFiltroAtivoBadge('Ordenado por ${_getOrdenacaoTexto(ordenarPor)}'),
                ],
              ),
            ),
          if (filtrosExpandidos) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildDropdownField(
                    label: 'Usuário',
                    value: filtroUsuario,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todos')),
                      ...usuariosDisponiveis.map((u) => DropdownMenuItem(value: u, child: Text(u))),
                    ],
                    onChanged: (valor) => setState(() => filtroUsuario = valor),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: _buildDropdownField(
                    label: 'Operação',
                    value: filtroOperacao,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Todas')),
                      DropdownMenuItem(value: 'CREATE', child: Text('Criação')),
                      DropdownMenuItem(value: 'UPDATE', child: Text('Atualização')),
                      DropdownMenuItem(value: 'DELETE', child: Text('Exclusão')),
                    ],
                    onChanged: (valor) => setState(() => filtroOperacao = valor),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 1, child: Container()),
              ],
            ),
            const SizedBox(height: 16),
            _buildEntidadesCheckboxes(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ID da Entidade',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: filtroIdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'Digite o ID para buscar um registro específico...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: Container()),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 1,
              color: const Color(0xFFE2E8F0),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildDropdownField(
                    label: 'Ordenar por',
                    value: ordenarPor,
                    items: const [
                      DropdownMenuItem(value: 'dataHora', child: Text('Data/Hora')),
                      DropdownMenuItem(value: 'usuario', child: Text('Usuário')),
                      DropdownMenuItem(value: 'entidade', child: Text('Entidade')),
                      DropdownMenuItem(value: 'entidadeId', child: Text('ID da Entidade')),
                      DropdownMenuItem(value: 'operacao', child: Text('Operação')),
                    ],
                    onChanged: (valor) => setState(() => ordenarPor = valor ?? 'dataHora'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: _buildDropdownField(
                    label: 'Direção',
                    value: direcaoOrdenacao,
                    items: const [
                      DropdownMenuItem(
                        value: 'desc',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_downward, size: 16, color: Color(0xFF64748B)),
                            SizedBox(width: 8),
                            Text('Decrescente (↓ novo → antigo)'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'asc',
                        child: Row(
                          children: [
                            Icon(Icons.arrow_upward, size: 16, color: Color(0xFF64748B)),
                            SizedBox(width: 8),
                            Text('Crescente (↑ antigo → novo)'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (valor) => setState(() => direcaoOrdenacao = valor ?? 'desc'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 1, child: Container()),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _limparFiltros,
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Limpar Filtros'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _aplicarFiltros,
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('Aplicar Filtros'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _temFiltrosAtivos() {
    return filtroUsuario != null ||
        entidadesSelecionadas.isNotEmpty ||
        filtroOperacao != null ||
        filtroIdController.text.isNotEmpty ||
        ordenarPor != 'dataHora' ||
        direcaoOrdenacao != 'desc';
  }

  Widget _buildFiltroAtivoBadge(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0EA5E9).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0EA5E9),
        ),
      ),
    );
  }

  String _getOperacaoTexto(String operacao) {
    switch (operacao) {
      case 'CREATE':
        return 'Criação';
      case 'UPDATE':
        return 'Atualização';
      case 'DELETE':
        return 'Exclusão';
      default:
        return operacao;
    }
  }

  String _getOrdenacaoTexto(String campo) {
    switch (campo) {
      case 'dataHora':
        return 'Data/Hora';
      case 'usuario':
        return 'Usuário';
      case 'entidade':
        return 'Entidade';
      case 'entidadeId':
        return 'ID';
      case 'operacao':
        return 'Operação';
      default:
        return campo;
    }
  }

  Widget _buildEntidadesCheckboxes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Entidades',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  if (entidadesSelecionadas.length == entidadesDisponiveis.length) {
                    entidadesSelecionadas.clear();
                  } else {
                    entidadesSelecionadas = Set.from(entidadesDisponiveis);
                  }
                });
              },
              icon: Icon(
                entidadesSelecionadas.length == entidadesDisponiveis.length ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
              ),
              label: Text(
                entidadesSelecionadas.length == entidadesDisponiveis.length ? 'Desmarcar Todas' : 'Marcar Todas',
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0EA5E9),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: entidadesDisponiveis.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Nenhuma entidade disponível',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: entidadesDisponiveis.map((entidade) {
                    final isSelected = entidadesSelecionadas.contains(entidade);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            entidadesSelecionadas.remove(entidade);
                          } else {
                            entidadesSelecionadas.add(entidade);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0EA5E9).withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                              size: 18,
                              color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              entidade,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
            ),
            items: items,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
            dropdownColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildListaLogs() {
    if (logs.isEmpty) {
      final mesNome = mesSelecionado != null ? _getNomeMes(mesSelecionado!) : 'este período';

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history,
                size: 64,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum log encontrado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Não há registros em $mesNome',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tente selecionar outro período ou ajustar os filtros',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  spreadRadius: 0,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _mostrarDetalhesLog(log),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getOperacaoColor(log.operacao).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getOperacaoIcon(log.operacao),
                          color: _getOperacaoColor(log.operacao),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    log.descricao,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getOperacaoColor(log.operacao).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    log.operacaoFormatada,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _getOperacaoColor(log.operacao),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.person_outline, size: 14, color: const Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  log.usuario,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.category_outlined, size: 14, color: const Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  '${log.entidade} (ID: ${log.entidadeId})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 14, color: const Color(0xFF94A3B8)),
                                const SizedBox(width: 4),
                                Text(
                                  log.dataHoraFormatada,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFFCBD5E1),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaginacao() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0x1A000000),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total: $totalElements ${totalElements == 1 ? 'registro' : 'registros'}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: currentPage > 0 ? _paginaAnterior : null,
                color: const Color(0xFF0EA5E9),
                disabledColor: const Color(0xFFCBD5E1),
                iconSize: 24,
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Página ${currentPage + 1} de $totalPages',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: currentPage < totalPages - 1 ? _proximaPagina : null,
                color: const Color(0xFF0EA5E9),
                disabledColor: const Color(0xFFCBD5E1),
                iconSize: 24,
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
