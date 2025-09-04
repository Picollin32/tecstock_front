import 'package:TecStock/model/marca.dart';
import 'package:flutter/material.dart';
import '../services/marca_service.dart';

class CadastroMarcaPage extends StatefulWidget {
  const CadastroMarcaPage({super.key});

  @override
  State<CadastroMarcaPage> createState() => _MarcaPageState();
}

class _MarcaPageState extends State<CadastroMarcaPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _marcaController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Marca> _categorias = [];
  List<Marca> _categoriasFiltradas = [];
  bool _showForm = false;
  Marca? _categoriaEmEdicao;

  @override
  void initState() {
    super.initState();
    _limparFormulario();
    _carregarMarcas();
    _searchController.addListener(_filtrarMarcas);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filtrarMarcas);
    _searchController.dispose();
    _marcaController.dispose();
    super.dispose();
  }

  void _filtrarMarcas() {
    setState(() {
      if (_searchController.text.isEmpty) {
        _categoriasFiltradas = _categorias;
      } else {
        _categoriasFiltradas =
            _categorias.where((marca) => marca.marca.toLowerCase().contains(_searchController.text.toLowerCase())).toList();
      }
    });
  }

  void _salvarMarca() async {
    if (_formKey.currentState!.validate()) {
      final marca = Marca(
        marca: _marcaController.text,
      );

      final sucesso = _categoriaEmEdicao != null
          ? await MarcaService.atualizarMarca(_categoriaEmEdicao!.id!, marca)
          : await MarcaService.salvarMarca(marca);

      if (sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_categoriaEmEdicao != null ? "Marca atualizada com sucesso" : "Marca cadastrada com sucesso")),
        );
        _limparFormulario();
        _carregarMarcas();
        setState(() => _showForm = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao cadastrar marca")),
        );
      }
    }
  }

  void _editarMarca(Marca marca) {
    setState(() {
      _marcaController.text = marca.marca;
      _showForm = true;
      _categoriaEmEdicao = marca;
    });
  }

  void _confirmarExclusao(Marca marca) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja excluir a marca ${marca.marca}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final sucesso = await MarcaService.excluirMarca(marca.id!);
              if (sucesso) {
                _carregarMarcas();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Marca excluída com sucesso')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erro ao excluir marca')),
                );
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _carregarMarcas() async {
    final lista = await MarcaService.listarMarcas();
    setState(() {
      _categorias = lista;
      _categoriasFiltradas = lista;
    });
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    _marcaController.clear();
    _categoriaEmEdicao = null;
  }

  Widget _buildListaMarcas() {
    if (_categoriasFiltradas.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
              _searchController.text.isEmpty ? 'Nenhuma marca cadastrada.' : 'Nenhuma marca encontrada para "${_searchController.text}".'),
        ),
      );
    }

    return Column(
      children: _categoriasFiltradas.map((marca) {
        return Card(
          child: ListTile(
            title: Text(marca.marca),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: () => _editarMarca(marca),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmarExclusao(marca),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _marcaController,
            decoration: const InputDecoration(labelText: 'Marca'),
            validator: (v) => v!.isEmpty ? 'Informe a marca' : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onEditingComplete: () {
              Form.of(context).validate();
              FocusScope.of(context).nextFocus();
            },
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _salvarMarca,
            child: const Text('Salvar'),
          ),
          const Divider(thickness: 2),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de Marcas')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: Icon(_showForm ? Icons.close : Icons.add),
              label: Text(_showForm ? 'Cancelar Cadastro' : 'Nova Marca'),
              onPressed: () => setState(() => _showForm = !_showForm),
            ),
            const SizedBox(height: 10),
            if (_showForm) _buildFormulario(),
            if (!_showForm)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Pesquisar marca',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                        : null,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            _buildListaMarcas(),
          ],
        ),
      ),
    );
  }
}
