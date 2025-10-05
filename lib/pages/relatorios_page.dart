import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
  bool _isGeneratingPdf = false;

  dynamic _relatorioAtual;

  pw.MemoryImage? _cachedLogoImage;

  List<Funcionario> _funcionarios = [];
  int? _mecanicoSelecionadoId;
  bool _isLoadingFuncionarios = false;

  @override
  void initState() {
    super.initState();

    _dataFim = DateTime.now();
    _dataInicio = DateTime(_dataFim!.year, _dataFim!.month - 1, _dataFim!.day);
    _dataInicioController.text = DateFormat('dd/MM/yyyy').format(_dataInicio!);
    _dataFimController.text = DateFormat('dd/MM/yyyy').format(_dataFim!);
    _carregarFuncionarios();
    _preloadLogo();
  }

  Future<void> _preloadLogo() async {
    try {
      final logoBytes = await rootBundle.load('assets/images/TecStock_logo.png');
      _cachedLogoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      print('Erro ao pré-carregar logo: $e');
    }
  }

  Future<void> _carregarFuncionarios() async {
    setState(() {
      _isLoadingFuncionarios = true;
    });
    try {
      final response = await http.get(Uri.parse('http://localhost:8081/api/funcionarios/listarMecanicos'));
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
            _buildModernHeader(context),
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
            Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
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
                      onTap: _isGeneratingPdf ? null : _imprimirRelatorio,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isGeneratingPdf)
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                                ),
                              )
                            else
                              Icon(
                                Icons.picture_as_pdf,
                                color: Colors.orange.shade600,
                                size: 20,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              _isGeneratingPdf ? 'Gerando PDF...' : 'Imprimir PDF',
                              style: TextStyle(
                                color: Colors.orange.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
          case 'fiado':
            await _printRelatorioFiado(_relatorioAtual as RelatorioFiado);
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
    _cachedLogoImage ??= pw.MemoryImage(
      (await rootBundle.load('assets/images/TecStock_logo.png')).buffer.asUint8List(),
    );

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader('Relatório de Agendamentos', Icons.calendar_month, PdfColors.blue600, logoImage: _cachedLogoImage),
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
    _cachedLogoImage ??= pw.MemoryImage(
      (await rootBundle.load('assets/images/TecStock_logo.png')).buffer.asUint8List(),
    );

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader('Relatório de Serviços', Icons.build, PdfColors.indigo600, logoImage: _cachedLogoImage),
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
    _cachedLogoImage ??= pw.MemoryImage(
      (await rootBundle.load('assets/images/TecStock_logo.png')).buffer.asUint8List(),
    );

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader('Relatório de Estoque', Icons.inventory, PdfColors.purple600, logoImage: _cachedLogoImage),
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
    _cachedLogoImage ??= pw.MemoryImage(
      (await rootBundle.load('assets/images/TecStock_logo.png')).buffer.asUint8List(),
    );

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader('Relatório Financeiro', Icons.attach_money, PdfColors.green600, logoImage: _cachedLogoImage),
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
    _cachedLogoImage ??= pw.MemoryImage(
      (await rootBundle.load('assets/images/TecStock_logo.png')).buffer.asUint8List(),
    );

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader('Relatório de Comissão', Icons.account_balance_wallet, PdfColors.cyan600, logoImage: _cachedLogoImage),
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
    _cachedLogoImage ??= pw.MemoryImage(
      (await rootBundle.load('assets/images/TecStock_logo.png')).buffer.asUint8List(),
    );

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader('Relatório de Garantias', Icons.verified_user, PdfColors.teal600, logoImage: _cachedLogoImage),
          pw.SizedBox(height: 16),
          _buildPdfInfoRow('Período',
              '${DateFormat('dd/MM/yyyy').format(relatorio.dataInicio)} até ${DateFormat('dd/MM/yyyy').format(relatorio.dataFim)}'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Resumo'),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('Total de Garantias', relatorio.totalGarantias.toString()),
          _buildPdfMetricCard('Em Aberto', relatorio.garantiasEmAberto.toString()),
          _buildPdfMetricCard('Encerradas', relatorio.garantiasEncerradas.toString()),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Garantias no Período'),
          pw.SizedBox(height: 10),
          if (relatorio.garantias.isEmpty)
            pw.Center(
              child: pw.Text('Nenhuma garantia encontrada no período selecionado', style: const pw.TextStyle(fontSize: 11)),
            )
          else
            ...relatorio.garantias.map((garantia) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: garantia.emAberto ? PdfColors.green50 : PdfColors.red50,
                    border: pw.Border.all(color: garantia.emAberto ? PdfColors.green : PdfColors.red, width: 1.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('OS #${garantia.numeroOS}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text(garantia.statusDescricao,
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: garantia.emAberto ? PdfColors.green : PdfColors.red)),
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
                      if (garantia.mecanicoNome != null && garantia.mecanicoNome!.isNotEmpty)
                        pw.Text('Mecânico: ${garantia.mecanicoNome}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                )),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  Future<void> _printRelatorioFiado(RelatorioFiado relatorio) async {
    _cachedLogoImage ??= pw.MemoryImage(
      (await rootBundle.load('assets/images/TecStock_logo.png')).buffer.asUint8List(),
    );

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          _buildPdfHeader('Relatório de Fiado', Icons.credit_card, PdfColors.orange600, logoImage: _cachedLogoImage),
          pw.SizedBox(height: 16),
          _buildPdfInfoRow('Período',
              '${DateFormat('dd/MM/yyyy').format(relatorio.dataInicio)} até ${DateFormat('dd/MM/yyyy').format(relatorio.dataFim)}'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Resumo'),
          pw.SizedBox(height: 10),
          _buildPdfMetricCard('Total de Fiados', relatorio.totalFiados.toString()),
          _buildPdfMetricCard('No Prazo', relatorio.fiadosNoPrazo.toString()),
          _buildPdfMetricCard('Vencidos', relatorio.fiadosVencidos.toString()),
          _buildPdfMetricCard('Valor Total', 'R\$ ${relatorio.valorTotalFiado.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Valor No Prazo', 'R\$ ${relatorio.valorNoPrazo.toStringAsFixed(2)}'),
          _buildPdfMetricCard('Valor Vencido', 'R\$ ${relatorio.valorVencido.toStringAsFixed(2)}'),
          pw.SizedBox(height: 16),
          _buildPdfSectionTitle('Fiados no Período'),
          pw.SizedBox(height: 10),
          if (relatorio.fiados.isEmpty)
            pw.Center(
              child: pw.Text('Nenhum fiado encontrado no período selecionado', style: const pw.TextStyle(fontSize: 11)),
            )
          else
            ...relatorio.fiados.map((fiado) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: fiado.noPrazo ? PdfColors.green50 : PdfColors.red50,
                    border: pw.Border.all(color: fiado.noPrazo ? PdfColors.green : PdfColors.red, width: 1.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('OS #${fiado.numeroOS}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text(fiado.statusDescricao,
                              style: pw.TextStyle(
                                  fontSize: 10, fontWeight: pw.FontWeight.bold, color: fiado.noPrazo ? PdfColors.green : PdfColors.red)),
                        ],
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('Cliente: ${fiado.clienteNome} - CPF: ${fiado.clienteCpf}', style: const pw.TextStyle(fontSize: 10)),
                      if (fiado.clienteTelefone != null && fiado.clienteTelefone!.isNotEmpty)
                        pw.Text('Telefone: ${fiado.clienteTelefone}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Veículo: ${fiado.veiculoNome} - ${fiado.veiculoPlaca}', style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 3),
                      pw.Text(
                          'Valor: R\$ ${fiado.valorTotal.toStringAsFixed(2)} | Prazo: ${fiado.prazoFiadoDias} ${fiado.prazoFiadoDias == 1 ? 'dia' : 'dias'}',
                          style: const pw.TextStyle(fontSize: 9)),
                      if (fiado.tipoPagamentoNome != null && fiado.tipoPagamentoNome!.isNotEmpty)
                        pw.Text('Tipo Pagamento: ${fiado.tipoPagamentoNome}', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Encerramento OS: ${DateFormat('dd/MM/yyyy').format(fiado.dataEncerramento)}',
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Vencimento: ${DateFormat('dd/MM/yyyy').format(fiado.dataVencimentoFiado)}',
                          style: const pw.TextStyle(fontSize: 9)),
                      if (fiado.mecanicoNome != null && fiado.mecanicoNome!.isNotEmpty)
                        pw.Text('Mecânico: ${fiado.mecanicoNome}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                )),
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

  Widget _buildRelatorioFiado(RelatorioFiado relatorio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
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
                      if (fiado.tipoPagamentoNome != null && fiado.tipoPagamentoNome!.isNotEmpty)
                        _buildInfoRow(
                          Icons.payment,
                          'Tipo de Pagamento',
                          fiado.tipoPagamentoNome!,
                          statusColor,
                        ),
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
