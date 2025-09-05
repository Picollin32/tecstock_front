import 'package:TecStock/pages/agendamento_page.dart';
import 'package:TecStock/pages/cadastro_fabricante_page.dart';
import 'package:TecStock/pages/cadastro_fornecedor_page.dart';
import 'package:TecStock/pages/cadastro_funcioario_page.dart';
import 'package:TecStock/pages/cadastro_marca_page.dart';
import 'package:TecStock/pages/cadastro_peca_page.dart';
import 'package:TecStock/pages/cadastro_servico_page.dart';
import 'package:TecStock/pages/checklist_page.dart';
import 'package:TecStock/services/agendamento_service.dart';
import 'package:TecStock/services/cliente_service.dart';
import 'package:TecStock/services/veiculo_service.dart';
import 'package:TecStock/services/checklist_service.dart';
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

  Map<String, int> _dashboardStats = {
    'Agendamentos Hoje': 0,
    'Clientes Ativos': 0,
    'Veículos Cadastrados': 0,
    'Checklists Realizados': 0,
  };

  bool _isLoadingStats = true;
  List<Map<String, dynamic>> _recentActivities = [];

  static final List<Map<String, dynamic>> _quickActions = [
    {
      'title': 'Novo Agendamento',
      'subtitle': 'Criar agendamento',
      'icon': Icons.event_note,
      'color': Colors.blue,
      'page': const AgendamentoPage(),
    },
    {
      'title': 'Checklist Veículo',
      'subtitle': 'Inspeção rápida',
      'icon': Icons.checklist_rtl,
      'color': Colors.green,
      'page': const ChecklistPage(),
    },
    {
      'title': 'Cadastrar Cliente',
      'subtitle': 'Novo cliente',
      'icon': Icons.person_add,
      'color': Colors.orange,
      'page': const CadastroClientePage(),
    },
    {
      'title': 'Cadastrar Veículo',
      'subtitle': 'Novo veículo',
      'icon': Icons.add_road,
      'color': Colors.purple,
      'page': const CadastroVeiculoPage(),
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
        {'title': 'Veículos', 'icon': Icons.directions_car, 'page': const CadastroVeiculoPage()},
        {'title': 'Marcas', 'icon': Icons.loyalty, 'page': const CadastroMarcaPage()},
        {'title': 'Fornecedor', 'icon': Icons.local_shipping, 'page': const CadastroFornecedorPage()},
        {'title': 'Fabricantes', 'icon': Icons.factory, 'page': const CadastroFabricantePage()},
        {'title': 'Peças', 'icon': Icons.settings, 'page': const CadastroPecaPage()},
        {'title': 'Serviços', 'icon': Icons.home_repair_service, 'page': const CadastroServicoPage()},
      ],
    },
    {
      'group': 'Operações',
      'items': [
        {'title': 'Ordem de Serviço', 'icon': Icons.description},
        {'title': 'Agendamento', 'icon': Icons.support_agent, 'page': const AgendamentoPage()},
        {'title': 'Checklist', 'icon': Icons.checklist, 'page': const ChecklistPage()},
      ],
    },
    {
      'group': 'Relatórios',
      'items': [
        {'title': 'Relatórios', 'icon': Icons.analytics},
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

    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final agendamentos = await AgendamentoService.listarAgendamentos();
      final clientes = await ClienteService.listarClientes();
      final veiculos = await VeiculoService.listarVeiculos();
      final checklists = await ChecklistService.listarChecklists();
      final today = DateTime.now();
      int agendamentosHoje = 0;

      for (final agendamento in agendamentos) {
        final agendamentoDate = agendamento.data;
        if (agendamentoDate.year == today.year && agendamentoDate.month == today.month && agendamentoDate.day == today.day) {
          agendamentosHoje++;
        }
      }

      setState(() {
        _dashboardStats = {
          'Agendamentos Hoje': agendamentosHoje,
          'Clientes Ativos': clientes.length,
          'Veículos Cadastrados': veiculos.length,
          'Checklists Realizados': checklists.length,
        };
        _recentActivities = [];

        if (checklists.isNotEmpty) {
          final sortedChecklists = List.from(checklists)..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
          for (int i = 0; i < sortedChecklists.length && i < 2; i++) {
            final checklist = sortedChecklists[i];
            _recentActivities.add({
              'title': 'Checklist realizado',
              'subtitle': 'Veículo: ${checklist.veiculoNome ?? 'N/A'} - Placa: ${checklist.veiculoPlaca ?? 'N/A'}',
              'icon': Icons.checklist,
              'color': const Color(0xFF2196F3),
              'time': _getRelativeTime(checklist.id ?? 0),
            });
          }
        }

        if (agendamentos.isNotEmpty) {
          final sortedAgendamentos = List.from(agendamentos)..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
          for (int i = 0; i < sortedAgendamentos.length && i < 2; i++) {
            final agendamento = sortedAgendamentos[i];
            _recentActivities.add({
              'title': 'Agendamento criado',
              'subtitle': 'Mecânico: ${agendamento.nomeMecanico} - Veículo: ${agendamento.placaVeiculo}',
              'icon': Icons.event_note,
              'color': const Color(0xFF4CAF50),
              'time': _getRelativeTime(agendamento.id ?? 0),
            });
          }
        }

        if (clientes.isNotEmpty) {
          final sortedClientes = List.from(clientes)..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
          final cliente = sortedClientes.first;
          _recentActivities.add({
            'title': 'Cliente cadastrado',
            'subtitle': '${cliente.nome} - CPF: ${cliente.cpf}',
            'icon': Icons.person_add,
            'color': const Color(0xFFFF9800),
            'time': _getRelativeTime(cliente.id ?? 0),
          });
        }

        if (_recentActivities.length > 3) {
          _recentActivities = _recentActivities.take(3).toList();
        }

        _isLoadingStats = false;
      });
    } catch (e) {
      print('Erro ao carregar dados do dashboard: $e');
      setState(() {
        _dashboardStats = {
          'Agendamentos Hoje': 0,
          'Clientes Ativos': 0,
          'Veículos Cadastrados': 0,
          'Checklists Realizados': 0,
        };
        _recentActivities = [];
        _isLoadingStats = false;
      });

      if (mounted) {
        String errorMessage = 'Erro ao carregar dados. ';
        if (e.toString().contains('Connection')) {
          errorMessage += 'Verifique se o servidor está rodando na porta 8081.';
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
            color: Colors.black.withOpacity(0.1),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.car_repair,
                  color: Colors.white,
                  size: 32,
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
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hoje, ${_formatDate(DateTime.now())}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
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
            color: Colors.black.withOpacity(0.05),
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
                  color: color.withOpacity(0.1),
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
                  color: color.withOpacity(0.6),
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
                color: Colors.black.withOpacity(0.05),
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
                  color: (action['color'] as Color).withOpacity(0.1),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Atividade Recente',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E3440),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
              : _recentActivities.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Nenhuma atividade recente encontrada',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (int i = 0; i < _recentActivities.length; i++) ...[
                          _buildActivityItem(
                            _recentActivities[i]['title'],
                            _recentActivities[i]['subtitle'],
                            _recentActivities[i]['icon'],
                            _recentActivities[i]['color'],
                            _recentActivities[i]['time'],
                          ),
                          if (i < _recentActivities.length - 1) const Divider(height: 24),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(String title, String subtitle, IconData icon, Color color, String time) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E3440),
                ),
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
      case 'Checklists Realizados':
        return Icons.checklist;
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

  String _getRelativeTime(int id) {
    if (id == 0) return 'Há alguns minutos';

    final now = DateTime.now();
    final diff = now.millisecondsSinceEpoch - (id * 60000);
    final minutes = (diff / 60000).abs().round();

    if (minutes < 60) {
      return minutes <= 1 ? '1 min atrás' : '$minutes min atrás';
    } else if (minutes < 1440) {
      final hours = (minutes / 60).round();
      return hours == 1 ? '1 hora atrás' : '$hours horas atrás';
    } else {
      final days = (minutes / 1440).round();
      return days == 1 ? '1 dia atrás' : '$days dias atrás';
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
          if (_currentTitle == 'Início')
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
              onPressed: _isLoadingStats
                  ? null
                  : () async {
                      HapticFeedback.lightImpact();
                      try {
                        await _loadDashboardData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('📊 Dados atualizados com sucesso!'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Erro ao atualizar: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    },
              tooltip: 'Atualizar dados',
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
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.car_repair,
                              color: Colors.white,
                              size: 32,
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
                              color: Colors.white.withOpacity(0.9),
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
                if (items.length == 1) {
                  final item = items.first as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _currentTitle == item['title'] ? const Color(0xFF1565C0).withOpacity(0.1) : Colors.transparent,
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _currentTitle == item['title'] ? const Color(0xFF1565C0) : const Color(0xFF1565C0).withOpacity(0.1),
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
                        color: Colors.black.withOpacity(0.05),
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
                          color: const Color(0xFF1565C0).withOpacity(0.1),
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
                      children: items.map<Widget>((raw) {
                        final item = raw as Map<String, dynamic>;
                        return Container(
                          margin: const EdgeInsets.only(left: 16, right: 8, bottom: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _currentTitle == item['title'] ? const Color(0xFF1565C0).withOpacity(0.1) : Colors.transparent,
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _currentTitle == item['title'] ? const Color(0xFF1565C0) : const Color(0xFF1565C0).withOpacity(0.1),
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
      body: _isDashboardActive ? _buildDashboard() : (_currentPageWidget ?? const SizedBox.shrink()),
    );
  }
}
