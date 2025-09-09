import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:TecStock/model/cliente.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:cpf_cnpj_validator/cpf_validator.dart';
import '../services/cliente_service.dart';
import '../utils/error_utils.dart';

class CadastroClientePage extends StatefulWidget {
  const CadastroClientePage({super.key});

  @override
  State<CadastroClientePage> createState() => _CadastroClientePageState();
}

class _CadastroClientePageState extends State<CadastroClientePage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _dataNascimentoController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final _maskTelefone = MaskTextInputFormatter(mask: '(##) #####-####', filter: {"#": RegExp(r'[0-9]')});
  final _maskCpf = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});

  List<Cliente> _clientes = [];
  List<Cliente> _clientesFiltrados = [];
  Cliente? _clienteEmEdicao;

  bool _isLoading = false;
  bool _isLoadingClientes = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const Color primaryColor = Color(0xFF059669);
  static const Color errorColor = Color(0xFFDC2626);
  static const Color successColor = Color(0xFF16A34A);
  static const Color shadowColor = Color(0x1A000000);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _limparFormulario();
    _carregarClientes();
    _searchController.addListener(_filtrarClientes);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
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
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _clientesFiltrados = _clientes.take(6).toList();
      } else {
        _clientesFiltrados = _clientes.where((cliente) {
          final nomeMatch = cliente.nome.toLowerCase().contains(query);
          final cpfSemMascara = query.replaceAll(RegExp(r'[^0-9]'), '');
          final cpfMatch = cliente.cpf.contains(cpfSemMascara) && cpfSemMascara.isNotEmpty;

          return nomeMatch || cpfMatch;
        }).toList();
      }
    });
  }

  Future<void> _carregarClientes() async {
    setState(() => _isLoadingClientes = true);
    try {
      final lista = await ClienteService.listarClientes();
      setState(() {
        _clientes = lista.reversed.toList();
        _filtrarClientes();
      });
    } catch (e) {
      ErrorUtils.showVisibleError(context, 'Erro ao carregar clientes');
    } finally {
      setState(() => _isLoadingClientes = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dataNascimentoController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  void _salvarCliente() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final dataNascimentoFormatada = DateFormat('dd/MM/yyyy').parse(_dataNascimentoController.text);

      final cliente = Cliente(
        nome: _nomeController.text,
        telefone: _telefoneController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        email: _emailController.text,
        cpf: _cpfController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        dataNascimento: dataNascimentoFormatada,
      );

      final resultado = _clienteEmEdicao != null
          ? await ClienteService.atualizarCliente(_clienteEmEdicao!.id!, cliente)
          : await ClienteService.salvarCliente(cliente);

      if (resultado['success']) {
        _showSuccessSnackBar(resultado['message']);
        _limparFormulario();
        await _carregarClientes();
        Navigator.of(context).pop();
      } else {
        ErrorUtils.showVisibleError(context, resultado['message']);
      }
    } catch (e) {
      String errorMessage = "Erro inesperado ao salvar cliente";
      if (e.toString().contains('CPF já cadastrado')) {
        errorMessage = "CPF já cadastrado";
      } else if (e.toString().contains('já cadastrado')) {
        errorMessage = "Cliente já cadastrado";
      }
      ErrorUtils.showVisibleError(context, errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _editarCliente(Cliente cliente) {
    setState(() {
      _nomeController.text = cliente.nome;
      _telefoneController.text = _maskTelefone.maskText(cliente.telefone);
      _emailController.text = cliente.email;
      _cpfController.text = _maskCpf.maskText(cliente.cpf);
      _dataNascimentoController.text = DateFormat('dd/MM/yyyy').format(cliente.dataNascimento);
      _clienteEmEdicao = cliente;
    });
    _showFormModal();
  }

  void _confirmarExclusao(Cliente cliente) {
    showDialog(
      context: context,
      builder: (_) => Theme(
        data: Theme.of(context).copyWith(
          dialogTheme: DialogTheme(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
          ),
        ),
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: errorColor, size: 28),
              const SizedBox(width: 12),
              const Text('Confirmar Exclusão'),
            ],
          ),
          content: Text('Deseja excluir o cliente ${cliente.nome}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: errorColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _excluirCliente(cliente);
              },
              child: const Text('Excluir'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _excluirCliente(Cliente cliente) async {
    setState(() => _isLoading = true);
    try {
      final sucesso = await ClienteService.excluirCliente(cliente.id!);
      if (sucesso) {
        await _carregarClientes();
        _showSuccessSnackBar('Cliente excluído com sucesso');
      } else {
        ErrorUtils.showVisibleError(context, 'Erro ao excluir cliente');
      }
    } catch (e) {
      ErrorUtils.showVisibleError(context, 'Erro inesperado ao excluir cliente');
    } finally {
      setState(() => _isLoading = false);
    }
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: successColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showFormModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _clienteEmEdicao != null ? Icons.edit : Icons.add,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _clienteEmEdicao != null ? 'Editar Cliente' : 'Novo Cliente',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _limparFormulario();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: _buildFormulario(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Pesquisar por nome ou CPF...',
          prefixIcon: Icon(Icons.search, color: primaryColor),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildClientGrid() {
    if (_isLoadingClientes) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_clientesFiltrados.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                _searchController.text.isEmpty ? Icons.people_outline : Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isEmpty ? 'Nenhum cliente cadastrado' : 'Nenhum resultado encontrado',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_searchController.text.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Comece adicionando seu primeiro cliente',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 900) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _clientesFiltrados.length,
          itemBuilder: (context, index) => _buildClientCard(_clientesFiltrados[index]),
        );
      },
    );
  }

  Widget _buildClientCard(Cliente cliente) {
    final idade = DateTime.now().difference(cliente.dataNascimento).inDays ~/ 365;

    String initials = cliente.nome.isNotEmpty ? cliente.nome.substring(0, 1).toUpperCase() : '?';

    if (cliente.nome.contains(' ')) {
      final words = cliente.nome.split(' ');
      if (words.length >= 2) {
        initials = words[0].substring(0, 1).toUpperCase() + words[1].substring(0, 1).toUpperCase();
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _editarCliente(cliente),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: primaryColor.withOpacity(0.1),
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cliente.nome,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$idade anos',
                              style: TextStyle(
                                color: primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editarCliente(cliente);
                        } else if (value == 'delete') {
                          _confirmarExclusao(cliente);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Excluir', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.badge, _maskCpf.maskText(cliente.cpf)),
                _buildInfoRow(Icons.phone, _maskTelefone.maskText(cliente.telefone)),
                _buildInfoRow(Icons.email, cliente.email),
                _buildInfoRow(Icons.cake, DateFormat('dd/MM/yyyy').format(cliente.dataNascimento)),
                const Spacer(),
                if (cliente.createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(
                          'Cadastrado em ${DateFormat('dd/MM/yyyy').format(cliente.createdAt!)}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'ID: ${cliente.id}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(
            controller: _nomeController,
            label: 'Nome Completo',
            icon: Icons.person,
            validator: (v) => v!.isEmpty ? 'Informe o nome' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _cpfController,
            label: 'CPF',
            icon: Icons.badge,
            keyboardType: TextInputType.number,
            inputFormatters: [_maskCpf],
            validator: (cpf) {
              if (cpf == null || cpf.isEmpty) {
                return 'Por favor, insira um CPF';
              }
              if (!CPFValidator.isValid(cpf)) {
                return 'CPF inválido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _telefoneController,
                  label: 'Telefone',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_maskTelefone],
                  validator: (v) => v!.isEmpty ? 'Informe o telefone' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _dataNascimentoController,
                  label: 'Data de Nascimento',
                  icon: Icons.calendar_today,
                  readOnly: true,
                  onTap: () => _selectDate(context),
                  validator: (v) => v!.isEmpty ? 'Informe a data de nascimento' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            label: 'E-mail',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (email) {
              if (email == null || email.isEmpty) {
                return 'Por favor, insira um e-mail';
              }
              final emailRegex = RegExp(
                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
              );
              if (!emailRegex.hasMatch(email)) {
                return 'Por favor, insira um e-mail válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _salvarCliente,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _clienteEmEdicao != null ? 'Atualizar Cliente' : 'Cadastrar Cliente',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        suffixIcon: readOnly ? Icon(Icons.calendar_today, color: primaryColor) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Gestão de Clientes',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _buildSearchBar()),
                  const SizedBox(width: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () {
                        _limparFormulario();
                        _showFormModal();
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      iconSize: 28,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_searchController.text.isEmpty && !_isLoadingClientes && _clientesFiltrados.isNotEmpty)
                Text(
                  'Últimos Clientes Cadastrados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              if (_searchController.text.isNotEmpty && !_isLoadingClientes)
                Text(
                  'Resultados da Busca (${_clientesFiltrados.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              const SizedBox(height: 16),
              _buildClientGrid(),
            ],
          ),
        ),
      ),
    );
  }
}
