import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../model/relatorio.dart';
import '../model/funcionario.dart';
import '../services/relatorio_service.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import '../utils/pdf_logo_helper.dart';
import '../model/conta.dart';
import '../services/conta_service.dart';

class RelatorioContasMes {
  final int mes;
  final int ano;
  final List<Conta> contasAPagar;
  final List<Conta> contasAReceber;
  final List<Conta> contasAtrasadas;
  final Map<String, double> resumo;

  RelatorioContasMes({
    required this.mes,
    required this.ano,
    required this.contasAPagar,
    required this.contasAReceber,
    required this.contasAtrasadas,
    required this.resumo,
  });
}

class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({super.key});

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatoriosPage> {
  static const Color primaryColor = Color(0xFF1565C0);

  final RelatorioService _relatorioService = RelatorioService();
  final TextEditingController _dataInicioController = TextEditingController();
  final TextEditingController _dataFimController = TextEditingController();

  DateTime? _dataInicio;
  DateTime? _dataFim;
  String _tipoRelatorio = 'consultores';
  String _periodoRapido = 'ultimos_30_dias';
  bool _isLoading = false;
  bool _isGeneratingPdf = false;

  dynamic _relatorioAtual;

  List<Funcionario> _funcionarios = [];
  int? _mecanicoSelecionadoId;
  bool _isLoadingFuncionarios = false;
  DateTime _mesContas = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String _filtroGarantiaRelatorio = 'TODOS';

  @override
  void initState() {
    super.initState();

    _aplicarPeriodoRapido('ultimos_30_dias');
    _carregarFuncionarios();
    _preloadLogo();
  }

  Future<void> _preloadLogo() async {
    await PdfLogoHelper.preloadLogo();
  }

  Future<void> _carregarFuncionarios() async {
    setState(() {
      _isLoadingFuncionarios = true;
    });
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.funcionariosUrl}/listarMecanicos'),
        headers: await AuthService.getAuthHeaders(),
      );
      if (response.statusCode == 200) {
        final List jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        final mecanicos = jsonList.map((e) => Funcionario.fromJson(e)).toList();

        mecanicos.sort((a, b) => a.nome.compareTo(b.nome));
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
      if (kDebugMode) {
        print('Erro ao carregar mecânicos: $e');
      }
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

  void _atualizarPeriodo(DateTime inicio, DateTime fim) {
    final start = DateTime(inicio.year, inicio.month, inicio.day);
    final end = DateTime(fim.year, fim.month, fim.day);

    _dataInicio = start;
    _dataFim = end;
    _dataInicioController.text = DateFormat('dd/MM/yyyy').format(start);
    _dataFimController.text = DateFormat('dd/MM/yyyy').format(end);
  }

  void _aplicarPeriodoRapido(String periodo) {
    final hoje = DateTime.now();
    late DateTime inicio;
    late DateTime fim;

    switch (periodo) {
      case 'hoje':
        inicio = hoje;
        fim = hoje;
        break;
      case 'ultimos_7_dias':
        inicio = hoje.subtract(const Duration(days: 6));
        fim = hoje;
        break;
      case 'ultimos_30_dias':
        inicio = hoje.subtract(const Duration(days: 29));
        fim = hoje;
        break;
      case 'ultimos_90_dias':
        inicio = hoje.subtract(const Duration(days: 89));
        fim = hoje;
        break;
      case 'mes_atual':
        inicio = DateTime(hoje.year, hoje.month, 1);
        fim = hoje;
        break;
      case 'mes_anterior':
        final primeiroDiaMesAtual = DateTime(hoje.year, hoje.month, 1);
        fim = primeiroDiaMesAtual.subtract(const Duration(days: 1));
        inicio = DateTime(fim.year, fim.month, 1);
        break;
      default:
        inicio = hoje.subtract(const Duration(days: 29));
        fim = hoje;
    }

    _atualizarPeriodo(inicio, fim);
    _periodoRapido = periodo;
  }

  Future<void> _gerarRelatorio() async {
    if (_tipoRelatorio != 'contas' && _tipoRelatorio != 'garantias') {
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
          relatorio = await _relatorioService.getRelatorioGarantias(DateTime(2000, 1, 1), DateTime.now());
          break;
        case 'consultores':
          relatorio = await _relatorioService.getRelatorioConsultores(_dataInicio!, _dataFim!);
          break;
        case 'contas':
          final results = await Future.wait([
            ContaService.listarAPagarPorMesAno(_mesContas.month, _mesContas.year),
            ContaService.listarAReceberPorMesAno(_mesContas.month, _mesContas.year),
            ContaService.listarAtrasadas(),
            ContaService.resumoMes(_mesContas.month, _mesContas.year),
          ]);
          relatorio = RelatorioContasMes(
            mes: _mesContas.month,
            ano: _mesContas.year,
            contasAPagar: results[0] as List<Conta>,
            contasAReceber: results[1] as List<Conta>,
            contasAtrasadas: results[2] as List<Conta>,
            resumo: results[3] as Map<String, double>,
          );
          break;
        case 'clientes':
          relatorio = await _relatorioService.getRelatorioClientes(_dataInicio!, _dataFim!);
          break;
        case 'veiculos':
          relatorio = await _relatorioService.getRelatorioVeiculos(_dataInicio!, _dataFim!);
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar relatório: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        automaticallyImplyLeading: false,
        title: const Text(
          'Relatórios',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_relatorioAtual != null) ...[
            if (isMobile) ...[
              IconButton(
                onPressed: _isGeneratingPdf ? null : _imprimirRelatorio,
                icon: _isGeneratingPdf
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf),
                tooltip: 'Imprimir PDF',
              ),
              IconButton(
                onPressed: () => setState(() => _relatorioAtual = null),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Nova Consulta',
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ElevatedButton.icon(
                  onPressed: _isGeneratingPdf ? null : _imprimirRelatorio,
                  icon: _isGeneratingPdf
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf, size: 18),
                  label: Text(_isGeneratingPdf ? 'Gerando...' : 'Imprimir PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton.icon(
                  onPressed: () => setState(() => _relatorioAtual = null),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Nova Consulta'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _relatorioAtual == null ? _buildFormSection(context) : _buildResultSection(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildModernCard(
            context,
            title: 'Tipo de Relatório',
            icon: Icons.assessment,
            color: Colors.purple,
            child: DropdownButtonFormField<String>(
              initialValue: _tipoRelatorio,
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
                  value: 'consultores',
                  child: Row(
                    children: [
                      Icon(Icons.people_alt, size: 20),
                      SizedBox(width: 12),
                      Text('Desempenho Consultores'),
                    ],
                  ),
                ),
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
                  value: 'contas',
                  child: Row(
                    children: [
                      Icon(Icons.account_balance, size: 20),
                      SizedBox(width: 12),
                      Text('Contas a Pagar/Receber'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'clientes',
                  child: Row(
                    children: [
                      Icon(Icons.people, size: 20),
                      SizedBox(width: 12),
                      Text('Relatório de Clientes'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: 'veiculos',
                  child: Row(
                    children: [
                      Icon(Icons.directions_car, size: 20),
                      SizedBox(width: 12),
                      Text('Relatório de Veículos'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _tipoRelatorio = value!;
                  _relatorioAtual = null;
                  _mecanicoSelecionadoId = null;
                  _filtroGarantiaRelatorio = 'TODOS';

                  if (_tipoRelatorio != 'contas' && _tipoRelatorio != 'garantias') {
                    _aplicarPeriodoRapido('ultimos_30_dias');
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 16),
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
                      initialValue: _mecanicoSelecionadoId,
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
          if (_tipoRelatorio == 'contas')
            _buildModernCard(
              context,
              title: 'Mês de Referência',
              icon: Icons.calendar_month,
              color: Colors.teal,
              child: _buildMesContasPicker(),
            )
          else if (_tipoRelatorio != 'garantias')
            _buildModernCard(
              context,
              title: 'Período',
              icon: Icons.date_range,
              color: Colors.green,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _periodoRapido,
                    decoration: InputDecoration(
                      labelText: 'Período rápido',
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
                      DropdownMenuItem(value: 'hoje', child: Text('Hoje')),
                      DropdownMenuItem(value: 'ultimos_7_dias', child: Text('Últimos 7 dias')),
                      DropdownMenuItem(value: 'ultimos_30_dias', child: Text('Últimos 30 dias')),
                      DropdownMenuItem(value: 'ultimos_90_dias', child: Text('Últimos 90 dias')),
                      DropdownMenuItem(value: 'mes_atual', child: Text('Mês atual')),
                      DropdownMenuItem(value: 'mes_anterior', child: Text('Mês anterior')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _aplicarPeriodoRapido(value);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Dica: escolha um período rápido e ajuste as datas manualmente apenas se necessário.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 400;
                      final dataInicio = TextField(
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
                      );
                      final dataFim = TextField(
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
                      );
                      if (isNarrow) {
                        return Column(
                          children: [
                            dataInicio,
                            const SizedBox(height: 12),
                            dataFim,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: dataInicio),
                          const SizedBox(width: 16),
                          Expanded(child: dataFim),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          if (_tipoRelatorio == 'garantias') ...[
            const SizedBox(height: 16),
            _buildModernCard(
              context,
              title: 'Filtro de Garantias',
              icon: Icons.filter_alt_outlined,
              color: Colors.teal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChipFiltroGarantia(value: 'TODOS', label: 'Todos', color: Colors.teal),
                      _buildChipFiltroGarantia(value: 'ATIVA', label: 'Ativa', color: Colors.green),
                      _buildChipFiltroGarantia(value: 'INATIVA', label: 'Inativa', color: Colors.blueGrey),
                      _buildChipFiltroGarantia(value: 'RECLAMADA', label: 'Reclamada', color: Colors.amber),
                      _buildChipFiltroGarantia(
                        value: 'PROXIMA_VENCIMENTO',
                        label: 'Próx. ao Vencimento (30d)',
                        color: Colors.deepOrange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Este filtro será aplicado antes da geração do relatório e também no PDF.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade700],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
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
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
            color: Colors.black.withValues(alpha: 0.05),
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
                  color: color.withValues(alpha: 0.1),
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

  void _imprimirRelatorio() {
    if (_relatorioAtual == null) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Future.delayed(const Duration(milliseconds: 50));

        switch (_tipoRelatorio) {
          case 'agendamentos':
            await _printRelatorioAgendamentos(_relatorioAtual as RelatorioAgendamentos);
            break;
          case 'servicos':
            await _printRelatorioServicos(_relatorioAtual as RelatorioServicos);
            break;
          case 'estoque':
            await _printRelatorioEstoque(_relatorioAtual as RelatorioEstoque);
            break;
          case 'financeiro':
            await _printRelatorioFinanceiro(_relatorioAtual as RelatorioFinanceiro);
            break;
          case 'comissao':
            await _printRelatorioComissao(_relatorioAtual as RelatorioComissao);
            break;
          case 'garantias':
            await _printRelatorioGarantias(_relatorioAtual as RelatorioGarantias);
            break;
          case 'consultores':
            await _printRelatorioConsultores(_relatorioAtual as RelatorioConsultores);
            break;
          case 'contas':
            await _printRelatorioContas(_relatorioAtual as RelatorioContasMes);
            break;
          case 'clientes':
            await _printRelatorioClientes(_relatorioAtual as RelatorioClientes);
            break;
          case 'veiculos':
            await _printRelatorioVeiculos(_relatorioAtual as RelatorioVeiculos);
            break;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao gerar PDF: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isGeneratingPdf = false;
          });
        }
      }
    });
  }

  Future<void> _printRelatorioAgendamentos(RelatorioAgendamentos relatorio) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader('Relatório de Agendamentos', Icons.calendar_month, PdfColors.blue600, logoImage: PdfLogoHelper.getCachedLogo()),
          pw.SizedBox(height: 16),
          _buildPdfInfoRow('Período',
              '${DateFormat('dd/MM/yyyy').format(relatorio.dataInicio)} até ${DateFormat('dd/MM/yyyy').format(relatorio.dataFim)}'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Resumo Geral'),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('Total de Agendamentos', relatorio.totalAgendamentos.toString()),
          _buildPdfMetricCard('Mecânicos Ativos', relatorio.agendamentosPorMecanico.toString()),
          pw.SizedBox(height: 16),
          if (relatorio.agendamentosPorDia.isNotEmpty) ...[
            _buildPdfSectionTitle('Agendamentos por Dia'),
            pw.SizedBox(height: 10),
            _buildPdfTable(
              headers: ['Data', 'Quantidade'],
              rows: relatorio.agendamentosPorDia
                  .map((item) => [
                        DateFormat('dd/MM/yyyy').format(DateTime.parse(item.data)),
                        '${item.quantidade} agendamento${item.quantidade != 1 ? 's' : ''}',
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 16),
          ],
          if (relatorio.agendamentosPorMecanicoLista.isNotEmpty) ...[
            _buildPdfSectionTitle('Agendamentos por Mecânico'),
            pw.SizedBox(height: 10),
            _buildPdfTable(
              headers: ['Mecânico', 'Quantidade'],
              rows: relatorio.agendamentosPorMecanicoLista
                  .map((item) => [
                        item.nomeMecanico,
                        '${item.quantidade} agendamento${item.quantidade != 1 ? 's' : ''}',
                      ])
                  .toList(),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  Future<void> _printRelatorioServicos(RelatorioServicos relatorio) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader('Relatório de Serviços', Icons.build, PdfColors.indigo600, logoImage: PdfLogoHelper.getCachedLogo()),
          pw.SizedBox(height: 16),
          _buildPdfInfoRow('Período',
              '${DateFormat('dd/MM/yyyy').format(relatorio.dataInicio)} até ${DateFormat('dd/MM/yyyy').format(relatorio.dataFim)}'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Serviços Realizados'),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('Valor dos Serviços Realizados', 'R\$ ${relatorio.valorServicosRealizados.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Descontos em Serviços', 'R\$ ${relatorio.descontoServicos.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Total de Serviços Realizados', relatorio.totalServicosRealizados.toString()),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Ordens de Serviço'),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('Total de Ordens de Serviço', relatorio.totalOrdensServico.toString()),
          _buildPdfMetricCard('Ordens Finalizadas (Encerradas)', relatorio.ordensFinalizadas.toString()),
          _buildPdfMetricCard('Ordens em Andamento (Abertas)', relatorio.ordensEmAndamento.toString()),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Métricas Adicionais'),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('Valor Médio por Ordem', 'R\$ ${relatorio.valorMedioPorOrdem.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Tempo Médio de Execução', '${relatorio.tempoMedioExecucao.toStringAsFixed(1)} dias'),
          pw.SizedBox(height: 16),
          if (relatorio.servicosMaisRealizados.isNotEmpty) ...[
            _buildPdfSectionTitle('Serviços Mais Realizados'),
            pw.SizedBox(height: 10),
            _buildPdfTable(
              headers: ['Serviço', 'Quantidade', 'Valor Total'],
              rows: relatorio.servicosMaisRealizados
                  .map((item) => [
                        item.nomeServico,
                        '${item.quantidade}x',
                        'R\$ ${item.valorTotal.toStringAsFixed(2)}',
                      ])
                  .toList(),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  Future<void> _printRelatorioEstoque(RelatorioEstoque relatorio) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader('Relatório de Estoque', Icons.inventory, PdfColors.purple600, logoImage: PdfLogoHelper.getCachedLogo()),
          pw.SizedBox(height: 16),
          _buildPdfInfoRow('Período',
              '${DateFormat('dd/MM/yyyy').format(relatorio.dataInicio)} até ${DateFormat('dd/MM/yyyy').format(relatorio.dataFim)}'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Movimentações'),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('Total de Movimentações', relatorio.totalMovimentacoes.toString()),
          _buildPdfMetricCard('Entradas', relatorio.totalEntradas.toString()),
          _buildPdfMetricCard('Saídas', relatorio.totalSaidas.toString()),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Valores'),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('Valor Total do Estoque', 'R\$ ${relatorio.valorTotalEstoque.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Valor das Entradas', 'R\$ ${relatorio.valorEntradas.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Valor das Saídas', 'R\$ ${relatorio.valorSaidas.toStringAsFixed(2)}'),
          pw.SizedBox(height: 16),
          if (relatorio.pecasMaisMovimentadas.isNotEmpty) ...[
            _buildPdfSectionTitle('Peças Mais Movimentadas'),
            pw.SizedBox(height: 10),
            _buildPdfTable(
              headers: ['Peça', 'Quantidade', 'Valor'],
              rows: relatorio.pecasMaisMovimentadas
                  .map((item) => [
                        item.nomePeca,
                        item.quantidade.toString(),
                        'R\$ ${item.valor.toStringAsFixed(2)}',
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 15),
          ],
          if (relatorio.pecasEstoqueBaixo.isNotEmpty) ...[
            _buildPdfSectionTitle('Peças com Estoque Baixo'),
            pw.SizedBox(height: 10),
            _buildPdfTable(
              headers: ['Peça', 'Quantidade', 'Valor'],
              rows: relatorio.pecasEstoqueBaixo
                  .map((item) => [
                        item.nomePeca,
                        item.quantidade.toString(),
                        'R\$ ${item.valor.toStringAsFixed(2)}',
                      ])
                  .toList(),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  Future<void> _printRelatorioFinanceiro(RelatorioFinanceiro relatorio) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader('Relatório Financeiro', Icons.attach_money, PdfColors.green600, logoImage: PdfLogoHelper.getCachedLogo()),
          pw.SizedBox(height: 16),
          _buildPdfInfoRow('Período',
              '${DateFormat('dd/MM/yyyy').format(relatorio.dataInicio)} até ${DateFormat('dd/MM/yyyy').format(relatorio.dataFim)}'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Receitas'),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('Receita de Peças', 'R\$ ${relatorio.receitaPecas.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Receita de Serviços', 'R\$ ${relatorio.receitaServicos.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Receita Total', 'R\$ ${relatorio.receitaTotal.toStringAsFixed(2)}'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Despesas e Descontos'),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('Despesas com Estoque', 'R\$ ${relatorio.despesasEstoque.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Descontos em Peças', 'R\$ ${relatorio.descontosPecas.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Descontos em Serviços', 'R\$ ${relatorio.descontosServicos.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Total de Descontos', 'R\$ ${relatorio.descontosTotal.toStringAsFixed(2)}'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Resultado'),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: relatorio.lucroEstimado >= 0 ? PdfColors.green50 : PdfColors.red50,
              border: pw.Border.all(color: relatorio.lucroEstimado >= 0 ? PdfColors.green : PdfColors.red, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  relatorio.lucroEstimado >= 0 ? 'Lucro' : 'Prejuízo',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'R\$ ${relatorio.lucroEstimado.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: relatorio.lucroEstimado >= 0 ? PdfColors.green : PdfColors.red,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('Ticket Médio', 'R\$ ${relatorio.ticketMedio.toStringAsFixed(2)}'),
          pw.SizedBox(height: 15),
          if (relatorio.receitaPorTipoPagamento.isNotEmpty) ...[
            _buildPdfSectionTitle('Receita por Tipo de Pagamento'),
            pw.SizedBox(height: 10),
            _buildPdfTable(
              headers: ['Tipo de Pagamento', 'Transações', 'Valor'],
              rows: relatorio.receitaPorTipoPagamento.entries
                  .map((entry) => [
                        entry.key,
                        '${relatorio.quantidadePorTipoPagamento[entry.key] ?? 0}x',
                        'R\$ ${entry.value.toStringAsFixed(2)}',
                      ])
                  .toList(),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  Future<void> _printRelatorioComissao(RelatorioComissao relatorio) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader('Relatório de Comissão', Icons.account_balance_wallet, PdfColors.cyan600,
              logoImage: PdfLogoHelper.getCachedLogo()),
          pw.SizedBox(height: 16),
          _buildPdfInfoRow('Período',
              '${DateFormat('dd/MM/yyyy').format(relatorio.dataInicio)} até ${DateFormat('dd/MM/yyyy').format(relatorio.dataFim)}'),
          _buildPdfInfoRow('Mecânico', relatorio.mecanicoNome),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: [PdfColors.green50, PdfColors.green100],
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
              ),
              border: pw.Border.all(color: PdfColors.green600, width: 3),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              boxShadow: [
                pw.BoxShadow(
                  color: PdfColors.grey300,
                  blurRadius: 6,
                  offset: const PdfPoint(0, 3),
                ),
              ],
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'COMISSÃO TOTAL',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green900),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'R\$ ${relatorio.valorComissao.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: PdfColors.green700),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Métricas'),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('Ordens de Serviço', relatorio.totalOrdensServico.toString()),
          _buildPdfMetricCard('Serviços Realizados', relatorio.totalServicosRealizados.toString()),
          _buildPdfMetricCard('Valor Total', 'R\$ ${relatorio.valorTotalServicos.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Descontos', 'R\$ ${relatorio.descontoServicos.toStringAsFixed(2)}'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Serviços Mais Realizados'),
          pw.SizedBox(height: 10),
          _buildPdfTable(
            headers: ['Serviço', 'Quantidade', 'Valor Total'],
            rows: _agregarServicosComissao(relatorio)
                .map((item) => [
                      item['nome'].toString(),
                      '${item['quantidade']}x',
                      'R\$ ${(item['valorTotal'] as double).toStringAsFixed(2)}',
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Ordens de Serviço Realizadas'),
          pw.SizedBox(height: 10),
          ...relatorio.ordensServico.map((os) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey50,
                  border: pw.Border.all(color: PdfColors.cyan200, width: 1.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('OS #${os.numeroOS}',
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.cyan900)),
                        pw.Text('R\$ ${os.valorServicos.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green700)),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Cliente: ${os.clienteNome}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Veículo: ${os.veiculoNome} - ${os.veiculoPlaca}', style: const pw.TextStyle(fontSize: 10)),
                    if (os.dataHoraEncerramento != null)
                      pw.Text('Encerrada: ${DateFormat('dd/MM/yyyy HH:mm').format(os.dataHoraEncerramento!)}',
                          style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    pw.SizedBox(height: 6),
                    pw.Text('Serviços (${os.servicosRealizados.length}):',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ...os.servicosRealizados.map((servico) => pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 10, top: 2),
                          child: pw.Text('- ${servico.nomeServico} - R\$ ${servico.valor.toStringAsFixed(2)}',
                              style: const pw.TextStyle(fontSize: 8)),
                        )),
                  ],
                ),
              )),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  Future<void> _printRelatorioGarantias(RelatorioGarantias relatorio) async {
    final doc = pw.Document();
    final garantiasFiltradas = _filtrarGarantiasRelatorio(relatorio.garantias);
    final totalAtivas = relatorio.garantias.where(_isGarantiaAtiva).length;
    final totalInativas = relatorio.garantias.where(_isGarantiaInativa).length;
    final totalReclamadas = relatorio.garantias.where(_isGarantiaReclamada).length;
    final totalProximas = relatorio.garantias.where(_isGarantiaProximaVencimento).length;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader('Relatório de Garantias', Icons.verified_user, PdfColors.teal600, logoImage: PdfLogoHelper.getCachedLogo()),
          pw.SizedBox(height: 16),
          _buildPdfInfoRow('Período',
              '${DateFormat('dd/MM/yyyy').format(relatorio.dataInicio)} até ${DateFormat('dd/MM/yyyy').format(relatorio.dataFim)}'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Resumo'),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('Ativas', totalAtivas.toString()),
          _buildPdfMetricCard('Inativas', totalInativas.toString()),
          _buildPdfMetricCard('Reclamadas', totalReclamadas.toString()),
          _buildPdfMetricCard('Próx. ao vencimento (30 dias)', totalProximas.toString()),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Garantias Filtradas'),
          pw.SizedBox(height: 10),
          if (garantiasFiltradas.isEmpty)
            pw.Center(
              child: pw.Text('Nenhuma garantia encontrada para o filtro selecionado', style: const pw.TextStyle(fontSize: 11)),
            )
          else
            ...garantiasFiltradas.map((garantia) {
              final bool isReclamada = _isGarantiaReclamada(garantia);
              final bool isInativa = _isGarantiaInativa(garantia);
              final bool isProxima = _isGarantiaProximaVencimento(garantia);
              final int diasRestantes = _diasRestantesGarantia(garantia);

              return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                  color: isReclamada
                      ? PdfColors.amber50
                      : isInativa
                          ? PdfColors.blueGrey50
                          : isProxima
                              ? PdfColors.orange50
                              : PdfColors.green50,
                  border: pw.Border.all(
                      color: isReclamada
                          ? PdfColors.amber
                          : isInativa
                              ? PdfColors.blueGrey
                              : isProxima
                                  ? PdfColors.orange
                                  : PdfColors.green,
                      width: 1.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('OS #${garantia.numeroOS}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text(
                            isReclamada
                                ? 'Reclamada'
                                : isInativa
                                    ? 'Inativa'
                                    : 'Ativa',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                color: isReclamada
                                    ? PdfColors.amber
                                    : isInativa
                                        ? PdfColors.blueGrey
                                        : isProxima
                                            ? PdfColors.orange
                                            : PdfColors.green)),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('Cliente: ${garantia.clienteNome} - CPF: ${garantia.clienteCpf}', style: const pw.TextStyle(fontSize: 10)),
                      if (garantia.clienteTelefone != null && garantia.clienteTelefone!.isNotEmpty)
                        pw.Text('Telefone: ${garantia.clienteTelefone}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Veículo: ${garantia.veiculoNome} - ${garantia.veiculoPlaca}', style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 3),
                      pw.Text(
                          'Valor: R\$ ${garantia.valorTotal.toStringAsFixed(2)} | Garantia: ${garantia.garantiaMeses} ${garantia.garantiaMeses == 1 ? 'mês' : 'meses'}',
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Encerramento: ${DateFormat('dd/MM/yyyy').format(garantia.dataEncerramento)}',
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(
                          'Período: ${DateFormat('dd/MM/yyyy').format(garantia.dataInicioGarantia)} - ${DateFormat('dd/MM/yyyy').format(garantia.dataFimGarantia)}',
                          style: const pw.TextStyle(fontSize: 9)),
                    if (isProxima)
                      pw.Text('Próxima ao vencimento: $diasRestantes dia(s)', style: pw.TextStyle(fontSize: 9, color: PdfColors.orange700)),
                    if ((garantia.retornoMotivo ?? '').isNotEmpty)
                      pw.Text('Motivo: ${garantia.retornoMotivo}', style: const pw.TextStyle(fontSize: 9)),
                      if (garantia.mecanicoNome != null && garantia.mecanicoNome!.isNotEmpty)
                        pw.Text('Mecânico: ${garantia.mecanicoNome}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
              );
            }),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  pw.Widget _buildPdfHeader(String title, IconData icon, PdfColor color, {pw.MemoryImage? logoImage}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [color, _darkenColor(color)],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey400,
            blurRadius: 4,
            offset: const PdfPoint(0, 2),
          ),
        ],
      ),
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
                  title,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  children: [
                    pw.Text(
                      'Data: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.white),
                    ),
                    pw.SizedBox(width: 20),
                    pw.Text(
                      'Hora: ${DateFormat('HH:mm').format(DateTime.now())}',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.white),
                    ),
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
              'TecStock',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  PdfColor _darkenColor(PdfColor color) {
    return PdfColor(color.red * 0.8, color.green * 0.8, color.blue * 0.8);
  }

  pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.blue200),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 100,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 4,
            height: 20,
            decoration: pw.BoxDecoration(
              color: PdfColors.blue600,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfMetricCard(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTable({required List<String> headers, required List<List<String>> rows}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Row(
              children: headers
                  .map((header) => pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(10),
                          child: pw.Text(
                            header,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            return pw.Container(
              decoration: pw.BoxDecoration(
                color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
              child: pw.Row(
                children: row
                    .map((cell) => pw.Expanded(
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.all(10),
                            child: pw.Text(
                              cell,
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _agregarServicosComissao(RelatorioComissao relatorio) {
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

    var servicosOrdenados = servicosAgregados.values.toList()..sort((a, b) => b['quantidade'].compareTo(a['quantidade']));

    return servicosOrdenados;
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
      case 'consultores':
        return _buildRelatorioConsultores(_relatorioAtual as RelatorioConsultores);
      case 'contas':
        return _buildRelatorioContas(_relatorioAtual as RelatorioContasMes);
      case 'clientes':
        return _buildRelatorioClientes(_relatorioAtual as RelatorioClientes);
      case 'veiculos':
        return _buildRelatorioVeiculos(_relatorioAtual as RelatorioVeiculos);
      default:
        return const SizedBox();
    }
  }

  Widget _buildRelatorioAgendamentos(RelatorioAgendamentos relatorio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  color: Colors.white.withValues(alpha: 0.2),
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
        _buildSectionHeader('Resumo Geral', Icons.assessment, Colors.blue),
        const SizedBox(height: 12),
        _buildMetricCard('Total de Agendamentos', relatorio.totalAgendamentos.toString(), Icons.event, color: Colors.blue),
        _buildMetricCard('Mecânicos Ativos', relatorio.agendamentosPorMecanico.toString(), Icons.person, color: Colors.green),
        const SizedBox(height: 24),
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
                  color: Colors.white.withValues(alpha: 0.2),
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
        _buildSectionHeader('Ordens de Serviço', Icons.assignment, Colors.deepPurple),
        const SizedBox(height: 12),
        _buildMetricCard('Total de Ordens de Serviço', relatorio.totalOrdensServico.toString(), Icons.assignment, color: Colors.deepPurple),
        _buildMetricCard('Ordens Finalizadas (Encerradas)', relatorio.ordensFinalizadas.toString(), Icons.check_circle,
            color: Colors.green),
        _buildMetricCard('Ordens em Andamento (Abertas)', relatorio.ordensEmAndamento.toString(), Icons.pending, color: Colors.orange),
        const SizedBox(height: 24),
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
                  color: Colors.white.withValues(alpha: 0.2),
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
        _buildSectionHeader('Movimentações', Icons.swap_horiz, Colors.teal),
        const SizedBox(height: 12),
        _buildMetricCard('Total de Movimentações', relatorio.totalMovimentacoes.toString(), Icons.swap_horiz, color: Colors.teal),
        _buildMetricCard('Entradas', relatorio.totalEntradas.toString(), Icons.arrow_circle_down, color: Colors.green),
        _buildMetricCard('Saídas', relatorio.totalSaidas.toString(), Icons.arrow_circle_up, color: Colors.red),
        const SizedBox(height: 24),
        _buildSectionHeader('Valores', Icons.attach_money, Colors.blue),
        const SizedBox(height: 12),
        _buildMetricCard('Valor Total do Estoque', 'R\$ ${relatorio.valorTotalEstoque.toStringAsFixed(2)}', Icons.inventory_2,
            color: Colors.blue),
        _buildMetricCard('Valor das Entradas', 'R\$ ${relatorio.valorEntradas.toStringAsFixed(2)}', Icons.add_circle_outline,
            color: Colors.green),
        _buildMetricCard('Valor das Saídas', 'R\$ ${relatorio.valorSaidas.toStringAsFixed(2)}', Icons.remove_circle_outline,
            color: Colors.red),
        const SizedBox(height: 24),
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
                  color: Colors.white.withValues(alpha: 0.2),
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
        _buildSectionHeader('Receitas', Icons.trending_up, Colors.green),
        const SizedBox(height: 12),
        _buildMetricCard('Receita de Peças', 'R\$ ${relatorio.receitaPecas.toStringAsFixed(2)}', Icons.inventory_2, color: Colors.green),
        _buildMetricCard('Receita de Serviços', 'R\$ ${relatorio.receitaServicos.toStringAsFixed(2)}', Icons.build_circle,
            color: Colors.green),
        _buildMetricCard('Receita Total', 'R\$ ${relatorio.receitaTotal.toStringAsFixed(2)}', Icons.monetization_on,
            color: Colors.green.shade700),
        const SizedBox(height: 24),
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
                color: (relatorio.lucroEstimado >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.3),
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
        border: Border.all(color: cardColor.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.08),
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
              color: cardColor.withValues(alpha: 0.1),
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
        color: color.withValues(alpha: 0.1),
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
                color: Colors.green.withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.2),
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
        ...(() {
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
            color: Colors.grey.withValues(alpha: 0.1),
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

  bool _isGarantiaReclamada(GarantiaItem garantia) {
    final status = garantia.statusGarantia.isNotEmpty ? garantia.statusGarantia : garantia.statusDescricao;
    return status.toLowerCase().contains('reclamad');
  }

  bool _isGarantiaInativa(GarantiaItem garantia) {
    final status = garantia.statusGarantia.isNotEmpty ? garantia.statusGarantia : garantia.statusDescricao;
    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final fimSemHora = DateTime(
      garantia.dataFimGarantia.year,
      garantia.dataFimGarantia.month,
      garantia.dataFimGarantia.day,
    );

    return status.toLowerCase().contains('expirad') || status.toLowerCase().contains('inativ') || fimSemHora.isBefore(hojeSemHora);
  }

  bool _isGarantiaAtiva(GarantiaItem garantia) {
    return !_isGarantiaReclamada(garantia) && !_isGarantiaInativa(garantia);
  }

  int _diasRestantesGarantia(GarantiaItem garantia) {
    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final fimSemHora = DateTime(
      garantia.dataFimGarantia.year,
      garantia.dataFimGarantia.month,
      garantia.dataFimGarantia.day,
    );
    return fimSemHora.difference(hojeSemHora).inDays;
  }

  bool _isGarantiaProximaVencimento(GarantiaItem garantia) {
    if (!_isGarantiaAtiva(garantia)) return false;
    final dias = _diasRestantesGarantia(garantia);
    return dias >= 0 && dias <= 30;
  }

  List<GarantiaItem> _filtrarGarantiasRelatorio(List<GarantiaItem> garantias) {
    switch (_filtroGarantiaRelatorio) {
      case 'TODOS':
        return garantias;
      case 'ATIVA':
        return garantias.where(_isGarantiaAtiva).toList();
      case 'INATIVA':
        return garantias.where(_isGarantiaInativa).toList();
      case 'RECLAMADA':
        return garantias.where(_isGarantiaReclamada).toList();
      case 'PROXIMA_VENCIMENTO':
        return garantias.where(_isGarantiaProximaVencimento).toList();
      default:
        return garantias;
    }
  }

  Widget _buildChipFiltroGarantia({
    required String value,
    required String label,
    required Color color,
  }) {
    final isSelected = _filtroGarantiaRelatorio == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _filtroGarantiaRelatorio = value;
        });
      },
      selectedColor: color.withValues(alpha: 0.18),
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(
        color: isSelected ? color.withValues(alpha: 0.6) : Colors.grey.shade300,
      ),
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey.shade700,
        fontWeight: FontWeight.w700,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildRelatorioGarantias(RelatorioGarantias relatorio) {
    final garantiasFiltradas = _filtrarGarantiasRelatorio(relatorio.garantias);
    final totalAtivas = relatorio.garantias.where(_isGarantiaAtiva).length;
    final totalInativas = relatorio.garantias.where(_isGarantiaInativa).length;
    final totalReclamadas = relatorio.garantias.where(_isGarantiaReclamada).length;
    final totalProximas = relatorio.garantias.where(_isGarantiaProximaVencimento).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  color: Colors.white.withValues(alpha: 0.2),
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
        _buildSectionHeader('Resumo', Icons.assessment, Colors.teal),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCardEnhanced(
                'Ativas',
                totalAtivas.toString(),
                Icons.check_circle_outlined,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'Inativas',
                totalInativas.toString(),
                Icons.timer_off,
                Colors.blueGrey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCardEnhanced(
                'Reclamadas',
                totalReclamadas.toString(),
                Icons.undo,
                Colors.amber,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'Próx. Vencimento (30d)',
                totalProximas.toString(),
                Icons.schedule,
                Colors.deepOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
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
        if (garantiasFiltradas.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma garantia encontrada para o filtro selecionado',
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
        ...garantiasFiltradas.map((garantia) {
          final bool isReclamada = _isGarantiaReclamada(garantia);
          final bool isInativa = _isGarantiaInativa(garantia);
          final bool isProximaVencimento = _isGarantiaProximaVencimento(garantia);
          final int diasRestantes = _diasRestantesGarantia(garantia);
          final Color statusColor = isReclamada
              ? Colors.amber
              : isInativa
                  ? Colors.blueGrey
                  : isProximaVencimento
                      ? Colors.deepOrange
                      : Colors.green;
          final Color backgroundColor = statusColor.withValues(alpha: 0.08);
          final Color borderColor = statusColor.withValues(alpha: 0.3);
          final String statusVisual = isReclamada
              ? 'Reclamada'
              : isInativa
                  ? 'Inativa'
                  : 'Ativa';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
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
                          color: statusColor.withValues(alpha: 0.2),
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
                                statusVisual,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (isProximaVencimento) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Próxima ao vencimento: $diasRestantes dias',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ),
                            ],
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
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
                      if (isReclamada && (garantia.retornoMotivo ?? '').isNotEmpty) ...[
                        const Divider(height: 24),
                        _buildInfoRow(
                          Icons.undo,
                          'Motivo',
                          garantia.retornoMotivo!,
                          statusColor,
                        ),
                      ],
                      const Divider(height: 24),
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

  Widget _buildRelatorioConsultores(RelatorioConsultores relatorio) {
    final consultoresOrdenados = List<ConsultorMetricas>.from(relatorio.consultores)
      ..sort((a, b) => b.valorTotalOS.compareTo(a.valorTotalOS));
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.people_alt, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Desempenho Consultores',
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
        _buildSectionHeader('Resumo Geral', Icons.assessment, Colors.deepPurple),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCardEnhanced(
                'Total Orçamentos',
                relatorio.totalOrcamentosGeral.toString(),
                Icons.description_outlined,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'Total OS',
                relatorio.totalOSGeral.toString(),
                Icons.assignment_outlined,
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
                'Total Checklists',
                relatorio.totalChecklistsGeral.toString(),
                Icons.checklist,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'Total Agendamentos',
                relatorio.totalAgendamentosGeral.toString(),
                Icons.calendar_today,
                Colors.pink,
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
                'R\$ ${relatorio.valorTotalGeral.toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'Ticket Médio',
                'R\$ ${relatorio.valorMedioGeral.toStringAsFixed(2)}',
                Icons.analytics,
                Colors.indigo,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'Taxa Conversão',
                '${relatorio.taxaConversaoGeral.toStringAsFixed(1)}%',
                Icons.trending_up,
                Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildSectionHeader('Ranking de Consultores', Icons.emoji_events, Colors.amber),
        const SizedBox(height: 16),
        ...consultoresOrdenados.asMap().entries.map((entry) {
          final index = entry.key;
          final consultor = entry.value;

          Color rankColor;
          IconData rankIcon;
          Color backgroundColor;

          if (index == 0) {
            rankColor = Colors.amber;
            rankIcon = Icons.emoji_events;
            backgroundColor = Colors.amber.shade50;
          } else if (index == 1) {
            rankColor = Colors.grey;
            rankIcon = Icons.emoji_events;
            backgroundColor = Colors.grey.shade50;
          } else if (index == 2) {
            rankColor = Colors.brown;
            rankIcon = Icons.emoji_events;
            backgroundColor = Colors.brown.shade50;
          } else {
            rankColor = Colors.blue;
            rankIcon = Icons.person;
            backgroundColor = Colors.blue.shade50;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: rankColor.withValues(alpha: 0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: rankColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compactHeader = constraints.maxWidth < 430;

                      final leading = Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: rankColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: index < 3
                              ? Icon(rankIcon, color: rankColor, size: 28)
                              : Text(
                                  '${index + 1}º',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: rankColor,
                                  ),
                                ),
                        ),
                      );

                      final info = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            consultor.consultorNome,
                            style: TextStyle(
                              fontSize: compactHeader ? 16 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'R\$ ${consultor.valorTotalOS.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: compactHeader ? 15 : 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      );

                      final conversionBadge = Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: rankColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${consultor.taxaConversao.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );

                      if (compactHeader) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                leading,
                                const SizedBox(width: 12),
                                Expanded(child: info),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: conversionBadge,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          leading,
                          const SizedBox(width: 16),
                          Expanded(child: info),
                          conversionBadge,
                        ],
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compactMetrics = constraints.maxWidth < 820;
                      final spacing = isMobile ? 10.0 : 12.0;

                      if (!compactMetrics) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildConsultorMetricItem(
                                    'Orçamentos',
                                    consultor.totalOrcamentos.toString(),
                                    Icons.description,
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildConsultorMetricItem(
                                    'OS',
                                    consultor.totalOS.toString(),
                                    Icons.assignment,
                                    Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildConsultorMetricItem(
                                    'Checklists',
                                    consultor.totalChecklists.toString(),
                                    Icons.checklist,
                                    Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildConsultorMetricItem(
                                    'Agendamentos',
                                    consultor.totalAgendamentos.toString(),
                                    Icons.calendar_today,
                                    Colors.pink,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildConsultorMetricItem(
                                    'Ticket Médio',
                                    'R\$ ${consultor.valorMedioOS.toStringAsFixed(2)}',
                                    Icons.analytics,
                                    Colors.purple,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildConsultorMetricItem(
                                    'Conversão',
                                    '${consultor.taxaConversao.toStringAsFixed(1)}%',
                                    Icons.trending_up,
                                    Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      final columns = constraints.maxWidth < 520 ? 2 : 3;
                      final itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

                      final metricItems = [
                        _buildConsultorMetricItem(
                          'Orçamentos',
                          consultor.totalOrcamentos.toString(),
                          Icons.description,
                          Colors.blue,
                        ),
                        _buildConsultorMetricItem(
                          'OS',
                          consultor.totalOS.toString(),
                          Icons.assignment,
                          Colors.green,
                        ),
                        _buildConsultorMetricItem(
                          'Checklists',
                          consultor.totalChecklists.toString(),
                          Icons.checklist,
                          Colors.orange,
                        ),
                        _buildConsultorMetricItem(
                          'Agendamentos',
                          consultor.totalAgendamentos.toString(),
                          Icons.calendar_today,
                          Colors.pink,
                        ),
                        _buildConsultorMetricItem(
                          'Ticket Médio',
                          'R\$ ${consultor.valorMedioOS.toStringAsFixed(2)}',
                          Icons.analytics,
                          Colors.purple,
                        ),
                        _buildConsultorMetricItem(
                          'Conversão',
                          '${consultor.taxaConversao.toStringAsFixed(1)}%',
                          Icons.trending_up,
                          Colors.teal,
                        ),
                      ];

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: metricItems.map((item) => SizedBox(width: itemWidth, child: item)).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildConsultorMetricItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minHeight: 108),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _printRelatorioConsultores(RelatorioConsultores relatorio) async {
    final consultoresOrdenados = List<ConsultorMetricas>.from(relatorio.consultores)
      ..sort((a, b) => b.valorTotalOS.compareTo(a.valorTotalOS));

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader('Desempenho Consultores', Icons.people_alt, PdfColors.deepPurple600, logoImage: PdfLogoHelper.getCachedLogo()),
          pw.SizedBox(height: 16),
          _buildPdfInfoRow('Período',
              '${DateFormat('dd/MM/yyyy').format(relatorio.dataInicio)} até ${DateFormat('dd/MM/yyyy').format(relatorio.dataFim)}'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Resumo Geral'),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('Total de Orçamentos', relatorio.totalOrcamentosGeral.toString()),
          _buildPdfMetricCard('Total de OS', relatorio.totalOSGeral.toString()),
          _buildPdfMetricCard('Total de Checklists', relatorio.totalChecklistsGeral.toString()),
          _buildPdfMetricCard('Total de Agendamentos', relatorio.totalAgendamentosGeral.toString()),
          _buildPdfMetricCard('Valor Total', 'R\$ ${relatorio.valorTotalGeral.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Ticket Médio', 'R\$ ${relatorio.valorMedioGeral.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Taxa de Conversão', '${relatorio.taxaConversaoGeral.toStringAsFixed(1)}%'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Ranking de Consultores'),
          pw.SizedBox(height: 10),
          _buildPdfTable(
            headers: ['Pos.', 'Consultor', 'Orç.', 'OS', 'Checks', 'Agend.', 'Valor Total', 'Ticket', 'Conv.%'],
            rows: consultoresOrdenados.asMap().entries.map((entry) {
              final index = entry.key;
              final c = entry.value;
              String posicao = '${index + 1}º';
              if (index == 0) posicao = '1º *';
              if (index == 1) posicao = '2º *';
              if (index == 2) posicao = '3º *';

              return [
                posicao,
                c.consultorNome,
                c.totalOrcamentos.toString(),
                c.totalOS.toString(),
                c.totalChecklists.toString(),
                c.totalAgendamentos.toString(),
                'R\$ ${c.valorTotalOS.toStringAsFixed(2)}',
                'R\$ ${c.valorMedioOS.toStringAsFixed(2)}',
                '${c.taxaConversao.toStringAsFixed(1)}%',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  Widget _buildMesContasPicker() {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: Colors.teal.shade600),
          onPressed: () => setState(() {
            _mesContas = DateTime(_mesContas.year, _mesContas.month - 1, 1);
          }),
        ),
        Expanded(
          child: Center(
            child: Text(
              DateFormat('MMMM yyyy', 'pt_BR').format(_mesContas),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.teal.shade700),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right, color: Colors.teal.shade600),
          onPressed: () => setState(() {
            _mesContas = DateTime(_mesContas.year, _mesContas.month + 1, 1);
          }),
        ),
      ],
    );
  }

  Widget _buildRelatorioContas(RelatorioContasMes dados) {
    final String mesLabel = DateFormat('MMMM yyyy', 'pt_BR').format(DateTime(dados.ano, dados.mes));

    final totalAPagarPendente = dados.contasAPagar.where((c) => !c.pago).fold(0.0, (s, c) => s + c.valorPendente);
    final totalAReceberPendente = dados.contasAReceber.where((c) => !c.pago).fold(0.0, (s, c) => s + c.valorPendente);
    final totalAPagarPago = dados.contasAPagar.where((c) => c.pago).fold(0.0, (s, c) => s + c.valor) +
        dados.contasAPagar.where((c) => !c.pago && c.temPagamentoParcial).fold(0.0, (s, c) => s + c.valorPagoParcial);
    final totalAReceberRecebido = dados.contasAReceber.where((c) => c.pago).fold(0.0, (s, c) => s + c.valor) +
        dados.contasAReceber.where((c) => !c.pago && c.temPagamentoParcial).fold(0.0, (s, c) => s + c.valorPagoParcial);
    final saldo = totalAReceberRecebido - totalAPagarPago;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade500, Colors.teal.shade700],
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contas a Pagar / Receber',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(mesLabel, style: const TextStyle(fontSize: 14, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: saldo >= 0 ? [Colors.green.shade400, Colors.green.shade600] : [Colors.red.shade400, Colors.red.shade600],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: (saldo >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(saldo >= 0 ? Icons.trending_up : Icons.trending_down, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      saldo >= 0 ? 'Saldo Positivo' : 'Saldo Negativo',
                      style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'R\$ ${saldo.abs().toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCardEnhanced(
                'A Pagar (Pendente)',
                'R\$ ${totalAPagarPendente.toStringAsFixed(2)}',
                Icons.arrow_upward,
                Colors.red,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'A Receber (Pendente)',
                'R\$ ${totalAReceberPendente.toStringAsFixed(2)}',
                Icons.arrow_downward,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCardEnhanced(
                'Já Pago',
                'R\$ ${totalAPagarPago.toStringAsFixed(2)}',
                Icons.check_circle,
                Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'Já Recebido',
                'R\$ ${totalAReceberRecebido.toStringAsFixed(2)}',
                Icons.check_circle,
                Colors.teal,
              ),
            ),
          ],
        ),
        if (dados.contasAtrasadas.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader(
            'Contas Atrasadas (${dados.contasAtrasadas.length})',
            Icons.warning_amber_rounded,
            Colors.red,
          ),
          const SizedBox(height: 12),
          ...dados.contasAtrasadas.take(8).map((c) => _buildContaItem(c)),
          if (dados.contasAtrasadas.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                '+ ${dados.contasAtrasadas.length - 8} contas atrasadas',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700, fontSize: 12),
              ),
            ),
        ],
        if (dados.contasAPagar.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader(
            'Contas a Pagar (${dados.contasAPagar.length})',
            Icons.payment,
            Colors.red,
          ),
          const SizedBox(height: 12),
          ...dados.contasAPagar.map((c) => _buildContaItem(c)),
        ],
        if (dados.contasAReceber.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader(
            'Contas a Receber (${dados.contasAReceber.length})',
            Icons.request_quote,
            Colors.green,
          ),
          const SizedBox(height: 12),
          ...dados.contasAReceber.map((c) => _buildContaItem(c)),
        ],
        if (dados.contasAPagar.isEmpty && dados.contasAReceber.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.account_balance, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma conta encontrada para este mês',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContaItem(Conta conta) {
    final descricaoConta = conta.descricao.replaceAll(RegExp(r'\bfiado\b', caseSensitive: false), 'Crediário Próprio');
    final Color cor = conta.isAPagar ? Colors.red : Colors.green;
    final bool atrasada = conta.isAtrasada;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: conta.pago ? Colors.grey.shade50 : (atrasada ? Colors.red.shade50 : cor.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: conta.pago ? Colors.grey.shade200 : (atrasada ? Colors.red.shade300 : cor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            conta.pago ? Icons.check_circle : (atrasada ? Icons.warning_amber_rounded : Icons.schedule),
            color: conta.pago ? Colors.grey : (atrasada ? Colors.red : cor),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descricaoConta,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: conta.pago ? Colors.grey.shade600 : Colors.black87,
                  ),
                ),
                if (conta.dataVencimento != null)
                  Text(
                    conta.pago
                        ? 'Pago em ${conta.dataPagamento != null ? DateFormat('dd/MM/yyyy').format(conta.dataPagamento!) : "—"}'
                        : 'Vence em ${DateFormat('dd/MM/yyyy').format(conta.dataVencimento!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: conta.pago ? Colors.grey : (atrasada ? Colors.red.shade700 : Colors.grey.shade600),
                    ),
                  ),
                if (conta.temPagamentoParcial)
                  Text(
                    'Parcial: R\$ ${conta.valorPagoParcial.toStringAsFixed(2)} pago',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'R\$ ${(conta.pago ? conta.valor : conta.valorPendente).toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: conta.pago ? Colors.grey : cor,
                  fontSize: 13,
                ),
              ),
              if (conta.parcelaNumero != null && conta.totalParcelas != null)
                Text(
                  '${conta.parcelaNumero}/${conta.totalParcelas}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRelatorioClientes(RelatorioClientes relatorio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade500, Colors.blue.shade700],
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.people, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Relatório de Clientes',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Resumo Geral', Icons.assessment, Colors.blue),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCardEnhanced(
                'Total de Clientes',
                relatorio.totalClientes.toString(),
                Icons.people,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'Total de OS',
                relatorio.clientes.fold(0, (s, c) => s + c.totalOS).toString(),
                Icons.assignment,
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
                'Faturamento Total',
                'R\$ ${relatorio.clientes.fold(0.0, (s, c) => s + c.valorTotal).toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'Ticket Médio',
                'R\$ ${relatorio.clientes.isEmpty ? '0.00' : (relatorio.clientes.fold(0.0, (s, c) => s + c.ticketMedio) / relatorio.clientes.length).toStringAsFixed(2)}',
                Icons.analytics,
                Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildSectionHeader('Top Clientes', Icons.emoji_events, Colors.amber),
        const SizedBox(height: 16),
        ...relatorio.clientes.asMap().entries.map((entry) {
          final index = entry.key;
          final cliente = entry.value;
          final rankColor = index == 0
              ? Colors.amber
              : index == 1
                  ? Colors.grey
                  : index == 2
                      ? Colors.brown
                      : Colors.blue;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rankColor.withValues(alpha: 0.3), width: 2),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: rankColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: index < 3
                              ? Icon(Icons.emoji_events, color: rankColor, size: 22)
                              : Text(
                                  '${index + 1}º',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: rankColor),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cliente.clienteNome,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'CPF: ${cliente.clienteCpf}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            if (cliente.clienteTelefone != null && cliente.clienteTelefone!.isNotEmpty)
                              Text(
                                'Tel: ${cliente.clienteTelefone}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'R\$ ${cliente.valorTotal.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: rankColor),
                          ),
                          Text(
                            '${cliente.totalOS} OS',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildConsultorMetricItem(
                              'Ticket Médio',
                              'R\$ ${cliente.ticketMedio.toStringAsFixed(2)}',
                              Icons.analytics,
                              Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildConsultorMetricItem(
                              'Última Visita',
                              cliente.ultimaVisita != null ? DateFormat('dd/MM/yyyy').format(cliente.ultimaVisita!) : '—',
                              Icons.calendar_today,
                              Colors.teal,
                            ),
                          ),
                        ],
                      ),
                      if (cliente.placasVeiculos.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: cliente.placasVeiculos
                              .map((v) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.directions_car, size: 14, color: Colors.blue.shade700),
                                        const SizedBox(width: 4),
                                        Text(v, style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
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

  Widget _buildRelatorioVeiculos(RelatorioVeiculos relatorio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade500, Colors.indigo.shade700],
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_car, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Relatório de Veículos',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Resumo Geral', Icons.assessment, Colors.indigo),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCardEnhanced(
                'Total de Veículos',
                relatorio.totalVeiculos.toString(),
                Icons.directions_car,
                Colors.indigo,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCardEnhanced(
                'Total de OS',
                relatorio.veiculos.fold(0, (s, v) => s + v.totalOS).toString(),
                Icons.assignment,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildMetricCard(
          'Faturamento Total',
          'R\$ ${relatorio.veiculos.fold(0.0, (s, v) => s + v.valorTotal).toStringAsFixed(2)}',
          Icons.attach_money,
          color: Colors.indigo,
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Veículos Atendidos', Icons.list_alt, Colors.indigo),
        const SizedBox(height: 16),
        ...relatorio.veiculos.asMap().entries.map((entry) {
          final index = entry.key;
          final veiculo = entry.value;
          final rankColor = index == 0
              ? Colors.amber
              : index == 1
                  ? Colors.grey
                  : index == 2
                      ? Colors.brown
                      : Colors.indigo;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rankColor.withValues(alpha: 0.3), width: 2),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: rankColor.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: index < 3
                              ? Icon(Icons.emoji_events, color: rankColor, size: 22)
                              : Text(
                                  '${index + 1}º',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: rankColor),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              veiculo.veiculoNome,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: rankColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    veiculo.veiculoPlaca,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: rankColor),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if ((veiculo.veiculoMarca ?? '').isNotEmpty)
                                  Text(veiculo.veiculoMarca!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                if ((veiculo.veiculoAno ?? '').isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Text('(${veiculo.veiculoAno!})', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ],
                            ),
                            Text(
                              'Dono: ${veiculo.proprietarioNome}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'R\$ ${veiculo.valorTotal.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: rankColor),
                          ),
                          Text(
                            '${veiculo.totalOS} OS',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildConsultorMetricItem(
                              'Última Visita',
                              veiculo.ultimaVisita != null ? DateFormat('dd/MM/yyyy').format(veiculo.ultimaVisita!) : '—',
                              Icons.calendar_today,
                              Colors.teal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildConsultorMetricItem(
                              'CPF Proprietário',
                              veiculo.proprietarioCpf ?? '—',
                              Icons.badge,
                              Colors.blue,
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
        }),
      ],
    );
  }

  Future<void> _printRelatorioClientes(RelatorioClientes relatorio) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader('Relatório de Clientes', Icons.people, PdfColors.blue600, logoImage: PdfLogoHelper.getCachedLogo()),
          pw.SizedBox(height: 16),
          _buildPdfInfoRow('Período',
              '${DateFormat('dd/MM/yyyy').format(relatorio.dataInicio)} até ${DateFormat('dd/MM/yyyy').format(relatorio.dataFim)}'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Resumo Geral'),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('Total de Clientes', relatorio.totalClientes.toString()),
          _buildPdfMetricCard('Total de OS', relatorio.clientes.fold(0, (s, c) => s + c.totalOS).toString()),
          _buildPdfMetricCard('Faturamento Total', 'R\$ ${relatorio.clientes.fold(0.0, (s, c) => s + c.valorTotal).toStringAsFixed(2)}'),
          _buildPdfMetricCard('Ticket Médio Geral',
              'R\$ ${relatorio.clientes.isEmpty ? '0.00' : (relatorio.clientes.fold(0.0, (s, c) => s + c.ticketMedio) / relatorio.clientes.length).toStringAsFixed(2)}'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Top Clientes'),
          pw.SizedBox(height: 10),
          _buildPdfTable(
            headers: ['Cliente', 'CPF', 'OS', 'Total Gasto', 'Ticket Médio', 'Última Visita'],
            rows: relatorio.clientes
                .map((c) => [
                      c.clienteNome,
                      c.clienteCpf,
                      c.totalOS.toString(),
                      'R\$ ${c.valorTotal.toStringAsFixed(2)}',
                      'R\$ ${c.ticketMedio.toStringAsFixed(2)}',
                      c.ultimaVisita != null ? DateFormat('dd/MM/yyyy').format(c.ultimaVisita!) : '—',
                    ])
                .toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  Future<void> _printRelatorioVeiculos(RelatorioVeiculos relatorio) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader('Relatório de Veículos', Icons.directions_car, PdfColors.indigo600, logoImage: PdfLogoHelper.getCachedLogo()),
          pw.SizedBox(height: 16),
          _buildPdfInfoRow('Período',
              '${DateFormat('dd/MM/yyyy').format(relatorio.dataInicio)} até ${DateFormat('dd/MM/yyyy').format(relatorio.dataFim)}'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Resumo Geral'),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('Total de Veículos', relatorio.totalVeiculos.toString()),
          _buildPdfMetricCard('Total de OS', relatorio.veiculos.fold(0, (s, v) => s + v.totalOS).toString()),
          _buildPdfMetricCard('Faturamento Total', 'R\$ ${relatorio.veiculos.fold(0.0, (s, v) => s + v.valorTotal).toStringAsFixed(2)}'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Veículos Atendidos'),
          pw.SizedBox(height: 10),
          _buildPdfTable(
            headers: ['Placa', 'Veículo', 'Marca', 'Ano', 'Proprietário', 'OS', 'Total Gasto', 'Última Visita'],
            rows: relatorio.veiculos
                .map((v) => [
                      v.veiculoPlaca,
                      v.veiculoNome,
                      v.veiculoMarca ?? '',
                      v.veiculoAno ?? '',
                      v.proprietarioNome,
                      v.totalOS.toString(),
                      'R\$ ${v.valorTotal.toStringAsFixed(2)}',
                      v.ultimaVisita != null ? DateFormat('dd/MM/yyyy').format(v.ultimaVisita!) : '—',
                    ])
                .toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  Future<void> _printRelatorioContas(RelatorioContasMes dados) async {
    final doc = pw.Document();
    final String mesLabel = DateFormat('MMMM yyyy', 'pt_BR').format(DateTime(dados.ano, dados.mes));

    final totalAPagarPendente = dados.contasAPagar.where((c) => !c.pago).fold(0.0, (s, c) => s + c.valorPendente);
    final totalAReceberPendente = dados.contasAReceber.where((c) => !c.pago).fold(0.0, (s, c) => s + c.valorPendente);
    final totalAPagarPago = dados.contasAPagar.where((c) => c.pago).fold(0.0, (s, c) => s + c.valor) +
        dados.contasAPagar.where((c) => !c.pago && c.temPagamentoParcial).fold(0.0, (s, c) => s + c.valorPagoParcial);
    final totalAReceberRecebido = dados.contasAReceber.where((c) => c.pago).fold(0.0, (s, c) => s + c.valor) +
        dados.contasAReceber.where((c) => !c.pago && c.temPagamentoParcial).fold(0.0, (s, c) => s + c.valorPagoParcial);
    final saldo = totalAReceberRecebido - totalAPagarPago;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader(
            'Contas a Pagar/Receber',
            Icons.account_balance,
            PdfColors.teal600,
            logoImage: PdfLogoHelper.getCachedLogo(),
          ),
          pw.SizedBox(height: 16),
          _buildPdfInfoRow('Mês de Referência', mesLabel),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Resumo do Mês'),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('A Pagar (Pendente)', 'R\$ ${totalAPagarPendente.toStringAsFixed(2)}'),
          _buildPdfMetricCard('A Receber (Pendente)', 'R\$ ${totalAReceberPendente.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Já Pago', 'R\$ ${totalAPagarPago.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Já Recebido', 'R\$ ${totalAReceberRecebido.toStringAsFixed(2)}'),
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 6),
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: pw.BoxDecoration(
              color: saldo >= 0 ? PdfColors.green50 : PdfColors.red50,
              border: pw.Border.all(color: saldo >= 0 ? PdfColors.green : PdfColors.red, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Saldo do Mês', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.Text(
                  'R\$ ${saldo.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: saldo >= 0 ? PdfColors.green700 : PdfColors.red700,
                  ),
                ),
              ],
            ),
          ),
          if (dados.contasAtrasadas.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildPdfSectionTitle('Contas Atrasadas'),
            pw.SizedBox(height: 10),
            _buildPdfTable(
              headers: ['Descrição', 'Tipo', 'Vencimento', 'Valor Pendente'],
              rows: dados.contasAtrasadas
                  .map((c) => [
                        c.descricao.replaceAll(RegExp(r'\bfiado\b', caseSensitive: false), 'Crediário Próprio'),
                        c.isAPagar ? 'A Pagar' : 'A Receber',
                        c.dataVencimento != null ? DateFormat('dd/MM/yyyy').format(c.dataVencimento!) : '—',
                        'R\$ ${c.valorPendente.toStringAsFixed(2)}',
                      ])
                  .toList(),
            ),
          ],
          if (dados.contasAPagar.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildPdfSectionTitle('Contas a Pagar'),
            pw.SizedBox(height: 10),
            _buildPdfTable(
              headers: ['Descrição', 'Vencimento', 'Valor', 'Status'],
              rows: dados.contasAPagar
                  .map((c) => [
                        c.descricao.replaceAll(RegExp(r'\bfiado\b', caseSensitive: false), 'Crediário Próprio'),
                        c.dataVencimento != null ? DateFormat('dd/MM/yyyy').format(c.dataVencimento!) : '—',
                        'R\$ ${c.valor.toStringAsFixed(2)}',
                        c.pago ? 'Pago' : (c.isAtrasada ? 'Atrasado' : 'Pendente'),
                      ])
                  .toList(),
            ),
          ],
          if (dados.contasAReceber.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildPdfSectionTitle('Contas a Receber'),
            pw.SizedBox(height: 10),
            _buildPdfTable(
              headers: ['Descrição', 'Vencimento', 'Valor', 'Status'],
              rows: dados.contasAReceber
                  .map((c) => [
                        c.descricao.replaceAll(RegExp(r'\bfiado\b', caseSensitive: false), 'Crediário Próprio'),
                        c.dataVencimento != null ? DateFormat('dd/MM/yyyy').format(c.dataVencimento!) : '—',
                        'R\$ ${c.valor.toStringAsFixed(2)}',
                        c.pago ? 'Recebido' : (c.isAtrasada ? 'Atrasado' : 'Pendente'),
                      ])
                  .toList(),
            ),
          ],
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }
}
