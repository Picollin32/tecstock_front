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

class _CadastroPecaPageState extends State<CadastroPecaPage> with TickerProviderStateMixin {
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

  List<Peca> _pecas = [];
  List<Peca> _pecasFiltradas = [];
  Peca? _pecaEmEdicao;

  bool _isLoading = false;
  bool _isLoadingPecas = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF059669);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color shadowColor = Color(0x1A000000);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _carregarDados();
    _searchController.addListener(_filtrarPecas);
    _precoUnitarioController.addListener(_calcularPrecoFinal);
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

  Future<void> _carregarDados() async {
    setState(() => _isLoadingPecas = true);
    try {
      await Future.wait([
        _carregarPecas(),
        _carregarFornecedoresEFabricantes(),
      ]);
    } catch (e) {
      _showErrorSnackBar('Erro ao carregar dados');
    } finally {
      setState(() => _isLoadingPecas = false);
    }
  }

  Future<void> _carregarPecas() async {
    try {
      final listaPecas = await PecaService.listarPecas();
      setState(() {
        _pecas = listaPecas.reversed.toList();
        _filtrarPecas();
      });
    } catch (e) {
      _showErrorSnackBar('Erro ao carregar peças');
    }
  }

  Future<void> _carregarFornecedoresEFabricantes() async {
    try {
      final listaFornecedores = await FornecedorService.listarFornecedores();
      final listaFabricantes = await FabricanteService.listarFabricantes();
      listaFabricantes.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

      setState(() {
        _fornecedores = listaFornecedores;
        _fabricantes = listaFabricantes;
      });
    } catch (e) {
      _showErrorSnackBar('Erro ao carregar fornecedores e fabricantes');
    }
  }

  void _filtrarPecas() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _pecasFiltradas = _pecas.take(6).toList();
      } else {
        _pecasFiltradas = _pecas.where((peca) {
          return peca.codigoFabricante.toLowerCase().contains(query) || peca.nome.toLowerCase().contains(query);
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
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

      if (sucesso) {
        _showSuccessSnackBar(_pecaEmEdicao != null ? "Peça atualizada com sucesso" : "Peça cadastrada com sucesso");
        _limparFormulario();
        await _carregarPecas();
        Navigator.of(context).pop();
      } else {
        _showErrorSnackBar("Erro ao salvar peça");
      }
    } catch (e) {
      _showErrorSnackBar("Erro inesperado ao salvar peça");
    } finally {
      setState(() => _isLoading = false);
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
      _pecaEmEdicao = peca;
      _calcularPrecoFinal();
    });
    _showFormModal();
  }

  void _confirmarExclusao(Peca peca) {
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
          content: Text('Deseja excluir a peça ${peca.nome}?'),
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
                await _excluirPeca(peca);
              },
              child: const Text('Excluir'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _excluirPeca(Peca peca) async {
    setState(() => _isLoading = true);
    try {
      final sucesso = await PecaService.excluirPeca(peca.id!);
      if (sucesso) {
        await _carregarPecas();
        _showSuccessSnackBar('Peça excluída com sucesso');
      } else {
        _showErrorSnackBar('Erro ao excluir peça');
      }
    } catch (e) {
      _showErrorSnackBar('Erro inesperado ao excluir peça');
    } finally {
      setState(() => _isLoading = false);
    }
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: errorColor,
        duration: const Duration(seconds: 4),
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
                      _pecaEmEdicao != null ? Icons.edit : Icons.add,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _pecaEmEdicao != null ? 'Editar Peça' : 'Nova Peça',
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
          hintText: 'Pesquisar por nome ou código...',
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

  Widget _buildPartGrid() {
    if (_isLoadingPecas) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_pecasFiltradas.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                _searchController.text.isEmpty ? Icons.inventory_2_outlined : Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isEmpty ? 'Nenhuma peça cadastrada' : 'Nenhum resultado encontrado',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_searchController.text.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Comece adicionando sua primeira peça',
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
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.85,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _pecasFiltradas.length,
          itemBuilder: (context, index) => _buildPartCard(_pecasFiltradas[index]),
        );
      },
    );
  }

  Widget _buildPartCard(Peca peca) {
    final precoFinal = peca.precoUnitario * (1 + (peca.fornecedor?.margemLucro ?? 0.0));
    final stockStatus = _getStockStatus(peca.quantidadeEstoque);

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
          onTap: () => _editarPeca(peca),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        peca.nome,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editarPeca(peca);
                        } else if (value == 'delete') {
                          _confirmarExclusao(peca);
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
                _buildInfoRow(Icons.qr_code, peca.codigoFabricante),
                _buildInfoRow(Icons.business, peca.fabricante.nome),
                _buildInfoRow(Icons.store, peca.fornecedor?.nome ?? "Não informado"),
                _buildInfoRow(Icons.attach_money, 'R\$ ${peca.precoUnitario.toStringAsFixed(2)}', isPrice: true),
                _buildInfoRow(Icons.sell, 'R\$ ${precoFinal.toStringAsFixed(2)}', isPrice: true, isFinalPrice: true),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: stockStatus['color'].withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${peca.quantidadeEstoque} unid.',
                        style: TextStyle(
                          color: stockStatus['color'],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      stockStatus['icon'],
                      color: stockStatus['color'],
                      size: 16,
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

  Map<String, dynamic> _getStockStatus(int quantidade) {
    if (quantidade <= 0) {
      return {'icon': Icons.error, 'color': errorColor};
    } else if (quantidade <= 10) {
      return {'icon': Icons.warning, 'color': warningColor};
    } else {
      return {'icon': Icons.check_circle, 'color': successColor};
    }
  }

  Widget _buildInfoRow(IconData icon, String text, {bool isPrice = false, bool isFinalPrice = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: isPrice ? (isFinalPrice ? successColor : warningColor) : Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isPrice ? (isFinalPrice ? successColor : warningColor) : Colors.grey[700],
                fontWeight: isPrice ? FontWeight.w600 : FontWeight.normal,
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
            label: 'Nome da Peça',
            icon: Icons.inventory_2,
            validator: (v) => v!.isEmpty ? 'Informe o nome' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _codigoFabricanteController,
            label: 'Código do Fabricante',
            icon: Icons.qr_code,
            validator: (v) => v!.isEmpty ? 'Informe o código' : null,
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            value: _fabricanteSelecionado,
            label: 'Fabricante',
            icon: Icons.business,
            items: _fabricantes
                .map((fabricante) => DropdownMenuItem<Fabricante>(
                      value: fabricante,
                      child: Text(fabricante.nome),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _fabricanteSelecionado = value),
            validator: (value) => value == null ? 'Selecione um fabricante' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _precoUnitarioController,
                  label: 'Preço Unitário (Custo)',
                  icon: Icons.attach_money,
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
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _quantidadeEstoqueController,
                  label: 'Estoque',
                  icon: Icons.inventory,
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Informe o estoque' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.store, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Informações de Venda',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  value: _fornecedorSelecionado,
                  label: 'Fornecedor',
                  icon: Icons.store,
                  items: _fornecedores
                      .map((fornecedor) => DropdownMenuItem<Fornecedor>(
                            value: fornecedor,
                            child: Text("${fornecedor.nome} (+${(fornecedor.margemLucro! * 100).toStringAsFixed(0)}%)"),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _fornecedorSelecionado = value;
                      _calcularPrecoFinal();
                    });
                  },
                  validator: (value) => value == null ? 'Selecione um fornecedor' : null,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _precoFinalController,
                  label: 'Preço Final (Venda)',
                  icon: Icons.sell,
                  enabled: false,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: successColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _salvar,
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
                      _pecaEmEdicao != null ? 'Atualizar Peça' : 'Cadastrar Peça',
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
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool enabled = true,
    TextStyle? style,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      style: style,
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
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
        fillColor: enabled ? Colors.grey[50] : Colors.grey[100],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Gestão de Peças',
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
              if (_searchController.text.isEmpty && !_isLoadingPecas && _pecasFiltradas.isNotEmpty)
                Text(
                  'Últimas Peças Cadastradas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              if (_searchController.text.isNotEmpty && !_isLoadingPecas)
                Text(
                  'Resultados da Busca (${_pecasFiltradas.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              const SizedBox(height: 16),
              _buildPartGrid(),
            ],
          ),
        ),
      ),
    );
  }
}
