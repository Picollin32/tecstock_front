import 'package:TecStock/model/marca.dart';
import 'package:TecStock/model/veiculo.dart';
import 'package:TecStock/services/marca_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../services/veiculo_service.dart';

class CadastroVeiculoPage extends StatefulWidget {
  const CadastroVeiculoPage({super.key});

  @override
  State<CadastroVeiculoPage> createState() => _CadastroVeiculoPageState();
}

class _CadastroVeiculoPageState extends State<CadastroVeiculoPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nome = TextEditingController();
  final TextEditingController _placa = TextEditingController();
  final TextEditingController _ano = TextEditingController();
  final TextEditingController _modelo = TextEditingController();
  int? _marcaSelecionadaId;
  List<Marca> _marcas = [];
  final TextEditingController _cor = TextEditingController();
  final TextEditingController _quilometragem = TextEditingController();

  final List<String> _categorias = ['Passeio', 'Caminhonete'];
  String? _categoriaSelecionada;

  final _maskPlaca = MaskTextInputFormatter(
      mask: 'AAA-#X##',
      filter: {"#": RegExp(r'[0-9]'), "A": RegExp(r'[a-zA-Z]'), "X": RegExp(r'[a-zA-Z0-9]')},
      type: MaskAutoCompletionType.lazy);

  final _upperCaseFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  });

  final TextEditingController _searchController = TextEditingController();
  List<Veiculo> _veiculos = [];
  List<Veiculo> _veiculosFiltrados = [];
  bool _showForm = false;
  Veiculo? _veiculoEmEdicao;

  @override
  void initState() {
    super.initState();
    _limparFormulario();
    _carregarMarcas();
    _carregarVeiculos();
    _searchController.addListener(_filtrarVeiculos);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filtrarVeiculos);
    _searchController.dispose();
    _nome.dispose();
    _placa.dispose();
    _ano.dispose();
    _modelo.dispose();
    _cor.dispose();
    _quilometragem.dispose();
    super.dispose();
  }

  void _filtrarVeiculos() {
    final unmaskedQuery = _maskPlaca.unmaskText(_searchController.text).toUpperCase();

    setState(() {
      if (unmaskedQuery.isEmpty) {
        _veiculosFiltrados = _veiculos.take(3).toList();
      } else {
        _veiculosFiltrados = _veiculos.where((veiculo) {
          final placaSemMascara = veiculo.placa.replaceAll('-', '');

          return placaSemMascara.toUpperCase().contains(unmaskedQuery);
        }).toList();
      }
    });
  }

  Future<void> _carregarVeiculos() async {
    final lista = await VeiculoService.listarVeiculos();
    setState(() {
      _veiculos = lista.reversed.toList();
      _filtrarVeiculos();
    });
  }

  Future<void> _carregarMarcas() async {
    final lista = await MarcaService.listarMarcas();
    setState(() {
      _marcas = lista;
    });
  }

  void _salvarVeiculo() async {
    if (_formKey.currentState!.validate()) {
      Marca? marcaSelecionada;
      if (_marcaSelecionadaId != null) {
        marcaSelecionada = _marcas.firstWhere(
          (marca) => marca.id == _marcaSelecionadaId,
          orElse: () => _marcas.first,
        );
      }
      final kmString = _quilometragem.text.replaceAll(',', '.');

      final veiculo = Veiculo(
        id: _veiculoEmEdicao?.id,
        nome: _nome.text,
        placa: _placa.text.toUpperCase(),
        ano: int.tryParse(_ano.text) ?? 0,
        modelo: _modelo.text,
        marca: marcaSelecionada,
        cor: _cor.text,
        quilometragem: double.tryParse(kmString) ?? 0.0,
        categoria: _categoriaSelecionada!,
      );

      final sucesso = _veiculoEmEdicao != null
          ? await VeiculoService.atualizarVeiculo(veiculo.id!, veiculo)
          : await VeiculoService.salvarVeiculo(veiculo);

      if (sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_veiculoEmEdicao != null ? "Veículo atualizado com sucesso" : "Veículo cadastrado com sucesso")),
        );
        _limparFormulario();
        await _carregarVeiculos();
        setState(() => _showForm = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao cadastrar veículo")),
        );
      }
    }
  }

  void _editarVeiculo(Veiculo veiculo) {
    setState(() {
      _nome.text = veiculo.nome;
      _placa.text = veiculo.placa;
      _ano.text = veiculo.ano.toString();
      _modelo.text = veiculo.modelo;
      _marcaSelecionadaId = veiculo.marca?.id;
      _cor.text = veiculo.cor;
      _quilometragem.text = veiculo.quilometragem.toString().replaceAll('.', ',');
      _categoriaSelecionada = veiculo.categoria;
      _showForm = true;
      _veiculoEmEdicao = veiculo;
    });
  }

  void _confirmarExclusao(Veiculo veiculo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja excluir o veículo ${veiculo.nome}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final sucesso = await VeiculoService.excluirVeiculo(veiculo.id!);
              if (sucesso) {
                await _carregarVeiculos();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veículo excluído com sucesso')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erro ao excluir veículo')),
                );
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    _nome.clear();
    _placa.clear();
    _ano.clear();
    _modelo.clear();
    _marcaSelecionadaId = null;
    _cor.clear();
    _quilometragem.clear();
    _categoriaSelecionada = 'Passeio';
    _veiculoEmEdicao = null;
  }

  Widget _buildListaVeiculos() {
    if (_veiculosFiltrados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(_searchController.text.isEmpty
              ? 'Nenhum veículo cadastrado.'
              : 'Nenhum veículo encontrado para "${_searchController.text}".'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            _searchController.text.isEmpty ? 'Últimos Veículos Cadastrados' : 'Resultados da Busca',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ..._veiculosFiltrados.map((veiculo) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              isThreeLine: true,
              title: Text(veiculo.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Placa: ${veiculo.placa}'),
                  Text('Modelo: ${veiculo.modelo} - ${veiculo.ano}'),
                  Text('Marca: ${veiculo.marca?.marca ?? "Não informada"}'),
                  Text('Categoria: ${veiculo.categoria}'),
                  Text('Cor: ${veiculo.cor}'),
                  Text('Quilometragem: ${veiculo.quilometragem.toStringAsFixed(0)} km'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.orange),
                    onPressed: () => _editarVeiculo(veiculo),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmarExclusao(veiculo),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nome,
            decoration: const InputDecoration(labelText: 'Nome'),
            validator: (v) => v!.isEmpty ? 'Informe o nome' : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onEditingComplete: () => FocusScope.of(context).nextFocus(),
          ),
          TextFormField(
            controller: _placa,
            decoration: const InputDecoration(labelText: 'Placa'),
            inputFormatters: [_maskPlaca, _upperCaseFormatter],
            textCapitalization: TextCapitalization.characters,
            validator: (v) => v!.isEmpty ? 'Informe a placa' : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onEditingComplete: () => FocusScope.of(context).nextFocus(),
          ),
          TextFormField(
            controller: _ano,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Ano'),
            validator: (v) => v!.isEmpty ? 'Informe o ano' : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onEditingComplete: () => FocusScope.of(context).nextFocus(),
          ),
          TextFormField(
            controller: _modelo,
            decoration: const InputDecoration(labelText: 'Modelo'),
            validator: (v) => v!.isEmpty ? 'Informe o modelo' : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onEditingComplete: () => FocusScope.of(context).nextFocus(),
          ),
          DropdownButtonFormField<int>(
            value: _marcaSelecionadaId,
            onChanged: (int? newValue) {
              setState(() {
                _marcaSelecionadaId = newValue;
              });
            },
            decoration: const InputDecoration(labelText: 'Marca'),
            items: _marcas.map((marca) {
              return DropdownMenuItem<int>(
                value: marca.id,
                child: Text(marca.marca),
              );
            }).toList(),
          ),
          DropdownButtonFormField<String>(
            value: _categoriaSelecionada,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: _categorias.map((String categoria) {
              return DropdownMenuItem<String>(
                value: categoria,
                child: Text(categoria),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _categoriaSelecionada = newValue;
              });
            },
            validator: (value) => value == null ? 'Selecione uma categoria' : null,
          ),
          TextFormField(
            controller: _cor,
            decoration: const InputDecoration(labelText: 'Cor'),
            validator: (v) => v!.isEmpty ? 'Informe a cor' : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onEditingComplete: () => FocusScope.of(context).nextFocus(),
          ),
          TextFormField(
            controller: _quilometragem,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Quilometragem'),
            validator: (v) => v!.isEmpty ? 'Informe a quilometragem' : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onEditingComplete: () => FocusScope.of(context).nextFocus(),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _salvarVeiculo,
            child: const Text('Salvar'),
          ),
          const Divider(thickness: 2, height: 40),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de Veículos')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: Icon(_showForm ? Icons.close : Icons.add),
              label: Text(_showForm ? 'Cancelar Cadastro' : 'Novo Veículo'),
              onPressed: () => setState(() {
                _limparFormulario();
                _showForm = !_showForm;
              }),
            ),
            const SizedBox(height: 10),
            if (_showForm) _buildFormulario(),
            if (!_showForm)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: TextField(
                  controller: _searchController,
                  inputFormatters: [_maskPlaca, _upperCaseFormatter],
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Pesquisar por Placa',
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
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
            _buildListaVeiculos(),
          ],
        ),
      ),
    );
  }
}
