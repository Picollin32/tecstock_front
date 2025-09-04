import 'package:flutter/material.dart';
import '../model/servico.dart';
import '../services/servico_service.dart';

class CadastroServicoPage extends StatefulWidget {
  const CadastroServicoPage({super.key});

  @override
  State<CadastroServicoPage> createState() => _CadastroServicoPageState();
}

class _CadastroServicoPageState extends State<CadastroServicoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _precoPasseioController = TextEditingController();
  final _precoCaminhoneteController = TextEditingController();
  final _searchController = TextEditingController();

  late Future<List<Servico>> _servicosFuture;
  List<Servico> _servicos = [];
  List<Servico> _servicosFiltrados = [];

  bool _showForm = false;
  Servico? _servicoEmEdicao;

  @override
  void initState() {
    super.initState();
    _servicosFuture = _carregarServicos();
    _searchController.addListener(_filtrarServicos);
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _precoPasseioController.dispose();
    _precoCaminhoneteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Servico>> _carregarServicos() async {
    final lista = await ServicoService.listarServicos();
    _servicos = lista.reversed.toList();
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      _servicosFiltrados = _servicos.take(3).toList();
    } else {
      _servicosFiltrados = _servicos.where((s) => s.nome.toLowerCase().contains(query)).toList();
    }
    return _servicos;
  }

  void _filtrarServicos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _servicosFiltrados = _servicos.take(3).toList();
      } else {
        _servicosFiltrados = _servicos.where((s) => s.nome.toLowerCase().contains(query)).toList();
      }
    });
  }

  void _salvar() async {
    if (_formKey.currentState!.validate()) {
      final nome = _nomeController.text;
      final precoPasseio = double.tryParse(_precoPasseioController.text.replaceAll(',', '.')) ?? 0.0;
      final precoCaminhonete = double.tryParse(_precoCaminhoneteController.text.replaceAll(',', '.')) ?? 0.0;

      final servico = Servico(
        id: _servicoEmEdicao?.id,
        nome: nome,
        precoPasseio: precoPasseio,
        precoCaminhonete: precoCaminhonete,
      );

      bool sucesso;
      if (_servicoEmEdicao != null) {
        sucesso = await ServicoService.atualizarServico(_servicoEmEdicao!.id!, servico);
      } else {
        sucesso = await ServicoService.salvarServico(servico);
      }

      if (sucesso) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_servicoEmEdicao != null ? 'Serviço atualizado' : 'Serviço cadastrado')));
        setState(() {
          _servicosFuture = _carregarServicos();
          _showForm = false;
          _limparFormulario();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao salvar')));
      }
    }
  }

  void _editarServico(Servico s) {
    setState(() {
      _nomeController.text = s.nome;
      _precoPasseioController.text = s.precoPasseio?.toStringAsFixed(2).replaceAll('.', ',') ?? '';
      _precoCaminhoneteController.text = s.precoCaminhonete?.toStringAsFixed(2).replaceAll('.', ',') ?? '';
      _showForm = true;
      _servicoEmEdicao = s;
    });
  }

  void _confirmarExclusao(Servico s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja excluir o serviço ${s.nome}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (s.id != null) {
                final sucesso = await ServicoService.excluirServico(s.id!);
                if (sucesso) {
                  setState(() {
                    _servicosFuture = _carregarServicos();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Serviço excluído')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao excluir')));
                }
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
    _precoPasseioController.clear();
    _precoCaminhoneteController.clear();
    _servicoEmEdicao = null;
  }

  Widget _buildLista() {
    return FutureBuilder<List<Servico>>(
      future: _servicosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Erro: ${snapshot.error}'));
        if (_servicosFiltrados.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(_searchController.text.isEmpty
                  ? 'Nenhum serviço cadastrado.'
                  : 'Nenhum serviço encontrado para "${_searchController.text}".'),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(_searchController.text.isEmpty ? 'Últimos Serviços Cadastrados' : 'Resultados da Busca',
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            ..._servicosFiltrados.map((s) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(s.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'Passeio: R\$ ${s.precoPasseio?.toStringAsFixed(2) ?? '-'} \nCaminhonete: R\$ ${s.precoCaminhonete?.toStringAsFixed(2) ?? '-'}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _editarServico(s)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmarExclusao(s)),
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
          TextFormField(
            controller: _nomeController,
            decoration: const InputDecoration(labelText: 'Nome do Serviço'),
            validator: (v) => v!.isEmpty ? 'Informe o nome' : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _precoPasseioController,
            decoration: const InputDecoration(labelText: 'Preço - Carro de Passeio'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe o preço para carro de passeio';
              if (!RegExp(r'^\d*[,.]?\d*$').hasMatch(v)) return 'Digite apenas números e vírgula';
              return null;
            },
            onChanged: (v) {
              String newValue = v.replaceAll(RegExp(r'[^\d,]'), '');
              if (newValue != v) {
                _precoPasseioController.value =
                    TextEditingValue(text: newValue, selection: TextSelection.collapsed(offset: newValue.length));
              }
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _precoCaminhoneteController,
            decoration: const InputDecoration(labelText: 'Preço - Caminhonete'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe o preço para caminhonete';
              if (!RegExp(r'^\d*[,.]?\d*$').hasMatch(v)) return 'Digite apenas números e vírgula';
              return null;
            },
            onChanged: (v) {
              String newValue = v.replaceAll(RegExp(r'[^\d,]'), '');
              if (newValue != v) {
                _precoCaminhoneteController.value =
                    TextEditingValue(text: newValue, selection: TextSelection.collapsed(offset: newValue.length));
              }
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _salvar, child: Text(_servicoEmEdicao != null ? 'Atualizar Serviço' : 'Salvar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de Serviços')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: Icon(_showForm ? Icons.close : Icons.add),
              label: Text(_showForm ? 'Cancelar Cadastro' : 'Novo Servi\u00e7o'),
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
                    labelText: 'Pesquisar por nome do serviço',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                        : null,
                  ),
                ),
              ),
              _buildLista(),
            ],
          ],
        ),
      ),
    );
  }
}
