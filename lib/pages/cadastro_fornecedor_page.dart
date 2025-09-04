import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:cpf_cnpj_validator/cnpj_validator.dart';
import '../model/fornecedor.dart';
import '../services/fornecedor_service.dart';

class CadastroFornecedorPage extends StatefulWidget {
  const CadastroFornecedorPage({super.key});

  @override
  State<CadastroFornecedorPage> createState() => _CadastroFornecedorPageState();
}

class _CadastroFornecedorPageState extends State<CadastroFornecedorPage> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _margemLucroController = TextEditingController();
  final _maskCnpj = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});
  final _maskTelefone = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _maskMargemLucro = MaskTextInputFormatter(
    mask: '###',
    filter: {"#": RegExp(r'[0-9]')},
  );
  final _searchController = TextEditingController();
  List<Fornecedor> _fornecedores = [];
  List<Fornecedor> _fornecedoresFiltrados = [];
  bool _showForm = false;
  Fornecedor? _fornecedorEmEdicao;

  @override
  void initState() {
    super.initState();
    _limparFormulario();
    _carregarFornecedores();
    _searchController.addListener(_filtrarFornecedores);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filtrarFornecedores);
    _searchController.dispose();
    _nomeController.dispose();
    _cnpjController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _margemLucroController.dispose();
    super.dispose();
  }

  List<Fornecedor> _getFiltrados(List<Fornecedor> allFornecedores) {
    final query = _maskCnpj.unmaskText(_searchController.text);
    if (query.isEmpty) {
      return allFornecedores.take(3).toList();
    } else {
      return allFornecedores.where((fornecedor) {
        return fornecedor.cnpj.contains(query);
      }).toList();
    }
  }

  void _filtrarFornecedores() {
    setState(() {
      _fornecedoresFiltrados = _getFiltrados(_fornecedores);
    });
  }

  Future<void> _carregarFornecedores() async {
    final lista = await FornecedorService.listarFornecedores();
    setState(() {
      _fornecedores = lista.reversed.toList();
      _fornecedoresFiltrados = _getFiltrados(_fornecedores);
    });
  }

  void _salvarFornecedor() async {
    if (_formKey.currentState!.validate()) {
      final fornecedor = Fornecedor(
        id: _fornecedorEmEdicao?.id,
        nome: _nomeController.text,
        cnpj: _cnpjController.text.replaceAll(RegExp(r'[^\d]'), ''),
        telefone: _telefoneController.text.replaceAll(RegExp(r'[^\d]'), ''),
        email: _emailController.text,
        margemLucro: (int.tryParse(_margemLucroController.text) ?? 0) / 100,
      );

      final sucesso = _fornecedorEmEdicao != null
          ? await FornecedorService.atualizarFornecedor(_fornecedorEmEdicao!.id!, fornecedor)
          : await FornecedorService.salvarFornecedor(fornecedor);

      if (sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_fornecedorEmEdicao != null ? "Fornecedor atualizado com sucesso" : "Fornecedor cadastrado com sucesso")),
        );
        _limparFormulario();
        await _carregarFornecedores();
        setState(() => _showForm = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao salvar fornecedor")),
        );
      }
    }
  }

  void _editarFornecedor(Fornecedor fornecedor) {
    setState(() {
      _nomeController.text = fornecedor.nome;
      _emailController.text = fornecedor.email;
      _margemLucroController.text = ((fornecedor.margemLucro ?? 0) * 100).toStringAsFixed(0);

      if (fornecedor.cnpj.isNotEmpty) {
        _cnpjController.text = fornecedor.cnpj.length == 14 ? _maskCnpj.maskText(fornecedor.cnpj) : fornecedor.cnpj;
      }
      if (fornecedor.telefone.isNotEmpty) {
        _telefoneController.text = fornecedor.telefone.length == 11 ? _maskTelefone.maskText(fornecedor.telefone) : fornecedor.telefone;
      }

      _showForm = true;
      _fornecedorEmEdicao = fornecedor;
    });
  }

  void _confirmarExclusao(Fornecedor fornecedor) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja excluir o fornecedor ${fornecedor.nome}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final sucesso = await FornecedorService.excluirFornecedor(fornecedor.id!);
              if (sucesso) {
                await _carregarFornecedores();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fornecedor excluído com sucesso')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao excluir fornecedor')));
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
    _cnpjController.clear();
    _telefoneController.clear();
    _emailController.clear();
    _margemLucroController.clear();
    _fornecedorEmEdicao = null;
  }

  Widget _buildListaFornecedores() {
    if (_fornecedoresFiltrados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(_searchController.text.isEmpty
              ? 'Nenhum fornecedor cadastrado.'
              : 'Nenhum fornecedor encontrado para "${_searchController.text}".'),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            _searchController.text.isEmpty ? 'Últimos Fornecedores Cadastrados' : 'Resultados da Busca',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ..._fornecedoresFiltrados.map((fornecedor) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              title: Text(fornecedor.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("CNPJ: ${_maskCnpj.maskText(fornecedor.cnpj)}\nTelefone: ${_maskTelefone.maskText(fornecedor.telefone)}"),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.orange), onPressed: () => _editarFornecedor(fornecedor)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmarExclusao(fornecedor)),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nomeController,
            decoration: const InputDecoration(labelText: 'Nome do Fornecedor'),
            validator: (v) => v!.isEmpty ? 'Informe o nome' : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onEditingComplete: () {
              Form.of(context).validate();
              FocusScope.of(context).nextFocus();
            },
          ),
          TextFormField(
            controller: _cnpjController,
            decoration: const InputDecoration(labelText: 'CNPJ'),
            keyboardType: TextInputType.number,
            inputFormatters: [_maskCnpj],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe o CNPJ';
              if (!CNPJValidator.isValid(v)) return 'CNPJ inválido';
              return null;
            },
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onEditingComplete: () {
              Form.of(context).validate();
              FocusScope.of(context).nextFocus();
            },
          ),
          TextFormField(
            controller: _telefoneController,
            decoration: const InputDecoration(labelText: 'Telefone'),
            keyboardType: TextInputType.number,
            inputFormatters: [_maskTelefone],
            validator: (v) => v!.isEmpty ? 'Informe o telefone' : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onEditingComplete: () {
              Form.of(context).validate();
              FocusScope.of(context).nextFocus();
            },
          ),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'E-mail'),
            keyboardType: TextInputType.emailAddress,
            validator: (email) {
              if (email == null || email.isEmpty) {
                return 'Por favor, insira um e-mail';
              }
              final emailRegex = RegExp(
                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
              );
              if (!emailRegex.hasMatch(email)) {
                return 'Por favor, insira um e-mail com formato válido';
              }
              return null;
            },
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onEditingComplete: () {
              Form.of(context).validate();
              FocusScope.of(context).nextFocus();
            },
          ),
          TextFormField(
            controller: _margemLucroController,
            decoration: const InputDecoration(labelText: 'Margem de Lucro (%)', suffixText: '%', hintText: 'Ex: 10'),
            keyboardType: TextInputType.number,
            inputFormatters: [_maskMargemLucro],
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Informe a margem de lucro';
              }
              final value = int.tryParse(v);
              if (value == null) {
                return 'Valor inválido';
              }
              return null;
            },
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onEditingComplete: () {
              Form.of(context).validate();
              FocusScope.of(context).nextFocus();
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _salvarFornecedor, child: const Text('Salvar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro de Fornecedores')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: Icon(_showForm ? Icons.close : Icons.add),
              label: Text(_showForm ? 'Cancelar Cadastro' : 'Novo Fornecedor'),
              onPressed: () => setState(() {
                if (_showForm) _limparFormulario();
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
                  decoration: InputDecoration(
                    labelText: 'Pesquisar por CNPJ',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                        : null,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [_maskCnpj],
                ),
              ),
            if (!_showForm) _buildListaFornecedores(),
          ],
        ),
      ),
    );
  }
}
