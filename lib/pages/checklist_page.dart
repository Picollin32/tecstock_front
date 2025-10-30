import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../services/cliente_service.dart';
import '../services/veiculo_service.dart';
import '../services/funcionario_service.dart';
import '../services/auth_service.dart';
import '../model/cliente.dart';
import '../model/veiculo.dart';
import '../model/funcionario.dart';
import '../services/checklist_service.dart';
import '../model/checklist.dart';

class ChecklistPage extends StatelessWidget {
  const ChecklistPage({super.key});

  @override
  Widget build(BuildContext context) => const ChecklistScreen();
}

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  final _clienteNomeController = TextEditingController();
  final _clienteCpfController = TextEditingController();
  final _clienteTelefoneController = TextEditingController();
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

  double _fuelLevel = 2.0;
  List<Funcionario> _funcionarios = [];
  Funcionario? _consultorSelecionado;
  String? _categoriaSelecionada;
  bool _isAdmin = false;
  bool _isLoadingInitialData = true;

  final Map<String, String> _inspecaoVisualStatus = {
    'Para-choque Dianteiro': '',
    'Para-choque Traseiro': '',
    'Capô': '',
    'Porta-malas': '',
    'Porta Diant. Esq.': '',
    'Porta Tras. Esq.': '',
    'Porta Diant. Dir.': '',
    'Porta Tras. Dir.': '',
    'Teto': '',
    'Para-brisa': '',
    'Retrovisores': '',
    'Pneus e Rodas': '',
    'Estepe': '',
  };

  final Map<String, TextEditingController> _inspecaoVisualObs = {
    'Para-choque Dianteiro': TextEditingController(),
    'Para-choque Traseiro': TextEditingController(),
    'Capô': TextEditingController(),
    'Porta-malas': TextEditingController(),
    'Porta Diant. Esq.': TextEditingController(),
    'Porta Tras. Esq.': TextEditingController(),
    'Porta Diant. Dir.': TextEditingController(),
    'Porta Tras. Dir.': TextEditingController(),
    'Teto': TextEditingController(),
    'Para-brisa': TextEditingController(),
    'Retrovisores': TextEditingController(),
    'Pneus e Rodas': TextEditingController(),
    'Estepe': TextEditingController(),
  };

  final Map<String, String> _testesFuncionamento = {
    'Buzina': '',
    'Farol Baixo / Alto': '',
    'Setas / Pisca-alerta': '',
    'Luz de Freio': '',
    'Limpador de para-brisa': '',
    'Ar Condicionado': '',
    'Rádio / Multimídia': '',
  };

  final Map<String, String> _itensVeiculo = {
    'Manual / Livreto': '',
    'CRLV': '',
    'Chave Reserva': '',
    'Macaco': '',
    'Chave de Roda': '',
    'Triângulo': '',
    'Tapetes': '',
  };

  List<dynamic> _veiculos = [];
  final TextEditingController _searchController = TextEditingController();
  List<Checklist> _recentFiltrados = [];

  final Map<String, dynamic> _clienteByCpf = {};
  final Map<String, dynamic> _veiculoByPlaca = {};

  pw.MemoryImage? _cachedLogoImage;

  bool _showForm = false;
  bool _isViewMode = false;
  List<Checklist> _recent = [];
  final _checklistNumberController = TextEditingController();
  int? _editingChecklistId;

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
    _fuelLevel = 2.0;
    _checklistNumberController.clear();
    _consultorSelecionado = null;
    _categoriaSelecionada = null;
    _isViewMode = false;

    _inspecaoVisualStatus.updateAll((key, value) => '');

    _inspecaoVisualObs.forEach((key, controller) => controller.clear());

    _testesFuncionamento.updateAll((key, value) => '');

    _itensVeiculo.updateAll((key, value) => '');
  }

  Future<void> _loadRecentChecklists() async {
    try {
      final all = await ChecklistService.listarChecklists();
      setState(() {
        final reversed = all.reversed.toList();
        _recent = reversed.take(3).toList();
        _recentFiltrados = _recent;
      });
    } catch (e) {
      print('Erro ao carregar checklists: $e');
    }
  }

  Future<void> _loadFuncionarios() async {
    try {
      final todosFuncionarios = await Funcionarioservice.listarFuncionarios();
      final consultores = todosFuncionarios.where((funcionario) => funcionario.nivelAcesso == 1).toList();

      Funcionario? consultorParaSelecionar;

      if (!_isAdmin && _consultorSelecionado == null) {
        final consultorId = await AuthService.getConsultorId();

        if (consultorId != null) {
          consultorParaSelecionar = consultores.where((f) => f.id == consultorId).firstOrNull;
        }
      }

      if (mounted) {
        setState(() {
          _funcionarios = consultores;
          for (var f in todosFuncionarios) {
            _clienteByCpf[f.cpf] = f;
          }
          if (consultorParaSelecionar != null) {
            _consultorSelecionado = consultorParaSelecionar;
          }
        });
      }
    } catch (e) {
      print('Erro ao carregar funcionários: $e');
    }
  }

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
    _initializeData();
    _loadClientesVeiculos();
    _loadRecentChecklists();
    _searchController.addListener(_filtrarRecentes);

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _initializeData() async {
    await _verificarPermissoes();
    await _loadFuncionarios();
    if (mounted) {
      setState(() {
        _isLoadingInitialData = false;
      });
    }
  }

  Future<void> _verificarPermissoes() async {
    final isAdmin = await AuthService.isAdmin();
    setState(() {
      _isAdmin = isAdmin;
    });
  }

  @override
  void dispose() {
    try {
      _fadeController.dispose();
      _slideController.dispose();
      _dateController.dispose();
      _timeController.dispose();
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
      _checklistNumberController.dispose();

      _inspecaoVisualObs.forEach((key, controller) => controller.dispose());

      _searchController.removeListener(_filtrarRecentes);
      _searchController.dispose();
    } catch (e) {
      // Erro ao fazer dispose (ignorado)
    }
    super.dispose();
  }

  void _filtrarRecentes() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _recentFiltrados = _recent;
      } else {
        _recentFiltrados = _recent
            .where(
                (c) => c.numeroChecklist.toLowerCase().contains(q) || (c.veiculoPlaca != null && c.veiculoPlaca!.toLowerCase().contains(q)))
            .toList();
      }
    });
  }

  Future<void> _loadClientesVeiculos() async {
    try {
      final clientes = await ClienteService.listarClientes();
      final veiculos = await VeiculoService.listarVeiculos();
      setState(() {
        _veiculos = veiculos;
        for (var c in clientes) {
          _clienteByCpf[c.cpf] = c;
        }
        for (var v in veiculos) {
          _veiculoByPlaca[v.placa] = v;
        }
      });
    } catch (e) {
      print('Erro ao carregar clientes/veículos: $e');
    }
  }

  Future<void> _printChecklist() async {
    _cachedLogoImage ??= pw.MemoryImage(
      (await rootBundle.load('assets/images/TecStock_logo.png')).buffer.asUint8List(),
    );

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Container(
                height: 1,
                color: PdfColors.grey300,
                margin: const pw.EdgeInsets.only(bottom: 8),
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TecStock - Sistema de Gerenciamento de Oficina',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Página ${context.pageNumber} de ${context.pagesCount}',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                  ),
                  pw.Text(
                    'Checklist: ${_checklistNumberController.text}',
                    style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) => [
          pw.Wrap(
            children: [
              _buildPdfHeader(logoImage: _cachedLogoImage),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 2,
                    child: _buildPdfClientVehicleData(),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    flex: 1,
                    child: _buildPdfResponsibleSection(),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Wrap(
            children: [
              _buildPdfSection(
                'QUEIXA PRINCIPAL / SERVIÇO SOLICITADO',
                [],
                content: _queixaPrincipalController.text.isNotEmpty ? _queixaPrincipalController.text : 'Não informado',
                compact: true,
              ),
            ],
          ),
          pw.SizedBox(height: 7),
          pw.Wrap(
            children: [
              _buildPdfInspectionTable(),
            ],
          ),
          pw.SizedBox(height: 7),
          pw.Wrap(
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _buildPdfTestsSection()),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: _buildPdfItemsSection()),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: _buildPdfSection(
                      'NÍVEL DE COMBUSTÍVEL',
                      [],
                      content: '${(_fuelLevel * 25).toStringAsFixed(0)}% (${_getFuelDescription()})',
                      compact: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              _buildSignaturePage(logoImage: _cachedLogoImage),
              pw.Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: pw.Column(
                  children: [
                    pw.Container(
                      height: 1,
                      color: PdfColors.grey300,
                      margin: const pw.EdgeInsets.only(bottom: 8),
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'TecStock - Sistema de Gerenciamento Automotivo',
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                        pw.Text(
                          'Página de Assinaturas',
                          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                        ),
                        pw.Text(
                          'Checklist: ${_checklistNumberController.text}',
                          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  String _getFuelDescription() {
    switch (_fuelLevel.round()) {
      case 0:
        return 'Vazio';
      case 1:
        return '1/4';
      case 2:
        return '1/2';
      case 3:
        return '3/4';
      case 4:
        return 'Cheio';
      default:
        return 'Indefinido';
    }
  }

  pw.Widget _buildPdfSection(String title, List<List<String>> data, {String? content, bool compact = false}) {
    final paddingValue = compact ? 6.0 : 8.0;
    final titleFontSize = compact ? 9.0 : 10.0;
    final contentFontSize = compact ? 8.5 : 9.0;
    final dataFontSize = compact ? 8.0 : 8.5;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: pw.EdgeInsets.all(paddingValue),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: titleFontSize, color: PdfColors.blue900),
          ),
          pw.SizedBox(height: compact ? 4 : 5),
          if (content != null)
            pw.Text(content, style: pw.TextStyle(fontSize: contentFontSize, height: 1.2))
          else
            ...data.map((row) => pw.Padding(
                  padding: pw.EdgeInsets.symmetric(vertical: compact ? 1 : 1.5),
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

  pw.Widget _buildPdfInspectionTable() {
    final items = [
      'Para-choque Dianteiro',
      'Para-choque Traseiro',
      'Capô',
      'Porta-malas',
      'Porta Diant. Esq.',
      'Porta Tras. Esq.',
      'Porta Diant. Dir.',
      'Porta Tras. Dir.',
      'Teto',
      'Para-brisa',
      'Retrovisores',
      'Pneus e Rodas',
      'Estepe'
    ];

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(
              'INSPEÇÃO VISUAL (AVARIAS)',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blue900),
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(2.5),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey50),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(3),
                    child: pw.Text('Observações', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5)),
                  ),
                ],
              ),
              ...items.map((item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(item, style: pw.TextStyle(fontSize: 7)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child:
                            pw.Text(_inspecaoVisualStatus[item] ?? '-', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(_inspecaoVisualObs[item]?.text ?? '-', style: pw.TextStyle(fontSize: 6.5)),
                      ),
                    ],
                  )),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTestsSection() {
    final tests = [
      'Buzina',
      'Farol Baixo / Alto',
      'Setas / Pisca-alerta',
      'Luz de Freio',
      'Limpador de para-brisa',
      'Ar Condicionado',
      'Rádio / Multimídia'
    ];

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'TESTES DE FUNCIONAMENTO',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blue900),
          ),
          pw.SizedBox(height: 4),
          ...tests.map((test) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text(test, style: pw.TextStyle(fontSize: 7))),
                    pw.Text(_testesFuncionamento[test] ?? '-', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  pw.Widget _buildPdfItemsSection() {
    final items = ['Manual / Livreto', 'CRLV', 'Chave Reserva', 'Macaco', 'Chave de Roda', 'Triângulo', 'Tapetes'];

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ITENS NO VEÍCULO',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.blue900),
          ),
          pw.SizedBox(height: 4),
          ...items.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(child: pw.Text(item, style: pw.TextStyle(fontSize: 7))),
                    pw.Text(_itensVeiculo[item] ?? '-', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  pw.Widget _buildPdfHeader({pw.MemoryImage? logoImage}) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [PdfColors.purple600, PdfColors.deepPurple600],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Row(
        children: [
          if (logoImage != null) ...[
            pw.Image(logoImage, width: 45, height: 45, fit: pw.BoxFit.contain),
            pw.SizedBox(width: 10),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CHECKLIST DE RECEPÇÃO DE VEÍCULO',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  children: [
                    pw.Text('Data: ${_dateController.text}', style: pw.TextStyle(fontSize: 8.5, color: PdfColors.white)),
                    pw.SizedBox(width: 14),
                    pw.Text('Hora: ${_timeController.text}', style: pw.TextStyle(fontSize: 8.5, color: PdfColors.white)),
                  ],
                ),
              ],
            ),
          ),
          if (_editingChecklistId != null)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Text(
                'Nº ${_checklistNumberController.text}',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.purple600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfClientVehicleData() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildPdfSection(
            'DADOS DO CLIENTE',
            [
              ['Nome:', _clienteNomeController.text],
              ['CPF:', _clienteCpfController.text],
              ['Telefone:', _clienteTelefoneController.text],
              ['Email:', _clienteEmailController.text],
            ],
            compact: true,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _buildPdfSection(
            'DADOS DO VEÍCULO',
            [
              ['Veículo:', _veiculoNomeController.text],
              ['Marca:', _veiculoMarcaController.text],
              ['Ano/Modelo:', _veiculoAnoController.text],
              ['Cor:', _veiculoCorController.text],
              ['Placa:', _veiculoPlacaController.text],
              ['Quilometragem:', _veiculoQuilometragemController.text],
            ],
            compact: true,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfResponsibleSection() {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RESPONSÁVEL',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blue900),
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Text('Nome: ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Expanded(
                child: pw.Text(
                  _consultorSelecionado?.nome ?? 'N/A',
                  style: pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Row(
            children: [
              pw.Text('CPF: ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Expanded(
                child: pw.Text(
                  _consultorSelecionado?.cpf ?? 'N/A',
                  style: pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignaturePage({pw.MemoryImage? logoImage}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 60),
      child: pw.Column(
        children: [
          _buildPdfHeader(logoImage: logoImage),
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
                  'RESUMO DO CHECKLIST',
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
                          _buildResumoItem('Cliente:', _clienteNomeController.text),
                          _buildResumoItem('CPF:', _clienteCpfController.text),
                          _buildResumoItem('Telefone:', _clienteTelefoneController.text),
                          _buildResumoItem('Data/Hora:', '${_dateController.text} - ${_timeController.text}'),
                          _buildResumoItem('Consultor:', _consultorSelecionado?.nome ?? ''),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 24),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildResumoItem('Veículo:', _veiculoNomeController.text),
                          _buildResumoItem('Marca:', _veiculoMarcaController.text),
                          _buildResumoItem('Placa:', _veiculoPlacaController.text),
                          _buildResumoItem('Quilometragem:', _veiculoQuilometragemController.text),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_queixaPrincipalController.text.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Queixa Principal:',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _queixaPrincipalController.text,
                    style: pw.TextStyle(fontSize: 10),
                  ),
                ],
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
                      '${_clienteNomeController.text} - CPF: ${_clienteCpfController.text}',
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
                          'Assinatura do Consultor Responsável',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      '${_consultorSelecionado?.nome ?? 'Nome: _________________________'} - CPF: ${_consultorSelecionado?.cpf ?? '_______________'}',
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
                    'Declaro que recebi meu veículo nas condições descritas neste checklist e autorizo a execução dos serviços solicitados.',
                    style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildResumoItem(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 85,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isNotEmpty ? value : '-',
              style: pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey[50],
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.purple.shade50,
              Colors.deepPurple.shade50,
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
                  if (_isLoadingInitialData)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: CircularProgressIndicator(color: Colors.purple.shade600),
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
          colors: [Colors.purple.shade600, Colors.deepPurple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
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
              Icons.checklist_outlined,
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
                  'Checklist de Veículos',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Gerencie checklists de recepção e inspeção',
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
                  setState(() {
                    if (_showForm) {
                      _clearFormFields();
                      _editingChecklistId = null;
                      _checklistNumberController.clear();
                      _showForm = false;
                    } else {
                      _clearFormFields();
                      _editingChecklistId = null;
                      _checklistNumberController.clear();
                      _showForm = true;
                    }
                  });

                  if (_showForm && !_isAdmin && _consultorSelecionado == null) {
                    final consultorId = await AuthService.getConsultorId();
                    if (consultorId != null && mounted) {
                      final consultor = _funcionarios.where((f) => f.id == consultorId).firstOrNull;
                      if (consultor != null && mounted) {
                        setState(() {
                          _consultorSelecionado = consultor;
                        });
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
                        color: Colors.purple.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showForm ? 'Cancelar' : 'Novo Checklist',
                        style: TextStyle(
                          color: Colors.purple.shade600,
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
              Icon(Icons.search, color: Colors.purple.shade600),
              const SizedBox(width: 12),
              Text(
                'Buscar Checklists',
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
              hintText: 'Pesquisar por número do checklist ou placa do veículo',
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
                borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
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
              Icons.checklist_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty ? 'Nenhum checklist cadastrado' : 'Nenhum resultado encontrado',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty ? 'Clique em "Novo Checklist" para começar' : 'Tente ajustar os termos da busca',
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
              Icon(Icons.history, color: Colors.purple.shade600),
              const SizedBox(width: 12),
              Text(
                _searchController.text.isEmpty ? 'Últimos Checklists' : 'Resultados da Busca',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_recentFiltrados.length} item${_recentFiltrados.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.purple.shade700,
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
              final c = _recentFiltrados[index];
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
                        colors: [Colors.purple.shade400, Colors.deepPurple.shade400],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.checklist_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        'Checklist ${c.numeroChecklist}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.status == 'Fechado' ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.status == 'Fechado' ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              c.status == 'Fechado' ? Icons.lock : Icons.lock_open,
                              size: 12,
                              color: c.status == 'Fechado' ? Colors.red[700] : Colors.green[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              c.status == 'Fechado' ? 'Fechado' : 'Aberto',
                              style: TextStyle(
                                color: c.status == 'Fechado' ? Colors.red[700] : Colors.green[700],
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
                      if (c.clienteNome != null && c.clienteNome!.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.person, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                c.clienteNome!,
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                      if (c.veiculoPlaca != null && c.veiculoPlaca!.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.directions_car, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              c.veiculoPlaca!,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      if (c.data != null && c.data!.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              c.data!,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      if (c.createdAt != null) Row(),
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
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          onPressed: () => _visualizarChecklist(c),
                          tooltip: 'Visualizar Checklist',
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
                          onPressed: () async {
                            if (c.id != null) {
                              setState(() {
                                _editingChecklistId = c.id;
                                _checklistNumberController.text = c.numeroChecklist;
                              });
                              await _carregarDadosChecklistParaEdicao(c.id!);
                              await _printChecklist();
                              setState(() {
                                _editingChecklistId = null;
                                _checklistNumberController.clear();
                              });
                              _clearFormFields();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (c.status != 'Fechado')
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
                            onPressed: () async {
                              setState(() {
                                _editingChecklistId = c.id;
                                _checklistNumberController.text = c.numeroChecklist;
                                _showForm = true;
                              });

                              if (c.id != null) {
                                await _carregarDadosChecklistParaEdicao(c.id!);
                              }
                            },
                            tooltip: 'Editar Checklist',
                          ),
                        )
                      else
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
                            tooltip: 'Checklist Fechado',
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (c.status != 'Fechado')
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
                            onPressed: () => _confirmarExclusao(c),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _confirmarExclusao(Checklist checklist) {
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
        content: Text('Deseja realmente excluir o checklist ${checklist.numeroChecklist}? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (checklist.id != null) {
                final sucesso = await ChecklistService.excluirChecklist(checklist.id!);
                if (sucesso) {
                  await _loadRecentChecklists();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Checklist excluído com sucesso'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.error, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Erro ao excluir checklist'),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
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
                colors: [Colors.purple.shade600, Colors.deepPurple.shade600],
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
                const Icon(Icons.checklist, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isViewMode ? 'Visualizar Checklist' : (_editingChecklistId != null ? 'Editar Checklist' : 'Novo Checklist'),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Checklist de Recepção de Veículo',
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
                    onPressed: () => _printChecklist(),
                    icon: Icon(Icons.picture_as_pdf, color: Colors.purple.shade600, size: 20),
                    tooltip: 'PDF',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
              ],
            ),
          ),
          AbsorbPointer(
            absorbing: _isViewMode,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_editingChecklistId != null)
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
                            '${_isViewMode ? "Visualizando" : "Editando"} checklist: ${_checklistNumberController.text.isNotEmpty ? _checklistNumberController.text : _editingChecklistId}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_editingChecklistId != null) const SizedBox(height: 24),
                  _buildFormSection('1. Dados do Cliente e Veículo', Icons.person_outline),
                  const SizedBox(height: 16),
                  _buildClientVehicleInfo(),
                  const SizedBox(height: 32),
                  _buildFormSection('2. Queixa Principal / Serviço Solicitado', Icons.report_problem_outlined),
                  const SizedBox(height: 16),
                  _buildComplaintSection(),
                  const SizedBox(height: 32),
                  _buildFormSection('3. Inspeção Visual (Avarias)', Icons.visibility_outlined),
                  const SizedBox(height: 16),
                  _buildVisualInspection(),
                  const SizedBox(height: 32),
                  _buildTestsAndItems(),
                  const SizedBox(height: 32),
                  _buildFormSection('6. Nível de Combustível', Icons.local_gas_station_outlined),
                  const SizedBox(height: 16),
                  _buildFuelLevel(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple.shade600, Colors.deepPurple.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isViewMode
                        ? () {
                            setState(() {
                              _showForm = false;
                              _editingChecklistId = null;
                              _isViewMode = false;
                              _clearFormFields();
                            });
                          }
                        : _salvarChecklist,
                    icon: Icon(_isViewMode ? Icons.arrow_back : Icons.save, color: Colors.white),
                    label: Text(
                      _isViewMode ? 'Voltar' : (_editingChecklistId != null ? 'Atualizar Checklist' : 'Salvar Checklist'),
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
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.purple.shade600, size: 20),
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

  Future<void> _carregarDadosChecklistParaEdicao(int checklistId) async {
    try {
      final checklist = await ChecklistService.buscarChecklistPorId(checklistId);
      if (checklist != null) {
        setState(() {
          _dateController.text = checklist.data ?? '';
          _timeController.text = checklist.hora ?? '';

          _clienteNomeController.text = checklist.clienteNome ?? '';
          _clienteCpfController.text = checklist.clienteCpf ?? '';
          _clienteTelefoneController.text = checklist.clienteTelefone ?? '';
          _clienteEmailController.text = checklist.clienteEmail ?? '';
          _veiculoNomeController.text = checklist.veiculoNome ?? '';
          _veiculoMarcaController.text = checklist.veiculoMarca ?? '';
          _veiculoAnoController.text = checklist.veiculoAno ?? '';
          _veiculoCorController.text = checklist.veiculoCor ?? '';
          _veiculoPlacaController.text = checklist.veiculoPlaca ?? '';
          _veiculoQuilometragemController.text = checklist.veiculoQuilometragem ?? '';
          _queixaPrincipalController.text = checklist.queixaPrincipal ?? '';
          _fuelLevel = (checklist.nivelCombustivel ?? 0) / 25.0;

          if (checklist.veiculoCategoria != null && checklist.veiculoCategoria!.isNotEmpty) {
            _categoriaSelecionada = checklist.veiculoCategoria;
          } else if (checklist.veiculoPlaca != null) {
            final veiculo = _veiculoByPlaca[checklist.veiculoPlaca!];
            if (veiculo != null) {
              _categoriaSelecionada = veiculo.categoria;
            }
          }

          if (checklist.consultorId != null) {
            try {
              _consultorSelecionado = _funcionarios.firstWhere(
                (funcionario) => funcionario.id == checklist.consultorId,
              );
            } catch (e) {
              _consultorSelecionado = null;
            }
          }
          _inspecaoVisualStatus['Para-choque Dianteiro'] = checklist.parachoquesDianteiro ?? '';
          _inspecaoVisualStatus['Para-choque Traseiro'] = checklist.parachoquesTraseiro ?? '';
          _inspecaoVisualStatus['Capô'] = checklist.capo ?? '';
          _inspecaoVisualStatus['Porta-malas'] = checklist.portaMalas ?? '';
          _inspecaoVisualStatus['Porta Diant. Esq.'] = checklist.portaDiantEsq ?? '';
          _inspecaoVisualStatus['Porta Tras. Esq.'] = checklist.portaTrasEsq ?? '';
          _inspecaoVisualStatus['Porta Diant. Dir.'] = checklist.portaDiantDir ?? '';
          _inspecaoVisualStatus['Porta Tras. Dir.'] = checklist.portaTrasDir ?? '';
          _inspecaoVisualStatus['Teto'] = checklist.teto ?? '';
          _inspecaoVisualStatus['Para-brisa'] = checklist.paraBrisa ?? '';
          _inspecaoVisualStatus['Retrovisores'] = checklist.retrovisores ?? '';
          _inspecaoVisualStatus['Pneus e Rodas'] = checklist.pneusRodas ?? '';
          _inspecaoVisualStatus['Estepe'] = checklist.estepe ?? '';
          _inspecaoVisualObs['Para-choque Dianteiro']?.text = checklist.parachoquesDianteiroObs ?? '';
          _inspecaoVisualObs['Para-choque Traseiro']?.text = checklist.parachoquesTraseiroObs ?? '';
          _inspecaoVisualObs['Capô']?.text = checklist.capoObs ?? '';
          _inspecaoVisualObs['Porta-malas']?.text = checklist.portaMalasObs ?? '';
          _inspecaoVisualObs['Porta Diant. Esq.']?.text = checklist.portaDiantEsqObs ?? '';
          _inspecaoVisualObs['Porta Tras. Esq.']?.text = checklist.portaTrasEsqObs ?? '';
          _inspecaoVisualObs['Porta Diant. Dir.']?.text = checklist.portaDiantDirObs ?? '';
          _inspecaoVisualObs['Porta Tras. Dir.']?.text = checklist.portaTrasDirObs ?? '';
          _inspecaoVisualObs['Teto']?.text = checklist.tetoObs ?? '';
          _inspecaoVisualObs['Para-brisa']?.text = checklist.paraBrisaObs ?? '';
          _inspecaoVisualObs['Retrovisores']?.text = checklist.retrovisoresObs ?? '';
          _inspecaoVisualObs['Pneus e Rodas']?.text = checklist.pneusRodasObs ?? '';
          _inspecaoVisualObs['Estepe']?.text = checklist.estepeObs ?? '';
          _testesFuncionamento['Buzina'] = checklist.buzina ?? '';
          _testesFuncionamento['Farol Baixo / Alto'] = checklist.farolBaixoAlto ?? '';
          _testesFuncionamento['Setas / Pisca-alerta'] = checklist.setasPiscaAlerta ?? '';
          _testesFuncionamento['Luz de Freio'] = checklist.luzFreio ?? '';
          _testesFuncionamento['Limpador de para-brisa'] = checklist.limpadorParaBrisa ?? '';
          _testesFuncionamento['Ar Condicionado'] = checklist.arCondicionado ?? '';
          _testesFuncionamento['Rádio / Multimídia'] = checklist.radioMultimidia ?? '';
          _itensVeiculo['Manual / Livreto'] = checklist.manualLivreto ?? '';
          _itensVeiculo['CRLV'] = checklist.crlv ?? '';
          _itensVeiculo['Chave Reserva'] = checklist.chaveReserva ?? '';
          _itensVeiculo['Macaco'] = checklist.macaco ?? '';
          _itensVeiculo['Chave de Roda'] = checklist.chaveRoda ?? '';
          _itensVeiculo['Triângulo'] = checklist.triangulo ?? '';
          _itensVeiculo['Tapetes'] = checklist.tapetes ?? '';
        });
      }
    } catch (e) {
      print('Erro ao carregar dados do checklist: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar dados do checklist')),
      );
    }
  }

  Future<void> _visualizarChecklist(Checklist c) async {
    try {
      final data = await ChecklistService.buscarChecklistPorId(c.id!);
      if (data != null) {
        setState(() {
          _isViewMode = true;
          _editingChecklistId = data.id;
        });
        await _carregarDadosChecklistParaEdicao(data.id!);
        setState(() {
          _showForm = true;
        });
        _slideController.forward();
      }
    } catch (e) {
      print('Erro ao carregar checklist para visualização: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar dados do checklist')),
      );
    }
  }

  bool _validarCamposObrigatorios() {
    List<String> camposVazios = [];

    if (_dateController.text.trim().isEmpty) camposVazios.add('Data');
    if (_timeController.text.trim().isEmpty) camposVazios.add('Hora');
    if (_clienteNomeController.text.trim().isEmpty) camposVazios.add('Nome do Cliente');
    if (_clienteCpfController.text.trim().isEmpty) camposVazios.add('CPF');
    if (_clienteTelefoneController.text.trim().isEmpty) camposVazios.add('Telefone');
    if (_clienteEmailController.text.trim().isEmpty) camposVazios.add('E-mail');
    if (_veiculoNomeController.text.trim().isEmpty) camposVazios.add('Veículo');
    if (_veiculoMarcaController.text.trim().isEmpty) camposVazios.add('Marca');
    if (_veiculoAnoController.text.trim().isEmpty) camposVazios.add('Ano/Modelo');
    if (_veiculoCorController.text.trim().isEmpty) camposVazios.add('Cor');
    if (_veiculoPlacaController.text.trim().isEmpty) camposVazios.add('Placa');
    if (_veiculoQuilometragemController.text.trim().isEmpty) camposVazios.add('Quilometragem');
    if (_queixaPrincipalController.text.trim().isEmpty) camposVazios.add('Queixa Principal');
    if (_consultorSelecionado == null) camposVazios.add('Consultor');

    _inspecaoVisualStatus.forEach((item, status) {
      if (status.isEmpty) {
        camposVazios.add('Inspeção Visual - $item');
      }
    });

    _testesFuncionamento.forEach((item, status) {
      if (status.isEmpty) {
        camposVazios.add('Teste de Funcionamento - $item');
      }
    });

    _itensVeiculo.forEach((item, status) {
      if (status.isEmpty) {
        camposVazios.add('Item do Veículo - $item');
      }
    });

    if (camposVazios.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Campos Obrigatórios'),
          content: const Text('Por favor, preencha todos os dados necessários antes de salvar o checklist.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _salvarChecklist() async {
    if (!_validarCamposObrigatorios()) {
      return;
    }

    final numeroParaUsar = _editingChecklistId != null ? _checklistNumberController.text : '';
    String getStatusForBackend(String key, Map<String, String> source) {
      return source[key] ?? '';
    }

    final checklist = Checklist(
      id: _editingChecklistId,
      numeroChecklist: numeroParaUsar,
      data: _dateController.text,
      hora: _timeController.text,
      clienteNome: _clienteNomeController.text,
      clienteCpf: _clienteCpfController.text,
      clienteTelefone: _clienteTelefoneController.text,
      clienteEmail: _clienteEmailController.text,
      veiculoNome: _veiculoNomeController.text,
      veiculoMarca: _veiculoMarcaController.text,
      veiculoAno: _veiculoAnoController.text,
      veiculoCor: _veiculoCorController.text,
      veiculoPlaca: _veiculoPlacaController.text,
      veiculoQuilometragem: _veiculoQuilometragemController.text,
      veiculoCategoria: _categoriaSelecionada,
      queixaPrincipal: _queixaPrincipalController.text,
      nivelCombustivel: (_fuelLevel * 25).toInt(),
      consultorId: _consultorSelecionado?.id,
      consultorNome: _consultorSelecionado?.nome,
      parachoquesDianteiro: getStatusForBackend('Para-choque Dianteiro', _inspecaoVisualStatus),
      parachoquesTraseiro: getStatusForBackend('Para-choque Traseiro', _inspecaoVisualStatus),
      capo: getStatusForBackend('Capô', _inspecaoVisualStatus),
      portaMalas: getStatusForBackend('Porta-malas', _inspecaoVisualStatus),
      portaDiantEsq: getStatusForBackend('Porta Diant. Esq.', _inspecaoVisualStatus),
      portaTrasEsq: getStatusForBackend('Porta Tras. Esq.', _inspecaoVisualStatus),
      portaDiantDir: getStatusForBackend('Porta Diant. Dir.', _inspecaoVisualStatus),
      portaTrasDir: getStatusForBackend('Porta Tras. Dir.', _inspecaoVisualStatus),
      teto: getStatusForBackend('Teto', _inspecaoVisualStatus),
      paraBrisa: getStatusForBackend('Para-brisa', _inspecaoVisualStatus),
      retrovisores: getStatusForBackend('Retrovisores', _inspecaoVisualStatus),
      pneusRodas: getStatusForBackend('Pneus e Rodas', _inspecaoVisualStatus),
      estepe: getStatusForBackend('Estepe', _inspecaoVisualStatus),
      parachoquesDianteiroObs: _inspecaoVisualObs['Para-choque Dianteiro']?.text,
      parachoquesTraseiroObs: _inspecaoVisualObs['Para-choque Traseiro']?.text,
      capoObs: _inspecaoVisualObs['Capô']?.text,
      portaMalasObs: _inspecaoVisualObs['Porta-malas']?.text,
      portaDiantEsqObs: _inspecaoVisualObs['Porta Diant. Esq.']?.text,
      portaTrasEsqObs: _inspecaoVisualObs['Porta Tras. Esq.']?.text,
      portaDiantDirObs: _inspecaoVisualObs['Porta Diant. Dir.']?.text,
      portaTrasDirObs: _inspecaoVisualObs['Porta Tras. Dir.']?.text,
      tetoObs: _inspecaoVisualObs['Teto']?.text,
      paraBrisaObs: _inspecaoVisualObs['Para-brisa']?.text,
      retrovisoresObs: _inspecaoVisualObs['Retrovisores']?.text,
      pneusRodasObs: _inspecaoVisualObs['Pneus e Rodas']?.text,
      estepeObs: _inspecaoVisualObs['Estepe']?.text,
      buzina: getStatusForBackend('Buzina', _testesFuncionamento),
      farolBaixoAlto: getStatusForBackend('Farol Baixo / Alto', _testesFuncionamento),
      setasPiscaAlerta: getStatusForBackend('Setas / Pisca-alerta', _testesFuncionamento),
      luzFreio: getStatusForBackend('Luz de Freio', _testesFuncionamento),
      limpadorParaBrisa: getStatusForBackend('Limpador de para-brisa', _testesFuncionamento),
      arCondicionado: getStatusForBackend('Ar Condicionado', _testesFuncionamento),
      radioMultimidia: getStatusForBackend('Rádio / Multimídia', _testesFuncionamento),
      manualLivreto: getStatusForBackend('Manual / Livreto', _itensVeiculo),
      crlv: getStatusForBackend('CRLV', _itensVeiculo),
      chaveReserva: getStatusForBackend('Chave Reserva', _itensVeiculo),
      macaco: getStatusForBackend('Macaco', _itensVeiculo),
      chaveRoda: getStatusForBackend('Chave de Roda', _itensVeiculo),
      triangulo: getStatusForBackend('Triângulo', _itensVeiculo),
      tapetes: getStatusForBackend('Tapetes', _itensVeiculo),
    );

    bool sucesso = false;
    if (_editingChecklistId != null) {
      sucesso = await ChecklistService.atualizarChecklist(_editingChecklistId!, checklist);
    } else {
      sucesso = await ChecklistService.salvarChecklist(checklist);
    }

    if (sucesso) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(_editingChecklistId != null ? 'Checklist atualizado com sucesso' : 'Checklist salvo com sucesso'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      _clearFormFields();
      setState(() {
        _showForm = false;
        _editingChecklistId = null;
      });
      await _loadRecentChecklists();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Erro ao salvar checklist'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
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
            SizedBox(width: itemWidth, child: _buildConsultorDropdown()),
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
              borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildConsultorDropdown() {
    final consultorAtual = _consultorSelecionado != null ? _funcionarios.where((f) => f.id == _consultorSelecionado!.id).firstOrNull : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Consultor',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Funcionario>(
          value: consultorAtual,
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
              borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          hint: const Text('Selecione um consultor'),
          items: (() {
            final lista = List<Funcionario>.from(_funcionarios);
            lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
            return lista.map<DropdownMenuItem<Funcionario>>((funcionario) {
              return DropdownMenuItem<Funcionario>(
                value: funcionario,
                child: Text(funcionario.nome),
              );
            }).toList();
          })(),
          onChanged: _isAdmin
              ? (Funcionario? funcionario) {
                  setState(() {
                    _consultorSelecionado = funcionario;
                  });
                }
              : null,
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
              color: _categoriaSelecionada == null ? Colors.purple[300]! : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(8),
            color: _categoriaSelecionada == null ? Colors.purple[50] : Colors.grey[50],
          ),
          child: Row(
            children: [
              if (_categoriaSelecionada == null) Icon(Icons.info_outline, color: Colors.purple[600], size: 16),
              if (_categoriaSelecionada == null) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _categoriaSelecionada ?? 'Selecione um veículo para definir a categoria',
                  style: TextStyle(
                    fontSize: 16,
                    color: _categoriaSelecionada != null ? Colors.grey[700] : Colors.purple[700],
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
            if (pessoa is Cliente) {
              setState(() {
                _clienteNomeController.text = pessoa.nome;
                _clienteCpfController.text = pessoa.cpf;
                _clienteTelefoneController.text = pessoa.telefone;
                _clienteEmailController.text = pessoa.email;
              });
            } else if (pessoa is Funcionario) {
              setState(() {
                _clienteNomeController.text = pessoa.nome;
                _clienteCpfController.text = pessoa.cpf;
                _clienteTelefoneController.text = pessoa.telefone;
                _clienteEmailController.text = pessoa.email;
              });
            }
          },
          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
            controller.text = _clienteCpfController.text;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              keyboardType: TextInputType.number,
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
                  borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
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
    final options = _veiculos.map((v) => (v as Veiculo).placa).whereType<String>().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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
            final v = _veiculoByPlaca[selection] as Veiculo?;
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
            }
          },
          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
            controller.text = _veiculoPlacaController.text;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              inputFormatters: [_maskPlaca, _upperCaseFormatter],
              onChanged: (value) {
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
                  borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
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
          hintText: 'Descreva em detalhes o problema relatado pelo cliente ou serviço solicitado...',
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
            borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildVisualInspection() {
    final items = [
      'Para-choque Dianteiro',
      'Para-choque Traseiro',
      'Capô',
      'Porta-malas',
      'Porta Diant. Esq.',
      'Porta Tras. Esq.',
      'Porta Diant. Dir.',
      'Porta Tras. Dir.',
      'Teto',
      'Para-brisa',
      'Retrovisores',
      'Pneus e Rodas',
      'Estepe'
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                    flex: 3,
                    child: Text(
                      'Item',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple.shade700),
                    )),
                Expanded(
                    flex: 2,
                    child: Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple.shade700),
                      textAlign: TextAlign.center,
                    )),
                Expanded(
                    flex: 3,
                    child: Text(
                      'Observações',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple.shade700),
                      textAlign: TextAlign.center,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => _buildInspectionRow(item)),
        ],
      ),
    );
  }

  Widget _buildInspectionRow(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _StatusSelector(
              currentStatus: _inspecaoVisualStatus[title] ?? '',
              onStatusChanged: (status) {
                setState(() {
                  _inspecaoVisualStatus[title] = status;
                });
              },
            ),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: _inspecaoVisualObs[title],
              decoration: InputDecoration(
                hintText: 'Observações...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestsAndItems() {
    final functionTestItems = [
      'Buzina',
      'Farol Baixo / Alto',
      'Setas / Pisca-alerta',
      'Luz de Freio',
      'Limpador de para-brisa',
      'Ar Condicionado',
      'Rádio / Multimídia'
    ];
    final vehicleItemsList = ['Manual / Livreto', 'CRLV', 'Chave Reserva', 'Macaco', 'Chave de Roda', 'Triângulo', 'Tapetes'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFormSection('4. Testes de Funcionamento', Icons.build_outlined),
                const SizedBox(height: 16),
                ...functionTestItems.map((item) => _buildCheckRow(item)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFormSection('5. Itens no Veículo', Icons.inventory_outlined),
                const SizedBox(height: 16),
                ...vehicleItemsList.map((item) => _buildCheckRow(item)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckRow(String title) {
    final isFunctionTest = _testesFuncionamento.containsKey(title);
    final currentValue = isFunctionTest ? _testesFuncionamento[title] : _itensVeiculo[title];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          _StatusSelector(
            label1: 'Sim',
            label2: 'Não',
            currentStatus: currentValue ?? '',
            onStatusChanged: (status) {
              setState(() {
                if (isFunctionTest) {
                  _testesFuncionamento[title] = status;
                } else {
                  _itensVeiculo[title] = status;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFuelLevel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vazio',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade600,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Text(
                  '${(_fuelLevel * 25).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                'Cheio',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.purple.shade400,
              inactiveTrackColor: Colors.grey[300],
              thumbColor: Colors.purple.shade600,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayColor: Colors.purple.withOpacity(0.2),
              trackHeight: 8,
            ),
            child: Slider(
              value: _fuelLevel,
              min: 0,
              max: 4,
              divisions: 4,
              onChanged: (value) {
                setState(() {
                  _fuelLevel = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSelector extends StatefulWidget {
  final String label1;
  final String label2;
  final String currentStatus;
  final Function(String) onStatusChanged;

  const _StatusSelector({
    this.label1 = 'OK',
    this.label2 = 'Avaria',
    this.currentStatus = '',
    required this.onStatusChanged,
  });

  @override
  _StatusSelectorState createState() => _StatusSelectorState();
}

class _StatusSelectorState extends State<_StatusSelector> {
  late List<bool> _selected;

  @override
  void initState() {
    super.initState();
    _updateSelectionFromStatus();
  }

  @override
  void didUpdateWidget(_StatusSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStatus != widget.currentStatus) {
      _updateSelectionFromStatus();
    }
  }

  void _updateSelectionFromStatus() {
    setState(() {
      if (widget.currentStatus == widget.label1) {
        _selected = [true, false];
      } else if (widget.currentStatus == widget.label2) {
        _selected = [false, true];
      } else {
        _selected = [false, false];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ToggleButtons(
      isSelected: _selected,
      onPressed: (index) {
        setState(() {
          _selected[index] = !_selected[index];
          if (_selected[index]) {
            _selected[1 - index] = false;
            widget.onStatusChanged(index == 0 ? widget.label1 : widget.label2);
          } else {
            widget.onStatusChanged('');
          }
        });
      },
      constraints: const BoxConstraints(minWidth: 50, minHeight: 32),
      borderRadius: BorderRadius.circular(8),
      selectedBorderColor: widget.label1 == 'OK' ? Colors.green.shade400 : Colors.purple.shade400,
      selectedColor: Colors.white,
      fillColor: widget.label1 == 'OK'
          ? (_selected[0]
              ? Colors.green.shade400
              : _selected[1]
                  ? Colors.red.shade400
                  : null)
          : (_selected[0]
              ? Colors.purple.shade400
              : _selected[1]
                  ? Colors.orange.shade400
                  : null),
      borderColor: Colors.grey[300],
      color: Colors.grey[600],
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            widget.label1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            widget.label2,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}
