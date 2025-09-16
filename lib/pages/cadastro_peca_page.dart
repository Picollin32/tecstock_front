import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/fabricante.dart';
import '../model/fornecedor.dart';
import '../model/peca.dart';
import '../services/fabricante_service.dart';
import '../services/fornecedor_service.dart';
import '../services/peca_service.dart';
import 'entrada_estoque_page.dart';

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
  final _estoqueSegurancaController = TextEditingController();
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
  String _filtroEstoque = 'todos';

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
    _estoqueSegurancaController.dispose();
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
      _showError('Erro ao carregar dados');
    } finally {
      setState(() => _isLoadingPecas = false);
    }
  }

  Future<void> _carregarPecas() async {
    try {
      final listaPecas = await PecaService.listarPecas();
      setState(() {
        _pecas = listaPecas
          ..sort((a, b) {
            final dataA = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final dataB = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return dataB.compareTo(dataA);
          });
        _filtrarPecas();
      });
    } catch (e) {
      _showError('Erro ao carregar peças');
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
      _showError('Erro ao carregar fornecedores e fabricantes');
    }
  }

  void _filtrarPecas() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      List<Peca> pecasFiltradas = _pecas;

      if (query.isNotEmpty) {
        pecasFiltradas = pecasFiltradas.where((peca) {
          return peca.codigoFabricante.toLowerCase().contains(query) || peca.nome.toLowerCase().contains(query);
        }).toList();
      }

      if (_filtroEstoque != 'todos') {
        pecasFiltradas = pecasFiltradas.where((peca) {
          final status = _getStockStatus(peca.quantidadeEstoque, peca.estoqueSeguranca);
          return status['status'] == _filtroEstoque;
        }).toList();
      }

      if (query.isEmpty && _filtroEstoque == 'todos') {
        _pecasFiltradas = pecasFiltradas.take(6).toList();
      } else {
        _pecasFiltradas = pecasFiltradas;
      }
    });
  }

  void _calcularPrecoFinal() {
    final precoUnitario = double.tryParse(_precoUnitarioController.text.replaceAll(',', '.')) ?? 0.0;
    final margemLucro = _fornecedorSelecionado?.margemLucro ?? 0.0;
    final margemDecimal = margemLucro > 1 ? margemLucro / 100 : margemLucro;

    final precoFinal = precoUnitario * (1 + margemDecimal);
    _precoFinalController.text = "R\$ ${precoFinal.toStringAsFixed(2).replaceAll('.', ',')}";
  }

  void _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      double preco = double.parse(_precoUnitarioController.text.replaceAll(',', '.'));
      double precoFinal = double.parse(_precoFinalController.text.replaceAll('R\$ ', '').replaceAll(',', '.'));

      final peca = Peca(
        id: _pecaEmEdicao?.id,
        nome: _nomeController.text,
        fabricante: _fabricanteSelecionado!,
        fornecedor: _fornecedorSelecionado,
        codigoFabricante: _codigoFabricanteController.text,
        precoUnitario: preco,
        precoFinal: precoFinal,
        quantidadeEstoque: _pecaEmEdicao?.quantidadeEstoque ?? 0,
        estoqueSeguranca: int.parse(_estoqueSegurancaController.text),
      );

      Map<String, dynamic> resultado;
      if (_pecaEmEdicao != null) {
        resultado = await PecaService.atualizarPeca(_pecaEmEdicao!.id!, peca);
      } else {
        resultado = await PecaService.salvarPeca(peca);
      }

      if (resultado['sucesso']) {
        Navigator.of(context).pop();
        _showSuccessSnackBar(resultado['mensagem']);
        _limparFormulario();
        await _carregarPecas();
      } else {
        _showVisibleError(resultado['mensagem']);
      }
    } catch (e) {
      _showVisibleError("Erro inesperado ao salvar peça: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _editarPeca(Peca peca) {
    setState(() {
      _nomeController.text = peca.nome;
      _codigoFabricanteController.text = peca.codigoFabricante;
      _precoUnitarioController.text = peca.precoUnitario.toStringAsFixed(2).replaceAll('.', ',');
      _precoFinalController.text = "R\$ ${peca.precoFinal.toStringAsFixed(2).replaceAll('.', ',')}";
      _estoqueSegurancaController.text = peca.estoqueSeguranca.toString();
      _fabricanteSelecionado = _fabricantes.firstWhere((f) => f.id == peca.fabricante.id, orElse: () => _fabricantes.first);
      _fornecedorSelecionado = peca.fornecedor != null ? _fornecedores.firstWhere((fo) => fo.id == peca.fornecedor!.id) : null;
      _pecaEmEdicao = peca;
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
      final resultado = await PecaService.excluirPeca(peca.id!);
      if (resultado['sucesso']) {
        await _carregarPecas();
        _showSuccessSnackBar(resultado['mensagem']);
      } else {
        _showVisibleError(resultado['mensagem']);
      }
    } catch (e) {
      _showVisibleError('Erro inesperado ao excluir peça: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    _nomeController.clear();
    _codigoFabricanteController.clear();
    _precoUnitarioController.clear();
    _estoqueSegurancaController.clear();
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

  void _showVisibleError(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: errorColor, size: 24),
              const SizedBox(width: 8),
              const Text('Erro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    _showVisibleError(message);
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
      String emptyMessage;
      String emptySubtitle;
      IconData emptyIcon;

      if (_filtroEstoque == 'critico') {
        emptyMessage = 'Nenhuma peça crítica encontrada';
        emptySubtitle = 'Todas as peças têm estoque adequado!';
        emptyIcon = Icons.check_circle_outline;
      } else if (_filtroEstoque == 'sem_estoque') {
        emptyMessage = 'Nenhuma peça sem estoque encontrada';
        emptySubtitle = 'Todas as peças têm estoque!';
        emptyIcon = Icons.check_circle_outline;
      } else if (_searchController.text.isNotEmpty) {
        emptyMessage = 'Nenhum resultado encontrado';
        emptySubtitle = 'Tente ajustar os termos da busca';
        emptyIcon = Icons.search_off;
      } else {
        emptyMessage = 'Nenhuma peça cadastrada';
        emptySubtitle = 'Comece adicionando sua primeira peça';
        emptyIcon = Icons.inventory_2_outlined;
      }

      return Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                emptyIcon,
                size: 64,
                color: (_filtroEstoque != 'todos') ? successColor : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: (_filtroEstoque != 'todos') ? successColor : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                style: TextStyle(
                  color: (_filtroEstoque != 'todos') ? successColor.withOpacity(0.7) : Colors.grey[500],
                ),
              ),
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
          childAspectRatio = 2.6;
        } else if (crossAxisCount == 2) {
          childAspectRatio = 1.6;
        } else {
          childAspectRatio = 1.1;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _pecasFiltradas.length,
          itemBuilder: (context, index) => _buildPartCard(_pecasFiltradas[index]),
        );
      },
    );
  }

  Widget _buildPartCard(Peca peca) {
    final stockStatus = _getStockStatus(peca.quantidadeEstoque, peca.estoqueSeguranca);

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
          onTap: () {
            // _editarPeca(peca);
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.inventory_2,
                        color: primaryColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            peca.nome,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Venda: R\$ ${peca.precoFinal.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: successColor,
                                fontSize: 10,
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
                          _editarPeca(peca);
                        } else if (value == 'delete') {
                          _confirmarExclusao(peca);
                        }
                      },
                      itemBuilder: (context) => [
                        // const PopupMenuItem(
                        //   value: 'edit',
                        //   child: Row(
                        //     children: [
                        //       Icon(Icons.edit, size: 18),
                        //       SizedBox(width: 8),
                        //       Text('Editar'),
                        //     ],
                        //   ),
                        // ),
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
                const SizedBox(height: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.qr_code, peca.codigoFabricante),
                      _buildInfoRow(Icons.business, peca.fabricante.nome),
                      _buildInfoRow(
                        Icons.store,
                        peca.fornecedor != null
                            ? "${peca.fornecedor!.nome} (+${(peca.fornecedor!.margemLucro! > 1 ? peca.fornecedor!.margemLucro! : peca.fornecedor!.margemLucro! * 100).toStringAsFixed(0)}%)"
                            : "Não informado",
                      ),
                      _buildInfoRow(Icons.attach_money, 'Custo: R\$ ${peca.precoUnitario.toStringAsFixed(2)}', isPrice: true),
                      _buildInfoRow(Icons.sell, 'Venda: R\$ ${peca.precoFinal.toStringAsFixed(2)}', isPrice: true, isFinalPrice: true),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!, width: 1),
                  ),
                  child: Column(
                    children: [
                      if (peca.createdAt != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(
                                'Cadastrado: ${DateFormat('dd/MM/yyyy').format(peca.createdAt!)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          Icon(Icons.inventory, size: 12, color: stockStatus['color']),
                          const SizedBox(width: 6),
                          Text(
                            'Estoque: ${peca.quantidadeEstoque} unid.',
                            style: TextStyle(
                              color: stockStatus['color'],
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: stockStatus['color'].withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              stockStatus['label'],
                              style: TextStyle(
                                color: stockStatus['color'],
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            stockStatus['icon'],
                            color: stockStatus['color'],
                            size: 14,
                          ),
                        ],
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

  Map<String, dynamic> _getStockStatus(int quantidadeAtual, int estoqueSeguranca) {
    if (quantidadeAtual <= 0) {
      return {'icon': Icons.error, 'color': errorColor, 'status': 'sem_estoque', 'label': 'Sem Estoque'};
    } else if (quantidadeAtual < (estoqueSeguranca / 2).ceil()) {
      return {'icon': Icons.warning, 'color': warningColor, 'status': 'critico', 'label': 'Crítico'};
    } else {
      return {'icon': Icons.check_circle, 'color': successColor, 'status': 'ok', 'label': 'OK'};
    }
  }

  int _contarPecasCriticas() {
    return _pecas.where((peca) {
      final status = _getStockStatus(peca.quantidadeEstoque, peca.estoqueSeguranca);
      return status['status'] == 'critico';
    }).length;
  }

  int _contarPecasSemEstoque() {
    return _pecas.where((peca) {
      final status = _getStockStatus(peca.quantidadeEstoque, peca.estoqueSeguranca);
      return status['status'] == 'sem_estoque';
    }).length;
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
                  controller: _estoqueSegurancaController,
                  label: 'Estoque de Segurança',
                  icon: Icons.inventory,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe o estoque de segurança';
                    }
                    if (int.tryParse(value) == null || int.parse(value) < 0) {
                      return 'Digite um número válido';
                    }
                    return null;
                  },
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
                            child: Text(
                                "${fornecedor.nome} (+${(fornecedor.margemLucro! > 1 ? fornecedor.margemLucro! : fornecedor.margemLucro! * 100).toStringAsFixed(0)}%)"),
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
                  const SizedBox(width: 12),
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
                      tooltip: 'Nova Peça',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: successColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: successColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () async {
                        await EntradaEstoquePage.showModal(context);

                        await _carregarPecas();
                      },
                      icon: const Icon(Icons.add_box, color: Colors.white),
                      iconSize: 28,
                      padding: const EdgeInsets.all(12),
                      tooltip: 'Entrada de Estoque',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: _filtroEstoque == 'critico' ? warningColor : Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (_filtroEstoque == 'critico' ? warningColor : Colors.grey).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _filtroEstoque = _filtroEstoque == 'critico' ? 'todos' : 'critico';
                            });
                            _filtrarPecas();
                          },
                          icon: Icon(
                            Icons.warning_amber,
                            color: _filtroEstoque == 'critico' ? Colors.white : Colors.grey[600],
                          ),
                          iconSize: 24,
                          padding: const EdgeInsets.all(12),
                          tooltip: _filtroEstoque == 'critico' ? 'Mostrar todas as peças' : 'Filtrar peças críticas',
                        ),
                      ),
                      if (_contarPecasCriticas() > 0 && _filtroEstoque != 'critico')
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: warningColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              '${_contarPecasCriticas()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: _filtroEstoque == 'sem_estoque' ? errorColor : Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (_filtroEstoque == 'sem_estoque' ? errorColor : Colors.grey).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _filtroEstoque = _filtroEstoque == 'sem_estoque' ? 'todos' : 'sem_estoque';
                            });
                            _filtrarPecas();
                          },
                          icon: Icon(
                            Icons.error,
                            color: _filtroEstoque == 'sem_estoque' ? Colors.white : Colors.grey[600],
                          ),
                          iconSize: 24,
                          padding: const EdgeInsets.all(12),
                          tooltip: _filtroEstoque == 'sem_estoque' ? 'Mostrar todas as peças' : 'Filtrar peças sem estoque',
                        ),
                      ),
                      if (_contarPecasSemEstoque() > 0 && _filtroEstoque != 'sem_estoque')
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: errorColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              '${_contarPecasSemEstoque()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_searchController.text.isEmpty && _filtroEstoque == 'todos' && !_isLoadingPecas && _pecasFiltradas.isNotEmpty)
                Text(
                  'Movimentações Recentes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              if (_filtroEstoque == 'critico' && _searchController.text.isEmpty && !_isLoadingPecas)
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: warningColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Peças com Estoque Crítico (${_pecasFiltradas.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: warningColor,
                      ),
                    ),
                  ],
                ),
              if (_filtroEstoque == 'sem_estoque' && _searchController.text.isEmpty && !_isLoadingPecas)
                Row(
                  children: [
                    Icon(Icons.error, color: errorColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Peças Sem Estoque (${_pecasFiltradas.length})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: errorColor,
                      ),
                    ),
                  ],
                ),
              if (_searchController.text.isNotEmpty && !_isLoadingPecas)
                Text(
                  'Resultados da Busca${_filtroEstoque != 'todos' ? ' - ${_filtroEstoque == 'critico' ? 'Apenas Críticas' : 'Sem Estoque'}' : ''} (${_pecasFiltradas.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _filtroEstoque != 'todos' ? (_filtroEstoque == 'critico' ? warningColor : errorColor) : Colors.grey[800],
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
