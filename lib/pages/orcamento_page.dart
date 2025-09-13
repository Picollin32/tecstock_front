import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/servico_service.dart';
import '../services/tipo_pagamento_service.dart';
import '../services/orcamento_service.dart';
import '../services/peca_service.dart';
import '../services/cliente_service.dart';
import '../services/veiculo_service.dart';
import '../services/funcionario_service.dart';
import '../utils/adaptive_phone_formatter.dart';
import '../model/servico.dart';
import '../model/tipo_pagamento.dart';
import '../model/orcamento.dart';
import '../model/peca_ordem_servico.dart';
import '../model/peca.dart';

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
  final _veiculoQuilometragemController = TextEditingController();
  final _queixaPrincipalController = TextEditingController();
  final _observacoesController = TextEditingController();

  List<dynamic> _clientes = [];
  List<dynamic> _funcionarios = [];
  List<dynamic> _veiculos = [];
  List<Servico> _servicosDisponiveis = [];
  List<TipoPagamento> _tiposPagamento = [];
  List<Peca> _pecasDisponiveis = [];
  final List<Servico> _servicosSelecionados = [];
  final List<PecaOrdemServico> _pecasSelecionadas = [];
  TipoPagamento? _tipoPagamentoSelecionado;
  int _garantiaMeses = 3;
  int? _numeroParcelas;
  String? _mecanicoSelecionado;
  String? _consultorSelecionado;
  String? _categoriaSelecionada;

  final TextEditingController _codigoPecaController = TextEditingController();
  final Map<String, dynamic> _clienteByCpf = {};
  final Map<String, dynamic> _veiculoByPlaca = {};
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

    // Adicionar listeners para autocomplete
    _clienteCpfController.addListener(_onClienteCpfChanged);
    _veiculoPlacaController.addListener(_onVeiculoPlacaChanged);

    _loadData();
    _searchController.addListener(_filtrarRecentes);

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
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
    _descontoServicosController.dispose();
    _descontoPecasController.dispose();
    _codigoPecaController.dispose();
    super.dispose();
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

      setState(() {
        _recent = results[0] as List<Orcamento>;
        _servicosDisponiveis = results[1] as List<Servico>;
        _tiposPagamento = results[2] as List<TipoPagamento>;
        _pecasDisponiveis = results[3] as List<Peca>;
        _clientes = results[4];
        _veiculos = results[5];
        _funcionarios = results[6];

        _recent.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
        _recentFiltrados = List.from(_recent);

        // Criar mapas para busca rápida
        _clienteByCpf.clear();
        for (var cliente in _clientes) {
          _clienteByCpf[cliente.cpf] = cliente;
        }

        _veiculoByPlaca.clear();
        for (var veiculo in _veiculos) {
          _veiculoByPlaca[veiculo.placa] = veiculo;
        }

        _isLoadingData = false;
      });
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
    _codigoPecaController.clear();

    setState(() {
      _servicosSelecionados.clear();
      _pecasSelecionadas.clear();
      _tipoPagamentoSelecionado = null;
      _garantiaMeses = 3;
      _numeroParcelas = null;
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
              Colors.teal.shade50,
              Colors.cyan.shade50,
              Colors.blue.shade50,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModernHeader(colorScheme),
                  const SizedBox(height: 32),
                  if (_showForm) _buildFullForm(),
                  if (!_showForm) ...[
                    _buildSearchSection(colorScheme),
                    const SizedBox(height: 24),
                    _buildRecentList(),
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
          colors: [Colors.teal.shade600, Colors.cyan.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
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
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showForm = true;
                _isViewMode = false;
                _editingOrcamentoId = null;
                _clearForm();
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Novo Orçamento'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.teal.shade700,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
              Icon(Icons.search, color: Colors.teal.shade600),
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
                borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
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
          // Header do formulário
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade600, Colors.cyan.shade600],
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
                  _editingOrcamentoId == null ? 'Novo Orçamento' : 'Editar Orçamento',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showForm = false;
                      _isViewMode = false;
                      _editingOrcamentoId = null;
                    });
                  },
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          // Conteúdo do formulário
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
                _buildFormSection('4. Queixa Principal / Problema Relatado', Icons.report_problem_outlined),
                const SizedBox(height: 16),
                _buildComplaintSection(),
                const SizedBox(height: 32),
                _buildFormSection('5. Serviços a Orçar', Icons.build_outlined),
                const SizedBox(height: 16),
                _buildServicesSelection(),
                const SizedBox(height: 32),
                _buildFormSection('6. Peças a Orçar', Icons.inventory_outlined),
                const SizedBox(height: 16),
                _buildPartsSelection(),
                const SizedBox(height: 32),
                _buildFormSection('8. Resumo de Valores', Icons.receipt_long_outlined),
                const SizedBox(height: 16),
                _buildPriceSummarySection(),
                const SizedBox(height: 32),
                _buildFormSection('9. Observações Adicionais', Icons.notes_outlined),
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
                            colors: [Colors.teal.shade600, Colors.cyan.shade600],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _salvarOrcamento,
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: Text(
                            _editingOrcamentoId != null ? 'Atualizar Orçamento' : 'Salvar Orçamento',
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            Icons.request_quote,
            color: Colors.teal.shade600,
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
            const SizedBox(height: 4),
            Text('Cliente: ${orcamento.clienteNome}'),
            Text('Veículo: ${orcamento.veiculoPlaca}'),
            Text('Status: ${orcamento.status}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'R\$ ${orcamento.precoTotal.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd/MM/yyyy').format(orcamento.dataHora),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: () {
          // Implementar ação de tap no card
        },
      ),
    );
  }

  Widget _buildFormSection(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.teal.shade600, size: 20),
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
      child: Column(
        children: [
          // Data e Hora
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Data', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _dateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Data do orçamento',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hora', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _timeController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Hora do orçamento',
                        prefixIcon: const Icon(Icons.access_time),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dados do Cliente
          Text('Dados do Cliente', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800], fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nome', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _clienteNomeController,
                      decoration: InputDecoration(
                        hintText: 'Nome do cliente',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CPF', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _clienteCpfController,
                      decoration: InputDecoration(
                        hintText: 'CPF do cliente',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      onChanged: (value) {
                        // Trigger autocomplete when CPF is typed
                        if (value.length >= 11) {
                          _onClienteCpfChanged();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Telefone', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _clienteTelefoneController,
                      inputFormatters: [_maskTelefone],
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: 'Telefone do cliente',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _clienteEmailController,
                      decoration: InputDecoration(
                        hintText: 'Email do cliente',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Dados do Veículo
          Text('Dados do Veículo', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[800], fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Veículo', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _veiculoNomeController,
                      decoration: InputDecoration(
                        hintText: 'Nome/modelo do veículo',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Marca', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _veiculoMarcaController,
                      decoration: InputDecoration(
                        hintText: 'Marca do veículo',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ano', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _veiculoAnoController,
                      decoration: InputDecoration(
                        hintText: 'Ano do veículo',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cor', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _veiculoCorController,
                      decoration: InputDecoration(
                        hintText: 'Cor do veículo',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Placa', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _veiculoPlacaController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        hintText: 'Placa do veículo',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      onChanged: (value) {
                        // Trigger autocomplete when plate is typed
                        if (value.length >= 7) {
                          _onVeiculoPlacaChanged();
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quilometragem', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _veiculoQuilometragemController,
                      decoration: InputDecoration(
                        hintText: 'Quilometragem atual',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCategoriaDropdown(),
        ],
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Defina os responsáveis pelo orçamento',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mecânico', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _mecanicoSelecionado,
                          hint: const Text('Selecione um mecânico'),
                          isExpanded: true,
                          items: _funcionarios.map<DropdownMenuItem<String>>((funcionario) {
                            return DropdownMenuItem<String>(
                              value: funcionario.nome,
                              child: Text('${funcionario.nome} (Nível ${funcionario.nivelAcesso})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _mecanicoSelecionado = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Consultor', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _consultorSelecionado,
                          hint: const Text('Selecione um consultor'),
                          isExpanded: true,
                          items: _funcionarios.map<DropdownMenuItem<String>>((funcionario) {
                            return DropdownMenuItem<String>(
                              value: funcionario.nome,
                              child: Text('${funcionario.nome} (Nível ${funcionario.nivelAcesso})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _consultorSelecionado = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
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
                'Selecione os serviços a orçar',
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
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _servicosDisponiveis.map((servico) {
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
                      Text(
                        'R\$ ${_getPrecoServicoPorCategoria(servico).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: isSelected ? Colors.white70 : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  onSelected: _isViewMode ? null : (selected) => _onServicoToggled(servico),
                  selectedColor: Colors.teal.shade400,
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? Colors.teal.shade400 : Colors.grey[300]!,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Peças a orçar',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
              ),
              if (_pecasSelecionadas.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    'Total Peças: R\$ ${_calcularTotalPecas().toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
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
                          backgroundColor: Colors.teal.shade600,
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
                if (_pecasSelecionadas.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Peças selecionadas:',
                    style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  ...(_pecasSelecionadas.map((pecaOS) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pecaOS.peca.nome,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    'Código: ${pecaOS.peca.codigoFabricante}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Qtd: ${pecaOS.quantidade}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'R\$ ${(pecaOS.peca.precoFinal * pecaOS.quantidade).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            if (!_isViewMode) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _removerPeca(pecaOS),
                                icon: Icon(Icons.remove_circle, color: Colors.red.shade400),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ],
                        ),
                      ))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummarySection() {
    final totalPecas = _calcularTotalPecas();
    final totalGeral = _precoTotalServicos + totalPecas - _descontoServicos - _descontoPecas;

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
            'Resumo Financeiro',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
          ),
          const SizedBox(height: 16),

          // Garantia e Forma de Pagamento
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Garantia (meses)', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _garantiaMeses,
                          isExpanded: true,
                          items: [1, 2, 3, 4, 5, 6, 12].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value meses'),
                            );
                          }).toList(),
                          onChanged: _isViewMode
                              ? null
                              : (value) {
                                  setState(() {
                                    _garantiaMeses = value!;
                                  });
                                },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Forma de Pagamento', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TipoPagamento>(
                          value: _tipoPagamentoSelecionado,
                          hint: const Text('Selecione a forma de pagamento'),
                          isExpanded: true,
                          items: _tiposPagamento.map((TipoPagamento tipo) {
                            return DropdownMenuItem<TipoPagamento>(
                              value: tipo,
                              child: Text(tipo.nome),
                            );
                          }).toList(),
                          onChanged: _isViewMode
                              ? null
                              : (value) {
                                  setState(() {
                                    _tipoPagamentoSelecionado = value;
                                    if (value?.codigo != 3) {
                                      _numeroParcelas = null;
                                    }
                                  });
                                },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Número de parcelas (se cartão)
          if (_tipoPagamentoSelecionado?.codigo == 3) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Número de Parcelas', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _numeroParcelas,
                            hint: const Text('Selecione o número de parcelas'),
                            isExpanded: true,
                            items: List.generate(12, (index) => index + 1).map((int value) {
                              return DropdownMenuItem<int>(
                                value: value,
                                child: Text('${value}x'),
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
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Container()), // Espaço vazio
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Descontos
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Desconto Serviços (R\$)', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descontoServicosController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0,00',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      onChanged: (value) {
                        final desconto = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
                        setState(() {
                          _descontoServicos = desconto;
                          _calcularPrecoTotal();
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
                    Text('Desconto Peças (R\$)', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descontoPecasController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0,00',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                      onChanged: (value) {
                        final desconto = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
                        setState(() {
                          _descontoPecas = desconto;
                          _calcularPrecoTotal();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Resumo de valores
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                _buildValueRow('Valor dos Serviços:', _precoTotalServicos, Colors.green),
                _buildValueRow('Valor das Peças:', totalPecas, Colors.blue),
                if (_descontoServicos > 0 || _descontoPecas > 0) ...[
                  const Divider(),
                  if (_descontoServicos > 0) _buildValueRow('(-) Desconto Serviços:', _descontoServicos, Colors.red, isNegative: true),
                  if (_descontoPecas > 0) _buildValueRow('(-) Desconto Peças:', _descontoPecas, Colors.red, isNegative: true),
                ],
                const Divider(thickness: 2),
                _buildValueRow('TOTAL GERAL:', totalGeral, Colors.purple, isBold: true),
                if (_tipoPagamentoSelecionado?.codigo == 3 && _numeroParcelas != null)
                  _buildValueRow('Valor por Parcela:', totalGeral / _numeroParcelas!, Colors.orange),
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
                borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
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

  Widget _buildValueRow(String label, double value, Color color, {bool isBold = false, bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: Colors.grey[800],
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            '${isNegative ? '-' : ''}R\$ ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
              fontSize: isBold ? 16 : 14,
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
      _calcularPrecoTotal();
    });
  }

  void _buscarPecaPorCodigo(String codigo) {
    if (codigo.isEmpty) return;

    final peca = _pecasDisponiveis.where((p) => p.codigoFabricante.toLowerCase() == codigo.toLowerCase()).firstOrNull;

    if (peca != null) {
      // Verifica se a peça já está na lista
      final pecaExistente = _pecasSelecionadas.where((ps) => ps.peca.id == peca.id).firstOrNull;

      if (pecaExistente != null) {
        // Se já existe, aumenta a quantidade
        setState(() {
          pecaExistente.quantidade++;
          _codigoPecaController.clear();
          _calcularPrecoTotal();
        });
      } else {
        // Se não existe, adiciona nova
        setState(() {
          _pecasSelecionadas.add(PecaOrdemServico(
            peca: peca,
            quantidade: 1,
          ));
          _codigoPecaController.clear();
          _calcularPrecoTotal();
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Peça com código "$codigo" não encontrada'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removerPeca(PecaOrdemServico pecaOS) {
    setState(() {
      _pecasSelecionadas.remove(pecaOS);
      _calcularPrecoTotal();
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
      // Se categoria não definida, usar preço padrão (passeio)
      return servico.precoPasseio ?? 0.0;
    }
  }

  void _salvarOrcamento() async {
    // Validações básicas
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

    try {
      final numeroOrcamento = _orcamentoNumberController.text.isNotEmpty
          ? _orcamentoNumberController.text
          : 'ORC${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

      final orcamento = Orcamento(
        id: _editingOrcamentoId,
        numeroOrcamento: numeroOrcamento,
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
        nomeMecanico: _mecanicoSelecionado,
        nomeConsultor: _consultorSelecionado,
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
        });
      } else {
        _showErrorMessage('Erro ao salvar orçamento');
      }
    } catch (e) {
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
          _veiculoMarcaController.text = veiculo.marca?.nome ?? '';
          _veiculoAnoController.text = veiculo.ano?.toString() ?? '';
          _veiculoCorController.text = veiculo.cor ?? '';
          _veiculoQuilometragemController.text = veiculo.quilometragem?.toString() ?? '';
          _categoriaSelecionada = veiculo.categoria ?? '';
        });
        _calcularPrecoTotal(); // Recalcular preços com base na categoria
      }
    }
  }

  Widget _buildPecaAutocomplete() {
    return Autocomplete<Peca>(
      displayStringForOption: (Peca option) => '${option.codigoFabricante} - ${option.nome}',
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<Peca>.empty();
        }
        return _pecasDisponiveis.where((Peca option) {
          return option.codigoFabricante.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
              option.nome.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (Peca selection) {
        _codigoPecaController.text = selection.codigoFabricante;
        _buscarPecaPorCodigo(selection.codigoFabricante);
      },
      fieldViewBuilder:
          (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Digite o código ou nome da peça',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          onSubmitted: (String value) {
            onFieldSubmitted();
          },
        );
      },
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
