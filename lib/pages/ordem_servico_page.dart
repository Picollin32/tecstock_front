import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/cliente_service.dart';
import '../utils/adaptive_phone_formatter.dart';
import '../services/veiculo_service.dart';
import '../services/checklist_service.dart';
import '../services/servico_service.dart';
import '../services/tipo_pagamento_service.dart';
import '../services/ordem_servico_service.dart';
import '../services/funcionario_service.dart';
import '../services/peca_service.dart';
import '../model/checklist.dart';
import '../model/servico.dart';
import '../model/tipo_pagamento.dart';
import '../model/ordem_servico.dart';
import '../model/peca_ordem_servico.dart';
import '../model/peca.dart';

class OrdemServicoPage extends StatelessWidget {
  const OrdemServicoPage({super.key});

  @override
  Widget build(BuildContext context) => const OrdemServicoScreen();
}

class OrdemServicoScreen extends StatefulWidget {
  const OrdemServicoScreen({super.key});

  @override
  State<OrdemServicoScreen> createState() => _OrdemServicoScreenState();
}

class _OrdemServicoScreenState extends State<OrdemServicoScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _osNumberController = TextEditingController();

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
  final _checklistController = TextEditingController();

  List<dynamic> _clientes = [];
  List<dynamic> _funcionarios = [];
  List<dynamic> _pessoasTodasClientesFuncionarios = [];
  List<dynamic> _veiculos = [];
  List<Checklist> _checklists = [];
  List<Checklist> _checklistsFiltrados = [];
  List<Servico> _servicosDisponiveis = [];
  List<TipoPagamento> _tiposPagamento = [];
  List<Peca> _pecasDisponiveis = [];
  Checklist? _checklistSelecionado;
  final List<Servico> _servicosSelecionados = [];
  final List<PecaOrdemServico> _pecasSelecionadas = [];
  TipoPagamento? _tipoPagamentoSelecionado;
  int _garantiaMeses = 3;
  int? _numeroParcelas;
  String? _mecanicoSelecionado;
  String? _consultorSelecionado;

  final TextEditingController _codigoPecaController = TextEditingController();

  late TextEditingController _pecaSearchController;
  Peca? _pecaEncontrada;
  final Map<String, dynamic> _clienteByCpf = {};
  final Map<String, dynamic> _veiculoByPlaca = {};
  bool _showForm = false;
  List<OrdemServico> _recent = [];
  List<OrdemServico> _recentFiltrados = [];
  final TextEditingController _searchController = TextEditingController();
  int? _editingOSId;
  double _precoTotal = 0.0;
  double _precoTotalServicos = 0.0;
  String? _categoriaSelecionada;
  bool _isViewMode = false;
  double _descontoServicos = 0.0;
  double _descontoPecas = 0.0;
  final TextEditingController _descontoServicosController = TextEditingController();
  final TextEditingController _descontoPecasController = TextEditingController();

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

    _loadData();
    _searchController.addListener(_filtrarRecentes);

    _fadeController.forward();
    _slideController.forward();
    _pecaSearchController = TextEditingController();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _osNumberController.dispose();
    _clienteNomeController.dispose();
    _clienteCpfController.dispose();
    _clienteTelefoneController.dispose();
    _clienteEmailController.dispose();
    _veiculoNomeController.dispose();
    _veiculoMarcaController.dispose();
    _veiculoAnoController.dispose();
    _veiculoCorController.dispose();
    _veiculoPlacaController.dispose();
    _veiculoQuilometragemController.dispose();
    _queixaPrincipalController.dispose();
    _observacoesController.dispose();
    _checklistController.dispose();
    _searchController.removeListener(_filtrarRecentes);
    _searchController.dispose();
    _descontoServicosController.dispose();
    _descontoPecasController.dispose();
    _pecaSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final clientesFuture = ClienteService.listarClientes();
      final funcionariosFuture = Funcionarioservice.listarFuncionarios();
      final veiculosFuture = VeiculoService.listarVeiculos();
      final checklistsFuture = ChecklistService.listarChecklists();
      final servicosFuture = ServicoService.listarServicos();
      final tiposPagamentoFuture = TipoPagamentoService.listarTiposPagamento();
      final ordensFuture = OrdemServicoService.listarOrdensServico();
      final pecasFuture = PecaService.listarPecas();

      final results = await Future.wait([
        clientesFuture,
        funcionariosFuture,
        veiculosFuture,
        checklistsFuture,
        servicosFuture,
        tiposPagamentoFuture,
        ordensFuture,
        pecasFuture
      ]);

      setState(() {
        _clientes = results[0];
        _funcionarios = results[1];
        _veiculos = results[2];
        _checklists = (results[3] as List<Checklist>).where((c) => c.createdAt != null).toList()
          ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
        _checklistsFiltrados = _checklists;
        _servicosDisponiveis = results[4] as List<Servico>;
        _tiposPagamento = results[5] as List<TipoPagamento>;
        _pecasDisponiveis = results[7] as List<Peca>;

        final ordensServico = results[6] as List<OrdemServico>;
        ordensServico.sort((a, b) {
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        _recent = ordensServico.take(5).toList();
        _recentFiltrados = _recent;
        _pessoasTodasClientesFuncionarios = [..._clientes, ..._funcionarios];

        for (var c in _clientes) {
          _clienteByCpf[c.cpf] = c;
        }

        for (var f in _funcionarios) {
          _clienteByCpf[f.cpf] = f;
        }
        for (var v in _veiculos) {
          _veiculoByPlaca[v.placa] = v;
        }
      });
    } catch (e) {
      print('Erro ao carregar dados: $e');
    }
  }

  void _filtrarRecentes() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _recentFiltrados = _recent;
      } else {
        _recentFiltrados = _recent
            .where((os) =>
                os.numeroOS.toLowerCase().contains(q) ||
                (os.clienteNome.toLowerCase().contains(q)) ||
                (os.veiculoPlaca.toLowerCase().contains(q)))
            .toList();
      }
    });
  }

  void _filtrarChecklists() {
    setState(() {
      _checklistsFiltrados = _checklists.where((checklist) {
        bool matchCliente = true;
        bool matchVeiculo = true;

        if (_clienteCpfController.text.isNotEmpty) {
          matchCliente = checklist.clienteCpf?.toLowerCase() == _clienteCpfController.text.toLowerCase();
        }

        if (_veiculoPlacaController.text.isNotEmpty) {
          matchVeiculo = checklist.veiculoPlaca?.toLowerCase() == _veiculoPlacaController.text.toLowerCase();
        }

        return matchCliente && matchVeiculo;
      }).toList();
    });
  }

  void _onServicoToggled(Servico servico) {
    setState(() {
      final index = _servicosSelecionados.indexWhere((s) => s.id == servico.id);
      if (index != -1) {
        _servicosSelecionados.removeAt(index);
      } else {
        _servicosSelecionados.add(servico);
      }
      _calcularPrecoTotal();
    });
  }

  void _calcularPrecoTotal() {
    double totalServicos = 0.0;

    for (var servico in _servicosSelecionados) {
      if (_categoriaSelecionada == 'Caminhonete') {
        totalServicos += servico.precoCaminhonete ?? 0.0;
      } else if (_categoriaSelecionada == 'Passeio') {
        totalServicos += servico.precoPasseio ?? 0.0;
      }
    }

    double totalPecas = _calcularTotalPecas();

    double totalServicosComDesconto = totalServicos - _descontoServicos;
    double totalPecasComDesconto = totalPecas - _descontoPecas;

    setState(() {
      _precoTotalServicos = totalServicos;
      _precoTotal = totalServicosComDesconto + totalPecasComDesconto;
    });
  }

  double _calcularTotalPecas() {
    return _pecasSelecionadas.fold(0.0, (total, pecaOS) => total + pecaOS.valorTotalCalculado);
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
      _showErrorSnackBar('Desconto máximo para serviços é de 10% (R\$ ${maxDesconto.toStringAsFixed(2)})');
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
      _showErrorSnackBar('Desconto máximo para peças é limitado pela margem de lucro (R\$ ${maxDesconto.toStringAsFixed(2)})');
    } else {
      _descontoPecas = desconto;
    }
    _calcularPrecoTotal();
  }

  double _calcularTotalPecasOS(OrdemServico? os) {
    if (os != null) {
      return os.pecasUtilizadas.fold(0.0, (total, pecaOS) => total + pecaOS.valorTotalCalculado);
    } else {
      return _calcularTotalPecas();
    }
  }

  double _calcularTotalServicosOS(OrdemServico? os) {
    if (os != null) {
      final servicosParaPDF = os.servicosRealizados;
      final categoriaVeiculo = os.veiculoCategoria;
      double totalServicos = 0.0;

      for (var servico in servicosParaPDF) {
        if (categoriaVeiculo == 'Caminhonete') {
          totalServicos += servico.precoCaminhonete ?? 0.0;
        } else if (categoriaVeiculo == 'Passeio') {
          totalServicos += servico.precoPasseio ?? 0.0;
        }
      }
      return totalServicos;
    } else {
      double totalServicos = 0.0;
      for (var servico in _servicosSelecionados) {
        if (_categoriaSelecionada == 'Caminhonete') {
          totalServicos += servico.precoCaminhonete ?? 0.0;
        } else if (_categoriaSelecionada == 'Passeio') {
          totalServicos += servico.precoPasseio ?? 0.0;
        }
      }
      return totalServicos;
    }
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
          _calcularPrecoTotal();
          _showSuccessSnackBar('Quantidade da peça ${peca.nome} atualizada para $quantidadeTotal');
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
          _calcularPrecoTotal();
          _showSuccessSnackBar('Peça adicionada: ${peca.nome} ($quantidade unid.)');
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
    _calcularPrecoTotal();
    _showSuccessSnackBar('Peça removida: ${pecaOS.peca.nome}');
  }

  Future<void> _clearFormFields() async {
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
    _osNumberController.clear();
    _checklistController.clear();
    _codigoPecaController.clear();
    _descontoServicosController.clear();
    _descontoPecasController.clear();

    setState(() {
      _checklistSelecionado = null;
      _servicosSelecionados.clear();
      _pecasSelecionadas.clear();
      _tipoPagamentoSelecionado = null;
      _garantiaMeses = 3;
      _numeroParcelas = null;
      _mecanicoSelecionado = null;
      _consultorSelecionado = null;
      _precoTotal = 0.0;
      _precoTotalServicos = 0.0;
      _categoriaSelecionada = null;
      _pecaEncontrada = null;
      _checklistsFiltrados = _checklists;
      _isViewMode = false;
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
              Icons.description,
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
                  'Ordem de Serviço',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gerencie ordens de serviço automotivo',
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
                    await _clearFormFields();
                    setState(() {
                      _editingOSId = null;
                      _showForm = false;
                    });
                  } else {
                    await _clearFormFields();
                    setState(() {
                      _showForm = true;
                    });
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showForm ? Icons.close : Icons.add_circle,
                        color: Colors.teal.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showForm ? 'Cancelar' : 'Nova OS',
                        style: TextStyle(
                          color: Colors.teal.shade600,
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
              Icon(Icons.search, color: Colors.teal.shade600),
              const SizedBox(width: 12),
              Text(
                'Buscar Ordens de Serviço',
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
              hintText: 'Pesquisar por número da OS, cliente ou placa do veículo',
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
              Icons.description,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty ? 'Nenhuma OS cadastrada' : 'Nenhum resultado encontrado',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty ? 'Clique em "Nova OS" para começar' : 'Tente ajustar os termos da busca',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.history, color: Colors.teal.shade600),
              const SizedBox(width: 12),
              Text(
                _searchController.text.isEmpty ? 'Últimas Ordens de Serviço' : 'Resultados da Busca',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_recentFiltrados.length} item${_recentFiltrados.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.teal.shade700,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentFiltrados.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey[200],
              indent: 20,
              endIndent: 20,
            ),
            itemBuilder: (context, index) {
              final os = _recentFiltrados[index];
              return _buildOSListItem(os);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOSListItem(OrdemServico os) {
    Color statusColor = Colors.blue;
    IconData statusIcon = Icons.schedule;

    switch (os.status) {
      case 'ABERTA':
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
        break;
      case 'EM_ANDAMENTO':
        statusColor = Colors.orange;
        statusIcon = Icons.build;
        break;
      case 'CONCLUIDA':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'ENCERRADA':
        statusColor = Colors.grey;
        statusIcon = Icons.lock;
        break;
      case 'CANCELADA':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade400, Colors.cyan.shade400],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.description,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Text(
              'OS ${os.numeroOS}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 12, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    _getStatusDisplayText(os.status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            if (os.clienteNome.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      os.clienteNome,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            if (os.veiculoPlaca.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    '${os.veiculoNome} - ${os.veiculoPlaca}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            if (os.precoTotal > 0) ...[
              if (os.pecasUtilizadas.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.build_circle, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Peças: R\$ ${_calcularTotalPecasOS(os).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              if (os.servicosRealizados.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.handyman, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Serviços: R\$ ${_calcularTotalServicosOS(os).toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              if ((os.descontoServicos ?? 0) > 0 || (os.descontoPecas ?? 0) > 0)
                Row(
                  children: [
                    Icon(Icons.local_offer, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Descontos: R\$ ${((os.descontoServicos ?? 0) + (os.descontoPecas ?? 0)).toStringAsFixed(2)}',
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
                    'Total: R\$ ${os.precoTotal.toStringAsFixed(2)}',
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
                  DateFormat('dd/MM/yyyy HH:mm').format(os.dataHora),
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
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.visibility_outlined,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                onPressed: () => _visualizarOS(os),
                tooltip: 'Visualizar OS',
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
                onPressed: () => _printOS(os),
                tooltip: 'Imprimir PDF',
              ),
            ),
            const SizedBox(width: 8),
            if (os.status != 'ENCERRADA')
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
                  onPressed: () => _editOS(os),
                  tooltip: 'Editar OS',
                ),
              ),
            if (os.status != 'ENCERRADA') const SizedBox(width: 8),
            if (os.status == 'ENCERRADA')
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.lock_outlined,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                  onPressed: null,
                  tooltip: 'OS Encerrada',
                ),
              )
            else ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                  onPressed: () => _encerrarOS(os),
                  tooltip: 'Encerrar OS',
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
                  onPressed: () => _confirmarExclusao(os),
                  tooltip: 'Excluir OS',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFullForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                colors: [Colors.teal.shade600, Colors.cyan.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () async {
                      await _clearFormFields();
                      setState(() {
                        _showForm = false;
                        _editingOSId = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isViewMode
                            ? 'Visualizar Ordem de Serviço'
                            : _editingOSId != null
                                ? 'Editar Ordem de Serviço'
                                : 'Nova Ordem de Serviço',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sistema de Gestão de Serviços Automotivos',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                            ),
                      ),
                    ],
                  ),
                ),
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
                    onPressed: () => _printOS(null),
                    icon: Icon(Icons.picture_as_pdf, color: Colors.teal.shade600, size: 20),
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
                if (_editingOSId != null)
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
                              ? 'Visualizando OS: ${_osNumberController.text.isNotEmpty ? _osNumberController.text : _editingOSId}'
                              : 'Editando OS: ${_osNumberController.text.isNotEmpty ? _osNumberController.text : _editingOSId}',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_editingOSId != null) const SizedBox(height: 24),
                _buildFormSection('1. Dados do Cliente e Veículo', Icons.person_outline),
                const SizedBox(height: 16),
                _buildClientVehicleInfo(),
                const SizedBox(height: 32),
                _buildFormSection('2. Responsáveis', Icons.people_outlined),
                const SizedBox(height: 16),
                _buildResponsibleSection(),
                const SizedBox(height: 32),
                _buildFormSection('3. Checklist Relacionado', Icons.assignment_outlined),
                const SizedBox(height: 16),
                _buildChecklistSelection(),
                const SizedBox(height: 32),
                _buildFormSection('4. Queixa Principal / Problema Relatado', Icons.report_problem_outlined),
                const SizedBox(height: 16),
                _buildComplaintSection(),
                const SizedBox(height: 32),
                _buildFormSection('5. Serviços a Executar', Icons.build_outlined),
                const SizedBox(height: 16),
                _buildServicesSelection(),
                const SizedBox(height: 32),
                _buildFormSection('6. Peças Utilizadas', Icons.inventory_outlined),
                const SizedBox(height: 16),
                _buildPartsSelection(),
                const SizedBox(height: 32),
                _buildFormSection('7. Garantia e Forma de Pagamento', Icons.payment_outlined),
                const SizedBox(height: 16),
                _buildWarrantyAndPayment(),
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
                            await _clearFormFields();
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
                          onPressed: _salvarOS,
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: Text(
                            _editingOSId != null ? 'Atualizar OS' : 'Salvar OS',
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
                fontWeight: FontWeight.w600,
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
            SizedBox(width: itemWidth, child: _buildLabeledController('Cliente', _clienteNomeController)),
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

  Widget _buildLabeledController(String label, TextEditingController controller) {
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
          readOnly: _isViewMode,
          inputFormatters: label == 'Telefone/WhatsApp' ? [_maskTelefone] : null,
          onChanged: _isViewMode
              ? null
              : (value) {
                  if (label == 'CPF' || label == 'Placa') {
                    _filtrarChecklists();
                  }
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
              borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildCpfAutocomplete({required double fieldWidth}) {
    final options = _pessoasTodasClientesFuncionarios.map((c) => c.cpf).whereType<String>().toList();

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
            return options.where((cpf) => cpf.toLowerCase().contains(textEditingValue.text.toLowerCase()));
          },
          onSelected: (String selection) {
            final c = _clienteByCpf[selection];
            if (c != null) {
              setState(() {
                _clienteNomeController.text = c.nome;
                _clienteCpfController.text = c.cpf;
                _clienteTelefoneController.text = _maskTelefone.maskText(c.telefone);
                _clienteEmailController.text = c.email;
              });
              _filtrarChecklists();
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
              onChanged: _isViewMode
                  ? null
                  : (value) {
                      _clienteCpfController.text = value;
                      _filtrarChecklists();
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
                  borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
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
              _filtrarChecklists();
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
              onChanged: _isViewMode
                  ? null
                  : (value) {
                      _veiculoPlacaController.text = value;
                      _filtrarChecklists();
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
                  borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
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

  Widget _buildChecklistAutocomplete() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Checklist',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        Autocomplete<Checklist>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            final baseList = _checklistsFiltrados.isNotEmpty ? _checklistsFiltrados : _checklists;
            if (textEditingValue.text == '') return baseList;
            return baseList.where((checklist) {
              final searchText = textEditingValue.text.toLowerCase();
              return checklist.numeroChecklist.toLowerCase().contains(searchText) ||
                  (checklist.clienteNome?.toLowerCase().contains(searchText) ?? false) ||
                  (checklist.veiculoPlaca?.toLowerCase().contains(searchText) ?? false);
            });
          },
          displayStringForOption: (Checklist checklist) =>
              'Checklist ${checklist.numeroChecklist}${checklist.createdAt != null ? ' - ${DateFormat('dd/MM/yyyy').format(checklist.createdAt!)}' : ''}',
          onSelected: (Checklist selection) {
            setState(() {
              _checklistSelecionado = selection;
              _checklistController.text = 'Checklist ${selection.numeroChecklist}';
              if (selection.queixaPrincipal != null && selection.queixaPrincipal!.isNotEmpty) {
                _queixaPrincipalController.text = selection.queixaPrincipal!;
              }
            });
          },
          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
            if (_checklistSelecionado != null && controller.text.isEmpty) {
              controller.text = 'Checklist ${_checklistSelecionado!.numeroChecklist}';
            }
            return TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: _isViewMode,
              decoration: InputDecoration(
                hintText: _isViewMode ? 'Visualização' : 'Digite para buscar um checklist...',
                suffixIcon: _checklistSelecionado != null && !_isViewMode
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[400]),
                        onPressed: () {
                          controller.clear();
                          setState(() {
                            _checklistSelecionado = null;
                            _checklistController.clear();
                          });
                        },
                      )
                    : null,
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final optList = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.8,
                    maxHeight: 200,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: optList.length,
                    itemBuilder: (context, index) {
                      final checklist = optList[index];
                      return InkWell(
                        onTap: () => onSelected(checklist),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: index < optList.length - 1 ? Colors.grey[200]! : Colors.transparent,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Checklist ${checklist.numeroChecklist}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              if (checklist.createdAt != null)
                                Text(
                                  DateFormat('dd/MM/yyyy').format(checklist.createdAt!),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              if (checklist.clienteNome != null && checklist.clienteNome!.isNotEmpty)
                                Text(
                                  'Cliente: ${checklist.clienteNome}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              if (checklist.veiculoPlaca != null && checklist.veiculoPlaca!.isNotEmpty)
                                Text(
                                  'Placa: ${checklist.veiculoPlaca}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                            ],
                          ),
                        ),
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

  Widget _buildChecklistSelection() {
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
            'Selecione um checklist relacionado',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 12),
          if (_checklistsFiltrados.isEmpty)
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
                  Expanded(
                    child: Text(
                      'Nenhum checklist encontrado para este cliente/veículo. Insira os dados acima para filtrar.',
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            )
          else
            _buildChecklistAutocomplete(),
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
      child: TextField(
        controller: _queixaPrincipalController,
        readOnly: true,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: 'Queixa principal será preenchida automaticamente pelo checklist selecionado',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.info_outline, color: Colors.grey[600]),
          filled: true,
          fillColor: Colors.grey[100],
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
            borderSide: BorderSide(color: Colors.grey[400]!, width: 1),
          ),
          contentPadding: const EdgeInsets.all(16),
        ),
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
                                _calcularPrecoTotal();
                              }
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: _isViewMode
                              ? null
                              : () {
                                  int totalUsadoOutrasPecas = _pecasSelecionadas
                                      .where((p) => p.peca.id == pecaOS.peca.id && p != pecaOS)
                                      .fold(0, (total, p) => total + p.quantidade);

                                  if ((pecaOS.quantidade + 1) + totalUsadoOutrasPecas <= pecaOS.peca.quantidadeEstoque) {
                                    setState(() {
                                      pecaOS.quantidade++;
                                      pecaOS.valorUnitario = pecaOS.peca.precoFinal;
                                      pecaOS.valorTotal = pecaOS.valorUnitario! * pecaOS.quantidade;
                                    });
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
                DropdownButtonFormField<String>(
                  value: _mecanicoSelecionado,
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
                      borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  hint: const Text('Selecione um mecânico'),
                  items: _funcionarios.where((funcionario) => funcionario.nivelAcesso == 2).map((funcionario) {
                    return DropdownMenuItem<String>(
                      value: funcionario.nome,
                      child: Text(funcionario.nome),
                    );
                  }).toList(),
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
                DropdownButtonFormField<String>(
                  value: _consultorSelecionado,
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
                      borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  hint: const Text('Selecione um consultor'),
                  items: _funcionarios.where((funcionario) => funcionario.nivelAcesso == 1).map((funcionario) {
                    return DropdownMenuItem<String>(
                      value: funcionario.nome,
                      child: Text(funcionario.nome),
                    );
                  }).toList(),
                  onChanged: _isViewMode
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
                      borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
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
                DropdownButtonFormField<TipoPagamento>(
                  value: _tipoPagamentoSelecionado,
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
                      borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  hint: const Text('Selecione'),
                  items: _tiposPagamento.map((tipo) {
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
                            if (value?.codigo != 3 && value?.codigo != 4) {
                              _numeroParcelas = null;
                            }
                          });
                        },
                ),
                if (_tipoPagamentoSelecionado?.codigo == 3) ...[
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
                        borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
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
                if (_tipoPagamentoSelecionado?.codigo == 6) ...[
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
                        borderSide: BorderSide(color: Colors.teal.shade400, width: 2),
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
                              _numeroParcelas = value;
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
      child: TextField(
        controller: _observacoesController,
        readOnly: _isViewMode,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'Observações adicionais sobre o serviço...',
          hintStyle: TextStyle(color: Colors.grey[500]),
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
                        Icon(Icons.build_circle, color: Colors.blue.shade600, size: 20),
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
                    const Icon(Icons.receipt_long, color: Colors.white, size: 20),
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

  Future<void> _salvarOS() async {
    if (_clienteNomeController.text.isEmpty || _clienteCpfController.text.isEmpty) {
      _showErrorSnackBar('Por favor, preencha os dados do cliente');
      return;
    }

    if (_veiculoPlacaController.text.isEmpty) {
      _showErrorSnackBar('Por favor, preencha os dados do veículo');
      return;
    }

    if (_categoriaSelecionada == null) {
      _showErrorSnackBar('Por favor, selecione um veículo para definir a categoria');
      return;
    }

    if (_servicosSelecionados.isEmpty) {
      _showErrorSnackBar('Por favor, selecione pelo menos um serviço');
      return;
    }

    try {
      final ordemServico = OrdemServico(
        id: _editingOSId,
        numeroOS: _editingOSId != null ? _osNumberController.text : '',
        dataHora: DateTime.now(),
        clienteNome: _clienteNomeController.text,
        clienteCpf: _clienteCpfController.text,
        clienteTelefone: _clienteTelefoneController.text.isEmpty ? null : _clienteTelefoneController.text,
        clienteEmail: _clienteEmailController.text.isEmpty ? null : _clienteEmailController.text,
        veiculoNome: _veiculoNomeController.text,
        veiculoMarca: _veiculoMarcaController.text,
        veiculoAno: _veiculoAnoController.text,
        veiculoCor: _veiculoCorController.text,
        veiculoPlaca: _veiculoPlacaController.text,
        veiculoQuilometragem: _veiculoQuilometragemController.text,
        veiculoCategoria: _categoriaSelecionada,
        checklistId: _checklistSelecionado?.id,
        queixaPrincipal: _queixaPrincipalController.text,
        servicosRealizados: _servicosSelecionados,
        pecasUtilizadas: _pecasSelecionadas,
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
        observacoes: _observacoesController.text.isEmpty ? null : _observacoesController.text,
      );

      print('Tentando ${_editingOSId != null ? "atualizar" : "salvar"} OS...');
      print('Serviços selecionados: ${_servicosSelecionados.length}');
      print('Peças selecionadas: ${_pecasSelecionadas.length}');

      bool sucesso;
      if (_editingOSId != null) {
        print('Atualizando OS ID: $_editingOSId');
        sucesso = await OrdemServicoService.atualizarOrdemServico(_editingOSId!, ordemServico);
      } else {
        print('Salvando nova OS');
        sucesso = await OrdemServicoService.salvarOrdemServico(ordemServico);
      }

      if (sucesso) {
        _showSuccessSnackBar(_editingOSId != null ? 'OS atualizada com sucesso' : 'OS criada com sucesso');
        await _clearFormFields();
        await _loadData();
        setState(() {
          _showForm = false;
          _editingOSId = null;
        });
      } else {
        _showErrorSnackBar('Erro ao salvar OS');
      }
    } catch (e) {
      print('Erro ao salvar OS: $e');
      _showErrorSnackBar('Erro ao salvar OS: ${e.toString()}');
    }
  }

  void _printOS(OrdemServico? os) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => pw.Column(
          children: [
            _buildPdfHeader(os),
            pw.SizedBox(height: 16),
            _buildPdfClientVehicleData(os),
            pw.SizedBox(height: 12),
            _buildPdfSection(
              'QUEIXA PRINCIPAL / PROBLEMA RELATADO',
              [],
              content:
                  os?.queixaPrincipal ?? (_queixaPrincipalController.text.isNotEmpty ? _queixaPrincipalController.text : 'Não informado'),
              compact: true,
            ),
            pw.SizedBox(height: 12),
            _buildPdfServicesSection(os),
            pw.SizedBox(height: 12),
            _buildPdfPartsSection(os),
            pw.SizedBox(height: 12),
            _buildPdfPricingSection(os),
            pw.SizedBox(height: 12),
            _buildPdfSection(
              'OBSERVAÇÕES',
              [],
              content: os?.observacoes ??
                  (_observacoesController.text.isNotEmpty ? _observacoesController.text : 'Nenhuma observação adicional'),
              compact: true,
            ),
          ],
        ),
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => _buildSignaturePage(os),
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  pw.Widget _buildPdfHeader(OrdemServico? os) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColors.teal600, PdfColors.cyan600],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      padding: const pw.EdgeInsets.all(16),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ORDEM DE SERVIÇO',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Text('Data: ${DateFormat('dd/MM/yyyy').format(os?.dataHora ?? DateTime.now())}',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                    pw.SizedBox(width: 20),
                    pw.Text('Hora: ${DateFormat('HH:mm').format(os?.dataHora ?? DateTime.now())}',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                  ],
                ),
                pw.SizedBox(height: 6),
                if ((os?.checklistId != null) || (_checklistSelecionado != null))
                  pw.Text(
                    'Checklist: ${os?.checklistId?.toString() ?? _checklistSelecionado!.numeroChecklist}',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.white),
                  ),
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
              'OS #${os?.numeroOS ?? (_osNumberController.text.isNotEmpty ? _osNumberController.text : DateTime.now().millisecondsSinceEpoch.toString().substring(8))}',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfClientVehicleData(OrdemServico? os) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildPdfSection(
            'DADOS DO CLIENTE',
            [
              ['Nome:', os?.clienteNome ?? _clienteNomeController.text],
              ['CPF:', os?.clienteCpf ?? _clienteCpfController.text],
              ['Telefone:', os?.clienteTelefone ?? _clienteTelefoneController.text],
              ['Email:', os?.clienteEmail ?? _clienteEmailController.text],
            ],
            compact: true,
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _buildPdfSection(
            'DADOS DO VEÍCULO',
            [
              ['Veículo:', os?.veiculoNome ?? _veiculoNomeController.text],
              ['Marca:', os?.veiculoMarca ?? _veiculoMarcaController.text],
              ['Ano/Modelo:', os?.veiculoAno ?? _veiculoAnoController.text],
              ['Cor:', os?.veiculoCor ?? _veiculoCorController.text],
              ['Placa:', os?.veiculoPlaca ?? _veiculoPlacaController.text],
              ['Quilometragem:', os?.veiculoQuilometragem ?? _veiculoQuilometragemController.text],
            ],
            compact: true,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfSection(String title, List<List<String>> data, {String? content, bool compact = false}) {
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

  pw.Widget _buildPdfServicesSection(OrdemServico? os) {
    final servicosParaPDF = os?.servicosRealizados ?? _servicosSelecionados;
    final categoriaVeiculo = os?.veiculoCategoria ?? _categoriaSelecionada;

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
              'SERVIÇOS REALIZADOS',
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

  pw.Widget _buildPdfPartsSection(OrdemServico? os) {
    final pecasParaPDF = os?.pecasUtilizadas ?? _pecasSelecionadas;

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
              'PEÇAS UTILIZADAS',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Nenhuma peça foi utilizada neste serviço.',
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
              'PEÇAS UTILIZADAS',
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

  pw.Widget _buildPdfPricingSection(OrdemServico? os) {
    final tipoPagamento = os?.tipoPagamento ?? _tipoPagamentoSelecionado;
    final numeroParcelas = os?.numeroParcelas ?? _numeroParcelas;
    final garantiaMeses = os?.garantiaMeses ?? _garantiaMeses;

    final pecasParaPDF = os?.pecasUtilizadas ?? _pecasSelecionadas;
    final totalPecas = pecasParaPDF.fold(0.0, (total, pecaOS) => total + pecaOS.valorTotalCalculado);

    final totalServicos = _calcularTotalServicosOS(os);

    final descontoServicos = os?.descontoServicos ?? _descontoServicos;
    final descontoPecas = os?.descontoPecas ?? _descontoPecas;

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

  pw.Widget _buildSignaturePage(OrdemServico? os) {
    return pw.Column(
      children: [
        _buildPdfHeader(os),
        pw.SizedBox(height: 24),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
          ),
          padding: const pw.EdgeInsets.all(16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'RESUMO DA ORDEM DE SERVIÇO',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildResumoItem('Cliente:', os?.clienteNome ?? _clienteNomeController.text),
                        _buildResumoItem('CPF:', os?.clienteCpf ?? _clienteCpfController.text),
                        _buildResumoItem('Telefone:', os?.clienteTelefone ?? _clienteTelefoneController.text),
                        _buildResumoItem('Veículo:', os?.veiculoNome ?? _veiculoNomeController.text),
                        _buildResumoItem('Placa:', os?.veiculoPlaca ?? _veiculoPlacaController.text),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildResumoItem('Serviços:', () {
                          final servicosLength = os != null ? (os.servicosRealizados.length) : _servicosSelecionados.length;
                          return '$servicosLength item${servicosLength != 1 ? 's' : ''}';
                        }()),
                        _buildResumoItem('Peças:', () {
                          final pecasLength = os != null ? (os.pecasUtilizadas.length) : _pecasSelecionadas.length;
                          return '$pecasLength item${pecasLength != 1 ? 's' : ''}';
                        }()),
                        _buildResumoItem('Valor Serviços:', 'R\$ ${_calcularTotalServicosOS(os).toStringAsFixed(2)}'),
                        _buildResumoItem('Valor Peças:', 'R\$ ${_calcularTotalPecasOS(os).toStringAsFixed(2)}'),
                        if ((os?.descontoServicos ?? _descontoServicos) > 0)
                          _buildResumoItem('(-) Desc. Serviços:', '-R\$ ${(os?.descontoServicos ?? _descontoServicos).toStringAsFixed(2)}',
                              isDesconto: true),
                        if ((os?.descontoPecas ?? _descontoPecas) > 0)
                          _buildResumoItem('(-) Desc. Peças:', '-R\$ ${(os?.descontoPecas ?? _descontoPecas).toStringAsFixed(2)}',
                              isDesconto: true),
                        _buildResumoItem('TOTAL GERAL:', () {
                          final totalServicos = _calcularTotalServicosOS(os);
                          final totalPecas = _calcularTotalPecasOS(os);
                          final descontoServicos = os?.descontoServicos ?? _descontoServicos;
                          final descontoPecas = os?.descontoPecas ?? _descontoPecas;
                          final totalComDesconto = (totalServicos - descontoServicos) + (totalPecas - descontoPecas);
                          return 'R\$ ${totalComDesconto.toStringAsFixed(2)}';
                        }(), isTotal: true),
                        if ((os?.tipoPagamento ?? _tipoPagamentoSelecionado) != null)
                          _buildResumoItem('Pagamento:', (os?.tipoPagamento ?? _tipoPagamentoSelecionado)!.nome),
                        if ((os?.tipoPagamento ?? _tipoPagamentoSelecionado)?.codigo == 3 &&
                            (os?.numeroParcelas ?? _numeroParcelas) != null)
                          _buildResumoItem('Parcelas:', () {
                            final parcelas = (os?.numeroParcelas ?? _numeroParcelas)!;
                            final totalServicos = _calcularTotalServicosOS(os);
                            final totalPecas = _calcularTotalPecasOS(os);
                            final descontoServicos = os?.descontoServicos ?? _descontoServicos;
                            final descontoPecas = os?.descontoPecas ?? _descontoPecas;
                            final totalComDesconto = (totalServicos - descontoServicos) + (totalPecas - descontoPecas);
                            final raw = totalComDesconto / parcelas;
                            final rounded = double.parse(raw.toStringAsFixed(2));
                            final ultima = double.parse((totalComDesconto - rounded * (parcelas - 1)).toStringAsFixed(2));
                            if (ultima != rounded) {
                              return '${parcelas}x de R\$ ${rounded.toStringAsFixed(2)} (última R\$ ${ultima.toStringAsFixed(2)})';
                            }
                            return '${parcelas}x de R\$ ${rounded.toStringAsFixed(2)}';
                          }()),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.Spacer(),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
          ),
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            children: [
              pw.Text(
                'ASSINATURAS',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                  color: PdfColors.blue900,
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Column(
                children: [
                  pw.Container(
                    width: double.infinity,
                    height: 80,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'Assinatura do Cliente',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    '${os?.clienteNome ?? _clienteNomeController.text} - CPF: ${os?.clienteCpf ?? _clienteCpfController.text}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 32),
              pw.Column(
                children: [
                  pw.Container(
                    width: double.infinity,
                    height: 80,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'Assinatura do Mecânico Responsável',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Nome: _________________________ Data: ___/___/______',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Text(
                  'Declaro que autorizo a execução dos serviços descritos nesta ordem de serviço, estando ciente dos valores e prazos acordados.',
                  style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Center(
          child: pw.Text(
            'TecStock - Sistema de Gestão Automotiva',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildResumoItem(String label, String value, {bool isTotal = false, bool isDesconto = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: isTotal ? 11 : 10,
                fontWeight: pw.FontWeight.bold,
                color: isTotal
                    ? PdfColors.green700
                    : isDesconto
                        ? PdfColors.red700
                        : PdfColors.black,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: isTotal ? 11 : 10,
                fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: isTotal
                    ? PdfColors.green700
                    : isDesconto
                        ? PdfColors.red700
                        : PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editOS(OrdemServico os) async {
    if (os.status == 'ENCERRADA') {
      _showErrorSnackBar('Não é possível editar uma OS encerrada');
      return;
    }

    try {
      final osCompleta = await OrdemServicoService.buscarOrdemServicoPorId(os.id!);
      if (osCompleta != null) {
        setState(() {
          _editingOSId = osCompleta.id;
          _osNumberController.text = osCompleta.numeroOS;
          _dateController.text = DateFormat('dd/MM/yyyy').format(osCompleta.dataHora);
          _timeController.text = DateFormat('HH:mm').format(osCompleta.dataHora);
          _clienteNomeController.text = osCompleta.clienteNome;
          _clienteCpfController.text = osCompleta.clienteCpf;
          _clienteTelefoneController.text = _maskTelefone.maskText(osCompleta.clienteTelefone);
          _clienteEmailController.text = osCompleta.clienteEmail ?? '';
          _veiculoNomeController.text = osCompleta.veiculoNome;
          _veiculoMarcaController.text = osCompleta.veiculoMarca;
          _veiculoAnoController.text = osCompleta.veiculoAno;
          _veiculoCorController.text = osCompleta.veiculoCor;
          _veiculoPlacaController.text = osCompleta.veiculoPlaca;
          _veiculoQuilometragemController.text = osCompleta.veiculoQuilometragem;
          _queixaPrincipalController.text = osCompleta.queixaPrincipal;
          _observacoesController.text = osCompleta.observacoes ?? '';
          _garantiaMeses = osCompleta.garantiaMeses;
          _precoTotal = osCompleta.precoTotal;
          _precoTotalServicos = osCompleta.precoTotalServicos ?? 0.0;
          _descontoServicos = osCompleta.descontoServicos ?? 0.0;
          _descontoPecas = osCompleta.descontoPecas ?? 0.0;
          _descontoServicosController.text = _descontoServicos > 0 ? _descontoServicos.toStringAsFixed(2) : '';
          _descontoPecasController.text = _descontoPecas > 0 ? _descontoPecas.toStringAsFixed(2) : '';
          _numeroParcelas = osCompleta.numeroParcelas;
          _mecanicoSelecionado = osCompleta.nomeMecanico;
          _consultorSelecionado = osCompleta.nomeConsultor;

          if (osCompleta.checklistId != null) {
            _checklistSelecionado = _checklists.where((c) => c.id == osCompleta.checklistId).firstOrNull;
            if (_checklistSelecionado != null) {
              _checklistController.text = 'Checklist ${_checklistSelecionado!.numeroChecklist}';
            }
          }

          if (osCompleta.tipoPagamento != null) {
            _tipoPagamentoSelecionado = _tiposPagamento.where((tp) => tp.id == osCompleta.tipoPagamento!.id).firstOrNull;
          }

          _categoriaSelecionada = osCompleta.veiculoCategoria;

          if (_categoriaSelecionada == null || _categoriaSelecionada!.isEmpty) {
            final veiculo = _veiculoByPlaca[osCompleta.veiculoPlaca];
            if (veiculo != null) {
              _categoriaSelecionada = veiculo.categoria;
            }
          }

          _servicosSelecionados.clear();
          if (osCompleta.servicosRealizados.isNotEmpty) {
            for (var servicoOS in osCompleta.servicosRealizados) {
              var servicoEncontrado = _servicosDisponiveis.where((s) => s.id == servicoOS.id).firstOrNull;

              servicoEncontrado ??= _servicosDisponiveis.where((s) => s.nome == servicoOS.nome).firstOrNull;

              if (servicoEncontrado != null) {
                _servicosSelecionados.add(servicoEncontrado);
              } else {
                _servicosSelecionados.add(servicoOS);
              }
            }
          }

          _pecasSelecionadas.clear();
          if (osCompleta.pecasUtilizadas.isNotEmpty) {
            for (var pecaOS in osCompleta.pecasUtilizadas) {
              _pecasSelecionadas.add(PecaOrdemServico(
                id: pecaOS.id,
                peca: pecaOS.peca,
                quantidade: pecaOS.quantidade,
                valorUnitario: pecaOS.valorUnitario,
                valorTotal: pecaOS.valorTotal,
              ));
            }
          }

          _showForm = true;
        });

        _calcularPrecoTotal();
        _slideController.forward();
      }
    } catch (e) {
      print('Erro ao carregar OS para edição: $e');
      _showErrorSnackBar('Erro ao carregar dados da OS');
    }
  }

  Future<void> _confirmarExclusao(OrdemServico os) async {
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
        content: Text('Deseja realmente excluir a OS ${os.numeroOS}? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (os.id != null) {
                final sucesso = await OrdemServicoService.excluirOrdemServico(os.id!);
                if (sucesso) {
                  await _loadData();
                  _showSuccessSnackBar('OS excluída com sucesso');
                } else {
                  _showErrorSnackBar('Erro ao excluir OS');
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

  Future<void> _visualizarOS(OrdemServico os) async {
    try {
      final osCompleta = await OrdemServicoService.buscarOrdemServicoPorId(os.id!);
      if (osCompleta != null) {
        setState(() {
          _isViewMode = true;
          _editingOSId = osCompleta.id;
          _osNumberController.text = osCompleta.numeroOS;
          _dateController.text = DateFormat('dd/MM/yyyy').format(osCompleta.dataHora);
          _timeController.text = DateFormat('HH:mm').format(osCompleta.dataHora);
          _clienteNomeController.text = osCompleta.clienteNome;
          _clienteCpfController.text = osCompleta.clienteCpf;
          _clienteTelefoneController.text = osCompleta.clienteTelefone ?? '';
          _clienteEmailController.text = osCompleta.clienteEmail ?? '';
          _veiculoNomeController.text = osCompleta.veiculoNome;
          _veiculoMarcaController.text = osCompleta.veiculoMarca;
          _veiculoAnoController.text = osCompleta.veiculoAno;
          _veiculoCorController.text = osCompleta.veiculoCor;
          _veiculoPlacaController.text = osCompleta.veiculoPlaca;
          _veiculoQuilometragemController.text = osCompleta.veiculoQuilometragem;
          _queixaPrincipalController.text = osCompleta.queixaPrincipal;
          _observacoesController.text = osCompleta.observacoes ?? '';
          _garantiaMeses = osCompleta.garantiaMeses;
          _precoTotal = osCompleta.precoTotal;
          _precoTotalServicos = osCompleta.precoTotalServicos ?? 0.0;
          _descontoServicos = osCompleta.descontoServicos ?? 0.0;
          _descontoPecas = osCompleta.descontoPecas ?? 0.0;
          _descontoServicosController.text = _descontoServicos > 0 ? _descontoServicos.toStringAsFixed(2) : '';
          _descontoPecasController.text = _descontoPecas > 0 ? _descontoPecas.toStringAsFixed(2) : '';
          _numeroParcelas = osCompleta.numeroParcelas;
          _mecanicoSelecionado = osCompleta.nomeMecanico;
          _consultorSelecionado = osCompleta.nomeConsultor;

          if (osCompleta.checklistId != null) {
            _checklistSelecionado = _checklists.where((c) => c.id == osCompleta.checklistId).firstOrNull;
            if (_checklistSelecionado != null) {
              _checklistController.text = 'Checklist ${_checklistSelecionado!.numeroChecklist}';
            }
          }

          if (osCompleta.tipoPagamento != null) {
            _tipoPagamentoSelecionado = _tiposPagamento.where((tp) => tp.id == osCompleta.tipoPagamento!.id).firstOrNull;
          }

          _categoriaSelecionada = osCompleta.veiculoCategoria;

          if (_categoriaSelecionada == null || _categoriaSelecionada!.isEmpty) {
            final veiculo = _veiculoByPlaca[osCompleta.veiculoPlaca];
            if (veiculo != null) {
              _categoriaSelecionada = veiculo.categoria;
            }
          }

          _servicosSelecionados.clear();
          if (osCompleta.servicosRealizados.isNotEmpty) {
            for (var servicoOS in osCompleta.servicosRealizados) {
              var servicoEncontrado = _servicosDisponiveis.where((s) => s.id == servicoOS.id).firstOrNull;

              servicoEncontrado ??= _servicosDisponiveis.where((s) => s.nome == servicoOS.nome).firstOrNull;

              if (servicoEncontrado != null) {
                _servicosSelecionados.add(servicoEncontrado);
              } else {
                _servicosSelecionados.add(servicoOS);
              }
            }
          }

          _pecasSelecionadas.clear();
          if (osCompleta.pecasUtilizadas.isNotEmpty) {
            for (var pecaOS in osCompleta.pecasUtilizadas) {
              final pecaComValores = PecaOrdemServico(
                id: pecaOS.id,
                peca: pecaOS.peca,
                quantidade: pecaOS.quantidade,
                valorUnitario: pecaOS.valorUnitario,
                valorTotal: pecaOS.valorTotal,
              );
              _pecasSelecionadas.add(pecaComValores);
            }
          }

          _showForm = true;
        });

        _calcularPrecoTotal();
        _slideController.forward();
      }
    } catch (e) {
      print('Erro ao carregar OS para visualização: $e');
      _showErrorSnackBar('Erro ao carregar dados da OS');
    }
  }

  Future<void> _encerrarOS(OrdemServico os) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.check_circle, color: Colors.green.shade600),
            ),
            const SizedBox(width: 12),
            const Text('Encerrar OS'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deseja realmente encerrar a OS ${os.numeroOS}?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Após encerrada, a OS não poderá mais ser editada ou excluída.',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
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
              try {
                final success = await OrdemServicoService.atualizarStatus(os.id!, 'ENCERRADA');
                if (success) {
                  await _loadData();
                  _showSuccessSnackBar('OS encerrada com sucesso');
                } else {
                  _showErrorSnackBar('Erro ao encerrar OS');
                }
              } catch (e) {
                _showErrorSnackBar('Erro ao encerrar OS: ${e.toString()}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Encerrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _getStatusDisplayText(String status) {
    switch (status) {
      case 'ABERTA':
        return 'Aberta';
      case 'EM_ANDAMENTO':
        return 'Em Andamento';
      case 'CONCLUIDA':
        return 'Concluída';
      case 'ENCERRADA':
        return 'Encerrada';
      default:
        return status;
    }
  }
}
