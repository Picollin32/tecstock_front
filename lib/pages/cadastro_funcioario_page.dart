import 'package:flutter/material.dart';
import 'package:TecStock/model/funcionario.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:cpf_cnpj_validator/cpf_validator.dart';
import '../services/funcionario_service.dart';

class CadastroFuncionarioPage extends StatefulWidget {
  const CadastroFuncionarioPage({super.key});

  @override
  State<CadastroFuncionarioPage> createState() => _FuncionarioPageState();
}

class _FuncionarioPageState extends State<CadastroFuncionarioPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _dataNascimentoController = TextEditingController();
  int? _nivelAcessoSelecionado;

  final TextEditingController _searchController = TextEditingController();
  List<Funcionario> _funcionariosFiltrados = [];

  final _maskTelefone = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _maskCpf = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});

  List<Funcionario> _funcionarios = [];
  bool _showForm = false;
  Funcionario? _funcionarioEmEdicao;

  @override
  void initState() {
    super.initState();
    _limparFormulario();
    _carregarFuncionarios();
    _searchController.addListener(_filtrarFuncionarios);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filtrarFuncionarios);
    _searchController.dispose();
    _nomeController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _cpfController.dispose();
    _dataNascimentoController.dispose();
    super.dispose();
  }

  void _filtrarFuncionarios() {
    final query = _maskCpf.unmaskText(_searchController.text);
    setState(() {
      if (query.isEmpty) {
        _funcionariosFiltrados = _funcionarios.take(3).toList();
      } else {
        _funcionariosFiltrados = _funcionarios.where((f) {
          return f.cpf.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _carregarFuncionarios() async {
    final lista = await Funcionarioservice.listarFuncionarios();
    setState(() {
      _funcionarios = lista.reversed.toList();
      _filtrarFuncionarios();
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

  void _salvarFuncionario() async {
    if (_formKey.currentState!.validate()) {
      final dataNascimentoFormatada = DateFormat('dd/MM/yyyy').parse(_dataNascimentoController.text);

      final funcionario = Funcionario(
        nome: _nomeController.text,
        telefone: _telefoneController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        email: _emailController.text,
        cpf: _cpfController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        dataNascimento: dataNascimentoFormatada,
        nivelAcesso: _nivelAcessoSelecionado ?? 0,
      );

      final sucesso = _funcionarioEmEdicao != null
          ? await Funcionarioservice.atualizarFuncionario(_funcionarioEmEdicao!.id!, funcionario)
          : await Funcionarioservice.salvarFuncionario(funcionario);

      if (sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_funcionarioEmEdicao != null ? "Funcionário atualizado com sucesso" : "Funcionário cadastrado com sucesso")),
        );
        _limparFormulario();
        await _carregarFuncionarios();
        setState(() => _showForm = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Erro ao cadastrar funcionário")),
        );
      }
    }
  }

  void _editarFuncionario(Funcionario funcionario) {
    setState(() {
      _nomeController.text = funcionario.nome;
      _telefoneController.text = _maskTelefone.maskText(funcionario.telefone);
      _emailController.text = funcionario.email;
      _cpfController.text = _maskCpf.maskText(funcionario.cpf);
      _dataNascimentoController.text = DateFormat('dd/MM/yyyy').format(funcionario.dataNascimento);
      _nivelAcessoSelecionado = funcionario.nivelAcesso;
      _showForm = true;
      _funcionarioEmEdicao = funcionario;
    });
  }

  void _confirmarExclusao(Funcionario funcionario) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja excluir o funcionário ${funcionario.nome}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final sucesso = await Funcionarioservice.excluirFuncionario(funcionario.id!);
              if (sucesso) {
                await _carregarFuncionarios();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Funcionário excluído com sucesso')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erro ao excluir funcionário')),
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
    _nivelAcessoSelecionado = null;
    _funcionarioEmEdicao = null;
  }

  Widget _buildListaFuncionarios() {
    if (_funcionariosFiltrados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _searchController.text.isEmpty ? 'Nenhum funcionário cadastrado.' : 'Nenhum funcionário encontrado para o CPF informado.',
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
            _searchController.text.isEmpty ? 'Últimos Funcionários Cadastrados' : 'Resultados da Busca',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _funcionariosFiltrados.length,
          itemBuilder: (context, index) {
            final funcionario = _funcionariosFiltrados[index];
            final telefoneFormatado = _maskTelefone.maskText(funcionario.telefone);
            final cpfFormatado = _maskCpf.maskText(funcionario.cpf);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              child: ListTile(
                title: Text(funcionario.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Telefone: $telefoneFormatado'),
                    Text('CPF: $cpfFormatado'),
                    Text('E-mail: ${funcionario.email}'),
                    Text('Nível Acesso: ${funcionario.nivelAcesso}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => _editarFuncionario(funcionario),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmarExclusao(funcionario),
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
              decoration: const InputDecoration(labelText: 'Nome', contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
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
              decoration: const InputDecoration(labelText: 'Telefone', contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
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
              decoration: const InputDecoration(labelText: 'E-mail', contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
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
              decoration: const InputDecoration(labelText: 'CPF', contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
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
                  suffixIcon: Icon(Icons.calendar_today),
                  contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
              readOnly: true,
              onTap: () => _selectDate(context),
              validator: (v) => v!.isEmpty ? 'Informe a data de nascimento' : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: DropdownButtonFormField<int>(
              value: _nivelAcessoSelecionado,
              decoration:
                  InputDecoration(labelText: 'Nível de Acesso', contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12)),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Consultor(a)')),
                DropdownMenuItem(value: 2, child: Text('Mecânico(a)')),
              ],
              onChanged: (v) => setState(() => _nivelAcessoSelecionado = v),
              validator: (v) {
                if (v == null) return 'Informe o nível de acesso';
                return null;
              },
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _salvarFuncionario,
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
                label: Text(_showForm ? 'Cancelar Cadastro' : 'Novo Funcionário'),
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
            _buildListaFuncionarios(),
          ],
        ),
      ),
    );
  }
}
