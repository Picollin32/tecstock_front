import 'package:flutter/material.dart';
import '../model/fabricante.dart';
import '../model/fornecedor.dart';
import '../model/peca.dart';
import '../services/fabricante_service.dart';
import '../services/fornecedor_service.dart';
import '../services/peca_service.dart';

class CadastroPecaPage extends StatefulWidget {
  const CadastroPecaPage({super.key});

  @override
  State<CadastroPecaPage> createState() => _CadastroPecaPageState();
}

class _CadastroPecaPageState extends State<CadastroPecaPage> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _codigoFabricanteController = TextEditingController();
  final _precoUnitarioController = TextEditingController();
  final _quantidadeEstoqueController = TextEditingController();
  final _precoFinalController = TextEditingController();
  final _searchController = TextEditingController();

  Fornecedor? _fornecedorSelecionado;
  List<Fornecedor> _fornecedores = [];

  Fabricante? _fabricanteSelecionado;
  List<Fabricante> _fabricantes = [];

  late Future<List<Peca>> _pecasFuture;
  List<Peca> _pecas = [];
  List<Peca> _pecasFiltradas = [];

  bool _showForm = false;
  Peca? _pecaEmEdicao;

  @override
  void initState() {
    super.initState();
    _pecasFuture = _carregarPecas();
    _carregarFornecedoresEFabricantes();
    _searchController.addListener(_filtrarPecas);
    _precoUnitarioController.addListener(_calcularPrecoFinal);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filtrarPecas);
    _precoUnitarioController.removeListener(_calcularPrecoFinal);
    _nomeController.dispose();
    _codigoFabricanteController.dispose();
    _precoUnitarioController.dispose();
    _quantidadeEstoqueController.dispose();
    _precoFinalController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Peca>> _carregarPecas() async {
    final listaPecas = await PecaService.listarPecas();
    _pecas = listaPecas.reversed.toList();
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      _pecasFiltradas = _pecas.take(3).toList();
    } else {
      _pecasFiltradas = _pecas.where((peca) {
        return peca.codigoFabricante.toLowerCase().contains(query);
      }).toList();
    }

    return _pecas;
  }

  Future<void> _carregarFornecedoresEFabricantes() async {
    final listaFornecedores = await FornecedorService.listarFornecedores();
    final listaFabricantes = await FabricanteService.listarFabricantes();
    listaFabricantes.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

    setState(() {
      _fornecedores = listaFornecedores;
      _fabricantes = listaFabricantes;
    });
  }

  void _filtrarPecas() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _pecasFiltradas = _pecas.take(3).toList();
      } else {
        _pecasFiltradas = _pecas.where((peca) {
          return peca.codigoFabricante.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _calcularPrecoFinal() {
    final precoUnitario = double.tryParse(_precoUnitarioController.text.replaceAll(',', '.')) ?? 0.0;
    final margemLucro = _fornecedorSelecionado?.margemLucro ?? 0.0;
    final precoFinal = double.parse((precoUnitario * (1 + margemLucro)).toStringAsFixed(2));
    _precoFinalController.text = "R\$ ${precoFinal.toStringAsFixed(2).replaceAll('.', ',')}";
  }

  void _salvar() async {
    if (_formKey.currentState!.validate()) {
      double preco = double.parse(_precoUnitarioController.text.replaceAll(',', '.'));

      final peca = Peca(
        id: _pecaEmEdicao?.id,
        nome: _nomeController.text,
        fabricante: _fabricanteSelecionado!,
        fornecedor: _fornecedorSelecionado,
        codigoFabricante: _codigoFabricanteController.text,
        precoUnitario: preco,
        quantidadeEstoque: int.parse(_quantidadeEstoqueController.text),
      );

      bool sucesso;
      if (_pecaEmEdicao != null) {
        sucesso = await PecaService.atualizarPeca(_pecaEmEdicao!.id!, peca);
      } else {
        sucesso = await PecaService.salvarPeca(peca);
      }
      _handleSaveResponse(sucesso, isEditing: _pecaEmEdicao != null);
    }
  }

  void _handleSaveResponse(bool sucesso, {required bool isEditing}) {
    if (sucesso) {
      String message = isEditing ? "Peça atualizada com sucesso" : "Peça cadastrada com sucesso";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

      setState(() {
        _pecasFuture = _carregarPecas();
        _showForm = false;
        _limparFormulario();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao salvar dados")));
    }
  }

  void _editarPeca(Peca peca) {
    setState(() {
      _nomeController.text = peca.nome;
      _codigoFabricanteController.text = peca.codigoFabricante;
      _precoUnitarioController.text = peca.precoUnitario.toStringAsFixed(2).replaceAll('.', ',');
      _quantidadeEstoqueController.text = peca.quantidadeEstoque.toString();
      _fabricanteSelecionado = _fabricantes.firstWhere((f) => f.id == peca.fabricante.id, orElse: () => _fabricantes.first);
      _fornecedorSelecionado = peca.fornecedor != null ? _fornecedores.firstWhere((fo) => fo.id == peca.fornecedor!.id) : null;

      _showForm = true;
      _pecaEmEdicao = peca;
      _calcularPrecoFinal();
    });
  }

  void _confirmarExclusao(Peca peca) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja excluir a peça ${peca.nome}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final sucesso = await PecaService.excluirPeca(peca.id!);
              if (sucesso) {
                setState(() {
                  _pecasFuture = _carregarPecas();
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Peça excluída com sucesso')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao excluir peça')));
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
    _nomeController.clear();
    _codigoFabricanteController.clear();
    _precoUnitarioController.clear();
    _quantidadeEstoqueController.clear();
    _precoFinalController.clear();
    _fornecedorSelecionado = null;
    _fabricanteSelecionado = null;
    _pecaEmEdicao = null;
  }

  Widget _buildListaPecas() {
    return FutureBuilder<List<Peca>>(
      future: _pecasFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Erro ao carregar peças: ${snapshot.error}"));
        } else if (_pecasFiltradas.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(_searchController.text.isEmpty
                  ? 'Nenhuma peça cadastrada.'
                  : 'Nenhuma peça encontrada para "${_searchController.text}".'),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                _searchController.text.isEmpty ? 'Últimas Peças Cadastradas' : 'Resultados da Busca',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ..._pecasFiltradas.map((peca) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(peca.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      "Cód. Fabricante: ${peca.codigoFabricante}\nFornecedor: ${peca.fornecedor?.nome ?? 'Não informado'}\nPreço Final: R\$ ${(peca.precoUnitario * (1 + (peca.fornecedor?.margemLucro ?? 0.0))).toStringAsFixed(2)}"),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _editarPeca(peca)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmarExclusao(peca)),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextFormField(
              controller: _nomeController,
              decoration:
                  const InputDecoration(labelText: 'Nome da Peça', contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
              validator: (v) => v!.isEmpty ? 'Informe o nome' : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onEditingComplete: () {
                Form.of(context).validate();
                FocusScope.of(context).nextFocus();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: DropdownButtonFormField<Fabricante>(
              value: _fabricanteSelecionado,
              decoration:
                  const InputDecoration(labelText: 'Fabricante', contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
              items: _fabricantes.map((fabricante) {
                return DropdownMenuItem<Fabricante>(value: fabricante, child: Text(fabricante.nome));
              }).toList(),
              onChanged: (Fabricante? newValue) {
                setState(() => _fabricanteSelecionado = newValue);
                Form.of(context).validate();
                FocusScope.of(context).nextFocus();
              },
              validator: (v) => v == null ? 'Selecione um fabricante' : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextFormField(
              controller: _codigoFabricanteController,
              decoration: const InputDecoration(
                  labelText: 'Código do Fabricante', contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onEditingComplete: () {
                Form.of(context).validate();
                FocusScope.of(context).nextFocus();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextFormField(
              controller: _precoUnitarioController,
              decoration: const InputDecoration(
                  labelText: 'Preço Unitário (Custo)', contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Informe o preço';
                }
                if (!RegExp(r'^\d*[,.]?\d*$').hasMatch(value)) {
                  return 'Digite apenas números e vírgula';
                }
                return null;
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onChanged: (value) {
                String newValue = value.replaceAll(RegExp(r'[^\d,]'), '');
                if (newValue.indexOf(',') != newValue.lastIndexOf(',')) {
                  newValue = newValue.replaceFirst(RegExp(',.*'), ',');
                }
                if (newValue != value) {
                  _precoUnitarioController.value = TextEditingValue(
                    text: newValue,
                    selection: TextSelection.collapsed(offset: newValue.length),
                  );
                }
                _calcularPrecoFinal();
              },
              onEditingComplete: () {
                Form.of(context).validate();
                FocusScope.of(context).nextFocus();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextFormField(
              controller: _quantidadeEstoqueController,
              decoration: const InputDecoration(
                  labelText: 'Quantidade em Estoque', contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Informe o estoque' : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onEditingComplete: () {
                Form.of(context).validate();
                FocusScope.of(context).nextFocus();
              },
            ),
          ),
          const Divider(thickness: 2, height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: DropdownButtonFormField<Fornecedor>(
              value: _fornecedorSelecionado,
              decoration:
                  const InputDecoration(labelText: 'Fornecedor', contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
              items: _fornecedores.map((fornecedor) {
                return DropdownMenuItem<Fornecedor>(
                    value: fornecedor, child: Text("${fornecedor.nome} (+${(fornecedor.margemLucro! * 100).toStringAsFixed(0)}%)"));
              }).toList(),
              onChanged: (Fornecedor? newValue) {
                setState(() {
                  _fornecedorSelecionado = newValue;
                  _calcularPrecoFinal();
                });
                Form.of(context).validate();
                FocusScope.of(context).nextFocus();
              },
              validator: (v) => v == null ? 'Selecione um fornecedor' : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextFormField(
              controller: _precoFinalController,
              decoration: const InputDecoration(
                  labelText: 'Preço Final (Venda)', contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
              enabled: false,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _salvar, child: Text(_pecaEmEdicao != null ? 'Atualizar Peça' : 'Salvar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de Peças')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: Icon(_showForm ? Icons.close : Icons.add),
              label: Text(_showForm ? 'Cancelar Cadastro' : 'Nova Peça'),
              onPressed: () => setState(() {
                _showForm = !_showForm;
                _limparFormulario();
              }),
            ),
            const SizedBox(height: 10),
            if (_showForm) _buildFormulario(),
            if (!_showForm) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Pesquisar por Código do Fabricante',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                        : null,
                  ),
                ),
              ),
              _buildListaPecas(),
            ],
          ],
        ),
      ),
    );
  }
}
