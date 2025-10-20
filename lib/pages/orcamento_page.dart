import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../services/servico_service.dart';
import '../services/tipo_pagamento_service.dart';
import '../services/orcamento_service.dart';
import '../services/peca_service.dart';
import '../services/cliente_service.dart';
import '../services/veiculo_service.dart';
import '../services/funcionario_service.dart';
import '../services/auth_service.dart';
import '../utils/adaptive_phone_formatter.dart';
import '../model/servico.dart';
import '../model/tipo_pagamento.dart';
import '../model/orcamento.dart';
import '../model/peca_ordem_servico.dart';
import '../model/peca.dart';
import '../model/funcionario.dart';
import '../model/veiculo.dart';

extension IterableExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class OrcamentoPage extends StatelessWidget {
  const OrcamentoPage({super.key});

  @override
  Widget build(BuildContext context) => const OrcamentoScreen();
}

class OrcamentoScreen extends StatefulWidget {
  const OrcamentoScreen({super.key});

  @override
  State<OrcamentoScreen> createState() => _OrcamentoScreenState();
}

class _OrcamentoScreenState extends State<OrcamentoScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late ScrollController _scrollController;
  late FocusNode _clienteFocusNode;

  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _orcamentoNumberController = TextEditingController();

  final _clienteNomeController = TextEditingController();
  final _clienteCpfController = TextEditingController();
  final _clienteTelefoneController = TextEditingController();
  final AdaptivePhoneFormatter _maskTelefone = AdaptivePhoneFormatter();
  final _clienteEmailController = TextEditingController();

  final _veiculoNomeController = TextEditingController();
  final _veiculoMarcaController = TextEditingController();
  final _veiculoAnoController = TextEditingController();
  final _veiculoCorController = TextEditingController();
  final _veiculoPlacaController = TextEditingController();
  final _maskPlaca = MaskTextInputFormatter(
      mask: 'AAA-#X##',
      filter: {"#": RegExp(r'[0-9]'), "A": RegExp(r'[a-zA-Z]'), "X": RegExp(r'[a-zA-Z0-9]')},
      type: MaskAutoCompletionType.lazy);
  final _upperCaseFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  });
  final _veiculoQuilometragemController = TextEditingController();
  final _queixaPrincipalController = TextEditingController();
  final _observacoesController = TextEditingController();

  List<dynamic> _funcionarios = [];
  List<dynamic> _veiculos = [];
  List<Servico> _servicosDisponiveis = [];
  List<Servico> _servicosFiltrados = [];
  List<TipoPagamento> _tiposPagamento = [];
  List<Peca> _pecasDisponiveis = [];
  final List<Servico> _servicosSelecionados = [];
  final List<PecaOrdemServico> _pecasSelecionadas = [];
  TipoPagamento? _tipoPagamentoSelecionado;
  int _garantiaMeses = 3;
  int? _numeroParcelas;
  int? _prazoFiadoDias;
  Funcionario? _mecanicoSelecionado;
  Funcionario? _consultorSelecionado;
  String? _categoriaSelecionada;

  final TextEditingController _codigoPecaController = TextEditingController();
  final TextEditingController _servicoSearchController = TextEditingController();
  late TextEditingController _pecaSearchController;
  Peca? _pecaEncontrada;
  final Map<String, dynamic> _clienteByCpf = {};
  final Map<String, dynamic> _veiculoByPlaca = {};

  pw.MemoryImage? _cachedLogoImage;

  bool _showForm = false;
  List<Orcamento> _recent = [];
  List<Orcamento> _recentFiltrados = [];
  final TextEditingController _searchController = TextEditingController();
  int? _editingOrcamentoId;
  double _precoTotal = 0.0;
  double _precoTotalServicos = 0.0;
  bool _isViewMode = false;
  double _descontoServicos = 0.0;
  double _descontoPecas = 0.0;
  final TextEditingController _descontoServicosController = TextEditingController();
  final TextEditingController _descontoPecasController = TextEditingController();
  bool _isLoadingData = false;
  bool _isAdmin = false;
  bool _isLoadingInitialData = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _timeController.text = DateFormat('HH:mm').format(DateTime.now());
    _clienteCpfController.addListener(_onClienteCpfChanged);
    _veiculoPlacaController.addListener(_onVeiculoPlacaChanged);
    _pecaSearchController = TextEditingController();

    _initializeData();
    _searchController.addListener(_filtrarRecentes);
    _servicoSearchController.addListener(_filtrarServicos);
    _fadeController.forward();
    _slideController.forward();
    _scrollController = ScrollController();
    _clienteFocusNode = FocusNode();
  }

  Future<void> _initializeData() async {
    await _verificarPermissoes();
    await _loadData();
    if (mounted) {
      setState(() {
        _isLoadingInitialData = false;
      });
    }
  }

  @override
  void dispose() {
    try {
      _fadeController.dispose();
      _slideController.dispose();
      _dateController.dispose();
      _timeController.dispose();
      _orcamentoNumberController.dispose();
      _clienteNomeController.dispose();
      _clienteCpfController.removeListener(_onClienteCpfChanged);
      _clienteCpfController.dispose();
      _clienteTelefoneController.dispose();
      _clienteEmailController.dispose();
      _veiculoNomeController.dispose();
      _veiculoMarcaController.dispose();
      _veiculoAnoController.dispose();
      _veiculoCorController.dispose();
      _veiculoPlacaController.removeListener(_onVeiculoPlacaChanged);
      _veiculoPlacaController.dispose();
      _veiculoQuilometragemController.dispose();
      _queixaPrincipalController.dispose();
      _observacoesController.dispose();
      _searchController.removeListener(_filtrarRecentes);
      _searchController.dispose();
      _servicoSearchController.removeListener(_filtrarServicos);
      _servicoSearchController.dispose();
      _descontoServicosController.dispose();
      _descontoPecasController.dispose();
      _codigoPecaController.dispose();
      _pecaSearchController.dispose();
      _scrollController.dispose();
      _clienteFocusNode.dispose();
    } catch (e) {
      // Erro ao fazer dispose (ignorado)
    }
    super.dispose();
  }

  Future<void> _verificarPermissoes() async {
    final isAdmin = await AuthService.isAdmin();
    setState(() {
      _isAdmin = isAdmin;
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingData = true;
    });

    try {
      final results = await Future.wait([
        OrcamentoService.listarOrcamentos(),
        ServicoService.listarServicos(),
        TipoPagamentoService.listarTiposPagamento(),
        PecaService.listarPecas(),
        ClienteService.listarClientes(),
        VeiculoService.listarVeiculos(),
        Funcionarioservice.listarFuncionarios(),
      ]);

      final orcamentos = results[0] as List<Orcamento>;
      final servicos = results[1] as List<Servico>;
      final tiposPagamento = results[2] as List<TipoPagamento>;
      final pecas = results[3] as List<Peca>;
      final clientes = results[4] as List<dynamic>;
      final veiculos = results[5] as List<Veiculo>;
      final funcionarios = results[6] as List<Funcionario>;

      servicos.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

      final Map<int, TipoPagamento> tpById = {};
      for (var tp in tiposPagamento) {
        if (tp.id != null) tpById[tp.id!] = tp;
      }

      orcamentos.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));

      final clienteByCpf = <String, dynamic>{};
      for (var cliente in clientes) {
        clienteByCpf[cliente.cpf] = cliente;
      }
      for (var func in funcionarios) {
        clienteByCpf[func.cpf] = func;
      }

      final veiculoByPlaca = <String, Veiculo>{};
      for (var veiculo in veiculos) {
        veiculoByPlaca[veiculo.placa] = veiculo;
      }

      Funcionario? consultorParaSelecionar;

      if (!_isAdmin && _consultorSelecionado == null) {
        final consultorId = await AuthService.getConsultorId();

        if (consultorId != null) {
          consultorParaSelecionar = funcionarios.where((f) => f.id == consultorId && f.nivelAcesso == 1).firstOrNull;
        }
      }

      if (mounted) {
        setState(() {
          _recent = orcamentos;
          _servicosDisponiveis = servicos;
          _servicosFiltrados = servicos;
          _tiposPagamento = tpById.values.toList();
          _pecasDisponiveis = pecas;
          _veiculos = veiculos;
          _funcionarios = funcionarios;
          _recentFiltrados = List.from(orcamentos);
          _clienteByCpf.clear();
          _clienteByCpf.addAll(clienteByCpf);
          _veiculoByPlaca.clear();
          _veiculoByPlaca.addAll(veiculoByPlaca);
          _isLoadingData = false;

          if (consultorParaSelecionar != null) {
            _consultorSelecionado = consultorParaSelecionar;
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingData = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar dados: $e')),
        );
      }
    }
  }

  void _filtrarRecentes() {
    final searchText = _searchController.text.toLowerCase();
    setState(() {
      if (searchText.isEmpty) {
        _recentFiltrados = List.from(_recent);
      } else {
        _recentFiltrados = _recent.where((orcamento) {
          return orcamento.numeroOrcamento.toLowerCase().contains(searchText) ||
              orcamento.clienteNome.toLowerCase().contains(searchText) ||
              orcamento.veiculoPlaca.toLowerCase().contains(searchText);
        }).toList();
      }
    });
  }

  void _filtrarServicos() {
    final query = _servicoSearchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _servicosFiltrados = _servicosDisponiveis;
      } else {
        _servicosFiltrados = _servicosDisponiveis.where((servico) {
          return servico.nome.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _clearForm() {
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _timeController.text = DateFormat('HH:mm').format(DateTime.now());
    _orcamentoNumberController.clear();
    _clienteNomeController.clear();
    _clienteCpfController.clear();
    _clienteTelefoneController.clear();
    _clienteEmailController.clear();
    _veiculoNomeController.clear();
    _veiculoMarcaController.clear();
    _veiculoAnoController.clear();
    _veiculoCorController.clear();
    _veiculoPlacaController.clear();
    _veiculoQuilometragemController.clear();
    _queixaPrincipalController.clear();
    _observacoesController.clear();
    _descontoServicosController.clear();
    _descontoPecasController.clear();
    _servicoSearchController.clear();
    _codigoPecaController.clear();

    setState(() {
      _servicosSelecionados.clear();
      _pecasSelecionadas.clear();
      _tipoPagamentoSelecionado = null;
      _garantiaMeses = 3;
      _numeroParcelas = null;
      _prazoFiadoDias = null;
      _mecanicoSelecionado = null;
      _consultorSelecionado = null;
      _precoTotal = 0.0;
      _precoTotalServicos = 0.0;
      _descontoServicos = 0.0;
      _descontoPecas = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.indigo.shade50,
              Colors.lightBlue.shade50,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModernHeader(colorScheme),
                  const SizedBox(height: 32),
                  if (_isLoadingInitialData)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: CircularProgressIndicator(color: Colors.blue.shade600),
                      ),
                    )
                  else ...[
                    if (_showForm) _buildFullForm(),
                    if (!_showForm) ...[
                      _buildSearchSection(colorScheme),
                      const SizedBox(height: 24),
                      _buildRecentList(),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.request_quote_outlined,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Orçamentos',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gerencie orçamentos automotivos',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  if (_showForm) {
                    _clearForm();
                    setState(() {
                      _editingOrcamentoId = null;
                      _showForm = false;
                    });
                  } else {
                    _clearForm();
                    setState(() {
                      _showForm = true;
                    });

                    if (!_isAdmin && _consultorSelecionado == null) {
                      final consultorId = await AuthService.getConsultorId();
                      if (consultorId != null && mounted) {
                        final consultor = _funcionarios.where((f) => f.id == consultorId && f.nivelAcesso == 1).firstOrNull;
                        if (consultor != null && mounted) {
                          setState(() {
                            _consultorSelecionado = consultor;
                          });
                        }
                      }
                    }
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showForm ? Icons.close : Icons.add_circle,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showForm ? 'Cancelar' : 'Novo Orçamento',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.search, color: Colors.blue.shade600),
              const SizedBox(width: 12),
              Text(
                'Buscar Orçamentos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Pesquisar por número do orçamento, cliente ou placa do veículo',
              prefixIcon: Icon(Icons.search_outlined, color: Colors.grey[400]),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[400]),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentList() {
    if (_isLoadingData) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_recentFiltrados.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.request_quote_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum orçamento encontrado',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crie seu primeiro orçamento clicando no botão acima',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentFiltrados.length,
      itemBuilder: (context, index) {
        final orcamento = _recentFiltrados[index];
        return _buildOrcamentoCard(orcamento);
      },
    );
  }

  Widget _buildFullForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.indigo.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.request_quote, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  _editingOrcamentoId == null
                      ? 'Novo Orçamento'
                      : _isViewMode
                          ? 'Visualizar Orçamento'
                          : 'Editar Orçamento',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () => _printOrcamento(null),
                    icon: Icon(Icons.picture_as_pdf, color: Colors.blue.shade600, size: 20),
                    tooltip: 'PDF',
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_editingOrcamentoId != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade600),
                        const SizedBox(width: 12),
                        Text(
                          _isViewMode
                              ? 'Visualizando Orçamento: ${_orcamentoNumberController.text.isNotEmpty ? _orcamentoNumberController.text : _editingOrcamentoId}'
                              : 'Editando Orçamento: ${_orcamentoNumberController.text.isNotEmpty ? _orcamentoNumberController.text : _editingOrcamentoId}',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_editingOrcamentoId != null) const SizedBox(height: 24),
                _buildFormSection('1. Dados do Cliente e Veículo', Icons.person_outline),
                const SizedBox(height: 16),
                _buildClientVehicleInfo(),
                const SizedBox(height: 32),
                _buildFormSection('2. Responsáveis', Icons.people_outlined),
                const SizedBox(height: 16),
                _buildResponsibleSection(),
                const SizedBox(height: 32),
                _buildFormSection('3. Queixa Principal / Problema Relatado', Icons.report_problem_outlined),
                const SizedBox(height: 16),
                _buildComplaintSection(),
                const SizedBox(height: 32),
                _buildFormSection('4. Serviços a Executar', Icons.build_outlined),
                const SizedBox(height: 16),
                _buildServicesSelection(),
                const SizedBox(height: 32),
                _buildFormSection('5. Peças Utilizadas', Icons.inventory_outlined),
                const SizedBox(height: 16),
                _buildPartsSelection(),
                const SizedBox(height: 32),
                _buildFormSection('6. Resumo de Valores', Icons.receipt_long_outlined),
                const SizedBox(height: 16),
                _buildPriceSummarySection(),
                const SizedBox(height: 32),
                _buildFormSection('7. Garantia e Forma de Pagamento', Icons.payment_outlined),
                const SizedBox(height: 16),
                _buildWarrantyAndPayment(),
                const SizedBox(height: 32),
                _buildFormSection('8. Observações Adicionais', Icons.notes_outlined),
                const SizedBox(height: 16),
                _buildObservationsSection(),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_isViewMode) ...[
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.grey.shade600, Colors.grey.shade700],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            _clearForm();
                            setState(() {
                              _showForm = false;
                            });
                          },
                          icon: const Icon(Icons.close, color: Colors.white),
                          label: const Text(
                            'Fechar',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade600, Colors.indigo.shade600],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _salvarOrcamento,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.save, color: Colors.white),
                          label: Text(
                            _isSaving ? 'Salvando...' : (_editingOrcamentoId != null ? 'Atualizar Orçamento' : 'Salvar Orçamento'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrcamentoCard(Orcamento orcamento) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.indigo.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.request_quote_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          'Orçamento ${orcamento.numeroOrcamento}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            if (orcamento.transformadoEmOS && orcamento.numeroOSGerado != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.purple.shade600),
                    const SizedBox(width: 6),
                    Text(
                      'Transformado em OS ${orcamento.numeroOSGerado}',
                      style: TextStyle(
                        color: Colors.purple.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            if (orcamento.clienteNome.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      orcamento.clienteNome,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            if (orcamento.veiculoPlaca.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    '${orcamento.veiculoNome} - ${orcamento.veiculoPlaca}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            if (orcamento.precoTotal > 0) ...[
              if (orcamento.pecasOrcadas.isNotEmpty || (orcamento.precoTotalPecas ?? 0) > 0)
                Row(
                  children: [
                    Icon(Icons.request_quote_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Peças: R\$ ${((orcamento.precoTotalPecas != null && orcamento.precoTotalPecas! > 0) ? orcamento.precoTotalPecas! : orcamento.pecasOrcadas.fold<double>(0.0, (t, p) => t + (p.peca.precoFinal * p.quantidade))).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              if (orcamento.servicosOrcados.isNotEmpty || (orcamento.precoTotalServicos ?? 0) > 0)
                Row(
                  children: [
                    Icon(Icons.handyman, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Serviços: R\$ ${((orcamento.precoTotalServicos != null && orcamento.precoTotalServicos! > 0) ? orcamento.precoTotalServicos! : orcamento.servicosOrcados.fold<double>(0.0, (t, s) => t + _getPrecoServicoPorCategoria(s))).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              if (((orcamento.descontoServicos ?? 0) > 0) || ((orcamento.descontoPecas ?? 0) > 0))
                Row(
                  children: [
                    Icon(Icons.local_offer, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Descontos: R\$ ${(((orcamento.descontoServicos ?? 0) + (orcamento.descontoPecas ?? 0))).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              Row(
                children: [
                  Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Total: R\$ ${orcamento.precoTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.purple[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(orcamento.dataHora),
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.visibility_outlined,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                onPressed: () => _visualizarOrcamento(orcamento),
                tooltip: 'Visualizar Orçamento',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.picture_as_pdf,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
                onPressed: () => _printOrcamento(orcamento),
                tooltip: 'Imprimir PDF',
              ),
            ),
            const SizedBox(width: 8),
            if (!orcamento.transformadoEmOS) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.assignment_turned_in,
                    color: Colors.purple.shade600,
                    size: 20,
                  ),
                  onPressed: () => _confirmarTransformacaoEmOS(orcamento),
                  tooltip: 'Transformar em OS',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    color: Colors.orange.shade600,
                    size: 20,
                  ),
                  onPressed: () => _editOrcamento(orcamento),
                  tooltip: 'Editar Orçamento',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                  onPressed: () => _confirmarExclusaoOrcamento(orcamento),
                  tooltip: 'Excluir Orçamento',
                ),
              ),
            ] else
              Container(
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.lock_outlined,
                    color: Colors.purple.shade600,
                    size: 20,
                  ),
                  onPressed: null,
                  tooltip: 'Orçamento Bloqueado - Transformado em OS ${orcamento.numeroOSGerado}',
                ),
              ),
          ],
        ),
        onTap: () async {
          _editOrcamento(orcamento);
        },
      ),
    );
  }

  void _visualizarOrcamento(Orcamento orcamento) {
    setState(() {
      _editingOrcamentoId = orcamento.id;
      _showForm = true;
      _isViewMode = true;
    });
    _carregarOrcamentoParaEdicao(orcamento);
  }

  void _printOrcamento(Orcamento? orcamento) {
    _generateOrcamentoPdf(orcamento);
  }

  Future<void> _generateOrcamentoPdf(Orcamento? orcamento) async {
    _cachedLogoImage ??= pw.MemoryImage(
      (await rootBundle.load('assets/images/TecStock_logo.png')).buffer.asUint8List(),
    );

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => pw.Column(
          children: [
            _buildPdfHeaderOrcamento(orcamento, logoImage: _cachedLogoImage),
            pw.SizedBox(height: 16),
            _buildPdfClientVehicleDataOrcamento(orcamento),
            pw.SizedBox(height: 12),
            _buildPdfSectionOrcamento(
              'QUEIXA PRINCIPAL / PROBLEMA RELATADO',
              [],
              content: orcamento?.queixaPrincipal ??
                  (_queixaPrincipalController.text.isNotEmpty ? _queixaPrincipalController.text : 'Não informado'),
              compact: true,
            ),
            pw.SizedBox(height: 12),
            _buildPdfServicesSectionOrcamento(orcamento),
            pw.SizedBox(height: 12),
            _buildPdfPartsSectionOrcamento(orcamento),
            pw.SizedBox(height: 12),
            _buildPdfPricingSectionOrcamento(orcamento),
            pw.SizedBox(height: 12),
            _buildPdfSectionOrcamento(
              'OBSERVAÇÕES',
              [],
              content: orcamento?.observacoes ??
                  (_observacoesController.text.isNotEmpty ? _observacoesController.text : 'Nenhuma observação adicional'),
              compact: true,
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  pw.Widget _buildPdfHeaderOrcamento(Orcamento? orcamento, {pw.MemoryImage? logoImage}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColors.blue600, PdfColors.indigo600],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      padding: const pw.EdgeInsets.all(16),
      child: pw.Row(
        children: [
          if (logoImage != null) ...[
            pw.Image(logoImage, width: 60, height: 60, fit: pw.BoxFit.contain),
            pw.SizedBox(width: 16),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ORÇAMENTO',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Text('Data: ${DateFormat('dd/MM/yyyy').format(orcamento?.dataHora ?? DateTime.now())}',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                    pw.SizedBox(width: 20),
                    pw.Text('Hora: ${DateFormat('HH:mm').format(orcamento?.dataHora ?? DateTime.now())}',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                  ],
                ),
                pw.SizedBox(height: 6),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Text(
              'ORC #${orcamento?.numeroOrcamento ?? (_orcamentoNumberController.text.isNotEmpty ? _orcamentoNumberController.text : DateTime.now().millisecondsSinceEpoch.toString().substring(8))}',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfClientVehicleDataOrcamento(Orcamento? orcamento) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildPdfSectionOrcamento(
            'DADOS DO CLIENTE',
            [
              ['Nome:', orcamento?.clienteNome ?? _clienteNomeController.text],
              ['CPF:', orcamento?.clienteCpf ?? _clienteCpfController.text],
              ['Telefone:', orcamento?.clienteTelefone ?? _clienteTelefoneController.text],
              ['Email:', orcamento?.clienteEmail ?? _clienteEmailController.text],
            ],
            compact: true,
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _buildPdfSectionOrcamento(
            'DADOS DO VEÍCULO',
            [
              ['Veículo:', orcamento?.veiculoNome ?? _veiculoNomeController.text],
              ['Marca:', orcamento?.veiculoMarca ?? _veiculoMarcaController.text],
              ['Ano/Modelo:', orcamento?.veiculoAno ?? _veiculoAnoController.text],
              ['Cor:', orcamento?.veiculoCor ?? _veiculoCorController.text],
              ['Placa:', orcamento?.veiculoPlaca ?? _veiculoPlacaController.text],
              ['Quilometragem:', orcamento?.veiculoQuilometragem ?? _veiculoQuilometragemController.text],
            ],
            compact: true,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfSectionOrcamento(String title, List<List<String>> data, {String? content, bool compact = false}) {
    final paddingValue = compact ? 8.0 : 12.0;
    final titleFontSize = compact ? 11.0 : 12.0;
    final contentFontSize = compact ? 10.0 : 11.0;
    final dataFontSize = compact ? 9.0 : 10.0;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      padding: pw.EdgeInsets.all(paddingValue),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: titleFontSize, color: PdfColors.blue900),
          ),
          pw.SizedBox(height: compact ? 6 : 8),
          if (content != null)
            pw.Text(content, style: pw.TextStyle(fontSize: contentFontSize))
          else
            ...data.map((row) => pw.Padding(
                  padding: pw.EdgeInsets.symmetric(vertical: compact ? 1 : 2),
                  child: pw.Row(
                    children: [
                      pw.SizedBox(
                        width: compact ? 80 : 100,
                        child: pw.Text(row[0], style: pw.TextStyle(fontSize: dataFontSize, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Expanded(
                        child: pw.Text(row[1], style: pw.TextStyle(fontSize: dataFontSize)),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  pw.Widget _buildPdfServicesSectionOrcamento(Orcamento? orcamento) {
    final servicosParaPDF = orcamento?.servicosOrcados ?? _servicosSelecionados;
    final categoriaVeiculo = orcamento?.veiculoCategoria ?? _categoriaSelecionada;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Text(
              'SERVIÇOS ORÇADOS',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue900),
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey50),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Serviço', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Categoria', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Preço', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ),
                ],
              ),
              ...servicosParaPDF.map((servico) {
                double preco = 0.0;
                if (categoriaVeiculo == 'Caminhonete') {
                  preco = servico.precoCaminhonete ?? 0.0;
                } else if (categoriaVeiculo == 'Passeio') {
                  preco = servico.precoPasseio ?? 0.0;
                }

                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(servico.nome, style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(categoriaVeiculo ?? 'Não definida', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('R\$ ${preco.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfPartsSectionOrcamento(Orcamento? orcamento) {
    final pecasParaPDF = orcamento?.pecasOrcadas ?? _pecasSelecionadas;

    if (pecasParaPDF.isEmpty) {
      return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        padding: const pw.EdgeInsets.all(10),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'PEÇAS ORÇADAS',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Nenhuma peça foi orçada.',
              style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Text(
              'PEÇAS ORÇADAS',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue900),
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey50),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Peça', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Código', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Qtd', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Valor Unit.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ),
                ],
              ),
              ...pecasParaPDF.map((pecaOS) {
                return pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(pecaOS.peca.nome, style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(pecaOS.peca.codigoFabricante, style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('${pecaOS.quantidade}', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('R\$ ${pecaOS.peca.precoFinal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text('R\$ ${pecaOS.valorTotalCalculado.toStringAsFixed(2)}',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfPricingSectionOrcamento(Orcamento? orcamento) {
    final tipoPagamento = orcamento?.tipoPagamento ?? _tipoPagamentoSelecionado;
    final numeroParcelas = orcamento?.numeroParcelas ?? _numeroParcelas;
    final garantiaMeses = orcamento?.garantiaMeses ?? _garantiaMeses;

    final pecasParaPDF = orcamento?.pecasOrcadas ?? _pecasSelecionadas;
    final totalPecas = pecasParaPDF.fold(0.0, (total, pecaOS) => total + pecaOS.valorTotalCalculado);

    double totalServicos = 0.0;
    if (orcamento != null) {
      final servicosParaPDF = orcamento.servicosOrcados;
      final categoriaVeiculo = orcamento.veiculoCategoria;
      for (var servico in servicosParaPDF) {
        if (categoriaVeiculo == 'Caminhonete') {
          totalServicos += servico.precoCaminhonete ?? 0.0;
        } else if (categoriaVeiculo == 'Passeio') {
          totalServicos += servico.precoPasseio ?? 0.0;
        }
      }
    } else {
      for (var servico in _servicosSelecionados) {
        if (_categoriaSelecionada == 'Caminhonete') {
          totalServicos += servico.precoCaminhonete ?? 0.0;
        } else if (_categoriaSelecionada == 'Passeio') {
          totalServicos += servico.precoPasseio ?? 0.0;
        }
      }
    }

    final descontoServicos = orcamento?.descontoServicos ?? _descontoServicos;
    final descontoPecas = orcamento?.descontoPecas ?? _descontoPecas;

    final totalServicosComDesconto = totalServicos - (descontoServicos > 0 ? descontoServicos : 0.0);
    final totalPecasComDesconto = totalPecas - (descontoPecas > 0 ? descontoPecas : 0.0);
    final totalGeral = totalServicosComDesconto + totalPecasComDesconto;

    double valorParcelaCalculado = 0.0;
    double ultimaParcelaCalculada = 0.0;
    if (numeroParcelas != null && numeroParcelas > 0) {
      final raw = totalGeral / numeroParcelas;
      final rounded = double.parse(raw.toStringAsFixed(2));
      valorParcelaCalculado = rounded;
      ultimaParcelaCalculada = double.parse((totalGeral - rounded * (numeroParcelas - 1)).toStringAsFixed(2));
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'INFORMAÇÕES FINANCEIRAS',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue900),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Valor dos Serviços:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('R\$ ${totalServicos.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
            ],
          ),
          if (descontoServicos > 0) ...[
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('(-) Desconto Serviços:', style: pw.TextStyle(fontSize: 9, color: PdfColors.red700)),
                pw.Text('-R\$ ${descontoServicos.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, color: PdfColors.red700)),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Subtotal Serviços:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('R\$ ${totalServicosComDesconto.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
              ],
            ),
          ],
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Valor das Peças:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('R\$ ${totalPecas.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
            ],
          ),
          if (descontoPecas > 0) ...[
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('(-) Desconto Peças:', style: pw.TextStyle(fontSize: 9, color: PdfColors.red700)),
                pw.Text('-R\$ ${descontoPecas.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, color: PdfColors.red700)),
              ],
            ),
            pw.SizedBox(height: 2),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Subtotal Peças:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('R\$ ${totalPecasComDesconto.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
              ],
            ),
          ],
          pw.SizedBox(height: 8),
          if (descontoServicos > 0 || descontoPecas > 0) ...[
            pw.Container(
              height: 0.5,
              color: PdfColors.orange400,
              margin: const pw.EdgeInsets.symmetric(vertical: 4),
            ),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL DE DESCONTOS:',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.orange700)),
                pw.Text('-R\$ ${(descontoServicos + descontoPecas).toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.orange700)),
              ],
            ),
            pw.SizedBox(height: 4),
          ],
          pw.Container(
            height: 1,
            color: PdfColors.grey400,
            margin: const pw.EdgeInsets.symmetric(vertical: 4),
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('VALOR TOTAL GERAL:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text('R\$ ${totalGeral.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.purple700)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Forma de Pagamento:', style: pw.TextStyle(fontSize: 9)),
              pw.Text(tipoPagamento?.nome ?? 'Não informado', style: pw.TextStyle(fontSize: 9)),
            ],
          ),
          if (tipoPagamento?.codigo == 3 && numeroParcelas != null) ...[
            pw.SizedBox(height: 3),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Número de Parcelas:', style: pw.TextStyle(fontSize: 9)),
                pw.Text('${numeroParcelas}x', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 3),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Valor por Parcela:', style: pw.TextStyle(fontSize: 9)),
                pw.Text('R\$ ${valorParcelaCalculado.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
              ],
            ),
            if (ultimaParcelaCalculada != valorParcelaCalculado)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text('Última parcela: R\$ ${ultimaParcelaCalculada.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ),
          ],
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Garantia:', style: pw.TextStyle(fontSize: 9)),
              pw.Text('$garantiaMeses meses', style: pw.TextStyle(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  void _editOrcamento(Orcamento orcamento) {
    setState(() {
      _editingOrcamentoId = orcamento.id;
      _showForm = true;
      _isViewMode = false;
    });
    _carregarOrcamentoParaEdicao(orcamento);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (_scrollController.hasClients) {
          await _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted && !_isViewMode) _clienteFocusNode.requestFocus();
    });
  }

  Future<void> _confirmarExclusaoOrcamento(Orcamento orcamento) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning_amber, color: Colors.red.shade600),
            ),
            const SizedBox(width: 12),
            const Text('Confirmar Exclusão'),
          ],
        ),
        content: Text('Deseja realmente excluir o orçamento ${orcamento.numeroOrcamento}? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (orcamento.id != null) {
                final sucesso = await OrcamentoService.excluirOrcamento(orcamento.id!);
                if (sucesso) {
                  await _loadData();
                  _showSuccessMessage('Orçamento excluído com sucesso');
                } else {
                  _showErrorMessage('Erro ao excluir orçamento');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarTransformacaoEmOS(Orcamento orcamento) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.assignment_turned_in, color: Colors.purple.shade600),
            ),
            const SizedBox(width: 12),
            const Text('Transformar em OS'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deseja transformar o orçamento ${orcamento.numeroOrcamento} em uma Ordem de Serviço?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'O orçamento será bloqueado e não poderá mais ser editado.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (orcamento.id != null) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                final ordemServico = await OrcamentoService.transformarEmOrdemServico(orcamento.id!);

                Navigator.pop(context);

                if (ordemServico != null) {
                  await _loadData();
                  _showSuccessMessage('Orçamento transformado em OS ${ordemServico.numeroOS} com sucesso!');
                } else {
                  _showErrorMessage('Erro ao transformar orçamento em OS');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Transformar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _carregarOrcamentoParaEdicao(Orcamento orcamento) {
    setState(() {
      _editingOrcamentoId = orcamento.id;
      _showForm = true;

      _orcamentoNumberController.text = orcamento.numeroOrcamento;
      _dateController.text = DateFormat('dd/MM/yyyy').format(orcamento.dataHora);
      _timeController.text = DateFormat('HH:mm').format(orcamento.dataHora);

      _clienteNomeController.text = orcamento.clienteNome;
      _clienteCpfController.text = orcamento.clienteCpf;
      _clienteTelefoneController.text = orcamento.clienteTelefone ?? '';
      _clienteEmailController.text = orcamento.clienteEmail ?? '';

      _veiculoNomeController.text = orcamento.veiculoNome;
      _veiculoMarcaController.text = orcamento.veiculoMarca;
      _veiculoAnoController.text = orcamento.veiculoAno;
      _veiculoCorController.text = orcamento.veiculoCor;
      _veiculoPlacaController.text = orcamento.veiculoPlaca;
      _veiculoQuilometragemController.text = orcamento.veiculoQuilometragem;
      _categoriaSelecionada = orcamento.veiculoCategoria ?? '';

      _queixaPrincipalController.text = orcamento.queixaPrincipal;
      _observacoesController.text = orcamento.observacoes ?? '';

      _servicosSelecionados.clear();
      _servicosSelecionados.addAll(orcamento.servicosOrcados);

      _pecasSelecionadas.clear();
      _pecasSelecionadas.addAll(orcamento.pecasOrcadas);

      _precoTotal = orcamento.precoTotal;
      _precoTotalServicos = orcamento.precoTotalServicos ?? 0.0;
      _descontoServicos = orcamento.descontoServicos ?? 0.0;
      _descontoPecas = orcamento.descontoPecas ?? 0.0;
      _descontoServicosController.text = _descontoServicos > 0 ? _descontoServicos.toStringAsFixed(2) : '';
      _descontoPecasController.text = _descontoPecas > 0 ? _descontoPecas.toStringAsFixed(2) : '';

      _garantiaMeses = orcamento.garantiaMeses;
      _tipoPagamentoSelecionado = orcamento.tipoPagamento;
      _numeroParcelas = orcamento.numeroParcelas;
      _prazoFiadoDias = orcamento.prazoFiadoDias;

      if (orcamento.mecanico != null && orcamento.mecanico!.id != null) {
        _mecanicoSelecionado = _funcionarios.where((f) => f.id == orcamento.mecanico!.id && f.nivelAcesso == 2).firstOrNull;
      } else {
        _mecanicoSelecionado = null;
      }

      if (orcamento.consultor != null && orcamento.consultor!.id != null) {
        _consultorSelecionado = _funcionarios.where((f) => f.id == orcamento.consultor!.id && f.nivelAcesso == 1).firstOrNull;
      } else {
        _consultorSelecionado = null;
      }
    });
    _calcularPrecoTotal();
  }

  Widget _buildFormSection(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue.shade600, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
        ),
      ],
    );
  }

  Widget _buildClientVehicleInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth > 700 ? 3 : 2;
        final itemWidth = (constraints.maxWidth - (16 * (columns - 1))) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(width: itemWidth, child: _buildCpfAutocomplete(fieldWidth: itemWidth)),
            SizedBox(width: itemWidth, child: _buildLabeledController('Cliente', _clienteNomeController, focusNode: _clienteFocusNode)),
            SizedBox(width: itemWidth, child: _buildLabeledController('Telefone/WhatsApp', _clienteTelefoneController)),
            SizedBox(width: itemWidth, child: _buildLabeledController('E-mail', _clienteEmailController)),
            SizedBox(width: itemWidth, child: _buildPlacaAutocomplete(fieldWidth: itemWidth)),
            SizedBox(width: itemWidth, child: _buildLabeledController('Veículo', _veiculoNomeController)),
            SizedBox(width: itemWidth, child: _buildLabeledController('Marca', _veiculoMarcaController)),
            SizedBox(width: itemWidth, child: _buildLabeledController('Ano/Modelo', _veiculoAnoController)),
            SizedBox(width: itemWidth, child: _buildLabeledController('Cor', _veiculoCorController)),
            SizedBox(width: itemWidth, child: _buildLabeledController('Quilometragem', _veiculoQuilometragemController)),
            SizedBox(width: itemWidth, child: _buildCategoriaDropdown()),
          ],
        );
      }),
    );
  }

  Widget _buildResponsibleSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mecânico Responsável',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<Funcionario>(
                  value: _mecanicoSelecionado != null ? _funcionarios.where((f) => f.id == _mecanicoSelecionado!.id).firstOrNull : null,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  hint: const Text('Selecione um mecânico'),
                  items: (() {
                    final lista = _funcionarios.where((funcionario) => funcionario.nivelAcesso == 2).toList();
                    lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
                    return lista.map<DropdownMenuItem<Funcionario>>((funcionario) {
                      return DropdownMenuItem<Funcionario>(
                        value: funcionario,
                        child: Text(funcionario.nome),
                      );
                    }).toList();
                  })(),
                  onChanged: _isViewMode
                      ? null
                      : (value) {
                          setState(() {
                            _mecanicoSelecionado = value;
                          });
                        },
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consultor Responsável',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<Funcionario>(
                  value: _consultorSelecionado != null ? _funcionarios.where((f) => f.id == _consultorSelecionado!.id).firstOrNull : null,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  hint: const Text('Selecione um consultor'),
                  items: (() {
                    final lista = _funcionarios.where((funcionario) => funcionario.nivelAcesso == 1).toList();
                    lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
                    return lista.map<DropdownMenuItem<Funcionario>>((funcionario) {
                      return DropdownMenuItem<Funcionario>(
                        value: funcionario,
                        child: Text(funcionario.nome),
                      );
                    }).toList();
                  })(),
                  onChanged: (_isViewMode || !_isAdmin)
                      ? null
                      : (value) {
                          setState(() {
                            _consultorSelecionado = value;
                          });
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Descrição do problema ou serviços solicitados',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _queixaPrincipalController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Descreva o problema relatado pelo cliente ou os serviços que ele deseja orçar...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesSelection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selecione os serviços',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
              ),
              if (_precoTotalServicos > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Total Serviços: R\$ ${_precoTotalServicos.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _servicoSearchController,
              enabled: !_isViewMode,
              decoration: InputDecoration(
                hintText: 'Pesquisar serviços...',
                prefixIcon: Icon(Icons.search, color: Colors.blue.shade600),
                suffixIcon: _servicoSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _servicoSearchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_servicosDisponiveis.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade600),
                  const SizedBox(width: 8),
                  const Text('Nenhum serviço cadastrado no sistema.'),
                ],
              ),
            )
          else if (_servicosFiltrados.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_off, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  const Text('Nenhum serviço encontrado com o termo pesquisado.'),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _servicosFiltrados.map((servico) {
                final isSelected = _servicosSelecionados.any((s) => s.id == servico.id);
                return FilterChip(
                  selected: isSelected,
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        servico.nome,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_categoriaSelecionada == 'Caminhonete')
                        Text(
                          'R\$ ${(servico.precoCaminhonete ?? 0.0).toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.grey[600],
                            fontSize: 12,
                          ),
                        )
                      else if (_categoriaSelecionada == 'Passeio')
                        Text(
                          'R\$ ${(servico.precoPasseio ?? 0.0).toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.grey[600],
                            fontSize: 12,
                          ),
                        )
                      else
                        Text(
                          'Categoria não definida',
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.orange[600],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                  onSelected: _isViewMode ? null : (selected) => _onServicoToggled(servico),
                  selectedColor: Colors.blue.shade400,
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? Colors.blue.shade400 : Colors.grey[300]!,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPartsSelection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildPecaAutocomplete(),
                    ),
                    if (!_isViewMode) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => _buscarPecaPorCodigo(_codigoPecaController.text),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Adicionar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_pecaEncontrada != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Peça Encontrada',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _pecaEncontrada!.nome,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Código: ${_pecaEncontrada!.codigoFabricante}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        Text(
                          'Preço: R\$ ${_pecaEncontrada!.precoFinal.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        Row(
                          children: [
                            Text(
                              'Estoque: ${_pecaEncontrada!.quantidadeEstoque} unid.',
                              style: TextStyle(
                                color: _pecaEncontrada!.quantidadeEstoque <= 5
                                    ? Colors.red[600]
                                    : _pecaEncontrada!.quantidadeEstoque <= 10
                                        ? Colors.orange[600]
                                        : Colors.green[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (_pecaEncontrada!.quantidadeEstoque <= 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'SEM ESTOQUE',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else if (_pecaEncontrada!.quantidadeEstoque <= 5)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'ESTOQUE BAIXO',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_pecasSelecionadas.isNotEmpty) ...[
            Text(
              'Peças Selecionadas',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ...(_pecasSelecionadas.map((pecaOS) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pecaOS.peca.nome,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Código: ${pecaOS.peca.codigoFabricante}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Preço final: R\$ ${pecaOS.peca.precoFinal.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Estoque: ${pecaOS.peca.quantidadeEstoque} unid. (Usando: ${pecaOS.quantidade})',
                            style: TextStyle(
                              color: pecaOS.quantidade >= pecaOS.peca.quantidadeEstoque
                                  ? Colors.red[600]
                                  : pecaOS.peca.quantidadeEstoque <= 5
                                      ? Colors.red[600]
                                      : pecaOS.peca.quantidadeEstoque <= 10
                                          ? Colors.orange[600]
                                          : Colors.green[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: Colors.grey[300],
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: pecaOS.peca.quantidadeEstoque > 0
                                  ? (pecaOS.quantidade / pecaOS.peca.quantidadeEstoque).clamp(0.0, 1.0)
                                  : 0.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: pecaOS.quantidade >= pecaOS.peca.quantidadeEstoque
                                      ? Colors.red[400]
                                      : pecaOS.quantidade / pecaOS.peca.quantidadeEstoque > 0.8
                                          ? Colors.orange[400]
                                          : Colors.green[400],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _isViewMode
                              ? null
                              : () {
                                  if (pecaOS.quantidade > 1) {
                                    setState(() {
                                      pecaOS.quantidade--;
                                      pecaOS.valorUnitario = pecaOS.peca.precoFinal;
                                      pecaOS.valorTotal = pecaOS.valorUnitario! * pecaOS.quantidade;
                                    });
                                    _resetarDescontos();
                                    _calcularPrecoTotal();
                                  }
                                },
                          icon: Icon(Icons.remove_circle_outline, size: 20, color: _isViewMode ? Colors.grey[400] : Colors.grey[600]),
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                        ),
                        SizedBox(
                          width: 60,
                          height: 32,
                          child: TextFormField(
                            key: ValueKey('quantidade_${pecaOS.peca.id}_${pecaOS.quantidade}'),
                            initialValue: '${pecaOS.quantidade}',
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            enabled: !_isViewMode,
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.blue.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.blue.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: Colors.blue.shade400),
                              ),
                              filled: true,
                              fillColor: Colors.blue.shade50,
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                int novaQuantidade = int.tryParse(value) ?? 1;

                                if (novaQuantidade <= 0) {
                                  novaQuantidade = 1;
                                }

                                int totalUsadoOutrasPecas = _pecasSelecionadas
                                    .where((p) => p.peca.id == pecaOS.peca.id && p != pecaOS)
                                    .fold(0, (total, p) => total + p.quantidade);

                                if (novaQuantidade + totalUsadoOutrasPecas > pecaOS.peca.quantidadeEstoque) {
                                  _showErrorSnackBar(
                                      'Quantidade total solicitada (${novaQuantidade + totalUsadoOutrasPecas}) excede o estoque disponível (${pecaOS.peca.quantidadeEstoque} unidades)');
                                  return;
                                }

                                setState(() {
                                  pecaOS.quantidade = novaQuantidade;
                                  pecaOS.valorUnitario = pecaOS.peca.precoFinal;
                                  pecaOS.valorTotal = pecaOS.valorUnitario! * pecaOS.quantidade;
                                });
                                _resetarDescontos();
                                _calcularPrecoTotal();
                              }
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: _isViewMode
                              ? null
                              : () async {
                                  int totalUsadoOutrasPecas = _pecasSelecionadas
                                      .where((p) => p.peca.id == pecaOS.peca.id && p != pecaOS)
                                      .fold(0, (total, p) => total + p.quantidade);

                                  if ((pecaOS.quantidade + 1) + totalUsadoOutrasPecas <= pecaOS.peca.quantidadeEstoque) {
                                    setState(() {
                                      pecaOS.quantidade++;
                                      pecaOS.valorUnitario = pecaOS.peca.precoFinal;
                                      pecaOS.valorTotal = pecaOS.valorUnitario! * pecaOS.quantidade;
                                    });
                                    _resetarDescontos();
                                    _calcularPrecoTotal();
                                  } else {
                                    _showErrorSnackBar(
                                        'Não é possível aumentar quantidade. Estoque disponível: ${pecaOS.peca.quantidadeEstoque} unidades');
                                  }
                                },
                          icon: Icon(Icons.add_circle_outline, size: 20, color: _isViewMode ? Colors.grey[400] : Colors.grey[600]),
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'R\$ ${pecaOS.valorTotalCalculado.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!_isViewMode)
                      IconButton(
                        onPressed: () async => await _removerPeca(pecaOS),
                        icon: Icon(Icons.delete, color: Colors.red.shade400, size: 20),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              );
            }).toList()),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total das Peças:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'R\$ ${_calcularTotalPecas().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Nenhuma peça selecionada. Digite o código da peça e pressione Enter ou clique em Adicionar.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceSummarySection() {
    double totalPecas = _calcularTotalPecas();
    double totalServicos = _precoTotalServicos;
    double totalServicosComDesconto = totalServicos - _descontoServicos;
    double totalPecasComDesconto = totalPecas - _descontoPecas;
    double totalGeral = totalServicosComDesconto + totalPecasComDesconto;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.handyman, color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Total de Serviços:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'R\$ ${totalServicos.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (!_isViewMode) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Desconto Serviços (máx 10%):',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _descontoServicosController,
                              keyboardType: TextInputType.number,
                              onChanged: _onDescontoServicosChanged,
                              decoration: InputDecoration(
                                prefixText: 'R\$ ',
                                hintText: '0,00',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Máx: R\$ ${_calcularMaxDescontoServicos().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_descontoServicos > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal com desconto:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'R\$ ${totalServicosComDesconto.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.request_quote_outlined, color: Colors.blue.shade600, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Total de Peças:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'R\$ ${totalPecas.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                if (!_isViewMode) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Desconto Peças (máx margem lucro):',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _descontoPecasController,
                              keyboardType: TextInputType.number,
                              onChanged: _onDescontoPecasChanged,
                              decoration: InputDecoration(
                                prefixText: 'R\$ ',
                                hintText: '0,00',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                isDense: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Máx: R\$ ${_calcularMaxDescontoPecas().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_descontoPecas > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal com desconto:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'R\$ ${totalPecasComDesconto.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_descontoServicos > 0 || _descontoPecas > 0) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  if (_descontoServicos > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '(-) Desconto Serviços:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.shade800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '-R\$ ${_descontoServicos.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  if (_descontoPecas > 0) ...[
                    if (_descontoServicos > 0) const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '(-) Desconto Peças:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.shade800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '-R\$ ${_descontoPecas.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            height: 1,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(vertical: 8),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.purple.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.request_quote_outlined, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'VALOR TOTAL GERAL:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                Text(
                  'R\$ ${totalGeral.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarrantyAndPayment() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Garantia (meses)',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _garantiaMeses,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: [1, 2, 3, 6, 12, 24].map((meses) {
                    return DropdownMenuItem<int>(
                      value: meses,
                      child: Text('$meses mês${meses > 1 ? 'es' : ''}${meses == 3 ? ' (padrão legal)' : ''}'),
                    );
                  }).toList(),
                  onChanged: _isViewMode
                      ? null
                      : (value) {
                          setState(() {
                            _garantiaMeses = value ?? 3;
                          });
                        },
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Forma de Pagamento',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  value: _tipoPagamentoSelecionado?.id,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  hint: const Text('Selecione'),
                  items: (() {
                    final lista = List<TipoPagamento>.from(_tiposPagamento);
                    lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
                    return lista.map((tipo) {
                      return DropdownMenuItem<int?>(
                        value: tipo.id,
                        child: Text(tipo.nome),
                      );
                    }).toList();
                  })(),
                  onChanged: _isViewMode
                      ? null
                      : (selectedId) {
                          setState(() {
                            try {
                              _tipoPagamentoSelecionado = _tiposPagamento.firstWhere((t) => t.id == selectedId);
                            } on StateError {
                              _tipoPagamentoSelecionado = null;
                            }
                            if (_tipoPagamentoSelecionado == null ||
                                (_tipoPagamentoSelecionado?.codigo != 3 && _tipoPagamentoSelecionado?.codigo != 4)) {
                              _numeroParcelas = null;
                            }
                            if (_tipoPagamentoSelecionado == null || _tipoPagamentoSelecionado?.codigo != 6) {
                              _prazoFiadoDias = null;
                            }
                          });
                        },
                ),
                if (_tipoPagamentoSelecionado?.codigo == 4) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Número de Parcelas',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _numeroParcelas,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: List.generate(12, (i) => i + 1).map((parcelas) {
                      return DropdownMenuItem<int>(
                        value: parcelas,
                        child: Text('${parcelas}x'),
                      );
                    }).toList(),
                    onChanged: _isViewMode
                        ? null
                        : (value) {
                            setState(() {
                              _numeroParcelas = value;
                            });
                          },
                  ),
                ],
                if (_tipoPagamentoSelecionado?.codigo == 5) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Prazo (meses)',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: _prazoFiadoDias != null ? (_prazoFiadoDias! ~/ 30) : null,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: List.generate(12, (i) => i + 1).map((mes) {
                      return DropdownMenuItem<int>(
                        value: mes,
                        child: Text('$mes mês${mes > 1 ? 'es' : ''}'),
                      );
                    }).toList(),
                    onChanged: _isViewMode
                        ? null
                        : (value) {
                            setState(() {
                              _prazoFiadoDias = value != null ? value * 30 : null;
                            });
                          },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObservationsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Observações sobre o orçamento',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _observacoesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Digite observações adicionais sobre o orçamento (opcional)...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  void _onServicoToggled(Servico servico) {
    setState(() {
      if (_servicosSelecionados.any((s) => s.id == servico.id)) {
        _servicosSelecionados.removeWhere((s) => s.id == servico.id);
      } else {
        _servicosSelecionados.add(servico);
      }
      _resetarDescontos();
      _calcularPrecoTotal();
    });
  }

  Future<void> _buscarPecaPorCodigo(String codigo) async {
    if (codigo.trim().isEmpty) {
      _showErrorSnackBar('Digite o código da peça');
      return;
    }

    try {
      final peca = await PecaService.buscarPecaPorCodigo(codigo.trim());
      setState(() {
        _pecaEncontrada = peca;
      });

      if (peca != null) {
        int quantidade = 1;

        if (peca.quantidadeEstoque <= 0) {
          _showErrorSnackBar('Peça ${peca.nome} está sem estoque (${peca.quantidadeEstoque} unidades disponíveis)');
          return;
        }

        int totalJaUsado = _pecasSelecionadas.where((p) => p.peca.id == peca.id).fold(0, (total, p) => total + p.quantidade);

        if (quantidade + totalJaUsado > peca.quantidadeEstoque) {
          _showErrorSnackBar('Não é possível adicionar mais desta peça. Total usado: $totalJaUsado, Estoque: ${peca.quantidadeEstoque}');
          return;
        }

        final pecaJaAdicionada = _pecasSelecionadas.where((p) => p.peca.id == peca.id).firstOrNull;
        if (pecaJaAdicionada != null) {
          final quantidadeTotal = pecaJaAdicionada.quantidade + quantidade;

          int totalUsadoOutrasPecas =
              _pecasSelecionadas.where((p) => p.peca.id == peca.id && p != pecaJaAdicionada).fold(0, (total, p) => total + p.quantidade);

          if (quantidadeTotal + totalUsadoOutrasPecas > peca.quantidadeEstoque) {
            _showErrorSnackBar(
                'Quantidade total (${quantidadeTotal + totalUsadoOutrasPecas}) excederia o estoque disponível (${peca.quantidadeEstoque} unidades)');
            return;
          }

          setState(() {
            pecaJaAdicionada.quantidade = quantidadeTotal;
            pecaJaAdicionada.valorUnitario = peca.precoFinal;
            pecaJaAdicionada.valorTotal = pecaJaAdicionada.valorUnitario! * quantidadeTotal;
            _codigoPecaController.clear();
          });
          _resetarDescontos();
          _calcularPrecoTotal();
          _showSuccessMessage('Quantidade da peça ${peca.nome} atualizada para $quantidadeTotal');
        } else {
          final pecaOS = PecaOrdemServico(
            peca: peca,
            quantidade: quantidade,
            valorUnitario: peca.precoFinal,
            valorTotal: peca.precoFinal * quantidade,
          );
          setState(() {
            _pecasSelecionadas.add(pecaOS);
            _codigoPecaController.clear();
          });
          _resetarDescontos();
          _calcularPrecoTotal();
          _showSuccessMessage('Peça adicionada: ${peca.nome} ($quantidade unid.)');
        }
      } else {
        _showErrorSnackBar('Peça não encontrada com o código: $codigo');
      }
    } catch (e) {
      _showErrorSnackBar('Erro ao buscar peça: $e');
    }
  }

  Future<void> _removerPeca(PecaOrdemServico pecaOS) async {
    setState(() {
      _pecasSelecionadas.remove(pecaOS);
    });
    _resetarDescontos();
    _calcularPrecoTotal();
    _showSuccessMessage('Peça removida: ${pecaOS.peca.nome}');
  }

  double _calcularMaxDescontoServicos() {
    return _precoTotalServicos * 0.10;
  }

  double _calcularMaxDescontoPecas() {
    double maxDesconto = 0.0;
    for (var pecaOS in _pecasSelecionadas) {
      double margemPorUnidade = pecaOS.peca.precoFinal - pecaOS.peca.precoUnitario;
      double margemTotal = margemPorUnidade * pecaOS.quantidade;
      maxDesconto += margemTotal;
    }
    return maxDesconto;
  }

  void _onDescontoServicosChanged(String value) {
    final desconto = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    final maxDesconto = _calcularMaxDescontoServicos();

    if (desconto > maxDesconto) {
      _descontoServicosController.text = maxDesconto.toStringAsFixed(2);
      _descontoServicos = maxDesconto;
      _showErrorMessage('Desconto máximo para serviços é de 10% (R\$ ${maxDesconto.toStringAsFixed(2)})');
    } else {
      _descontoServicos = desconto;
    }
    _calcularPrecoTotal();
  }

  void _onDescontoPecasChanged(String value) {
    final desconto = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    final maxDesconto = _calcularMaxDescontoPecas();

    if (desconto > maxDesconto) {
      _descontoPecasController.text = maxDesconto.toStringAsFixed(2);
      _descontoPecas = maxDesconto;
      _showErrorMessage('Desconto máximo para peças é limitado pela margem de lucro (R\$ ${maxDesconto.toStringAsFixed(2)})');
    } else {
      _descontoPecas = desconto;
    }
    _calcularPrecoTotal();
  }

  void _resetarDescontos() {
    setState(() {
      _descontoServicos = 0.0;
      _descontoPecas = 0.0;
      _descontoServicosController.clear();
      _descontoPecasController.clear();
    });
  }

  double _calcularTotalPecas() {
    return _pecasSelecionadas.fold(0.0, (total, pecaOS) => total + (pecaOS.peca.precoFinal * pecaOS.quantidade));
  }

  void _calcularPrecoTotal() {
    setState(() {
      _precoTotalServicos = _servicosSelecionados.fold(0.0, (total, servico) => total + _getPrecoServicoPorCategoria(servico));

      final totalPecas = _calcularTotalPecas();
      _precoTotal = _precoTotalServicos + totalPecas - _descontoServicos - _descontoPecas;
    });
  }

  double _getPrecoServicoPorCategoria(Servico servico) {
    if (_categoriaSelecionada == 'Caminhonete') {
      return servico.precoCaminhonete ?? 0.0;
    } else if (_categoriaSelecionada == 'Passeio') {
      return servico.precoPasseio ?? 0.0;
    } else {
      return servico.precoPasseio ?? 0.0;
    }
  }

  void _salvarOrcamento() async {
    if (_isSaving) {
      return;
    }

    if (_clienteNomeController.text.trim().isEmpty) {
      _showErrorMessage('O nome do cliente é obrigatório');
      return;
    }

    if (_clienteCpfController.text.trim().isEmpty) {
      _showErrorMessage('O CPF do cliente é obrigatório');
      return;
    }

    if (_veiculoNomeController.text.trim().isEmpty) {
      _showErrorMessage('O nome/modelo do veículo é obrigatório');
      return;
    }

    if (_veiculoPlacaController.text.trim().isEmpty) {
      _showErrorMessage('A placa do veículo é obrigatória');
      return;
    }

    if (_queixaPrincipalController.text.trim().isEmpty) {
      _showErrorMessage('A descrição do problema/serviços é obrigatória');
      return;
    }

    if (_servicosSelecionados.isEmpty && _pecasSelecionadas.isEmpty) {
      _showErrorMessage('Selecione pelo menos um serviço ou uma peça para orçar');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final orcamento = Orcamento(
        id: _editingOrcamentoId,
        numeroOrcamento: _editingOrcamentoId != null ? _orcamentoNumberController.text : '',
        dataHora: DateTime.now(),
        clienteNome: _clienteNomeController.text.trim(),
        clienteCpf: _clienteCpfController.text.trim(),
        clienteTelefone: _clienteTelefoneController.text.trim().isNotEmpty ? _clienteTelefoneController.text.trim() : null,
        clienteEmail: _clienteEmailController.text.trim().isNotEmpty ? _clienteEmailController.text.trim() : null,
        veiculoNome: _veiculoNomeController.text.trim(),
        veiculoMarca: _veiculoMarcaController.text.trim(),
        veiculoAno: _veiculoAnoController.text.trim(),
        veiculoCor: _veiculoCorController.text.trim(),
        veiculoPlaca: _veiculoPlacaController.text.trim().toUpperCase(),
        veiculoQuilometragem: _veiculoQuilometragemController.text.trim(),
        veiculoCategoria: (_categoriaSelecionada != null && _categoriaSelecionada!.isNotEmpty) ? _categoriaSelecionada : null,
        queixaPrincipal: _queixaPrincipalController.text.trim(),
        servicosOrcados: _servicosSelecionados,
        pecasOrcadas: _pecasSelecionadas,
        precoTotal: _precoTotal,
        precoTotalServicos: _precoTotalServicos,
        precoTotalPecas: _calcularTotalPecas(),
        descontoServicos: _descontoServicos > 0 ? _descontoServicos : null,
        descontoPecas: _descontoPecas > 0 ? _descontoPecas : null,
        garantiaMeses: _garantiaMeses,
        tipoPagamento: _tipoPagamentoSelecionado,
        numeroParcelas: _numeroParcelas,
        prazoFiadoDias: _prazoFiadoDias,
        mecanico: _mecanicoSelecionado,
        consultor: _consultorSelecionado,
        observacoes: _observacoesController.text.trim().isNotEmpty ? _observacoesController.text.trim() : null,
      );

      bool sucesso;
      if (_editingOrcamentoId != null) {
        sucesso = await OrcamentoService.atualizarOrcamento(_editingOrcamentoId!, orcamento);
      } else {
        sucesso = await OrcamentoService.salvarOrcamento(orcamento);
      }

      if (sucesso) {
        _showSuccessMessage(_editingOrcamentoId != null ? 'Orçamento atualizado com sucesso' : 'Orçamento criado com sucesso');

        _clearForm();
        await _loadData();
        setState(() {
          _showForm = false;
          _editingOrcamentoId = null;
          _isSaving = false;
        });
      } else {
        setState(() {
          _isSaving = false;
        });
        _showErrorMessage('Erro ao salvar orçamento');
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      print('Erro ao salvar orçamento: $e');
      _showErrorMessage('Erro ao salvar orçamento: ${e.toString()}');
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    _showErrorMessage(message);
  }

  void _onClienteCpfChanged() {
    final cpf = _clienteCpfController.text.trim();
    if (cpf.length >= 11) {
      final cliente = _clienteByCpf[cpf];
      if (cliente != null) {
        setState(() {
          _clienteNomeController.text = cliente.nome ?? '';
          _clienteTelefoneController.text = _maskTelefone.maskText(cliente.telefone ?? '');
          _clienteEmailController.text = cliente.email ?? '';
        });
      }
    }
  }

  void _onVeiculoPlacaChanged() {
    final placa = _veiculoPlacaController.text.trim().toUpperCase();
    if (placa.length >= 7) {
      final veiculo = _veiculoByPlaca[placa];
      if (veiculo != null) {
        setState(() {
          _veiculoNomeController.text = veiculo.nome ?? '';
          _veiculoMarcaController.text = veiculo.marca?.marca ?? '';
          _veiculoAnoController.text = veiculo.ano?.toString() ?? '';
          _veiculoCorController.text = veiculo.cor ?? '';
          _veiculoQuilometragemController.text = veiculo.quilometragem?.toString() ?? '';
          _categoriaSelecionada = veiculo.categoria;
        });
        _calcularPrecoTotal();
      }
    }
  }

  Widget _buildCpfAutocomplete({required double fieldWidth}) {
    final options = _clienteByCpf.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CPF',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text == '') return const Iterable<String>.empty();
            final searchValue = textEditingValue.text.replaceAll(RegExp(r'[^0-9]'), '');
            return options.where((cpf) {
              final cpfSemMascara = cpf.replaceAll(RegExp(r'[^0-9]'), '');
              return cpfSemMascara.contains(searchValue);
            });
          },
          onSelected: (String selection) {
            final pessoa = _clienteByCpf[selection];
            if (pessoa != null) {
              final telefone = (pessoa.telefone ?? '').toString();
              setState(() {
                _clienteNomeController.text = pessoa.nome ?? '';
                _clienteCpfController.text = pessoa.cpf ?? '';
                _clienteTelefoneController.text = telefone.isNotEmpty ? _maskTelefone.maskText(telefone) : '';
                _clienteEmailController.text = pessoa.email ?? '';
              });
            }
          },
          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
            if (controller.text.isEmpty && _clienteCpfController.text.isNotEmpty) {
              controller.text = _clienteCpfController.text;
            }
            return TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: _isViewMode,
              inputFormatters: _isViewMode ? null : [FilteringTextInputFormatter.digitsOnly],
              keyboardType: _isViewMode ? null : TextInputType.number,
              onChanged: _isViewMode
                  ? null
                  : (value) {
                      _clienteCpfController.text = value;
                    },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final optList = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: optList.length,
                    itemBuilder: (context, index) {
                      final option = optList[index];
                      return ListTile(
                        dense: true,
                        title: Text(option),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLabeledController(String label, TextEditingController controller, {FocusNode? focusNode}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          readOnly: _isViewMode,
          inputFormatters: label == 'Telefone/WhatsApp' ? [_maskTelefone] : null,
          onChanged: _isViewMode ? null : (value) {},
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPlacaAutocomplete({required double fieldWidth}) {
    final options = _veiculos.map((v) => v.placa).whereType<String>().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Placa',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text == '') return const Iterable<String>.empty();
            return options.where((p) => p.toLowerCase().contains(textEditingValue.text.toLowerCase()));
          },
          onSelected: (String selection) {
            final v = _veiculoByPlaca[selection];
            if (v != null) {
              setState(() {
                _veiculoNomeController.text = v.nome;
                _veiculoMarcaController.text = v.marca?.marca ?? '';
                _veiculoAnoController.text = v.ano.toString();
                _veiculoCorController.text = v.cor;
                _veiculoPlacaController.text = v.placa;
                _veiculoQuilometragemController.text = v.quilometragem.toString();
                _categoriaSelecionada = v.categoria;
              });
              _calcularPrecoTotal();
            }
          },
          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
            if (controller.text.isEmpty && _veiculoPlacaController.text.isNotEmpty) {
              controller.text = _veiculoPlacaController.text;
            }
            return TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: _isViewMode,
              inputFormatters: _isViewMode ? null : [_maskPlaca, _upperCaseFormatter],
              onChanged: _isViewMode
                  ? null
                  : (value) {
                      _veiculoPlacaController.text = value;
                    },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final optList = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: optList.length,
                    itemBuilder: (context, index) {
                      final option = optList[index];
                      return ListTile(
                        dense: true,
                        title: Text(option),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPecaAutocomplete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buscar Peça',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        Autocomplete<Peca>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) return const Iterable<Peca>.empty();
            return _pecasDisponiveis.where((peca) {
              final searchText = textEditingValue.text.toLowerCase();
              return peca.codigoFabricante.toLowerCase().contains(searchText) ||
                  peca.nome.toLowerCase().contains(searchText) ||
                  peca.fabricante.nome.toLowerCase().contains(searchText);
            });
          },
          displayStringForOption: (Peca peca) => '${peca.codigoFabricante} - ${peca.nome} (${peca.fabricante.nome})',
          onSelected: (Peca selection) {
            setState(() {
              _pecaEncontrada = selection;
              _codigoPecaController.text = selection.codigoFabricante;
              _pecaSearchController.clear();
            });
          },
          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
            _pecaSearchController = controller;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: _isViewMode,
              onChanged: _isViewMode
                  ? null
                  : (value) {
                      if (_pecaEncontrada != null) {
                        setState(() {
                          _pecaEncontrada = null;
                        });
                      }
                    },
              decoration: InputDecoration(
                labelText: 'Código da Peça',
                hintText: 'Digite o código, nome ou fabricante...',
                prefixIcon: Icon(Icons.qr_code, color: Colors.grey[600]),
                suffixIcon: _pecaEncontrada != null
                    ? Container(
                        margin: const EdgeInsets.all(4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _pecaEncontrada!.quantidadeEstoque <= 5
                              ? Colors.red[50]
                              : _pecaEncontrada!.quantidadeEstoque <= 10
                                  ? Colors.orange[50]
                                  : Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Estoque: ${_pecaEncontrada!.quantidadeEstoque}',
                          style: TextStyle(
                            color: _pecaEncontrada!.quantidadeEstoque <= 5
                                ? Colors.red[700]
                                : _pecaEncontrada!.quantidadeEstoque <= 10
                                    ? Colors.orange[700]
                                    : Colors.green[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              onSubmitted: _isViewMode
                  ? null
                  : (value) {
                      if (_pecaEncontrada != null) {
                        _buscarPecaPorCodigo(_pecaEncontrada!.codigoFabricante);
                      } else {
                        _buscarPecaPorCodigo(value);
                      }
                      _pecaSearchController.clear();
                    },
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final optList = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400, maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: optList.length,
                    itemBuilder: (context, index) {
                      final peca = optList[index];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: peca.quantidadeEstoque <= 5
                                ? Colors.red[100]
                                : peca.quantidadeEstoque <= 10
                                    ? Colors.orange[100]
                                    : Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${peca.quantidadeEstoque}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: peca.quantidadeEstoque <= 5
                                    ? Colors.red[700]
                                    : peca.quantidadeEstoque <= 10
                                        ? Colors.orange[700]
                                        : Colors.green[700],
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          '${peca.codigoFabricante} - ${peca.nome}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fabricante: ${peca.fabricante.nome}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'Preço: R\$ ${peca.precoFinal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                        onTap: () => onSelected(peca),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoriaDropdown() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categoria do Veículo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: _categoriaSelecionada == null ? Colors.orange[300]! : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(8),
            color: _categoriaSelecionada == null ? Colors.orange[50] : Colors.grey[50],
          ),
          child: Row(
            children: [
              if (_categoriaSelecionada == null) Icon(Icons.info_outline, color: Colors.orange[600], size: 16),
              if (_categoriaSelecionada == null) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _categoriaSelecionada ?? 'Selecione um veículo para definir a categoria',
                  style: TextStyle(
                    fontSize: 16,
                    color: _categoriaSelecionada != null ? Colors.grey[700] : Colors.orange[700],
                    fontStyle: _categoriaSelecionada == null ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
