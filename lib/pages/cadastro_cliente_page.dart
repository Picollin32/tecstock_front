import 'package:flutter/material.dart';
import 'package:TecStock/model/cliente.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:cpf_cnpj_validator/cpf_validator.dart';
import '../services/cliente_service.dart';

class CadastroClientePage extends StatefulWidget {
  const CadastroClientePage({super.key});

  @override
  State<CadastroClientePage> createState() => _ClientePageState();
}

class _ClientePageState extends State<CadastroClientePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _dataNascimentoController = TextEditingController();

  final TextEditingController _searchController = TextEditingController();
  List<Cliente> _clientesFiltrados = [];

  final _maskTelefone = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _maskCpf = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});

  List<Cliente> _clientes = [];
  bool _showForm = false;
  Cliente? _clienteEmEdicao;

  @override
  void initState() {
    super.initState();
    _limparFormulario();
    _carregarClientes();
    _searchController.addListener(_filtrarClientes);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filtrarClientes);
    _searchController.dispose();
    _nomeController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _cpfController.dispose();
    _dataNascimentoController.dispose();
    super.dispose();
  }

  void _filtrarClientes() {
    final query = _maskCpf.unmaskText(_searchController.text);
    setState(() {
      if (query.isEmpty) {
        _clientesFiltrados = _clientes.take(3).toList();
      } else {
        _clientesFiltrados = _clientes.where((cliente) {
          return cliente.cpf.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _carregarClientes() async {
    final lista = await ClienteService.listarClientes();
    setState(() {
      _clientes = lista.reversed.toList();
      _filtrarClientes();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dataNascimentoController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _salvarCliente() async {
    if (_formKey.currentState!.validate()) {
      final dataNascimentoFormatada = DateFormat('dd/MM/yyyy').parse(_dataNascimentoController.text);

      final cliente = Cliente(
        nome: _nomeController.text,
        telefone: _telefoneController.text.replaceAll(RegExp(r'[^\d]'), ''),
        email: _emailController.text,
        cpf: _cpfController.text.replaceAll(RegExp(r'[^\d]'), ''),
        dataNascimento: dataNascimentoFormatada,
      );

      final sucesso = _clienteEmEdicao != null
          ? await ClienteService.atualizarCliente(_clienteEmEdicao!.id!, cliente)
          : await ClienteService.salvarCliente(cliente);

      if (sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_clienteEmEdicao != null ? "Cliente atualizado com sucesso" : "Cliente cadastrado com sucesso")),
        );
        _limparFormulario();
        await _carregarClientes();
        setState(() => _showForm = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao cadastrar cliente")),
        );
      }
    }
  }

  void _editarCliente(Cliente cliente) {
    setState(() {
      _nomeController.text = cliente.nome;
      _telefoneController.text = _maskTelefone.maskText(cliente.telefone);
      _emailController.text = cliente.email;
      _cpfController.text = _maskCpf.maskText(cliente.cpf);
      _dataNascimentoController.text = DateFormat('dd/MM/yyyy').format(cliente.dataNascimento);
      _showForm = true;
      _clienteEmEdicao = cliente;
    });
  }

  void _confirmarExclusao(Cliente cliente) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja excluir o cliente ${cliente.nome}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final sucesso = await ClienteService.excluirCliente(cliente.id!);
              if (sucesso) {
                await _carregarClientes();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cliente excluído com sucesso')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erro ao excluir cliente')),
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
    _telefoneController.clear();
    _emailController.clear();
    _cpfController.clear();
    _dataNascimentoController.clear();
    _clienteEmEdicao = null;
  }

  Widget _buildListaClientes() {
    if (_clientesFiltrados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _searchController.text.isEmpty ? 'Nenhum cliente cadastrado.' : 'Nenhum cliente encontrado para o CPF informado.',
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
            _searchController.text.isEmpty ? 'Últimos Clientes Cadastrados' : 'Resultados da Busca',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _clientesFiltrados.length,
          itemBuilder: (context, index) {
            final cliente = _clientesFiltrados[index];
            final telefoneFormatado = _maskTelefone.maskText(cliente.telefone);
            final cpfFormatado = _maskCpf.maskText(cliente.cpf);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                title: Text(cliente.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Telefone: $telefoneFormatado'),
                    Text('CPF: $cpfFormatado'),
                    Text('E-mail: ${cliente.email}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => _editarCliente(cliente),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmarExclusao(cliente),
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
              decoration:
                  const InputDecoration(labelText: 'Nome', contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
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
            child: TextFormField(
              controller: _telefoneController,
              decoration:
                  const InputDecoration(labelText: 'Telefone', contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
              inputFormatters: [_maskTelefone],
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'Informe o telefone' : null,
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
              controller: _emailController,
              decoration:
                  const InputDecoration(labelText: 'E-mail', contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextFormField(
              controller: _cpfController,
              decoration: const InputDecoration(labelText: 'CPF', contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
              inputFormatters: [_maskCpf],
              keyboardType: TextInputType.number,
              validator: (cpf) {
                if (cpf == null || cpf.isEmpty) {
                  return 'Por favor, insira um CPF';
                }
                if (!CPFValidator.isValid(cpf)) {
                  return 'CPF inválido';
                }
                return null;
              },
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
              controller: _dataNascimentoController,
              decoration: const InputDecoration(
                  labelText: 'Data de Nascimento',
                  suffixIcon: const Icon(Icons.calendar_today),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
              readOnly: true,
              onTap: () => _selectDate(context),
              validator: (v) => v!.isEmpty ? 'Informe a data de nascimento' : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _salvarCliente,
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
                label: Text(_showForm ? 'Cancelar Cadastro' : 'Novo Cliente'),
                onPressed: () {
                  if (_showForm) {
                    _limparFormulario();
                  } else {
                    _limparFormulario();
                  }
                  setState(() => _showForm = !_showForm);
                }),
            const SizedBox(height: 10),
            if (_showForm) _buildFormulario(),
            if (!_showForm)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: TextField(
                  controller: _searchController,
                  inputFormatters: [_maskCpf],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Pesquisar por CPF',
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
            _buildListaClientes(),
          ],
        ),
      ),
    );
  }
}
