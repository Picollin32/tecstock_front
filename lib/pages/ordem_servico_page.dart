import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/cliente_service.dart';
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

  // Controllers básicos
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _osNumberController = TextEditingController();

  // Controllers do cliente
  final _clienteNomeController = TextEditingController();
  final _clienteCpfController = TextEditingController();
  final _clienteTelefoneController = TextEditingController();
  final _clienteEmailController = TextEditingController();

  // Controllers do veículo
  final _veiculoNomeController = TextEditingController();
  final _veiculoMarcaController = TextEditingController();
  final _veiculoAnoController = TextEditingController();
  final _veiculoCorController = TextEditingController();
  final _veiculoPlacaController = TextEditingController();
  final _veiculoQuilometragemController = TextEditingController();

  // Controllers da OS
  final _queixaPrincipalController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _checklistController = TextEditingController(); // Adicionado para o autocomplete

  // Dados para dropdowns e autocomplete
  List<dynamic> _clientes = [];
  List<dynamic> _funcionarios = [];
  List<dynamic> _pessoasTodasClientesFuncionarios = []; // Lista combinada
  List<dynamic> _veiculos = [];
  List<Checklist> _checklists = [];
  List<Checklist> _checklistsFiltrados = [];
  List<Servico> _servicosDisponiveis = [];
  List<TipoPagamento> _tiposPagamento = [];

  // Dados selecionados
  Checklist? _checklistSelecionado;
  List<Servico> _servicosSelecionados = [];
  List<PecaOrdemServico> _pecasSelecionadas = [];
  TipoPagamento? _tipoPagamentoSelecionado;
  int _garantiaMeses = 3; // Padrão de 3 meses por lei

  // Controllers para peças
  final TextEditingController _codigoPecaController = TextEditingController();

  // Peça encontrada na última busca
  Peca? _pecaEncontrada;

  // Mapas para autocomplete
  final Map<String, dynamic> _clienteByCpf = {};
  final Map<String, dynamic> _veiculoByPlaca = {};

  // Controle de formulário
  bool _showForm = false;
  List<OrdemServico> _recent = [];
  List<OrdemServico> _recentFiltrados = [];
  final TextEditingController _searchController = TextEditingController();
  int? _editingOSId;

  // Preço total e categoria do veículo
  double _precoTotal = 0.0;
  String? _categoriaSelecionada; // Modificado para aceitar null

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
    _checklistController.dispose(); // Adicionado
    _searchController.removeListener(_filtrarRecentes);
    _searchController.dispose();
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

      final results = await Future.wait(
          [clientesFuture, funcionariosFuture, veiculosFuture, checklistsFuture, servicosFuture, tiposPagamentoFuture, ordensFuture]);

      setState(() {
        _clientes = results[0];
        _funcionarios = results[1];
        _veiculos = results[2];
        _checklists = (results[3] as List<Checklist>).where((c) => c.createdAt != null).toList()
          ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!)); // Ordenar por data decrescente
        _checklistsFiltrados = _checklists;
        _servicosDisponiveis = results[4] as List<Servico>;
        _tiposPagamento = results[5] as List<TipoPagamento>;

        final ordensServico = results[6] as List<OrdemServico>;
        _recent = ordensServico.reversed.take(5).toList();
        _recentFiltrados = _recent;

        // Criar lista combinada de clientes e funcionários
        _pessoasTodasClientesFuncionarios = [..._clientes, ..._funcionarios];

        // Construir mapas para autocomplete
        for (var c in _clientes) {
          _clienteByCpf[c.cpf] = c;
        }
        // Adicionar funcionários ao mapa também
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
      // Usar preço exato baseado na categoria do veículo selecionado
      if (_categoriaSelecionada == 'Caminhonete') {
        totalServicos += servico.precoCaminhonete ?? 0.0;
      } else if (_categoriaSelecionada == 'Passeio') {
        totalServicos += servico.precoPasseio ?? 0.0;
      }
      // Se não há categoria definida, o preço não é incluído
    }

    double totalPecas = _calcularTotalPecas();

    setState(() {
      _precoTotal = totalServicos + totalPecas;
    });
  }

  double _calcularTotalPecas() {
    return _pecasSelecionadas.fold(0.0, (total, pecaOS) => total + pecaOS.valorTotal);
  }

  double _calcularTotalPecasOS(OrdemServico? os) {
    if (os != null) {
      return os.pecasUtilizadas.fold(0.0, (total, pecaOS) => total + pecaOS.valorTotal);
    } else {
      return _calcularTotalPecas();
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
        int quantidade = 1; // Sempre adicionar 1 unidade inicialmente

        // Verificar se há estoque suficiente
        if (peca.quantidadeEstoque <= 0) {
          _showErrorSnackBar('Peça ${peca.nome} está sem estoque (${peca.quantidadeEstoque} unidades disponíveis)');
          return;
        }

        if (quantidade > peca.quantidadeEstoque) {
          _showErrorSnackBar('Quantidade solicitada (${quantidade}) é maior que o estoque disponível (${peca.quantidadeEstoque} unidades)');
          return;
        }

        // Verificar se a peça já foi adicionada anteriormente
        final pecaJaAdicionada = _pecasSelecionadas.where((p) => p.peca.id == peca.id).firstOrNull;
        if (pecaJaAdicionada != null) {
          final quantidadeTotal = pecaJaAdicionada.quantidade + quantidade;
          if (quantidadeTotal > peca.quantidadeEstoque) {
            _showErrorSnackBar(
                'Quantidade total (${quantidadeTotal}) seria maior que o estoque disponível (${peca.quantidadeEstoque} unidades)');
            return;
          }
          // Atualizar quantidade da peça já existente
          setState(() {
            pecaJaAdicionada.quantidade = quantidadeTotal;
            _codigoPecaController.clear();
          });
          _calcularPrecoTotal();
          _showSuccessSnackBar('Quantidade da peça ${peca.nome} atualizada para ${quantidadeTotal}');
        } else {
          // Adicionar nova peça
          final pecaOS = PecaOrdemServico(peca: peca, quantidade: quantidade);
          setState(() {
            _pecasSelecionadas.add(pecaOS);
            _codigoPecaController.clear();
          });
          _calcularPrecoTotal();
          _showSuccessSnackBar('Peça adicionada: ${peca.nome} (${quantidade} unid.)');
        }
      } else {
        _showErrorSnackBar('Peça não encontrada com o código: $codigo');
      }
    } catch (e) {
      _showErrorSnackBar('Erro ao buscar peça: $e');
    }
  }

  void _removerPeca(PecaOrdemServico pecaOS) {
    setState(() {
      _pecasSelecionadas.remove(pecaOS);
    });
    _calcularPrecoTotal();
    _showSuccessSnackBar('Peça removida: ${pecaOS.peca.nome}');
  }

  void _clearFormFields() {
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
    _checklistController.clear(); // Adicionado
    _codigoPecaController.clear();

    setState(() {
      _checklistSelecionado = null;
      _servicosSelecionados.clear();
      _pecasSelecionadas.clear();
      _tipoPagamentoSelecionado = null;
      _garantiaMeses = 3;
      _precoTotal = 0.0;
      _categoriaSelecionada = null; // Resetar para null
      _pecaEncontrada = null; // Limpar peça encontrada
      _checklistsFiltrados = _checklists;
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
              Icons.build_circle_outlined,
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
                onTap: () {
                  setState(() {
                    if (_showForm) {
                      _clearFormFields();
                      _editingOSId = null;
                      _showForm = false;
                    } else {
                      _clearFormFields();
                      _editingOSId = null;
                      _showForm = true;
                    }
                  });
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
              Icons.build_circle_outlined,
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
            Icons.build_circle,
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
                    'ABERTA',
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
              // Valor das peças
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
              // Valor total
              Row(
                children: [
                  Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Serviços: R\$ ${os.precoTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
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
                onPressed: () => _editOS(os),
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
              ),
            ),
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
                    onPressed: () {
                      setState(() {
                        _showForm = false;
                        _editingOSId = null;
                        _clearFormFields();
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
                        _editingOSId != null ? 'Editar Ordem de Serviço' : 'Nova Ordem de Serviço',
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
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _printOS(null), // Para preview
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.print, color: Colors.teal.shade600, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'PDF',
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
                          'Editando OS: ${_osNumberController.text.isNotEmpty ? _osNumberController.text : _editingOSId}',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_editingOSId != null) const SizedBox(height: 24),

                // Seção 1: Dados do Cliente e Veículo
                _buildFormSection('1. Dados do Cliente e Veículo', Icons.person_outline),
                const SizedBox(height: 16),
                _buildClientVehicleInfo(),
                const SizedBox(height: 32),

                // Seção 2: Seleção de Checklist
                _buildFormSection('2. Checklist Relacionado', Icons.assignment_outlined),
                const SizedBox(height: 16),
                _buildChecklistSelection(),
                const SizedBox(height: 32),

                // Seção 3: Queixa Principal
                _buildFormSection('3. Queixa Principal / Problema Relatado', Icons.report_problem_outlined),
                const SizedBox(height: 16),
                _buildComplaintSection(),
                const SizedBox(height: 32),

                // Seção 4: Seleção de Serviços
                _buildFormSection('4. Serviços a Executar', Icons.build_outlined),
                const SizedBox(height: 16),
                _buildServicesSelection(),
                const SizedBox(height: 32),

                // Seção 5: Peças Utilizadas
                _buildFormSection('5. Peças Utilizadas', Icons.inventory_outlined),
                const SizedBox(height: 16),
                _buildPartsSelection(),
                const SizedBox(height: 32),

                // Seção 6: Garantia e Pagamento
                _buildFormSection('6. Garantia e Forma de Pagamento', Icons.payment_outlined),
                const SizedBox(height: 16),
                _buildWarrantyAndPayment(),
                const SizedBox(height: 32),

                // Seção 6: Observações
                _buildFormSection('7. Observações Adicionais', Icons.notes_outlined),
                const SizedBox(height: 16),
                _buildObservationsSection(),
                const SizedBox(height: 32),

                // Botões de ação
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
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
          onChanged: (value) {
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
                _clienteTelefoneController.text = c.telefone;
                _clienteEmailController.text = c.email;
              });
              _filtrarChecklists();
            }
          },
          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
            // Sincronizar apenas se o controller estiver vazio
            if (controller.text.isEmpty && _clienteCpfController.text.isNotEmpty) {
              controller.text = _clienteCpfController.text;
            }
            return TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: (value) {
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
                _categoriaSelecionada = v.categoria; // Manter valor original (pode ser null)
              });
              _filtrarChecklists();
              _calcularPrecoTotal(); // Recalcular preço com a nova categoria
            }
          },
          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
            // Sincronizar apenas se o controller estiver vazio
            if (controller.text.isEmpty && _veiculoPlacaController.text.isNotEmpty) {
              controller.text = _veiculoPlacaController.text;
            }
            return TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: (value) {
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
              decoration: InputDecoration(
                hintText: 'Digite para buscar um checklist...',
                suffixIcon: _checklistSelecionado != null
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
                    maxHeight: 200, // Limitar altura para evitar overflow
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
        maxLines: 4,
        decoration: InputDecoration(
          hintText: 'Descreva o problema ou serviço solicitado pelo cliente...',
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
              if (_precoTotal > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Total: R\$ ${_precoTotal.toStringAsFixed(2)}',
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
                  onSelected: (selected) => _onServicoToggled(servico),
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
          // Formulário para adicionar peças
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
                Text(
                  'Adicionar Peça',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codigoPecaController,
                        decoration: InputDecoration(
                          labelText: 'Código da Peça',
                          hintText: 'Digite o código...',
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
                        onChanged: (value) {
                          // Limpar a peça encontrada quando o código for alterado
                          if (_pecaEncontrada != null) {
                            setState(() {
                              _pecaEncontrada = null;
                            });
                          }
                        },
                        onSubmitted: _buscarPecaPorCodigo,
                      ),
                    ),
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
                ),

                // Seção de informações da peça encontrada
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

          // Lista de peças selecionadas
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
                            'Estoque: ${pecaOS.peca.quantidadeEstoque} unid.',
                            style: TextStyle(
                              color: pecaOS.peca.quantidadeEstoque <= 5
                                  ? Colors.red[600]
                                  : pecaOS.peca.quantidadeEstoque <= 10
                                      ? Colors.orange[600]
                                      : Colors.green[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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
                          onPressed: () {
                            if (pecaOS.quantidade > 1) {
                              setState(() {
                                pecaOS.quantidade--;
                              });
                              _calcularPrecoTotal();
                            }
                          },
                          icon: Icon(Icons.remove_circle_outline, size: 20, color: Colors.grey[600]),
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${pecaOS.quantidade}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (pecaOS.quantidade < pecaOS.peca.quantidadeEstoque) {
                              setState(() {
                                pecaOS.quantidade++;
                              });
                              _calcularPrecoTotal();
                            } else {
                              _showErrorSnackBar('Quantidade máxima disponível: ${pecaOS.peca.quantidadeEstoque}');
                            }
                          },
                          icon: Icon(Icons.add_circle_outline, size: 20, color: Colors.grey[600]),
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'R\$ ${pecaOS.valorTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => _removerPeca(pecaOS),
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
                  onChanged: (value) {
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
                  onChanged: (value) {
                    setState(() {
                      _tipoPagamentoSelecionado = value;
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

  Future<void> _salvarOS() async {
    // Validações básicas
    if (_clienteNomeController.text.isEmpty || _clienteCpfController.text.isEmpty) {
      _showErrorSnackBar('Por favor, preencha os dados do cliente');
      return;
    }

    if (_veiculoPlacaController.text.isEmpty) {
      _showErrorSnackBar('Por favor, preencha os dados do veículo');
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
        garantiaMeses: _garantiaMeses,
        tipoPagamento: _tipoPagamentoSelecionado,
        observacoes: _observacoesController.text.isEmpty ? null : _observacoesController.text,
      );

      if (_editingOSId != null) {
        await OrdemServicoService.atualizarOrdemServico(_editingOSId!, ordemServico);
        _showSuccessSnackBar('OS atualizada com sucesso');
      } else {
        await OrdemServicoService.salvarOrdemServico(ordemServico);
        _showSuccessSnackBar('OS criada com sucesso');
      }

      _clearFormFields();
      await _loadData();

      // Retornar à tela de listagem após salvar
      setState(() {
        _showForm = false;
        _editingOSId = null;
      });
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
            if ((os?.checklistId != null) || (_checklistSelecionado != null))
              _buildPdfSection(
                'CHECKLIST VINCULADO',
                [
                  ['Número:', os?.checklistId?.toString() ?? _checklistSelecionado!.numeroChecklist]
                ],
                compact: true,
              ),
            if ((os?.checklistId != null) || (_checklistSelecionado != null)) pw.SizedBox(height: 12),
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
                      child: pw.Text('R\$ ${pecaOS.valorTotal.toStringAsFixed(2)}',
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
    final precoTotal = os?.precoTotal ?? _precoTotal;
    final tipoPagamento = os?.tipoPagamento ?? _tipoPagamentoSelecionado;
    final garantiaMeses = os?.garantiaMeses ?? _garantiaMeses;

    // Calcular valores separados
    final pecasParaPDF = os?.pecasUtilizadas ?? _pecasSelecionadas;
    final totalPecas = pecasParaPDF.fold(0.0, (total, pecaOS) => total + pecaOS.valorTotal);
    final totalServicos = precoTotal - totalPecas;

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
          pw.SizedBox(height: 6),

          // Valor dos Serviços
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Valor dos Serviços:', style: pw.TextStyle(fontSize: 9)),
              pw.Text('R\$ ${totalServicos.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.SizedBox(height: 3),

          // Valor das Peças
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Valor das Peças:', style: pw.TextStyle(fontSize: 9)),
              pw.Text('R\$ ${totalPecas.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.SizedBox(height: 6),

          // Separador
          pw.Container(
            height: 1,
            color: PdfColors.grey300,
            margin: const pw.EdgeInsets.symmetric(vertical: 4),
          ),

          // Total Geral
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('VALOR TOTAL:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('R\$ ${precoTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
            ],
          ),
          pw.SizedBox(height: 8),

          // Forma de Pagamento
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Forma de Pagamento:', style: pw.TextStyle(fontSize: 9)),
              pw.Text(tipoPagamento?.nome ?? 'Não informado', style: pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.SizedBox(height: 4),

          // Garantia
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Garantia:', style: pw.TextStyle(fontSize: 9)),
              pw.Text('${garantiaMeses} meses', style: pw.TextStyle(fontSize: 9)),
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
                        _buildResumoItem(
                            'Serviços:', () {
                              final servicosLength = os != null ? (os.servicosRealizados.length) : _servicosSelecionados.length;
                              return '$servicosLength item${servicosLength != 1 ? 's' : ''}';
                            }()),
                        _buildResumoItem('Peças:', () {
                              final pecasLength = os != null ? (os.pecasUtilizadas.length) : _pecasSelecionadas.length;
                              return '$pecasLength item${pecasLength != 1 ? 's' : ''}';
                            }()),
                        _buildResumoItem('Valor Serviços:', 'R\$ ${((os?.precoTotal ?? _precoTotal) - _calcularTotalPecasOS(os)).toStringAsFixed(2)}'),
                        _buildResumoItem('Valor Peças:', 'R\$ ${_calcularTotalPecasOS(os).toStringAsFixed(2)}'),
                        _buildResumoItem('TOTAL GERAL:', 'R\$ ${(os?.precoTotal ?? _precoTotal).toStringAsFixed(2)}', isTotal: true),
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

  pw.Widget _buildResumoItem(String label, String value, {bool isTotal = false}) {
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
                color: isTotal ? PdfColors.green700 : PdfColors.black,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: isTotal ? 11 : 10,
                fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: isTotal ? PdfColors.green700 : PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editOS(OrdemServico os) async {
    try {
      // Carregar dados completos da OS
      final osCompleta = await OrdemServicoService.buscarOrdemServicoPorId(os.id!);
      if (osCompleta != null) {
        setState(() {
          _editingOSId = os.id;
          _osNumberController.text = os.numeroOS;
          _dateController.text = DateFormat('dd/MM/yyyy').format(os.dataHora);
          _timeController.text = DateFormat('HH:mm').format(os.dataHora);
          _clienteNomeController.text = os.clienteNome;
          _clienteCpfController.text = os.clienteCpf;
          _clienteTelefoneController.text = os.clienteTelefone ?? '';
          _clienteEmailController.text = os.clienteEmail ?? '';
          _veiculoNomeController.text = os.veiculoNome;
          _veiculoMarcaController.text = os.veiculoMarca;
          _veiculoAnoController.text = os.veiculoAno;
          _veiculoCorController.text = os.veiculoCor;
          _veiculoPlacaController.text = os.veiculoPlaca;
          _veiculoQuilometragemController.text = os.veiculoQuilometragem;
          _queixaPrincipalController.text = os.queixaPrincipal;
          _observacoesController.text = os.observacoes ?? '';
          _garantiaMeses = os.garantiaMeses;
          _precoTotal = os.precoTotal;

          // Encontrar checklist selecionado
          if (os.checklistId != null) {
            _checklistSelecionado = _checklists.where((c) => c.id == os.checklistId).firstOrNull;
            if (_checklistSelecionado != null) {
              _checklistController.text = 'Checklist ${_checklistSelecionado!.numeroChecklist}';
            }
          }

          // Encontrar tipo de pagamento
          if (os.tipoPagamento != null) {
            _tipoPagamentoSelecionado = _tiposPagamento.where((tp) => tp.id == os.tipoPagamento!.id).firstOrNull;
          }

          // Encontrar categoria do veículo pela placa
          final veiculo = _veiculoByPlaca[os.veiculoPlaca];
          if (veiculo != null) {
            _categoriaSelecionada = veiculo.categoria;
          }

          // Manter serviços selecionados do backend
          _servicosSelecionados.clear();
          if (os.servicosRealizados.isNotEmpty) {
            for (var servicoOS in os.servicosRealizados) {
              // Primeiro tentar encontrar por ID
              var servicoEncontrado = _servicosDisponiveis.where((s) => s.id == servicoOS.id).firstOrNull;

              // Se não encontrar por ID, tentar por nome
              if (servicoEncontrado == null) {
                servicoEncontrado = _servicosDisponiveis.where((s) => s.nome == servicoOS.nome).firstOrNull;
              }

              if (servicoEncontrado != null) {
                _servicosSelecionados.add(servicoEncontrado);
              } else {
                // Se não encontrar, usar o próprio serviço da OS (fallback)
                _servicosSelecionados.add(servicoOS);
              }
            }
          }

          // Carregar peças selecionadas
          _pecasSelecionadas.clear();
          if (os.pecasUtilizadas.isNotEmpty) {
            for (var pecaOS in os.pecasUtilizadas) {
              _pecasSelecionadas.add(PecaOrdemServico(
                peca: pecaOS.peca,
                quantidade: pecaOS.quantidade,
              ));
            }
          }

          // Não recalcular automaticamente - manter o preço original da OS

          _showForm = true;
        });

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
}
