import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/cliente_service.dart';
import '../services/veiculo_service.dart';
import '../model/cliente.dart';
import '../model/veiculo.dart';
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

class _ChecklistScreenState extends State<ChecklistScreen> {
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
  final _veiculoQuilometragemController = TextEditingController();

  double _fuelLevel = 2.0;

  List<dynamic> _clientes = [];
  List<dynamic> _veiculos = [];
  final TextEditingController _searchController = TextEditingController();
  List<Checklist> _recentFiltrados = [];

  final Map<String, dynamic> _clienteByCpf = {};
  final Map<String, dynamic> _veiculoByPlaca = {};

  bool _showForm = false;
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
    _fuelLevel = 2.0;
    _checklistNumberController.clear();
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

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
    _timeController.text = DateFormat('HH:mm').format(DateTime.now());
    _loadClientesVeiculos();
    _loadRecentChecklists();
    _searchController.addListener(_filtrarRecentes);
  }

  @override
  void dispose() {
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
    _checklistNumberController.dispose();
    _searchController.removeListener(_filtrarRecentes);
    _searchController.dispose();
    super.dispose();
  }

  void _filtrarRecentes() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _recentFiltrados = _recent;
      } else {
        _recentFiltrados = _recent.where((c) => c.numeroChecklist.toLowerCase().contains(q)).toList();
      }
    });
  }

  Future<void> _loadClientesVeiculos() async {
    try {
      final clientes = await ClienteService.listarClientes();
      final veiculos = await VeiculoService.listarVeiculos();
      setState(() {
        _clientes = clientes;
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
                icon: Icon(_showForm ? Icons.close : Icons.add),
                label: Text(_showForm ? 'Cancelar Cadastro' : 'Novo Checklist'),
                onPressed: () {
                  if (_showForm) {
                    _clearFormFields();
                  } else {
                    _clearFormFields();
                  }
                  setState(() => _showForm = !_showForm);
                }),
            const SizedBox(height: 10),
            if (_showForm) _buildFullForm(),
            if (!_showForm)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Pesquisar por número do checklist',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            if (!_showForm) const SizedBox(height: 10),
            if (!_showForm) _buildRecentList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentList() {
    if (_recentFiltrados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _searchController.text.isEmpty ? 'Nenhum checklist recente.' : 'Nenhum checklist encontrado para o filtro informado.',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            _searchController.text.isEmpty ? 'Últimos Checklists' : 'Resultados da Busca',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentFiltrados.length,
          itemBuilder: (context, index) {
            final c = _recentFiltrados[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                title: Text(c.numeroChecklist, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.id != null) Text('ID: ${c.id}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () {
                        setState(() {
                          _editingChecklistId = c.id;
                          _checklistNumberController.text = c.numeroChecklist;
                          _showForm = true;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        if (c.id != null) {
                          final ok = await ChecklistService.excluirChecklist(c.id!);
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checklist excluído com sucesso')));
                            _loadRecentChecklists();
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFullForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _showForm = false;
                      _editingChecklistId = null;
                      _checklistNumberController.clear();
                      _clearFormFields();
                    });
                  },
                ),
                const SizedBox(width: 8),
                Text('Checklist de Recepção de Veículo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('1. Dados do Cliente e Veículo'),
        if (_editingChecklistId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
                'Checklist número: ${_checklistNumberController.text.isNotEmpty ? _checklistNumberController.text : _editingChecklistId}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blue)),
          ),
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
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87),
      ),
    );
  }

  Widget _buildClientVehicleInfo() {
    return LayoutBuilder(builder: (context, constraints) {
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
        ],
      );
    });
  }

  Widget _buildLabeledController(String label, TextEditingController controller, {bool isDense = false}) {
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
              controller: controller,
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

  Widget _buildCpfAutocomplete({required double fieldWidth}) {
    final options = _clientes.map((c) => (c as Cliente).cpf).whereType<String>().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CPF', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black54)),
        const SizedBox(height: 4),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text == '') return const Iterable<String>.empty();
            return options.where((cpf) => cpf.toLowerCase().contains(textEditingValue.text.toLowerCase()));
          },
          onSelected: (String selection) {
            final c = _clienteByCpf[selection] as Cliente?;
            if (c != null) {
              setState(() {
                _clienteNomeController.text = c.nome;
                _clienteCpfController.text = c.cpf;
                _clienteTelefoneController.text = c.telefone;
                _clienteEmailController.text = c.email;
              });
            }
          },
          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
            controller.text = _clienteCpfController.text;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlacaAutocomplete({required double fieldWidth}) {
    final options = _veiculos.map((v) => (v as Veiculo).placa).whereType<String>().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Placa', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black54)),
        const SizedBox(height: 4),
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
              });
            }
          },
          fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
            controller.text = _veiculoPlacaController.text;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
            );
          },
        ),
      ],
    );
  }

  Widget _buildComplaintSection() {
    return TextField(
      maxLines: 4,
      decoration: const InputDecoration(
        hintText: 'Descreva em detalhes o problema relatado pelo cliente...',
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
    return Column(
      children: items.map((item) => _buildInspectionRow(item)).toList(),
    );
  }

  Widget _buildInspectionRow(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 3, child: Text(title, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(flex: 2, child: _StatusSelector()),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 32,
              child: _buildTextField('', isDense: true),
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

  Widget _buildTextField(String label, {bool isDense = false}) {
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

class _StatusSelector extends StatefulWidget {
  final String label1;
  final String label2;

  const _StatusSelector({this.label1 = 'OK', this.label2 = 'Avaria'});

  @override
  _StatusSelectorState createState() => _StatusSelectorState();
}

class _StatusSelectorState extends State<_StatusSelector> {
  final List<bool> _selected = [false, false];

  @override
  Widget build(BuildContext context) {
    return ToggleButtons(
      isSelected: _selected,
      onPressed: (index) {
        setState(() {
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
