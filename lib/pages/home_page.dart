import 'package:tecstock/pages/agendamento_page.dart';
import 'package:tecstock/pages/auditoria_page.dart';
import 'package:tecstock/pages/cadastro_fabricante_page.dart';
import 'package:tecstock/pages/cadastro_fornecedor_page.dart';
import 'package:tecstock/pages/cadastro_funcioario_page.dart';
import 'package:tecstock/pages/cadastro_marca_page.dart';
import 'package:tecstock/pages/cadastro_peca_page.dart';
import 'package:tecstock/pages/cadastro_servico_page.dart';
import 'package:tecstock/pages/cadastro_tipo_pagamento_page.dart';
import 'package:tecstock/pages/checklist_page.dart';
import 'package:tecstock/pages/gerenciamento_fiados_page.dart';
import 'package:tecstock/pages/gerenciar_usuarios_page.dart';
import 'package:tecstock/pages/login_page.dart';
import 'package:tecstock/pages/ordem_servico_page.dart';
import 'package:tecstock/pages/orcamento_page.dart';
import 'package:tecstock/pages/relatorios_page.dart';
import 'package:tecstock/services/agendamento_service.dart';
import 'package:tecstock/services/auth_service.dart';
import 'package:tecstock/services/cliente_service.dart';
import 'package:tecstock/services/veiculo_service.dart';
import 'package:tecstock/services/checklist_service.dart';
import 'package:tecstock/services/marca_service.dart';
import 'package:tecstock/services/fabricante_service.dart';
import 'package:tecstock/services/servico_service.dart';
import 'package:tecstock/services/fornecedor_service.dart';
import 'package:tecstock/services/funcionario_service.dart';
import 'package:tecstock/services/peca_service.dart';
import 'package:tecstock/services/tipo_pagamento_service.dart';
import 'package:tecstock/services/ordem_servico_service.dart';
import 'package:tecstock/services/orcamento_service.dart';
import 'package:tecstock/services/movimentacao_estoque_service.dart';
import 'package:tecstock/model/movimentacao_estoque.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'cadastro_cliente_page.dart';
import 'cadastro_veiculo_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late String _currentTitle;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isDashboardActive = true;
  Widget? _currentPageWidget;
  Key _pageKey = UniqueKey();

  String _nomeUsuarioLogado = '';
  int _nivelAcessoUsuarioLogado = 1;
  String _nomeEmpresa = '';

  Map<String, int> _dashboardStats = {
    'Agendamentos Hoje': 0,
    'Clientes Ativos': 0,
    'Veículos Cadastrados': 0,
    'Serviços Cadastrados': 0,
  };

  bool _isLoadingStats = true;
  List<Map<String, dynamic>> _recentActivities = [];
  int _currentPage = 0;
  final int _itemsPerPage = 10;

  static final List<Map<String, dynamic>> _quickActions = [
    {
      'title': 'Novo Agendamento',
      'subtitle': 'Criar agendamento',
      'icon': Icons.event_note,
      'color': Colors.blue,
      'page': const AgendamentoPage(),
    },
    {
      'title': 'Orçamento',
      'subtitle': 'Novo orçamento',
      'icon': Icons.receipt_long,
      'color': Colors.purple,
      'page': const OrcamentoPage(),
    },
    {
      'title': 'Ordem de Serviço',
      'subtitle': 'Nova OS',
      'icon': Icons.description,
      'color': Colors.teal,
      'page': const OrdemServicoPage(),
    },
    {
      'title': 'Cadastrar Cliente',
      'subtitle': 'Novo cliente',
      'icon': Icons.person_add,
      'color': Colors.orange,
      'page': const CadastroClientePage(),
    },
  ];

  static final List<Map<String, dynamic>> _menuGroups = [
    {
      'group': 'Geral',
      'items': [
        {
          'title': 'Início',
          'icon': Icons.home,
          'isDashboard': true,
        }
      ],
    },
    {
      'group': 'Cadastros',
      'items': [
        {'title': 'Funcionarios', 'icon': Icons.emoji_people, 'page': const CadastroFuncionarioPage()},
        {'title': 'Clientes', 'icon': Icons.person_search, 'page': const CadastroClientePage()},
        {'title': 'Marcas', 'icon': Icons.loyalty, 'page': const CadastroMarcaPage()},
        {'title': 'Veículos', 'icon': Icons.directions_car, 'page': const CadastroVeiculoPage()},
        {'title': 'Fornecedor', 'icon': Icons.local_shipping, 'page': const CadastroFornecedorPage()},
        {'title': 'Fabricantes', 'icon': Icons.factory, 'page': const CadastroFabricantePage()},
        {'title': 'Peças', 'icon': Icons.settings, 'page': const CadastroPecaPage()},
        {'title': 'Serviços', 'icon': Icons.home_repair_service, 'page': const CadastroServicoPage()},
        {'title': 'Tipos de Pagamento', 'icon': Icons.payment, 'page': const CadastroTipoPagamentoPage()},
      ],
    },
    {
      'group': 'Operações',
      'items': [
        {'title': 'Agendamento', 'icon': Icons.support_agent, 'page': const AgendamentoPage()},
        {'title': 'Checklist', 'icon': Icons.checklist, 'page': const ChecklistPage()},
        {'title': 'Orçamento', 'icon': Icons.receipt_long, 'page': const OrcamentoPage()},
        {'title': 'Ordem de Serviço', 'icon': Icons.description, 'page': const OrdemServicoPage()},
        {'title': 'Gerenciar Fiados', 'icon': Icons.credit_card, 'page': const GerenciamentoFiadosPage()},
        {'title': 'Gerenciar Usuários', 'icon': Icons.person, 'page': const GerenciarUsuariosPage()},
      ],
    },
    {
      'group': 'Relatórios',
      'items': [
        {'title': 'Relatórios', 'icon': Icons.analytics, 'page': const RelatoriosPage()},
      ],
    },
    {
      'group': 'Administração',
      'items': [
        {'title': 'Auditoria', 'icon': Icons.history, 'page': const AuditoriaPage()},
      ],
    },
  ];

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    Map<String, dynamic>? initial;
    for (var group in _menuGroups) {
      for (var item in group['items']) {
        if (item['title'] == 'Início') initial = item as Map<String, dynamic>?;
      }
    }
    initial ??= _menuGroups.first['items'].first as Map<String, dynamic>;

    if (initial['isDashboard'] == true) {
      _isDashboardActive = true;
      _currentPageWidget = null;
    } else {
      _isDashboardActive = false;
      _currentPageWidget = initial['page'];
    }
    _currentTitle = initial['title'];

    _fadeController.forward();
    _slideController.forward();

    _loadUserData();
    _loadDashboardData();
  }

  Future<void> _loadUserData() async {
    final nomeCompleto = await AuthService.getNomeCompleto();
    final nivelAcesso = await AuthService.getNivelAcesso();
    final nomeEmpresa = await AuthService.getNomeEmpresa();

    setState(() {
      _nomeUsuarioLogado = nomeCompleto ?? 'Usuário';
      _nomeEmpresa = nomeEmpresa ?? '';
      _nivelAcessoUsuarioLogado = nivelAcesso ?? 1;
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Logout'),
        content: const Text('Deseja realmente sair do sistema?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.lightImpact();

    setState(() {
      _isLoadingStats = true;
    });

    if (_currentTitle == 'Início') {
      try {
        await _loadDashboardData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dados recarregados com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao recarregar dados. Tente novamente.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      setState(() {
        _pageKey = UniqueKey();
        _isLoadingStats = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Página recarregada!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final futures = {
        'agendamentos': AgendamentoService.listarAgendamentos(),
        'clientes': ClienteService.listarClientes(),
        'veiculos': VeiculoService.listarVeiculos(),
        'checklists': ChecklistService.listarChecklists(),
        'marcas': MarcaService.listarMarcas(),
        'fabricantes': FabricanteService.listarFabricantes(),
        'servicos': ServicoService.listarServicos(),
        'fornecedores': FornecedorService.listarFornecedores(),
        'funcionarios': Funcionarioservice.listarFuncionarios(),
        'pecas': PecaService.listarPecas(),
        'tiposPagamento': TipoPagamentoService.listarTiposPagamento(),
        'ordens': OrdemServicoService.listarOrdensServico(),
        'orcamentos': OrcamentoService.listarOrcamentos(),
        'movimentacoes': MovimentacaoEstoqueService.listarTodas(),
      };

      final results = await Future.wait(futures.values);

      final keys = futures.keys.toList();
      final Map<String, dynamic> loaded = {};
      for (var i = 0; i < keys.length; i++) {
        loaded[keys[i]] = results[i];
      }

      dynamic safeList(String key) {
        final val = loaded[key];
        return val ?? <dynamic>[];
      }

      final agendamentos = safeList('agendamentos') as List<dynamic>;
      final clientes = safeList('clientes') as List<dynamic>;
      final veiculos = safeList('veiculos') as List<dynamic>;
      final checklists = safeList('checklists') as List<dynamic>;
      final marcas = safeList('marcas') as List<dynamic>;
      final fabricantes = safeList('fabricantes') as List<dynamic>;
      final servicos = safeList('servicos') as List<dynamic>;
      final fornecedores = safeList('fornecedores') as List<dynamic>;
      final funcionarios = safeList('funcionarios') as List<dynamic>;
      final pecas = safeList('pecas') as List<dynamic>;
      final tiposPagamento = safeList('tiposPagamento') as List<dynamic>;
      final ordens = safeList('ordens') as List<dynamic>;
      final orcamentos = safeList('orcamentos') as List<dynamic>;
      final movimentacoes = safeList('movimentacoes') as List<dynamic>;

      int agendamentosHoje = 0;
      for (final agendamento in agendamentos) {
        if (_isToday(agendamento.data)) {
          agendamentosHoje++;
        }
      }

      setState(() {
        _dashboardStats = {
          'Agendamentos Hoje': agendamentosHoje,
          'Clientes Ativos': clientes.length,
          'Veículos Cadastrados': veiculos.length,
          'Serviços Cadastrados': servicos.length,
        };
        _recentActivities = [];

        final Map<int, dynamic> checklistsFechadosMap = {};
        if (checklists.isNotEmpty) {
          final todayClosedChecklists =
              checklists.where((checklist) => checklist.status == 'FECHADO' && _isToday(checklist.updatedAt)).toList();

          for (final checklist in todayClosedChecklists) {
            if (checklist.id != null) {
              checklistsFechadosMap[checklist.id!] = checklist;
            }
          }
        }

        if (ordens.isNotEmpty) {
          final todayClosedOS = ordens.where((os) {
            final isEncerrada = os.status?.trim() == 'Encerrada';
            final hasDate = os.dataHoraEncerramento != null;
            final isToday = hasDate && _isToday(os.dataHoraEncerramento);
            return isEncerrada && hasDate && isToday;
          }).toList();

          for (final os in todayClosedOS) {
            final checklistRelacionado = os.checklistId != null ? checklistsFechadosMap[os.checklistId] : null;

            if (checklistRelacionado != null) {
              _recentActivities.add({
                'title': 'OS encerrada e Checklist fechado',
                'subtitle':
                    'OS #${os.numeroOS} + Checklist #${checklistRelacionado.numeroChecklist} - Cliente: ${os.clienteNome} - Veículo: ${os.veiculoPlaca}',
                'icon': Icons.check_circle,
                'color': const Color(0xFF10B981),
                'dateTime': os.dataHoraEncerramento ?? DateTime.now(),
                'type': 'os_checklist_encerrado',
                'isEdit': false,
                'tag': 'CONCLUÍDO',
                'tagColor': const Color(0xFF10B981),
              });

              checklistsFechadosMap.remove(os.checklistId);
            } else {
              _recentActivities.add({
                'title': 'Ordem de Serviço encerrada',
                'subtitle': 'OS #${os.numeroOS} - Cliente: ${os.clienteNome} - Veículo: ${os.veiculoPlaca}',
                'icon': Icons.check_circle,
                'color': const Color(0xFF10B981),
                'dateTime': os.dataHoraEncerramento ?? DateTime.now(),
                'type': 'os_encerrada',
                'isEdit': false,
                'tag': 'ENCERRADA',
                'tagColor': const Color(0xFF10B981),
              });
            }
          }
        }

        for (final checklist in checklistsFechadosMap.values) {
          _recentActivities.add({
            'title': 'Checklist fechado',
            'subtitle': 'Checklist #${checklist.numeroChecklist} - Veículo: ${checklist.veiculoPlaca ?? 'N/A'}',
            'icon': Icons.check_circle,
            'color': const Color(0xFF10B981),
            'dateTime': checklist.updatedAt ?? DateTime.now(),
            'type': 'checklist_fechado',
            'isEdit': false,
            'tag': 'FECHADO',
            'tagColor': const Color(0xFF10B981),
          });
        }

        if (checklists.isNotEmpty) {
          final todayChecklists = checklists.where((checklist) => _isToday(checklist.createdAt)).toList();
          final sortedChecklists = List.from(todayChecklists)
            ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));

          for (final checklist in sortedChecklists) {
            _recentActivities.add({
              'title': 'Checklist cadastrado',
              'subtitle':
                  'Checklist #${checklist.numeroChecklist} - Veículo: ${checklist.veiculoNome ?? 'N/A'} - Placa: ${checklist.veiculoPlaca ?? 'N/A'}',
              'icon': Icons.checklist,
              'color': const Color(0xFF2196F3),
              'dateTime': checklist.createdAt ?? DateTime.now(),
              'type': 'checklist',
              'isEdit': false,
            });
          }
        }

        if (agendamentos.isNotEmpty) {
          final todayAgendamentos = agendamentos.where((agendamento) => _isToday(agendamento.createdAt)).toList();
          final sortedAgendamentos = List.from(todayAgendamentos)
            ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));

          for (final agendamento in sortedAgendamentos) {
            _recentActivities.add({
              'title': 'Agendamento criado',
              'subtitle': 'Mecânico: ${agendamento.nomeMecanico} - Veículo: ${agendamento.placaVeiculo}',
              'icon': Icons.event_note,
              'color': const Color(0xFF4CAF50),
              'dateTime': agendamento.createdAt ?? DateTime.now(),
              'type': 'agendamento',
              'isEdit': false,
            });
          }
        }

        _addActivityFromEntity<dynamic>(
          entities: clientes.cast<dynamic>(),
          getName: (cliente) => cliente.nome,
          getSubtitle: (cliente) => '${cliente.nome} - CPF: ${cliente.cpf}',
          getCreatedAt: (cliente) => cliente.createdAt,
          getUpdatedAt: (cliente) => cliente.updatedAt,
          entityType: 'cliente',
          createIcon: Icons.person_add,
          createColor: const Color(0xFFFF9800),
        );

        _addActivityFromEntity<dynamic>(
          entities: veiculos.cast<dynamic>(),
          getName: (veiculo) => veiculo.modelo,
          getSubtitle: (veiculo) => '${veiculo.modelo} - Placa: ${veiculo.placa}',
          getCreatedAt: (veiculo) => veiculo.createdAt,
          getUpdatedAt: (veiculo) => veiculo.updatedAt,
          entityType: 'veículo',
          createIcon: Icons.directions_car,
          createColor: const Color(0xFF9C27B0),
        );

        _addActivityFromEntity<dynamic>(
          entities: marcas.cast<dynamic>(),
          getName: (marca) => marca.marca,
          getSubtitle: (marca) => marca.marca,
          getCreatedAt: (marca) => marca.createdAt,
          getUpdatedAt: (marca) => marca.updatedAt,
          entityType: 'marca',
          createIcon: Icons.branding_watermark,
          createColor: const Color(0xFFDC2626),
        );

        _addActivityFromEntity<dynamic>(
          entities: fabricantes.cast<dynamic>(),
          getName: (fabricante) => fabricante.nome,
          getSubtitle: (fabricante) => fabricante.nome,
          getCreatedAt: (fabricante) => fabricante.createdAt,
          getUpdatedAt: (fabricante) => fabricante.updatedAt,
          entityType: 'fabricante',
          createIcon: Icons.precision_manufacturing,
          createColor: const Color(0xFF7C3AED),
        );

        final todayOrdens = ordens.where((os) => _isToday(os.createdAt) || _isToday(os.updatedAt)).toList();
        final hasOSToday = todayOrdens.isNotEmpty;

        _addActivityFromEntity<dynamic>(
          entities: servicos.cast<dynamic>(),
          getName: (servico) => servico.nome,
          getSubtitle: (servico) => servico.nome,
          getCreatedAt: (servico) => servico.createdAt,
          getUpdatedAt: (servico) => servico.updatedAt,
          entityType: 'serviço',
          createIcon: Icons.build,
          createColor: const Color(0xFF8B5CF6),
          shouldShowEdited: (servico) {
            return !hasOSToday;
          },
        );

        _addActivityFromEntity<dynamic>(
          entities: fornecedores.cast<dynamic>(),
          getName: (fornecedor) => fornecedor.nome,
          getSubtitle: (fornecedor) => '${fornecedor.nome} - CNPJ: ${fornecedor.cnpj ?? 'N/A'}',
          getCreatedAt: (fornecedor) => fornecedor.createdAt,
          getUpdatedAt: (fornecedor) => fornecedor.updatedAt,
          entityType: 'fornecedor',
          createIcon: Icons.local_shipping,
          createColor: const Color(0xFF059669),
        );

        _addActivityFromEntity<dynamic>(
          entities: funcionarios.cast<dynamic>(),
          getName: (funcionario) => funcionario.nome,
          getSubtitle: (funcionario) => '${funcionario.nome} - CPF: ${funcionario.cpf ?? 'N/A'}',
          getCreatedAt: (funcionario) => funcionario.createdAt,
          getUpdatedAt: (funcionario) => funcionario.updatedAt,
          entityType: 'funcionário',
          createIcon: Icons.emoji_people,
          createColor: const Color(0xFF0EA5E9),
        );

        final todayMovimentacoes = movimentacoes.where((mov) => _isToday(mov.dataMovimentacao)).toList();
        final pecasComMovimentacaoHoje = todayMovimentacoes.map((mov) => mov.codigoPeca).toSet();

        final pecasCriadasHoje = pecas.where((peca) => _isToday(peca.createdAt)).toList();
        for (final peca in pecasCriadasHoje) {
          _recentActivities.add({
            'title': 'Peça cadastrada',
            'subtitle': '${peca.nome} - Código: ${peca.codigoFabricante ?? 'N/A'}',
            'icon': Icons.settings,
            'color': const Color(0xFFEF4444),
            'dateTime': peca.createdAt ?? DateTime.now(),
            'type': 'peça',
            'isEdit': false,
          });
        }

        final pecasEditadasHoje = pecas.where((peca) {
          final updated = peca.updatedAt;
          final created = peca.createdAt;
          final wasUpdatedToday = _isToday(updated) && created != null && !_isToday(created);
          final temMovimentacao = pecasComMovimentacaoHoje.contains(peca.codigoFabricante);
          return wasUpdatedToday && !temMovimentacao;
        }).toList();

        for (final peca in pecasEditadasHoje) {
          _recentActivities.add({
            'title': 'Peça atualizada',
            'subtitle': '${peca.nome} - Código: ${peca.codigoFabricante ?? 'N/A'}',
            'icon': Icons.edit,
            'color': Colors.orange,
            'dateTime': peca.updatedAt ?? DateTime.now(),
            'type': 'peça',
            'isEdit': true,
          });
        }

        _addActivityFromEntity<dynamic>(
          entities: tiposPagamento.cast<dynamic>(),
          getName: (tipo) => tipo.nome,
          getSubtitle: (tipo) => '${tipo.nome} - Código: ${tipo.codigo?.toString().padLeft(2, '0') ?? 'N/A'}',
          getCreatedAt: (tipo) => tipo.createdAt,
          getUpdatedAt: (tipo) => tipo.updatedAt,
          entityType: 'tipo de pagamento',
          createIcon: Icons.payment,
          createColor: const Color(0xFF059669),
        );

        _addActivityFromEntity<dynamic>(
          entities: ordens.cast<dynamic>(),
          getName: (os) => os.numeroOS ?? 'OS',
          getSubtitle: (os) {
            String subtitle = 'OS: ${os.numeroOS} - Cliente: ${os.clienteNome ?? 'N/A'}';
            if (os.numeroOrcamentoOrigem != null && os.numeroOrcamentoOrigem.isNotEmpty) {
              subtitle += ' (Origem: Orçamento ${os.numeroOrcamentoOrigem})';
            }
            return subtitle;
          },
          getCreatedAt: (os) => os.createdAt,
          getUpdatedAt: (os) => os.updatedAt,
          entityType: 'ordem de serviço',
          createIcon: Icons.description,
          createColor: const Color(0xFF009688),
          getTag: (os) => os.numeroOrcamentoOrigem != null && os.numeroOrcamentoOrigem.isNotEmpty ? 'DE ORÇAMENTO' : null,
          getTagColor: (os) => os.numeroOrcamentoOrigem != null && os.numeroOrcamentoOrigem.isNotEmpty ? Colors.purple : null,
        );

        _addActivityFromEntity<dynamic>(
          entities: orcamentos.cast<dynamic>(),
          getName: (orcamento) => orcamento.numeroOrcamento ?? 'Orçamento',
          getSubtitle: (orcamento) {
            String subtitle = 'Orçamento: ${orcamento.numeroOrcamento} - Cliente: ${orcamento.clienteNome ?? 'N/A'}';
            if (orcamento.transformadoEmOS && orcamento.numeroOSGerado != null) {
              subtitle += ' (Transformado em OS ${orcamento.numeroOSGerado})';
            }
            return subtitle;
          },
          getCreatedAt: (orcamento) => orcamento.createdAt,
          getUpdatedAt: (orcamento) => orcamento.updatedAt,
          entityType: 'orçamento',
          createIcon: Icons.request_quote,
          createColor: const Color(0xFF6366F1),
          getTag: (orcamento) => orcamento.transformadoEmOS ? 'TRANSFORMADO' : null,
          getTagColor: (orcamento) => orcamento.transformadoEmOS ? Colors.purple : null,
        );

        if (movimentacoes.isNotEmpty) {
          final todayMovimentacoes = movimentacoes.where((mov) => _isToday(mov.dataMovimentacao)).toList();

          for (final mov in todayMovimentacoes) {
            final isEntrada = mov.tipoMovimentacao == TipoMovimentacao.ENTRADA;
            final isReajuste = mov.tipoMovimentacao == TipoMovimentacao.REAJUSTE;
            final houveReajustePreco = mov.precoAnterior != null && mov.precoNovo != null;

            String title;
            String subtitle;
            IconData icon;
            Color color;
            String tag;
            Color tagColor;

            if (isReajuste) {
              title = 'Ajuste de Estoque';
              subtitle = 'Peça: ${mov.codigoPeca}';

              if (mov.observacoes != null && mov.observacoes!.isNotEmpty) {
                String obs = mov.observacoes!;
                if (obs.contains('|')) {
                  obs = obs.split('|')[0].trim();
                }
                subtitle += ' - $obs';
              }

              if (houveReajustePreco) {
                subtitle += '\nPreço: R\$ ${mov.precoAnterior!.toStringAsFixed(2)} → R\$ ${mov.precoNovo!.toStringAsFixed(2)}';
              }

              icon = Icons.tune;
              color = const Color(0xFF8B5CF6);
              tag = 'REAJUSTE';
              tagColor = const Color(0xFF8B5CF6);
            } else if (isEntrada) {
              title = 'Entrada de estoque';
              subtitle = 'Peça: ${mov.codigoPeca} - Qtd: ${mov.quantidade} - NF: ${mov.numeroNotaFiscal}';
              icon = Icons.arrow_downward;
              color = const Color(0xFF10B981);
              tag = 'ENTRADA';
              tagColor = const Color(0xFF10B981);
            } else {
              final obs = mov.observacoes != null && mov.observacoes!.isNotEmpty ? mov.observacoes : 'Sem observações';
              title = 'Saída de estoque';
              subtitle = 'Peça: ${mov.codigoPeca} - $obs';
              icon = Icons.arrow_upward;
              color = const Color(0xFFEF4444);
              tag = 'SAÍDA';
              tagColor = const Color(0xFFEF4444);
            }

            _recentActivities.add({
              'title': title,
              'subtitle': subtitle,
              'icon': icon,
              'color': color,
              'dateTime': mov.dataMovimentacao ?? DateTime.now(),
              'type': 'movimentacao',
              'isEdit': false,
              'tag': tag,
              'tagColor': tagColor,
            });
          }
        }

        _recentActivities.sort((a, b) {
          final dateTimeA = a['dateTime'] as DateTime;
          final dateTimeB = b['dateTime'] as DateTime;
          return dateTimeB.compareTo(dateTimeA);
        });

        _currentPage = 0;
        _isLoadingStats = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao carregar dados do dashboard: $e');
      }
      setState(() {
        _dashboardStats = {
          'Agendamentos Hoje': 0,
          'Clientes Ativos': 0,
          'Veículos Cadastrados': 0,
          'Serviços Cadastrados': 0,
        };
        _recentActivities = [];
        _isLoadingStats = false;
      });

      if (mounted) {
        String errorMessage = 'Erro ao carregar dados. ';
        if (e.toString().contains('Connection')) {
          errorMessage += 'Verifique se o servidor backend está rodando.';
        } else if (e.toString().contains('timeout')) {
          errorMessage += 'Tempo limite excedido. Tente novamente.';
        } else {
          errorMessage += 'Verifique a conexão com o servidor.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Tentar novamente',
              textColor: Colors.white,
              onPressed: () => _loadDashboardData(),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final today = DateTime.now();
    return date.year == today.year && date.month == today.month && date.day == today.day;
  }

  void _addActivityFromEntity<T>({
    required List<T> entities,
    required String Function(T) getName,
    required String Function(T) getSubtitle,
    required DateTime? Function(T) getCreatedAt,
    required DateTime? Function(T) getUpdatedAt,
    required String entityType,
    required IconData createIcon,
    required Color createColor,
    bool skipEdited = false,
    bool Function(T)? shouldShowEdited,
    String? Function(T)? getTag,
    Color? Function(T)? getTagColor,
  }) {
    final todayCreated = entities.where((entity) => _isToday(getCreatedAt(entity))).toList();
    for (final entity in todayCreated) {
      final tag = getTag != null ? getTag(entity) : null;
      final tagColor = getTagColor != null ? getTagColor(entity) : null;

      _recentActivities.add({
        'title': '${entityType.substring(0, 1).toUpperCase()}${entityType.substring(1)} cadastrado',
        'subtitle': getSubtitle(entity),
        'icon': createIcon,
        'color': createColor,
        'dateTime': getCreatedAt(entity) ?? DateTime.now(),
        'type': entityType,
        'isEdit': false,
        'tag': tag,
        'tagColor': tagColor,
      });
    }

    if (!skipEdited) {
      final todayEdited = entities.where((entity) {
        final updated = getUpdatedAt(entity);

        final wasUpdatedToday = updated != null && _isToday(updated);

        if (wasUpdatedToday && shouldShowEdited != null) {
          return shouldShowEdited(entity);
        }

        return wasUpdatedToday;
      }).toList();

      for (final entity in todayEdited) {
        final tag = getTag != null ? getTag(entity) : null;
        final tagColor = getTagColor != null ? getTagColor(entity) : null;

        _recentActivities.add({
          'title': '${entityType.substring(0, 1).toUpperCase()}${entityType.substring(1)} atualizado',
          'subtitle': getSubtitle(entity),
          'icon': Icons.edit,
          'color': Colors.orange,
          'dateTime': getUpdatedAt(entity) ?? DateTime.now(),
          'type': entityType,
          'isEdit': true,
          'tag': tag,
          'tagColor': tagColor,
        });
      }
    }
  }

  Widget _buildDashboard() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8F9FA),
            Color(0xFFE9ECEF),
          ],
        ),
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: RefreshIndicator(
            onRefresh: _loadDashboardData,
            color: const Color(0xFF1565C0),
            backgroundColor: Colors.white,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeSection(),
                  const SizedBox(height: 24),
                  _buildStatsCards(),
                  const SizedBox(height: 24),
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  _buildRecentActivity(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final currentTime = DateTime.now().hour;
    String greeting = 'Bom dia';
    if (currentTime >= 12 && currentTime < 18) {
      greeting = 'Boa tarde';
    } else if (currentTime >= 18) {
      greeting = 'Boa noite';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1565C0),
            Color(0xFF0D47A1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  'assets/images/TecStock_icone.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Text(
                      'Bem-vindo ao TecStock',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Sistema de Gerenciamento de Oficina',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hoje, ${_formatDate(DateTime.now())}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumo do Sistema',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E3440),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _dashboardStats.length,
              itemBuilder: (context, index) {
                final entry = _dashboardStats.entries.elementAt(index);
                final colors = [
                  const Color(0xFF4CAF50),
                  const Color(0xFF2196F3),
                  const Color(0xFFFF9800),
                  const Color(0xFF9C27B0),
                ];
                return _buildStatCard(entry.key, entry.value, colors[index % colors.length]);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconForStat(title),
                  color: color,
                  size: 24,
                ),
              ),
              if (!_isLoadingStats)
                Icon(
                  Icons.trending_up,
                  color: color.withValues(alpha: 0.6),
                  size: 16,
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _isLoadingStats
                  ? Container(
                      width: 40,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                          ),
                        ),
                      ),
                    )
                  : Text(
                      value.toString(),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ações Rápidas',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E3440),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: 1.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _quickActions.length,
              itemBuilder: (context, index) {
                final action = _quickActions[index];
                return _buildQuickActionCard(action);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(Map<String, dynamic> action) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          if (action['page'] != null) {
            setState(() {
              _isDashboardActive = false;
              _currentPageWidget = action['page'];
              _currentTitle = action['title'];
            });
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                spreadRadius: 0,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (action['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  action['icon'],
                  color: action['color'],
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                action['title'],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E3440),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                action['subtitle'],
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    final currentPageActivities = _recentActivities.length > startIndex
        ? _recentActivities.sublist(startIndex, endIndex > _recentActivities.length ? _recentActivities.length : endIndex)
        : <Map<String, dynamic>>[];

    final totalPages = (_recentActivities.length / _itemsPerPage).ceil();
    final hasData = _recentActivities.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Atividades de Hoje',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E3440),
              ),
            ),
            if (hasData && !_isLoadingStats)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_recentActivities.length} atividade${_recentActivities.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                spreadRadius: 0,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _isLoadingStats
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              : !hasData
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhuma atividade hoje',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'As atividades realizadas hoje aparecerão aqui',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (int i = 0; i < currentPageActivities.length; i++) ...[
                          _buildActivityItem(
                            currentPageActivities[i]['title'],
                            currentPageActivities[i]['subtitle'],
                            currentPageActivities[i]['icon'],
                            currentPageActivities[i]['color'],
                            _getFormattedTime(currentPageActivities[i]['dateTime']),
                            currentPageActivities[i]['isEdit'] ?? false,
                            currentPageActivities[i]['tag'],
                            currentPageActivities[i]['tagColor'],
                          ),
                          if (i < currentPageActivities.length - 1) const Divider(height: 24),
                        ],
                        if (totalPages > 1) ...[
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _currentPage > 0
                                    ? () {
                                        setState(() {
                                          _currentPage--;
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.chevron_left, size: 18),
                                label: const Text('Anterior'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _currentPage > 0 ? const Color(0xFF1565C0) : Colors.grey[300],
                                  foregroundColor: _currentPage > 0 ? Colors.white : Colors.grey[500],
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Página ${_currentPage + 1} de $totalPages',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _currentPage < totalPages - 1
                                    ? () {
                                        setState(() {
                                          _currentPage++;
                                        });
                                      }
                                    : null,
                                icon: const Icon(Icons.chevron_right, size: 18),
                                label: const Text('Próximo'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _currentPage < totalPages - 1 ? const Color(0xFF1565C0) : Colors.grey[300],
                                  foregroundColor: _currentPage < totalPages - 1 ? Colors.white : Colors.grey[500],
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(String title, String subtitle, IconData icon, Color color, String time,
      [bool isEdit = false, String? tag, Color? tagColor]) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E3440),
                      ),
                    ),
                  ),
                  if (isEdit) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'EDITADO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                  if (tag != null && tagColor != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: tagColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }

  IconData _getIconForStat(String title) {
    switch (title) {
      case 'Agendamentos Hoje':
        return Icons.today;
      case 'Clientes Ativos':
        return Icons.people;
      case 'Veículos Cadastrados':
        return Icons.directions_car;
      case 'Serviços Cadastrados':
        return Icons.home_repair_service;
      default:
        return Icons.analytics;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
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
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }

  String _getFormattedTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Agora mesmo';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}min atrás';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h atrás';
    } else {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  void _navigateTo(BuildContext context, Map<String, dynamic> item) {
    Navigator.pop(context);
    setState(() {
      if (item['isDashboard'] == true) {
        _isDashboardActive = true;
        _currentPageWidget = null;
      } else {
        _isDashboardActive = false;
        _currentPageWidget = item['page'];
      }
      _currentTitle = item['title'];

      if (item['isDashboard'] == true) {
        _loadDashboardData();
      }
    });
  }

  void _showComingSoon(BuildContext context, String title) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title - Em desenvolvimento'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF0D47A1),
          statusBarIconBrightness: Brightness.light,
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1565C0),
                Color(0xFF0D47A1),
              ],
            ),
          ),
        ),
        actions: [
          if (_nomeEmpresa.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Center(
                child: Row(
                  children: [
                    const Icon(Icons.business, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      _nomeEmpresa,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Center(
              child: Row(
                children: [
                  const Icon(Icons.person, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    _nomeUsuarioLogado,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_nivelAcessoUsuarioLogado == 1)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Sair do sistema',
          ),
          IconButton(
            icon: _isLoadingStats
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isLoadingStats ? null : _handleRefresh,
            tooltip: 'Atualizar página',
          ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFAFAFA),
                Color(0xFFF5F5F5),
              ],
            ),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: 200,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1565C0),
                      Color(0xFF0D47A1),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Image.asset(
                              'assets/images/TecStock_icone.png',
                              width: 64,
                              height: 64,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'TecStock',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Gerenciamento de Oficina',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ..._menuGroups.map((group) {
                final items = group['items'] as List<dynamic>;

                final filteredItems = items.where((raw) {
                  final item = raw as Map<String, dynamic>;
                  final title = item['title'] as String;

                  if (_nivelAcessoUsuarioLogado != 1) {
                    if (title == 'Tipos de Pagamento' ||
                        title == 'Gerenciar Usuários' ||
                        title == 'Auditoria' ||
                        title == 'Gerenciar Fiados' ||
                        title == 'Funcionarios') {
                      return false;
                    }
                  }
                  return true;
                }).toList();

                if (filteredItems.isEmpty) {
                  return const SizedBox.shrink();
                }

                if (filteredItems.length == 1) {
                  final item = filteredItems.first as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _currentTitle == item['title'] ? const Color(0xFF1565C0).withValues(alpha: 0.1) : Colors.transparent,
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _currentTitle == item['title'] ? const Color(0xFF1565C0) : const Color(0xFF1565C0).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          item['icon'],
                          color: _currentTitle == item['title'] ? Colors.white : const Color(0xFF1565C0),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        item['title'],
                        style: TextStyle(
                          fontWeight: _currentTitle == item['title'] ? FontWeight.w600 : FontWeight.w500,
                          color: _currentTitle == item['title'] ? const Color(0xFF1565C0) : const Color(0xFF374151),
                        ),
                      ),
                      onTap: () {
                        if (item['page'] != null || item['isDashboard'] == true) {
                          _navigateTo(context, item);
                        } else {
                          _showComingSoon(context, item['title']);
                        }
                      },
                    ),
                  );
                }

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        spreadRadius: 0,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.folder_outlined,
                          color: Color(0xFF1565C0),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        group['group'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      iconColor: const Color(0xFF1565C0),
                      collapsedIconColor: const Color(0xFF1565C0),
                      children: filteredItems.map<Widget>((raw) {
                        final item = raw as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(left: 16, right: 8, bottom: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _currentTitle == item['title'] ? const Color(0xFF1565C0).withValues(alpha: 0.1) : Colors.transparent,
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _currentTitle == item['title']
                                    ? const Color(0xFF1565C0)
                                    : const Color(0xFF1565C0).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                item['icon'],
                                color: _currentTitle == item['title'] ? Colors.white : const Color(0xFF1565C0),
                                size: 16,
                              ),
                            ),
                            title: Text(
                              item['title'],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _currentTitle == item['title'] ? FontWeight.w600 : FontWeight.w500,
                                color: _currentTitle == item['title'] ? const Color(0xFF1565C0) : const Color(0xFF6B7280),
                              ),
                            ),
                            onTap: () {
                              if (item['page'] != null || item['isDashboard'] == true) {
                                _navigateTo(context, item);
                              } else {
                                _showComingSoon(context, item['title']);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      body: _isDashboardActive
          ? _buildDashboard()
          : KeyedSubtree(
              key: _pageKey,
              child: _currentPageWidget ?? const SizedBox.shrink(),
            ),
    );
  }
}
