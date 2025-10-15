import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../utils/adaptive_phone_formatter.dart';
import 'package:cpf_cnpj_validator/cnpj_validator.dart';
import '../model/fornecedor.dart';
import '../services/fornecedor_service.dart';
import '../utils/error_utils.dart';

class CadastroFornecedorPage extends StatefulWidget {
  const CadastroFornecedorPage({super.key});

  @override
  State<CadastroFornecedorPage> createState() => _CadastroFornecedorPageState();
}

class _CadastroFornecedorPageState extends State<CadastroFornecedorPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _cnpjController = TextEditingController();
  final _telefoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _margemLucroController = TextEditingController();
  final _ruaController = TextEditingController();
  final _numeroCasaController = TextEditingController();
  final _bairroController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _ufController = TextEditingController();
  final _searchController = TextEditingController();

  final _maskCnpj = MaskTextInputFormatter(mask: '##.###.###/####-##', filter: {"#": RegExp(r'[0-9]')});
  final AdaptivePhoneFormatter _maskTelefone = AdaptivePhoneFormatter();

  final _decimalFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
    // Permite apenas números e vírgula
    final filteredText = newValue.text.replaceAll(RegExp(r'[^0-9,]'), '');

    // Garante apenas uma vírgula
    final parts = filteredText.split(',');
    String formattedText = parts[0];
    if (parts.length > 1) {
      formattedText += ',' + parts[1];
    }

    // Limita a 2 casas decimais após a vírgula
    if (parts.length > 1 && parts[1].length > 2) {
      formattedText = parts[0] + ',' + parts[1].substring(0, 2);
    }

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  });

  List<Fornecedor> _fornecedores = [];
  List<Fornecedor> _fornecedoresFiltrados = [];
  Fornecedor? _fornecedorEmEdicao;

  bool _isLoading = false;
  bool _isLoadingFornecedores = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const Color primaryColor = Color(0xFF059669);
  static const Color errorColor = Color(0xFFDC2626);
  static const Color successColor = Color(0xFF16A34A);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color shadowColor = Color(0x1A000000);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _limparFormulario();
    _carregarFornecedores();
    _searchController.addListener(_filtrarFornecedores);
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
    _searchController.removeListener(_filtrarFornecedores);
    _searchController.dispose();
    _nomeController.dispose();
    _cnpjController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _margemLucroController.dispose();
    _ruaController.dispose();
    _numeroCasaController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _ufController.dispose();
    super.dispose();
  }

  void _filtrarFornecedores() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _fornecedoresFiltrados = _fornecedores.take(6).toList();
      } else {
        _fornecedoresFiltrados = _fornecedores.where((fornecedor) {
          final nomeMatch = fornecedor.nome.toLowerCase().contains(query);
          final cnpjSemMascara = query.replaceAll(RegExp(r'[^0-9]'), '');
          final cnpjMatch = fornecedor.cnpj.contains(cnpjSemMascara) && cnpjSemMascara.isNotEmpty;

          return nomeMatch || cnpjMatch;
        }).toList();
      }
    });
  }

  Future<void> _carregarFornecedores() async {
    setState(() => _isLoadingFornecedores = true);
    try {
      final lista = await FornecedorService.listarFornecedores();
      lista.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      setState(() {
        _fornecedores = lista.toList();
        _filtrarFornecedores();
      });
    } catch (e) {
      ErrorUtils.showVisibleError(context, 'Erro ao carregar fornecedores');
    } finally {
      setState(() => _isLoadingFornecedores = false);
    }
  }

  void _salvarFornecedor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final margemText = _margemLucroController.text.replaceAll(',', '.');
      final margemValue = double.tryParse(margemText) ?? 0;

      final fornecedor = Fornecedor(
        id: _fornecedorEmEdicao?.id,
        nome: _nomeController.text,
        cnpj: _cnpjController.text.replaceAll(RegExp(r'[^\d]'), ''),
        telefone: _telefoneController.text.replaceAll(RegExp(r'[^\d]'), ''),
        email: _emailController.text,
        margemLucro: margemValue / 100,
        rua: _ruaController.text,
        numeroCasa: _numeroCasaController.text,
        bairro: _bairroController.text,
        cidade: _cidadeController.text,
        uf: _ufController.text,
      );

      final resultado = _fornecedorEmEdicao != null
          ? await FornecedorService.atualizarFornecedor(_fornecedorEmEdicao!.id!, fornecedor)
          : await FornecedorService.salvarFornecedor(fornecedor);

      if (resultado['success']) {
        _showSuccessSnackBar(resultado['message']);
        _limparFormulario();
        await _carregarFornecedores();
        Navigator.of(context).pop();
      } else {
        ErrorUtils.showVisibleError(context, resultado['message']);
      }
    } catch (e) {
      String errorMessage = "Erro inesperado ao salvar fornecedor";
      if (e.toString().contains('CNPJ já cadastrado')) {
        errorMessage = "Este CNPJ já está cadastrado para outro fornecedor";
      } else if (e.toString().contains('Duplicated entry') && e.toString().contains('cnpj')) {
        errorMessage = "Este CNPJ já está cadastrado para outro fornecedor";
      } else if (e.toString().contains('já cadastrado')) {
        errorMessage = "Fornecedor com esses dados já existe no sistema";
      } else if (e.toString().contains('Duplicate entry')) {
        errorMessage = "Fornecedor com esses dados já existe no sistema";
      }
      ErrorUtils.showVisibleError(context, errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _editarFornecedor(Fornecedor fornecedor) {
    setState(() {
      _nomeController.text = fornecedor.nome;
      _emailController.text = fornecedor.email;

      // Formata a margem de lucro com vírgula
      final margemPercentual = (fornecedor.margemLucro ?? 0) * 100;
      _margemLucroController.text = margemPercentual.toStringAsFixed(2).replaceAll('.', ',');

      _ruaController.text = fornecedor.rua ?? '';
      _numeroCasaController.text = fornecedor.numeroCasa ?? '';
      _bairroController.text = fornecedor.bairro ?? '';
      _cidadeController.text = fornecedor.cidade ?? '';
      _ufController.text = fornecedor.uf ?? '';

      if (fornecedor.cnpj.isNotEmpty) {
        _cnpjController.text = fornecedor.cnpj.length == 14 ? _maskCnpj.maskText(fornecedor.cnpj) : fornecedor.cnpj;
      }
      if (fornecedor.telefone.isNotEmpty) {
        _telefoneController.text = _maskTelefone.maskText(fornecedor.telefone);
      }

      _fornecedorEmEdicao = fornecedor;
    });
    _showFormModal();
  }

  void _confirmarExclusao(Fornecedor fornecedor) {
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
          content: Text('Deseja excluir o fornecedor ${fornecedor.nome}?'),
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
                await _excluirFornecedor(fornecedor);
              },
              child: const Text('Excluir'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _excluirFornecedor(Fornecedor fornecedor) async {
    setState(() => _isLoading = true);
    try {
      final resultado = await FornecedorService.excluirFornecedor(fornecedor.id!);
      if (resultado['success']) {
        await _carregarFornecedores();
        _showSuccessSnackBar('Fornecedor excluído com sucesso');
      } else {
        ErrorUtils.showVisibleError(context, resultado['message']);
      }
    } catch (e) {
      String errorMessage = "Erro inesperado ao excluir fornecedor";
      if (e.toString().contains('Fornecedor não pode ser excluído')) {
        errorMessage = "Fornecedor em uso";
      } else if (e.toString().contains('vinculado')) {
        errorMessage = "Fornecedor em uso";
      }
      ErrorUtils.showVisibleError(context, errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    _nomeController.clear();
    _cnpjController.clear();
    _telefoneController.clear();
    _emailController.clear();
    _margemLucroController.clear();
    _ruaController.clear();
    _numeroCasaController.clear();
    _bairroController.clear();
    _cidadeController.clear();
    _ufController.clear();
    _fornecedorEmEdicao = null;
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
                      _fornecedorEmEdicao != null ? Icons.edit : Icons.add,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _fornecedorEmEdicao != null ? 'Editar Fornecedor' : 'Novo Fornecedor',
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
          hintText: 'Pesquisar por nome ou CNPJ...',
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

  Widget _buildSupplierGrid() {
    if (_isLoadingFornecedores) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_fornecedoresFiltrados.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                _searchController.text.isEmpty ? Icons.store_outlined : Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isEmpty ? 'Nenhum fornecedor cadastrado' : 'Nenhum resultado encontrado',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_searchController.text.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Comece adicionando seu primeiro fornecedor',
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
        if (constraints.maxWidth >= 1100) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth >= 700) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        double childAspectRatio;
        if (crossAxisCount == 1) {
          childAspectRatio = 3.2;
        } else if (crossAxisCount == 2) {
          childAspectRatio = 2.2;
        } else {
          childAspectRatio = 1.4;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _fornecedoresFiltrados.length,
          itemBuilder: (context, index) => _buildSupplierCard(_fornecedoresFiltrados[index]),
        );
      },
    );
  }

  Widget _buildSupplierCard(Fornecedor fornecedor) {
    final margem = (fornecedor.margemLucro ?? 0) * 100;
    Color margemColor = successColor;

    if (margem < 10) {
      margemColor = errorColor;
    } else if (margem < 15) {
      margemColor = warningColor;
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
          onTap: () => _editarFornecedor(fornecedor),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: primaryColor.withOpacity(0.1),
                      child: Icon(
                        Icons.store,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fornecedor.nome,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: margemColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Margem: ${margem.toStringAsFixed(2).replaceAll('.', ',')}%',
                              style: TextStyle(
                                color: margemColor,
                                fontSize: 11,
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
                          _editarFornecedor(fornecedor);
                        } else if (value == 'delete') {
                          _confirmarExclusao(fornecedor);
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
                const SizedBox(height: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.badge, _maskCnpj.maskText(fornecedor.cnpj)),
                      _buildInfoRow(Icons.phone, _maskTelefone.maskText(fornecedor.telefone)),
                      _buildInfoRow(Icons.email, fornecedor.email),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!, width: 1),
                  ),
                  child: Column(
                    children: [
                      if (fornecedor.createdAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(
                                'Cadastrado: ${DateFormat('dd/MM/yyyy').format(fornecedor.createdAt!)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
            label: 'Nome do Fornecedor',
            icon: Icons.store,
            validator: (v) => v!.isEmpty ? 'Informe o nome' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _cnpjController,
            label: 'CNPJ',
            icon: Icons.badge,
            keyboardType: TextInputType.number,
            inputFormatters: [_maskCnpj],
            readOnly: _fornecedorEmEdicao != null,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Informe o CNPJ';
              if (!CNPJValidator.isValid(v)) return 'CNPJ inválido';
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
                  keyboardType: TextInputType.number,
                  inputFormatters: [_maskTelefone],
                  validator: (v) => v!.isEmpty ? 'Informe o telefone' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _margemLucroController,
                  label: 'Margem de Lucro',
                  icon: Icons.trending_up,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [_decimalFormatter],
                  suffixText: '%',
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Informe a margem';
                    }
                    final valueStr = v.replaceAll(',', '.');
                    final value = double.tryParse(valueStr);
                    if (value == null) {
                      return 'Valor inválido';
                    }
                    return null;
                  },
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
          const SizedBox(height: 24),
          Text(
            'Endereço',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _ruaController,
            label: 'Rua',
            icon: Icons.location_on,
            validator: (v) => v!.isEmpty ? 'Informe a rua' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: _bairroController,
                  label: 'Bairro',
                  icon: Icons.location_city,
                  validator: (v) => v!.isEmpty ? 'Informe o bairro' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildTextField(
                  controller: _numeroCasaController,
                  label: 'Número',
                  icon: Icons.home,
                  keyboardType: TextInputType.text,
                  validator: (v) => v!.isEmpty ? 'Informe o número' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: _cidadeController,
                  label: 'Cidade',
                  icon: Icons.location_city,
                  validator: (v) => v!.isEmpty ? 'Informe a cidade' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildTextField(
                  controller: _ufController,
                  label: 'UF',
                  icon: Icons.map,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(2),
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                  ],
                  validator: (v) => v!.isEmpty ? 'Informe a UF' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _salvarFornecedor,
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
                      _fornecedorEmEdicao != null ? 'Atualizar Fornecedor' : 'Cadastrar Fornecedor',
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
    String? suffixText,
    bool readOnly = false,
    VoidCallback? onTap,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      textCapitalization: textCapitalization,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffixText,
        prefixIcon: Icon(icon, color: primaryColor),
        suffixIcon: (readOnly && onTap != null) ? Icon(Icons.calendar_today, color: primaryColor) : null,
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
          'Gestão de Fornecedores',
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
              if (_searchController.text.isEmpty && !_isLoadingFornecedores && _fornecedoresFiltrados.isNotEmpty)
                Text(
                  'Últimos Fornecedores Cadastrados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              if (_searchController.text.isNotEmpty && !_isLoadingFornecedores)
                Text(
                  'Resultados da Busca (${_fornecedoresFiltrados.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              const SizedBox(height: 16),
              _buildSupplierGrid(),
            ],
          ),
        ),
      ),
    );
  }
}
