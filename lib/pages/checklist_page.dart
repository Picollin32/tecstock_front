import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// note: rely on app's global theme defined in main.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Expose the ChecklistScreen as the page to be pushed from the app.
class Checklist extends StatelessWidget {
  const Checklist({super.key});

  @override
  Widget build(BuildContext context) => const ChecklistScreen();
}

// Tela principal que contém o formulário do checklist.
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  // Controladores para os campos de texto.
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  // Variável para o slider de combustível.
  double _fuelLevel = 2.0;

  @override
  void initState() {
    super.initState();
    // Preenche a data e hora atuais ao iniciar a tela.
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _timeController.text = DateFormat('HH:mm').format(DateTime.now());
  }

  @override
  void dispose() {
    // Libera os controladores quando a tela é descartada.
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  // Função para gerar e imprimir o PDF.
  Future<void> _printChecklist() async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Checklist de Recepção de Veículo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24)),
            pw.Divider(height: 20),
            pw.Text('Data: ${_dateController.text}  -  Hora: ${_timeController.text}'),
            pw.SizedBox(height: 20),
            // Adicionar mais dados do formulário aqui para o PDF
            // Esta é uma implementação básica. Para um PDF completo,
            // seria necessário capturar o estado de todos os campos.
            pw.Text('Nível de Combustível: ${(_fuelLevel * 25).toStringAsFixed(0)}%'),
            pw.SizedBox(height: 20),
            pw.Text('Este é um exemplo de como o PDF seria gerado com os dados.'),
          ]);
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildSectionTitle('1. Dados do Cliente e Veículo'),
                _buildClientVehicleInfo(),
                const SizedBox(height: 24),
                _buildSectionTitle('2. Queixa Principal / Serviço Solicitado'),
                _buildComplaintSection(),
                const SizedBox(height: 24),
                _buildSectionTitle('3. Inspeção Visual (Avarias)'),
                _buildVisualInspection(),
                const SizedBox(height: 24),
                _buildTestsAndItems(),
                const SizedBox(height: 24),
                _buildSectionTitle('6. Nível de Combustível'),
                _buildFuelLevel(),
                const SizedBox(height: 32),
                _buildSignatures(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Widgets de Construção da UI ---

  // Constrói o cabeçalho com título e botão de imprimir.
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Checklist de Recepção de Veículo', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Inspeção detalhada na entrada do veículo na oficina.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _printChecklist,
          icon: const Icon(Icons.print),
          label: const Text('Imprimir / Salvar PDF'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(180, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  // Constrói um título de seção padronizado.
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }

  // Constrói os campos de informação do cliente e veículo.
  Widget _buildClientVehicleInfo() {
    // Use a responsive Wrap inside a LayoutBuilder so items flow and
    // don't force a fixed vertical size (prevents RenderFlex overflow).
    final fields = [
      'Cliente',
      'Telefone/WhatsApp',
      'E-mail',
      'Marca/Modelo',
      'Cor',
      'Placa',
      'Ano/Modelo',
      'Quilometragem',
    ];

    return LayoutBuilder(builder: (context, constraints) {
      // determine number of columns based on available width (similar to former logic)
      final columns = constraints.maxWidth > 700 ? 3 : 2;
      final itemWidth = (constraints.maxWidth - (16 * (columns - 1))) / columns;

      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: fields.map((label) => SizedBox(width: itemWidth, child: _buildTextField(label))).toList(),
      );
    });
  }

  // Constrói o campo de texto para a queixa principal.
  Widget _buildComplaintSection() {
    return TextField(
      maxLines: 4,
      decoration: const InputDecoration(
        hintText: 'Descreva em detalhes o problema relatado pelo cliente...',
      ),
    );
  }

  // Constrói a tabela de inspeção visual.
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
    // Lista corrida: retorna uma Column simples com todas as linhas de inspeção
    return Column(
      children: items.map((item) => _buildInspectionRow(item)).toList(),
    );
  }

  // Constrói uma linha da tabela de inspeção visual.
  Widget _buildInspectionRow(String title) {
    return Padding(
      // reduce vertical padding to save space
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 3, child: Text(title, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(flex: 2, child: _StatusSelector()),
          Expanded(
            flex: 3,
            child: SizedBox(
              // slightly smaller height to avoid small overflows
              height: 32,
              child: _buildTextField('', isDense: true),
            ),
          ),
        ],
      ),
    );
  }

  // Constrói as seções de testes e itens lado a lado.
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('4. Testes de Funcionamento'),
              ...functionTestItems.map((item) => _buildCheckRow(item)),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('5. Itens no Veículo'),
              ...vehicleItemsList.map((item) => _buildCheckRow(item)),
            ],
          ),
        ),
      ],
    );
  }

  // Constrói uma linha com um item e opções 'Sim'/'Não'.
  Widget _buildCheckRow(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          _StatusSelector(label1: 'Sim', label2: 'Não'),
        ],
      ),
    );
  }

  // Constrói o slider de nível de combustível.
  Widget _buildFuelLevel() {
    return Row(
      children: [
        Text('Vazio', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        Expanded(
          child: Slider(
            value: _fuelLevel,
            min: 0,
            max: 4,
            divisions: 4,
            label: '${(_fuelLevel * 25).toStringAsFixed(0)}%',
            onChanged: (value) {
              setState(() {
                _fuelLevel = value;
              });
            },
          ),
        ),
        Text('Cheio', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // Constrói a área de assinaturas.
  Widget _buildSignatures() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildSignatureLine('Assinatura do Cliente'),
        _buildSignatureLine('Assinatura do Recepcionista'),
      ],
    );
  }

  Widget _buildSignatureLine(String label) {
    return Column(
      children: [
        SizedBox(width: 250, child: Divider(color: Colors.grey[700])),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  // Helper para criar um campo de texto com um rótulo.
  Widget _buildTextField(String label, {bool isDense = false}) {
    // If label is empty (used in compact inspection rows), return a compact TextField only
    if (label.isEmpty) {
      return SizedBox(
        height: isDense ? 30 : 40,
        child: TextField(
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black54)),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: SizedBox(
            height: isDense ? 34 : 40,
            child: TextField(
              decoration: InputDecoration(
                isDense: isDense,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: isDense ? 8 : 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Widget customizado para seleção de status (OK/Avaria ou Sim/Não).
class _StatusSelector extends StatefulWidget {
  final String label1;
  final String label2;

  const _StatusSelector({this.label1 = 'OK', this.label2 = 'Avaria'});

  @override
  _StatusSelectorState createState() => _StatusSelectorState();
}

class _StatusSelectorState extends State<_StatusSelector> {
  // track selection index: 0 = first, 1 = second, null => none (both false)
  final List<bool> _selected = [false, false];

  @override
  Widget build(BuildContext context) {
    return ToggleButtons(
      isSelected: _selected,
      onPressed: (index) {
        setState(() {
          // allow toggle off as well (so no selection is possible)
          _selected[index] = !_selected[index];
          if (_selected[index]) {
            _selected[1 - index] = false;
          }
        });
      },
      constraints: const BoxConstraints(minWidth: 40, minHeight: 28),
      borderRadius: BorderRadius.circular(6),
      children: [
        Text(widget.label1, style: Theme.of(context).textTheme.labelSmall),
        Text(widget.label2, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
