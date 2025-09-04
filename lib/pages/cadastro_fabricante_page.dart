import 'package:flutter/material.dart';
import '../model/fabricante.dart';
import '../services/fabricante_service.dart';

class CadastroFabricantePage extends StatefulWidget {
  const CadastroFabricantePage({super.key});

  @override
  State<CadastroFabricantePage> createState() => _CadastroFabricantePageState();
}

class _CadastroFabricantePageState extends State<CadastroFabricantePage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _searchController = TextEditingController();

  List<Fabricante> _fabricantes = [];
  List<Fabricante> _fabricantesFiltrados = [];
  bool _showForm = false;
  Fabricante? _fabricanteEmEdicao;

  @override
  void initState() {
    super.initState();
    _carregarFabricantes();
    _searchController.addListener(_filtrarFabricantes);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filtrarFabricantes);
    _searchController.dispose();
    _nomeController.dispose();
    super.dispose();
  }

  void _filtrarFabricantes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _fabricantesFiltrados = _fabricantes.take(5).toList();
      } else {
        _fabricantesFiltrados = _fabricantes.where((fabricante) {
          return fabricante.nome.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _carregarFabricantes() async {
    final lista = await FabricanteService.listarFabricantes();
    setState(() {
      _fabricantes = lista.reversed.toList();
      _filtrarFabricantes();
    });
  }

  void _salvarFabricante() async {
    if (_formKey.currentState!.validate()) {
      final fabricante = Fabricante(nome: _nomeController.text);

      final sucesso = _fabricanteEmEdicao != null
          ? await FabricanteService.atualizarFabricante(_fabricanteEmEdicao!.id!, fabricante)
          : await FabricanteService.salvarFabricante(fabricante);

      if (sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_fabricanteEmEdicao != null ? "Fabricante atualizado com sucesso" : "Fabricante cadastrado com sucesso")),
        );
        _limparFormulario();
        await _carregarFabricantes();
        setState(() => _showForm = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao cadastrar fabricante")),
        );
      }
    }
  }

  void _editarFabricante(Fabricante fabricante) {
    setState(() {
      _nomeController.text = fabricante.nome;
      _showForm = true;
      _fabricanteEmEdicao = fabricante;
    });
  }

  void _confirmarExclusao(Fabricante fabricante) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja excluir o fabricante ${fabricante.nome}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final sucesso = await FabricanteService.excluirFabricante(fabricante.id!);
              if (sucesso) {
                await _carregarFabricantes();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fabricante excluído com sucesso')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erro ao excluir fabricante')),
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
    _nomeController.clear();
    _fabricanteEmEdicao = null;
  }

  Widget _buildListaFabricantes() {
    if (_fabricantesFiltrados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _searchController.text.isEmpty ? 'Nenhum fabricante cadastrado.' : 'Nenhum fabricante encontrado.',
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
            _searchController.text.isEmpty ? 'Últimos Fabricantes Cadastrados' : 'Resultados da Busca',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _fabricantesFiltrados.length,
          itemBuilder: (context, index) {
            final fabricante = _fabricantesFiltrados[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                title: Text(fabricante.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => _editarFabricante(fabricante),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmarExclusao(fabricante),
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

  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextFormField(
              controller: _nomeController,
              decoration: const InputDecoration(
                  labelText: 'Nome do Fabricante', contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
              validator: (v) => v!.isEmpty ? 'Informe o nome' : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onEditingComplete: () {
                Form.of(context).validate();
                FocusScope.of(context).nextFocus();
              },
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _salvarFabricante,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
                icon: Icon(_showForm ? Icons.close : Icons.add),
                label: Text(_showForm ? 'Cancelar Cadastro' : 'Novo Fabricante'),
                onPressed: () {
                  _limparFormulario();
                  setState(() => _showForm = !_showForm);
                }),
            const SizedBox(height: 10),
            if (_showForm) _buildFormulario(),
            if (!_showForm)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Pesquisar por Nome',
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
            _buildListaFabricantes(),
          ],
        ),
      ),
    );
  }
}
