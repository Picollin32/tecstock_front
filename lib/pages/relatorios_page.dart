import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/relatorio.dart';
import '../model/funcionario.dart';
import '../services/relatorio_service.dart';

class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({super.key});

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatoriosPage> {
  final RelatorioService _relatorioService = RelatorioService();
  final TextEditingController _dataInicioController = TextEditingController();
  final TextEditingController _dataFimController = TextEditingController();

  DateTime? _dataInicio;
  DateTime? _dataFim;
  String _tipoRelatorio = 'agendamentos';
  bool _isLoading = false;

  dynamic _relatorioAtual;

  // Para relatório de comissão
  List<Funcionario> _funcionarios = [];
  int? _mecanicoSelecionadoId;
  bool _isLoadingFuncionarios = false;

  @override
  void initState() {
    super.initState();
    // Definir período padrão: último mês
    _dataFim = DateTime.now();
    _dataInicio = DateTime(_dataFim!.year, _dataFim!.month - 1, _dataFim!.day);
    _dataInicioController.text = DateFormat('dd/MM/yyyy').format(_dataInicio!);
    _dataFimController.text = DateFormat('dd/MM/yyyy').format(_dataFim!);
    _carregarFuncionarios();
  }

  Future<void> _carregarFuncionarios() async {
    setState(() {
      _isLoadingFuncionarios = true;
    });
    try {
      // Buscar apenas mecânicos (nivelAcesso == 2)
      final response = await http.get(Uri.parse('http://localhost:8081/api/funcionarios/listarMecanicos'));
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        final mecanicos = jsonList.map((e) => Funcionario.fromJson(e)).toList();
        setState(() {
          _funcionarios = mecanicos;
          _isLoadingFuncionarios = false;
        });
      } else {
        setState(() {
          _isLoadingFuncionarios = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingFuncionarios = false;
      });
      print('Erro ao carregar mecânicos: $e');
    }
  }

  @override
  void dispose() {
    _dataInicioController.dispose();
    _dataFimController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData(BuildContext context, bool isInicio) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isInicio ? _dataInicio ?? DateTime.now() : _dataFim ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2100, 12, 31),
      locale: const Locale('pt', 'BR'),
    );

    if (picked != null) {
      setState(() {
        if (isInicio) {
          _dataInicio = picked;
          _dataInicioController.text = DateFormat('dd/MM/yyyy').format(picked);
        } else {
          _dataFim = picked;
          _dataFimController.text = DateFormat('dd/MM/yyyy').format(picked);
        }
      });
    }
  }

  Future<void> _gerarRelatorio() async {
    if (_dataInicio == null || _dataFim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione as datas de início e fim')),
      );
      return;
    }

    if (_dataInicio!.isAfter(_dataFim!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data inicial deve ser anterior à data final')),
      );
      return;
    }

    if (_tipoRelatorio == 'comissao' && _mecanicoSelecionadoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um mecânico para o relatório de comissão')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      dynamic relatorio;
      switch (_tipoRelatorio) {
        case 'agendamentos':
          relatorio = await _relatorioService.getRelatorioAgendamentos(_dataInicio!, _dataFim!);
          break;
        case 'servicos':
          relatorio = await _relatorioService.getRelatorioServicos(_dataInicio!, _dataFim!);
          break;
        case 'estoque':
          relatorio = await _relatorioService.getRelatorioEstoque(_dataInicio!, _dataFim!);
          break;
        case 'financeiro':
          relatorio = await _relatorioService.getRelatorioFinanceiro(_dataInicio!, _dataFim!);
          break;
        case 'comissao':
          relatorio = await _relatorioService.getRelatorioComissao(_dataInicio!, _dataFim!, _mecanicoSelecionadoId!);
          break;
        case 'garantias':
          relatorio = await _relatorioService.getRelatorioGarantias(_dataInicio!, _dataFim!);
          break;
        case 'fiado':
          relatorio = await _relatorioService.getRelatorioFiado(_dataInicio!, _dataFim!);
          break;
      }

      setState(() {
        _relatorioAtual = relatorio;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar relatório: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header moderno
            _buildModernHeader(context),

            // Conteúdo
            Expanded(
              child: _relatorioAtual == null ? _buildFormSection(context) : _buildResultSection(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
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
              Icons.analytics,
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
                  'Relatórios',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Análises e estatísticas do sistema',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                ),
              ],
            ),
          ),
          if (_relatorioAtual != null)
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
                      _relatorioAtual = null;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Nova Consulta',
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

  Widget _buildFormSection(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tipo de relatório
          _buildModernCard(
            context,
            title: 'Tipo de Relatório',
            icon: Icons.assessment,
            color: Colors.purple,
            child: DropdownButtonFormField<String>(
              value: _tipoRelatorio,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'agendamentos',
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month, size: 20),
                      SizedBox(width: 12),
                      Text('Relatório de Agendamentos'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'servicos',
                  child: Row(
                    children: [
                      Icon(Icons.build, size: 20),
                      SizedBox(width: 12),
                      Text('Relatório de Serviços'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'estoque',
                  child: Row(
                    children: [
                      Icon(Icons.inventory, size: 20),
                      SizedBox(width: 12),
                      Text('Relatório de Estoque'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'financeiro',
                  child: Row(
                    children: [
                      Icon(Icons.attach_money, size: 20),
                      SizedBox(width: 12),
                      Text('Relatório Financeiro'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'comissao',
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet, size: 20),
                      SizedBox(width: 12),
                      Text('Relatório de Comissão'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'garantias',
                  child: Row(
                    children: [
                      Icon(Icons.verified_user, size: 20),
                      SizedBox(width: 12),
                      Text('Relatório de Garantias'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'fiado',
                  child: Row(
                    children: [
                      Icon(Icons.credit_card, size: 20),
                      SizedBox(width: 12),
                      Text('Relatório de Fiado'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _tipoRelatorio = value!;
                  _relatorioAtual = null;
                  _mecanicoSelecionadoId = null;
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          // Seleção de Mecânico (apenas para relatório de comissão)
          if (_tipoRelatorio == 'comissao')
            _buildModernCard(
              context,
              title: 'Mecânico',
              icon: Icons.person,
              color: Colors.orange,
              child: _isLoadingFuncionarios
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : DropdownButtonFormField<int>(
                      value: _mecanicoSelecionadoId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        hintText: 'Selecione um mecânico',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: _funcionarios
                          .map((func) => DropdownMenuItem<int>(
                                value: func.id,
                                child: Text(func.nome),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _mecanicoSelecionadoId = value;
                          _relatorioAtual = null;
                        });
                      },
                    ),
            ),
          if (_tipoRelatorio == 'comissao') const SizedBox(height: 16),

          // Período
          _buildModernCard(
            context,
            title: 'Período',
            icon: Icons.date_range,
            color: Colors.green,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dataInicioController,
                    decoration: InputDecoration(
                      labelText: 'Data Início',
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      suffixIcon: const Icon(Icons.calendar_today),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    readOnly: true,
                    onTap: () => _selecionarData(context, true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _dataFimController,
                    decoration: InputDecoration(
                      labelText: 'Data Fim',
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      suffixIcon: const Icon(Icons.calendar_today),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    readOnly: true,
                    onTap: () => _selecionarData(context, false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botão gerar
          Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade700],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isLoading ? null : _gerarRelatorio,
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bar_chart, color: Colors.white, size: 24),
                            const SizedBox(width: 12),
                            Text(
                              _isLoading ? 'Gerando...' : 'Gerar Relatório',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildResultSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: _buildRelatorioContent(),
      ),
    );
  }

  Widget _buildModernCard(BuildContext context,
      {required String title, required IconData icon, required Color color, required Widget child}) {
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
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
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildRelatorioContent() {
    switch (_tipoRelatorio) {
      case 'agendamentos':
        return _buildRelatorioAgendamentos(_relatorioAtual as RelatorioAgendamentos);
      case 'servicos':
        return _buildRelatorioServicos(_relatorioAtual as RelatorioServicos);
      case 'estoque':
        return _buildRelatorioEstoque(_relatorioAtual as RelatorioEstoque);
      case 'financeiro':
        return _buildRelatorioFinanceiro(_relatorioAtual as RelatorioFinanceiro);
      case 'comissao':
        return _buildRelatorioComissao(_relatorioAtual as RelatorioComissao);
      case 'garantias':
        return _buildRelatorioGarantias(_relatorioAtual as RelatorioGarantias);
      case 'fiado':
        return _buildRelatorioFiado(_relatorioAtual as RelatorioFiado);
      default:
        return const SizedBox();
    }
  }

  Widget _buildRelatorioAgendamentos(RelatorioAgendamentos relatorio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho do relatório
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Relatório de Agendamentos',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Seção de Resumo
        _buildSectionHeader('Resumo Geral', Icons.assessment, Colors.blue),
        const SizedBox(height: 12),
        _buildMetricCard('Total de Agendamentos', relatorio.totalAgendamentos.toString(), Icons.event, color: Colors.blue),
        _buildMetricCard('Mecânicos Ativos', relatorio.agendamentosPorMecanico.toString(), Icons.person, color: Colors.green),

        const SizedBox(height: 24),

        // Seção de Agendamentos por Dia
        if (relatorio.agendamentosPorDia.isNotEmpty) ...[
          _buildSectionHeader('Agendamentos por Dia', Icons.calendar_today, Colors.purple),
          const SizedBox(height: 12),
          ...relatorio.agendamentosPorDia.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.purple.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(DateTime.parse(item.data)),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${item.quantidade} agendamento${item.quantidade != 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 24),
        ],

        // Seção de Agendamentos por Mecânico
        if (relatorio.agendamentosPorMecanicoLista.isNotEmpty) ...[
          _buildSectionHeader('Agendamentos por Mecânico', Icons.person, Colors.orange),
          const SizedBox(height: 12),
          ...relatorio.agendamentosPorMecanicoLista.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.orange.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.nomeMecanico,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${item.quantidade} agendamento${item.quantidade != 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildRelatorioServicos(RelatorioServicos relatorio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho do relatório
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade400, Colors.indigo.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.build, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Relatório de Serviços',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Serviços Realizados
        _buildSectionHeader('Serviços Realizados', Icons.construction, Colors.indigo),
        const SizedBox(height: 12),
        _buildMetricCard(
          'Valor dos Serviços Realizados',
          'R\$ ${relatorio.valorServicosRealizados.toStringAsFixed(2)}',
          Icons.construction,
          color: Colors.green,
        ),
        _buildMetricCard(
          'Descontos em Serviços',
          'R\$ ${relatorio.descontoServicos.toStringAsFixed(2)}',
          Icons.discount,
          color: Colors.orange,
        ),
        _buildMetricCard(
          'Total de Serviços Realizados',
          relatorio.totalServicosRealizados.toString(),
          Icons.done_all,
          color: Colors.indigo,
        ),

        const SizedBox(height: 24),

        // Serviços Mais Realizados
        if (relatorio.servicosMaisRealizados.isNotEmpty) ...[
          _buildSectionHeader('Serviços Mais Realizados', Icons.star, Colors.amber),
          const SizedBox(height: 12),
          ...relatorio.servicosMaisRealizados.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.build_circle, color: Colors.amber.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.nomeServico,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${item.quantidade} vezes realizado',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'R\$ ${item.valorTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 24),
        ],

        // Ordem de Serviço
        _buildSectionHeader('Ordens de Serviço', Icons.assignment, Colors.deepPurple),
        const SizedBox(height: 12),
        _buildMetricCard('Total de Ordens de Serviço', relatorio.totalOrdensServico.toString(), Icons.assignment, color: Colors.deepPurple),
        _buildMetricCard('Ordens Finalizadas (Encerradas)', relatorio.ordensFinalizadas.toString(), Icons.check_circle,
            color: Colors.green),
        _buildMetricCard('Ordens em Andamento (Abertas)', relatorio.ordensEmAndamento.toString(), Icons.pending, color: Colors.orange),

        const SizedBox(height: 24),

        // Métricas Adicionais
        _buildSectionHeader('Métricas Adicionais', Icons.analytics, Colors.blue),
        const SizedBox(height: 12),
        _buildMetricCard('Valor Médio por Ordem', 'R\$ ${relatorio.valorMedioPorOrdem.toStringAsFixed(2)}', Icons.analytics,
            color: Colors.blue),
        _buildMetricCard('Tempo Médio de Execução', '${relatorio.tempoMedioExecucao.toStringAsFixed(1)} dias', Icons.timer,
            color: Colors.cyan),
      ],
    );
  }

  Widget _buildRelatorioEstoque(RelatorioEstoque relatorio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho do relatório
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade400, Colors.teal.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Relatório de Estoque',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Movimentações
        _buildSectionHeader('Movimentações', Icons.swap_horiz, Colors.teal),
        const SizedBox(height: 12),
        _buildMetricCard('Total de Movimentações', relatorio.totalMovimentacoes.toString(), Icons.swap_horiz, color: Colors.teal),
        _buildMetricCard('Entradas', relatorio.totalEntradas.toString(), Icons.arrow_circle_down, color: Colors.green),
        _buildMetricCard('Saídas', relatorio.totalSaidas.toString(), Icons.arrow_circle_up, color: Colors.red),

        const SizedBox(height: 24),

        // Valores
        _buildSectionHeader('Valores', Icons.attach_money, Colors.blue),
        const SizedBox(height: 12),
        _buildMetricCard('Valor Total do Estoque', 'R\$ ${relatorio.valorTotalEstoque.toStringAsFixed(2)}', Icons.inventory_2,
            color: Colors.blue),
        _buildMetricCard('Valor das Entradas', 'R\$ ${relatorio.valorEntradas.toStringAsFixed(2)}', Icons.add_circle_outline,
            color: Colors.green),
        _buildMetricCard('Valor das Saídas', 'R\$ ${relatorio.valorSaidas.toStringAsFixed(2)}', Icons.remove_circle_outline,
            color: Colors.red),

        const SizedBox(height: 24),

        // Peças Mais Movimentadas
        if (relatorio.pecasMaisMovimentadas.isNotEmpty) ...[
          _buildSectionHeader('Peças Mais Movimentadas', Icons.star, Colors.amber),
          const SizedBox(height: 12),
          ...relatorio.pecasMaisMovimentadas.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.nomePeca,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Quantidade: ${item.quantidade}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'R\$ ${item.valor.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 24),
        ],

        // Peças com Estoque Baixo
        if (relatorio.pecasEstoqueBaixo.isNotEmpty) ...[
          _buildSectionHeader('Peças com Estoque Baixo', Icons.warning, Colors.red),
          const SizedBox(height: 12),
          ...relatorio.pecasEstoqueBaixo.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.nomePeca,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Quantidade: ${item.quantidade}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'R\$ ${item.valor.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildRelatorioFinanceiro(RelatorioFinanceiro relatorio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho do relatório
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.attach_money, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Relatório Financeiro',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Receitas
        _buildSectionHeader('Receitas', Icons.trending_up, Colors.green),
        const SizedBox(height: 12),
        _buildMetricCard('Receita de Peças', 'R\$ ${relatorio.receitaPecas.toStringAsFixed(2)}', Icons.inventory_2, color: Colors.green),
        _buildMetricCard('Receita de Serviços', 'R\$ ${relatorio.receitaServicos.toStringAsFixed(2)}', Icons.build_circle,
            color: Colors.green),
        _buildMetricCard('Receita Total', 'R\$ ${relatorio.receitaTotal.toStringAsFixed(2)}', Icons.monetization_on,
            color: Colors.green.shade700),

        const SizedBox(height: 24),

        // Despesas e Descontos
        _buildSectionHeader('Despesas e Descontos', Icons.trending_down, Colors.red),
        const SizedBox(height: 12),
        _buildMetricCard('Despesas com Estoque', 'R\$ ${relatorio.despesasEstoque.toStringAsFixed(2)}', Icons.shopping_cart,
            color: Colors.red),
        _buildMetricCard('Descontos em Peças', 'R\$ ${relatorio.descontosPecas.toStringAsFixed(2)}', Icons.discount, color: Colors.orange),
        _buildMetricCard('Descontos em Serviços', 'R\$ ${relatorio.descontosServicos.toStringAsFixed(2)}', Icons.percent,
            color: Colors.orange),
        _buildMetricCard('Total de Descontos', 'R\$ ${relatorio.descontosTotal.toStringAsFixed(2)}', Icons.remove_circle,
            color: Colors.deepOrange),

        const SizedBox(height: 24),

        // Resultado
        _buildSectionHeader('Resultado', Icons.assessment, Colors.indigo),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: relatorio.lucroEstimado >= 0
                  ? [Colors.green.shade400, Colors.green.shade600]
                  : [Colors.red.shade400, Colors.red.shade600],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: (relatorio.lucroEstimado >= 0 ? Colors.green : Colors.red).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                relatorio.lucroEstimado >= 0 ? Icons.trending_up : Icons.trending_down,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      relatorio.lucroEstimado >= 0 ? 'Lucro' : 'Prejuízo',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'R\$ ${relatorio.lucroEstimado.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildMetricCard('Ticket Médio', 'R\$ ${relatorio.ticketMedio.toStringAsFixed(2)}', Icons.analytics, color: Colors.indigo),

        const SizedBox(height: 24),

        // Receita por Tipo de Pagamento
        if (relatorio.receitaPorTipoPagamento.isNotEmpty) ...[
          _buildSectionHeader('Receita por Tipo de Pagamento', Icons.payment, Colors.blue),
          const SizedBox(height: 12),
          ...relatorio.receitaPorTipoPagamento.entries.map((entry) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payment, color: Colors.blue.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${relatorio.quantidadePorTipoPagamento[entry.key] ?? 0} transações',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'R\$ ${entry.value.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, {Color? color}) {
    final cardColor = color ?? Colors.blue;
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: cardColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cardColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatorioComissao(RelatorioComissao relatorio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Relatório de Comissão',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    relatorio.mecanicoNome,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${DateFormat('dd/MM/yyyy').format(relatorio.dataInicio)} - ${DateFormat('dd/MM/yyyy').format(relatorio.dataFim)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Card de Comissão em Destaque
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.green.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.monetization_on,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'COMISSÃO TOTAL',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'R\$ ${relatorio.valorComissao.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Cards de Métricas
        Row(
          children: [
            Expanded(
              child: _buildMetricCardEnhanced(
                'Ordens de Serviço',
                relatorio.totalOrdensServico.toString(),
                Icons.assignment_outlined,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'Serviços Realizados',
                relatorio.totalServicosRealizados.toString(),
                Icons.build_circle_outlined,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCardEnhanced(
                'Valor Total',
                'R\$ ${relatorio.valorTotalServicos.toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'Descontos',
                'R\$ ${relatorio.descontoServicos.toStringAsFixed(2)}',
                Icons.discount,
                Colors.red.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Seção de Serviços Mais Realizados
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.star, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Text(
                'Serviços Mais Realizados',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Lista de Serviços Agregados
        ...(() {
          // Agregar todos os serviços de todas as OSs
          Map<int, Map<String, dynamic>> servicosAgregados = {};

          for (var os in relatorio.ordensServico) {
            for (var servico in os.servicosRealizados) {
              if (servicosAgregados.containsKey(servico.idServico)) {
                servicosAgregados[servico.idServico]!['quantidade'] += 1;
                servicosAgregados[servico.idServico]!['valorTotal'] += servico.valor - servico.valorDesconto;
              } else {
                servicosAgregados[servico.idServico] = {
                  'nome': servico.nomeServico,
                  'quantidade': 1,
                  'valorTotal': servico.valor - servico.valorDesconto,
                };
              }
            }
          }

          // Ordenar por quantidade (mais realizados primeiro)
          var servicosOrdenados = servicosAgregados.entries.toList()
            ..sort((a, b) => b.value['quantidade'].compareTo(a.value['quantidade']));

          return servicosOrdenados.map((entry) {
            final servico = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.star, color: Colors.orange.shade700, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          servico['nome'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Realizado ${servico['quantidade']}x',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'R\$ ${servico['valorTotal'].toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }).toList();
        })(),

        const SizedBox(height: 32),

        // Seção de Ordens de Serviço
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Text(
                'Ordens de Serviço Realizadas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Lista de Ordens de Serviço
        ...relatorio.ordensServico.asMap().entries.map((entry) {
          final index = entry.key;
          final os = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: index < relatorio.ordensServico.length - 1 ? 16 : 0),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.description, color: Colors.blue.shade700, size: 28),
                  ),
                  title: Text(
                    'OS #${os.numeroOS}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                os.clienteNome,
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.directions_car, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              '${os.veiculoNome} - ${os.veiculoPlaca}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                            ),
                          ],
                        ),
                        if (os.dataHoraEncerramento != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade600),
                              const SizedBox(width: 6),
                              Text(
                                'Encerrada: ${DateFormat('dd/MM/yyyy HH:mm').format(os.dataHoraEncerramento!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'R\$ ${os.valorServicos.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.green.shade700,
                          ),
                        ),
                        if (os.descontoServicos > 0)
                          Text(
                            '-R\$ ${os.descontoServicos.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.red.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.build, size: 18, color: Colors.grey.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Serviços Realizados (${os.servicosRealizados.length})',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...os.servicosRealizados.map((servico) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green.shade400,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            servico.nomeServico,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (servico.dataRealizacao != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              DateFormat('dd/MM/yyyy').format(servico.dataRealizacao!),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'R\$ ${servico.valor.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (servico.valorDesconto > 0)
                                          Text(
                                            '-R\$ ${servico.valorDesconto.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange.shade700,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMetricCardEnhanced(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatorioGarantias(RelatorioGarantias relatorio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho do relatório
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade400, Colors.teal.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.verified_user, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Relatório de Garantias',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Estatísticas gerais
        _buildSectionHeader('Resumo', Icons.assessment, Colors.teal),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCardEnhanced(
                'Total de Garantias',
                relatorio.totalGarantias.toString(),
                Icons.assignment_outlined,
                Colors.teal,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'Em Aberto',
                relatorio.garantiasEmAberto.toString(),
                Icons.check_circle_outlined,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildMetricCardEnhanced(
          'Encerradas',
          relatorio.garantiasEncerradas.toString(),
          Icons.cancel_outlined,
          Colors.red,
        ),
        const SizedBox(height: 32),

        // Lista de Garantias
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.list_alt, color: Colors.teal.shade700),
              const SizedBox(width: 12),
              Text(
                'Garantias no Período',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Cards de Garantia
        if (relatorio.garantias.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma garantia encontrada no período selecionado',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        ...relatorio.garantias.map((garantia) {
          // Cor baseada no status
          final Color statusColor = garantia.emAberto ? Colors.green : Colors.red;
          final Color backgroundColor = garantia.emAberto ? Colors.green.shade50 : Colors.red.shade50;
          final Color borderColor = garantia.emAberto ? Colors.green.shade200 : Colors.red.shade200;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho do card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          garantia.emAberto ? Icons.check_circle : Icons.cancel,
                          color: statusColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OS #${garantia.numeroOS}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                garantia.statusDescricao,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'R\$ ${garantia.valorTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            Text(
                              '${garantia.garantiaMeses} ${garantia.garantiaMeses == 1 ? 'mês' : 'meses'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Informações detalhadas
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Cliente
                      _buildInfoRow(
                        Icons.person,
                        'Cliente',
                        garantia.clienteNome,
                        statusColor,
                      ),
                      _buildInfoRow(
                        Icons.badge,
                        'CPF',
                        garantia.clienteCpf,
                        statusColor,
                      ),
                      if (garantia.clienteTelefone != null && garantia.clienteTelefone!.isNotEmpty)
                        _buildInfoRow(
                          Icons.phone,
                          'Telefone',
                          garantia.clienteTelefone!,
                          statusColor,
                        ),

                      const Divider(height: 24),

                      // Veículo
                      _buildInfoRow(
                        Icons.directions_car,
                        'Veículo',
                        '${garantia.veiculoNome} - ${garantia.veiculoPlaca}',
                        statusColor,
                      ),
                      if (garantia.veiculoMarca != null && garantia.veiculoMarca!.isNotEmpty)
                        _buildInfoRow(
                          Icons.branding_watermark,
                          'Marca',
                          garantia.veiculoMarca!,
                          statusColor,
                        ),

                      const Divider(height: 24),

                      // Datas
                      _buildInfoRow(
                        Icons.event_available,
                        'Encerramento',
                        DateFormat('dd/MM/yyyy HH:mm').format(garantia.dataEncerramento),
                        statusColor,
                      ),
                      _buildInfoRow(
                        Icons.calendar_today,
                        'Início Garantia',
                        DateFormat('dd/MM/yyyy').format(garantia.dataInicioGarantia),
                        statusColor,
                      ),
                      _buildInfoRow(
                        Icons.event_busy,
                        'Fim Garantia',
                        DateFormat('dd/MM/yyyy').format(garantia.dataFimGarantia),
                        statusColor,
                      ),

                      const Divider(height: 24),

                      // Responsáveis
                      if (garantia.mecanicoNome != null && garantia.mecanicoNome!.isNotEmpty)
                        _buildInfoRow(
                          Icons.build,
                          'Mecânico',
                          garantia.mecanicoNome!,
                          statusColor,
                        ),
                      if (garantia.consultorNome != null && garantia.consultorNome!.isNotEmpty)
                        _buildInfoRow(
                          Icons.support_agent,
                          'Consultor',
                          garantia.consultorNome!,
                          statusColor,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatorioFiado(RelatorioFiado relatorio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho do relatório
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade400, Colors.orange.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.credit_card, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Relatório de Fiado',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Estatísticas gerais
        _buildSectionHeader('Resumo', Icons.assessment, Colors.orange),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCardEnhanced(
                'Total de Fiados',
                relatorio.totalFiados.toString(),
                Icons.assignment_outlined,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'No Prazo',
                relatorio.fiadosNoPrazo.toString(),
                Icons.check_circle_outlined,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCardEnhanced(
                'Vencidos',
                relatorio.fiadosVencidos.toString(),
                Icons.cancel_outlined,
                Colors.red,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'Valor Total',
                'R\$ ${relatorio.valorTotalFiado.toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCardEnhanced(
                'Valor No Prazo',
                'R\$ ${relatorio.valorNoPrazo.toStringAsFixed(2)}',
                Icons.check_circle_outlined,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'Valor Vencido',
                'R\$ ${relatorio.valorVencido.toStringAsFixed(2)}',
                Icons.warning_outlined,
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Lista de Fiados
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.list_alt, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Text(
                'Fiados no Período',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Cards de Fiado
        if (relatorio.fiados.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum fiado encontrado no período selecionado',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),

        ...relatorio.fiados.map((fiado) {
          // Cor baseada no status
          final Color statusColor = fiado.noPrazo ? Colors.green : Colors.red;
          final Color backgroundColor = fiado.noPrazo ? Colors.green.shade50 : Colors.red.shade50;
          final Color borderColor = fiado.noPrazo ? Colors.green.shade200 : Colors.red.shade200;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho do card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          fiado.noPrazo ? Icons.check_circle : Icons.warning,
                          color: statusColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OS #${fiado.numeroOS}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                fiado.statusDescricao,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'R\$ ${fiado.valorTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            Text(
                              '${fiado.prazoFiadoDias} ${fiado.prazoFiadoDias == 1 ? 'dia' : 'dias'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Informações detalhadas
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Cliente
                      _buildInfoRow(
                        Icons.person,
                        'Cliente',
                        fiado.clienteNome,
                        statusColor,
                      ),
                      _buildInfoRow(
                        Icons.badge,
                        'CPF',
                        fiado.clienteCpf,
                        statusColor,
                      ),
                      if (fiado.clienteTelefone != null && fiado.clienteTelefone!.isNotEmpty)
                        _buildInfoRow(
                          Icons.phone,
                          'Telefone',
                          fiado.clienteTelefone!,
                          statusColor,
                        ),

                      const Divider(height: 24),

                      // Veículo
                      _buildInfoRow(
                        Icons.directions_car,
                        'Veículo',
                        '${fiado.veiculoNome} - ${fiado.veiculoPlaca}',
                        statusColor,
                      ),
                      if (fiado.veiculoMarca != null && fiado.veiculoMarca!.isNotEmpty)
                        _buildInfoRow(
                          Icons.branding_watermark,
                          'Marca',
                          fiado.veiculoMarca!,
                          statusColor,
                        ),

                      const Divider(height: 24),

                      // Datas
                      _buildInfoRow(
                        Icons.event_available,
                        'Encerramento OS',
                        DateFormat('dd/MM/yyyy HH:mm').format(fiado.dataEncerramento),
                        statusColor,
                      ),
                      _buildInfoRow(
                        Icons.calendar_today,
                        'Início do Prazo',
                        DateFormat('dd/MM/yyyy').format(fiado.dataInicioFiado),
                        statusColor,
                      ),
                      _buildInfoRow(
                        Icons.event_busy,
                        'Vencimento',
                        DateFormat('dd/MM/yyyy').format(fiado.dataVencimentoFiado),
                        statusColor,
                      ),

                      const Divider(height: 24),

                      // Pagamento
                      if (fiado.tipoPagamentoNome != null && fiado.tipoPagamentoNome!.isNotEmpty)
                        _buildInfoRow(
                          Icons.payment,
                          'Tipo de Pagamento',
                          fiado.tipoPagamentoNome!,
                          statusColor,
                        ),

                      // Responsáveis
                      if (fiado.mecanicoNome != null && fiado.mecanicoNome!.isNotEmpty)
                        _buildInfoRow(
                          Icons.build,
                          'Mecânico',
                          fiado.mecanicoNome!,
                          statusColor,
                        ),
                      if (fiado.consultorNome != null && fiado.consultorNome!.isNotEmpty)
                        _buildInfoRow(
                          Icons.support_agent,
                          'Consultor',
                          fiado.consultorNome!,
                          statusColor,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
