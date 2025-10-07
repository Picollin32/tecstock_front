import 'package:flutter/material.dart';
import 'package:TecStock/model/usuario.dart';
import 'package:TecStock/model/funcionario.dart';
import '../services/usuario_service.dart';
import '../services/funcionario_service.dart';
import '../utils/error_utils.dart';

class GerenciarUsuariosPage extends StatefulWidget {
  const GerenciarUsuariosPage({super.key});

  @override
  State<GerenciarUsuariosPage> createState() => _GerenciarUsuariosPageState();
}

class _GerenciarUsuariosPageState extends State<GerenciarUsuariosPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeUsuarioController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Usuario> _usuarios = [];
  List<Usuario> _usuariosFiltrados = [];
  List<Funcionario> _consultores = [];
  Usuario? _usuarioEmEdicao;
  Funcionario? _consultorSelecionado;

  bool _isLoading = false;
  bool _isLoadingUsuarios = true;
  bool _senhaVisivel = false;
  bool _confirmarSenhaVisivel = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const Color primaryColor = Color(0xFF0EA5E9);
  static const Color errorColor = Color(0xFFDC2626);
  static const Color successColor = Color(0xFF16A34A);
  static const Color shadowColor = Color(0x1A000000);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _carregarDados();
    _searchController.addListener(_filtrarUsuarios);
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
    _searchController.removeListener(_filtrarUsuarios);
    _searchController.dispose();
    _nomeUsuarioController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  void _filtrarUsuarios() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _usuariosFiltrados = _usuarios.take(6).toList();
      } else {
        _usuariosFiltrados = _usuarios.where((usuario) {
          final nomeUsuarioMatch = usuario.nomeUsuario.toLowerCase().contains(query);
          final consultorMatch = usuario.consultor?.nome.toLowerCase().contains(query) ?? false;
          return nomeUsuarioMatch || consultorMatch;
        }).toList();
      }
    });
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoadingUsuarios = true);
    try {
      final todosFuncionarios = await Funcionarioservice.listarFuncionarios();
      _consultores = todosFuncionarios.where((f) => f.nivelAcesso == 1).toList();

      if (_consultores.isNotEmpty) {
        _consultorSelecionado = _consultores.first;
      }

      final lista = await UsuarioService.listarUsuarios();
      lista.sort((a, b) =>
          (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
      setState(() {
        _usuarios = lista;
        _filtrarUsuarios();
      });
    } catch (e) {
      ErrorUtils.showVisibleError(context, 'Erro ao carregar dados');
    } finally {
      setState(() => _isLoadingUsuarios = false);
    }
  }

  void _salvarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    final senhaPreenchida = _senhaController.text.isNotEmpty;
    if (senhaPreenchida && _senhaController.text != _confirmarSenhaController.text) {
      ErrorUtils.showVisibleError(context, 'As senhas não coincidem');
      return;
    }

    if (_consultorSelecionado == null) {
      ErrorUtils.showVisibleError(context, 'Selecione um consultor');
      return;
    }

    final nomeUsuarioJaExiste = _usuarios
        .any((u) => u.nomeUsuario.toLowerCase() == _nomeUsuarioController.text.trim().toLowerCase() && u.id != _usuarioEmEdicao?.id);

    if (nomeUsuarioJaExiste) {
      ErrorUtils.showVisibleError(context, 'Já existe um usuário com este nome');
      return;
    }

    final consultorJaPossuiUsuario = _usuarios.any((u) => u.consultor?.id == _consultorSelecionado!.id && u.id != _usuarioEmEdicao?.id);

    if (consultorJaPossuiUsuario) {
      ErrorUtils.showVisibleError(context, 'Este consultor já possui um usuário cadastrado');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final usuario = Usuario(
        id: _usuarioEmEdicao?.id,
        nomeUsuario: _nomeUsuarioController.text.trim(),
        senha: _senhaController.text.isNotEmpty ? _senhaController.text : null,
        nivelAcesso: _consultorSelecionado != null ? 1 : 0,
        consultor: _consultorSelecionado!,
      );

      Map<String, dynamic> result;
      if (_usuarioEmEdicao == null) {
        result = await UsuarioService.salvarUsuario(usuario);
      } else {
        result = await UsuarioService.atualizarUsuario(_usuarioEmEdicao!.id!, usuario);
      }

      if (result['success'] == true) {
        _limparFormulario();
        await _carregarDados();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Operação realizada com sucesso'),
              backgroundColor: successColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ErrorUtils.showVisibleError(context, result['message'] ?? 'Erro ao salvar usuário');
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showVisibleError(context, 'Erro ao salvar usuário: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    setState(() {
      _nomeUsuarioController.clear();
      _senhaController.clear();
      _confirmarSenhaController.clear();
      _usuarioEmEdicao = null;
      _senhaVisivel = false;
      _confirmarSenhaVisivel = false;
      if (_consultores.isNotEmpty) {
        _consultorSelecionado = _consultores.first;
      }
    });
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

  void _editarUsuario(Usuario usuario) {
    setState(() {
      _usuarioEmEdicao = usuario;
      _nomeUsuarioController.text = usuario.nomeUsuario;
      _senhaController.clear();
      _confirmarSenhaController.clear();
      if (usuario.consultor != null) {
        _consultorSelecionado = _consultores.firstWhere(
          (c) => c.id == usuario.consultor!.id,
          orElse: () => _consultores.first,
        );
      } else {
        _consultorSelecionado = _consultores.isNotEmpty ? _consultores.first : null;
      }
    });
    _showFormModal();
  }

  void _confirmarExclusao(Usuario usuario) {
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
          content: Text('Deseja excluir o usuário "${usuario.nomeUsuario}"?'),
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
                await _excluirUsuario(usuario);
              },
              child: const Text('Excluir'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _excluirUsuario(Usuario usuario) async {
    setState(() => _isLoading = true);
    try {
      final sucesso = await UsuarioService.excluirUsuario(usuario.id!);
      if (sucesso) {
        await _carregarDados();
        _showSuccessSnackBar('Usuário excluído com sucesso');
      } else {
        ErrorUtils.showVisibleError(context, 'Erro ao excluir usuário');
      }
    } catch (e) {
      ErrorUtils.showVisibleError(context, 'Erro inesperado ao excluir usuário');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showFormModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
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
                          _usuarioEmEdicao != null ? Icons.edit : Icons.add,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _usuarioEmEdicao != null ? 'Editar Usuário' : 'Novo Usuário',
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
                      padding: const EdgeInsets.all(20),
                      child: _buildFormContent(setModalState),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormContent(StateSetter setModalState) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _nomeUsuarioController,
            label: 'Nome de Usuário',
            icon: Icons.account_circle,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nome de usuário é obrigatório';
              }
              if (value.trim().length < 3) {
                return 'Nome de usuário deve ter pelo menos 3 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _senhaController,
            label: _usuarioEmEdicao != null ? 'Nova Senha (deixe vazio para manter)' : 'Senha',
            icon: Icons.lock,
            isVisible: _senhaVisivel,
            onToggleVisibility: () => setModalState(() => _senhaVisivel = !_senhaVisivel),
            validator: (value) {
              if (_usuarioEmEdicao != null && (value == null || value.isEmpty)) {
                return null;
              }
              if (value == null || value.isEmpty) {
                return 'Senha é obrigatória';
              }
              if (value.length < 6) {
                return 'Senha deve ter pelo menos 6 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildPasswordField(
            controller: _confirmarSenhaController,
            label: _usuarioEmEdicao != null ? 'Confirmar Nova Senha' : 'Confirmar Senha',
            icon: Icons.lock_outline,
            isVisible: _confirmarSenhaVisivel,
            onToggleVisibility: () => setModalState(() => _confirmarSenhaVisivel = !_confirmarSenhaVisivel),
            validator: (value) {
              if (_usuarioEmEdicao != null && (value == null || value.isEmpty) && (_senhaController.text.isEmpty)) {
                return null;
              }
              if (value == null || value.isEmpty) {
                return 'Confirme a senha';
              }
              if (value != _senhaController.text) {
                return 'As senhas não coincidem';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildDropdownField<Funcionario>(
            value: _consultorSelecionado,
            label: 'Consultor Responsável',
            icon: Icons.support_agent,
            items: _consultores
                .map((consultor) => DropdownMenuItem<Funcionario>(
                      value: consultor,
                      child: Text(consultor.nome),
                    ))
                .toList(),
            onChanged: (value) => setModalState(() => _consultorSelecionado = value),
            validator: (value) => value == null ? 'Selecione um consultor' : null,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _salvarUsuario,
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
                      _usuarioEmEdicao != null ? 'Atualizar Usuário' : 'Cadastrar Usuário',
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility_off : Icons.visibility,
            color: primaryColor,
          ),
          onPressed: onToggleVisibility,
        ),
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

  Widget _buildDropdownField<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
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
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: items,
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
          hintText: 'Buscar usuários...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: primaryColor),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey[400]),
                  onPressed: () {
                    _searchController.clear();
                    _filtrarUsuarios();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildUsuariosGrid() {
    if (_isLoadingUsuarios) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_usuariosFiltrados.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                _searchController.text.isEmpty ? Icons.person_outline : Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isEmpty ? 'Nenhum usuário cadastrado' : 'Nenhum resultado encontrado',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_searchController.text.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Comece adicionando o primeiro usuário',
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
        int crossAxisCount = 2;
        if (constraints.maxWidth > 1200) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 800) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _usuariosFiltrados.length,
          itemBuilder: (context, index) => _buildUsuarioCard(_usuariosFiltrados[index]),
        );
      },
    );
  }

  Widget _buildUsuarioCard(Usuario usuario) {
    String initials = usuario.nomeUsuario.isNotEmpty ? usuario.nomeUsuario.substring(0, 1).toUpperCase() : '?';
    if (usuario.nomeUsuario.contains(' ')) {
      final words = usuario.nomeUsuario.split(' ');
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
          onTap: () => _editarUsuario(usuario),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: primaryColor.withOpacity(0.1),
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        usuario.nomeUsuario,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editarUsuario(usuario);
                        } else if (value == 'delete') {
                          _confirmarExclusao(usuario);
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
                              Icon(Icons.delete, size: 18, color: errorColor),
                              SizedBox(width: 8),
                              Text('Excluir', style: TextStyle(color: errorColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.support_agent, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        usuario.consultor?.nome ?? 'Sem consultor',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Cadastrado: ${_formatDate(usuario.createdAt)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Gerenciar Usuários',
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
              if (_searchController.text.isEmpty && !_isLoadingUsuarios && _usuariosFiltrados.isNotEmpty)
                Text(
                  'Últimos Usuários Cadastrados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              if (_searchController.text.isNotEmpty && !_isLoadingUsuarios)
                Text(
                  'Resultados da Busca (${_usuariosFiltrados.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              const SizedBox(height: 16),
              _buildUsuariosGrid(),
            ],
          ),
        ),
      ),
    );
  }
}
