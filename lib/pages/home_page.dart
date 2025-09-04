import 'package:TecStock/pages/agendamento_page.dart';
import 'package:TecStock/pages/cadastro_fabricante_page.dart';
import 'package:TecStock/pages/cadastro_fornecedor_page.dart';
import 'package:TecStock/pages/cadastro_funcioario_page.dart';
import 'package:TecStock/pages/cadastro_marca_page.dart';
import 'package:TecStock/pages/cadastro_peca_page.dart';
import 'package:TecStock/pages/cadastro_servico_page.dart';
import 'package:TecStock/pages/checklist_page.dart';
import 'package:flutter/material.dart';
import 'cadastro_cliente_page.dart';
import 'cadastro_veiculo_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Widget _currentPage;
  late String _currentTitle;

  static final List<Map<String, dynamic>> _menuGroups = [
    {
      'group': 'Geral',
      'items': [
        {
          'title': 'Início',
          'icon': Icons.home,
          'page': const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.car_repair, size: 80, color: Color.fromARGB(255, 0, 20, 255)),
                SizedBox(height: 16),
                Text('Bem-vindo ao TecStock!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text('Selecione uma opção no menu lateral.', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
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
    Map<String, dynamic>? initial;
    for (var group in _menuGroups) {
      for (var item in group['items']) {
        if (item['title'] == 'Início') initial = item as Map<String, dynamic>?;
      }
    }
    initial ??= _menuGroups.first['items'].first as Map<String, dynamic>;
    _currentPage = initial['page'];
    _currentTitle = initial['title'];
  }

  void _navigateTo(BuildContext context, Widget page, String title) {
    Navigator.pop(context);
    setState(() {
      _currentPage = page;
      _currentTitle = title;
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
        title: Text(_currentTitle),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 0, 20, 255),
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 0, 20, 255),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.car_repair, color: Colors.white, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'TecStock',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Gerenciamento de Oficina',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ..._menuGroups.map((group) {
              final items = group['items'] as List<dynamic>;
              if (items.length == 1) {
                final item = items.first as Map<String, dynamic>;
                return ListTile(
                  leading: Icon(item['icon'], color: const Color.fromARGB(255, 0, 20, 255)),
                  title: Text(item['title']),
                  onTap: () {
                    if (item['page'] != null) {
                      _navigateTo(context, item['page'], item['title']);
                    } else {
                      _showComingSoon(context, item['title']);
                    }
                  },
                );
              }

              return ExpansionTile(
                leading: Icon(Icons.folder, color: const Color.fromARGB(255, 0, 20, 255)),
                title: Text(group['group']),
                children: items.map<Widget>((raw) {
                  final item = raw as Map<String, dynamic>;
                  return ListTile(
                    leading: Icon(item['icon'], color: const Color.fromARGB(255, 0, 20, 255)),
                    title: Text(item['title']),
                    onTap: () {
                      if (item['page'] != null) {
                        _navigateTo(context, item['page'], item['title']);
                      } else {
                        _showComingSoon(context, item['title']);
                      }
                    },
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ),
      body: _currentPage,
    );
  }
}
