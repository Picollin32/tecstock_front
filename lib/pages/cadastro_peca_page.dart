import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../model/fabricante.dart';
import '../model/fornecedor.dart';
import '../model/peca.dart';
import '../services/auth_service.dart';
import '../services/fabricante_service.dart';
import '../services/fornecedor_service.dart';
import '../services/peca_service.dart';
import '../services/ordem_servico_service.dart';
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

  final _numbersOnlyFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));

  Fornecedor? _fornecedorSelecionado;
  List<Fornecedor> _fornecedores = [];
  Fabricante? _fabricanteSelecionado;
  List<Fabricante> _fabricantes = [];
  int? _fornecedorFiltroId;
  final Set<int> _fornecedorIdsComPecas = {};
  List<Fornecedor> _fornecedoresFiltroDisponiveis = [];
  int? _fabricanteFiltroId;
  final Set<int> _fabricanteIdsComPecas = {};
  List<Fabricante> _fabricantesFiltroDisponiveis = [];

  List<Peca> _pecas = [];
  List<Peca> _pecasFiltradas = [];
  Peca? _pecaEmEdicao;
  Map<String, Map<String, dynamic>> _pecasEmOS = {};

  bool _isLoadingPecas = true;
  bool _isSaving = false;
  String _filtroEstoque = 'todos';
  StateSetter? _formModalSetState;

  Timer? _debounceTimer;
  int _currentPage = 0;
  int _totalPages = 0;
  int _totalElements = 0;
  final int _pageSize = 30;
  String _lastSearchQuery = '';
  String _pecaSearchMode = 'codigo';
  bool _filtrosExpandidos = false;

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
    _searchController.addListener(_onSearchChanged);
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
    _formModalSetState = null;
    _fadeController.dispose();
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _precoUnitarioController.removeListener(_calcularPrecoFinal);
    _nomeController.dispose();
    _codigoFabricanteController.dispose();
    _precoUnitarioController.dispose();
    _estoqueSegurancaController.dispose();
    _precoFinalController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _rebuildFormModal() {
    final setter = _formModalSetState;
    if (setter != null) {
      setter(() {});
    }
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoadingPecas = true);
    try {
      await Future.wait([
        _carregarPecas(),
        _carregarFornecedoresEFabricantes(),
        _carregarPecasEmOS(),
      ]);
    } catch (e) {
      _showError('Erro ao carregar dados');
    } finally {
      setState(() => _isLoadingPecas = false);
    }
  }

  Future<void> _carregarPecas() async {
    try {
      final resultado = await PecaService.buscarPaginado('', 0, size: _pageSize);

      if (resultado['success']) {
        final pecas = resultado['content'] as List<Peca>;
        final Set<int> fornecedoresEncontrados = pecas.map((p) => p.fornecedor?.id).whereType<int>().toSet();
        final Set<int> fabricantesEncontrados = pecas.map((p) => p.fabricante.id).whereType<int>().toSet();

        final filtradas = pecas.where((p) {
          final matchesFornecedor = _fornecedorFiltroId == null || p.fornecedor?.id == _fornecedorFiltroId;
          final matchesFabricante = _fabricanteFiltroId == null || p.fabricante.id == _fabricanteFiltroId;
          return matchesFornecedor && matchesFabricante;
        }).toList();

        setState(() {
          _pecas = pecas;
          _pecasFiltradas = filtradas;
          _totalPages = resultado['totalPages'] as int;
          _totalElements = resultado['totalElements'] as int;
          _currentPage = 0;
          _fornecedorIdsComPecas
            ..clear()
            ..addAll(fornecedoresEncontrados);
          _fabricanteIdsComPecas
            ..clear()
            ..addAll(fabricantesEncontrados);

          if (_fornecedorFiltroId != null && !_fornecedorIdsComPecas.contains(_fornecedorFiltroId)) {
            _fornecedorFiltroId = null;
          }
          if (_fabricanteFiltroId != null && !_fabricanteIdsComPecas.contains(_fabricanteFiltroId)) {
            _fabricanteFiltroId = null;
          }

          _fornecedoresFiltroDisponiveis = _fornecedores.where((f) => _fornecedorIdsComPecas.contains(f.id)).toList();
          _fabricantesFiltroDisponiveis = _fabricantes.where((f) => _fabricanteIdsComPecas.contains(f.id)).toList();
        });
      } else {
        _showError('Erro ao carregar peças');
      }
    } catch (e) {
      _showError('Erro ao carregar peças');
    }
  }

  Future<void> _carregarFornecedoresEFabricantes() async {
    try {
      final listaFornecedores = await FornecedorService.listarFornecedores();
      final listaFornecedoresPecas = listaFornecedores.where((f) => !f.servico).toList();
      final listaFabricantes = await FabricanteService.listarFabricantes();
      listaFornecedoresPecas.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
      listaFabricantes.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

      setState(() {
        _fornecedores = listaFornecedoresPecas;
        _fabricantes = listaFabricantes;
        _fornecedoresFiltroDisponiveis = _fornecedores.where((f) => _fornecedorIdsComPecas.contains(f.id)).toList();
        _fabricantesFiltroDisponiveis = _fabricantes.where((f) => _fabricanteIdsComPecas.contains(f.id)).toList();
      });
      _rebuildFormModal();
    } catch (e) {
      _showError('Erro ao carregar fornecedores e fabricantes');
    }
  }

  Future<void> _carregarPecasEmOS() async {
    try {
      final pecasEmOS = await OrdemServicoService.buscarPecasEmOSAbertas();
      setState(() {
        _pecasEmOS = pecasEmOS;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao carregar peças em OS: $e');
      }
    }
  }

  void _onSearchChanged({bool force = false}) {
    final query = _searchController.text.trim();
    final composite = '$_pecaSearchMode|$query';
    if (!force && composite == _lastSearchQuery) return;
    _lastSearchQuery = composite;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _currentPage = 0;
      });
      _filtrarPecas();
    });
  }

  bool _matchesPecaQuery(Peca peca, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    if (_pecaSearchMode == 'nome') {
      final nome = peca.nome.toLowerCase();
      return nome.startsWith(normalizedQuery);
    }
    final codigo = peca.codigoFabricante.toLowerCase();
    return codigo.startsWith(normalizedQuery);
  }

  Future<void> _filtrarPecas() async {
    final rawQuery = _searchController.text.trim();
    final query = _pecaSearchMode == 'codigo' ? rawQuery.replaceAll(' ', '').toLowerCase() : rawQuery.toLowerCase();
    setState(() => _isLoadingPecas = true);

    try {
      final resultado = await PecaService.buscarPaginado(
        query,
        _currentPage,
        size: _pageSize,
        fornecedorId: _fornecedorFiltroId,
        fabricanteId: _fabricanteFiltroId,
      );

      if (resultado['success']) {
        final pecas = resultado['content'] as List<Peca>;
        final Set<int> fornecedoresEncontrados = pecas.map((p) => p.fornecedor?.id).whereType<int>().toSet();
        final Set<int> fabricantesEncontrados = pecas.map((p) => p.fabricante.id).whereType<int>().toSet();

        List<Peca> pecasFiltradas = pecas.where((p) {
          final matchesFornecedor = _fornecedorFiltroId == null || p.fornecedor?.id == _fornecedorFiltroId;
          final matchesFabricante = _fabricanteFiltroId == null || p.fabricante.id == _fabricanteFiltroId;
          final matchesQuery = _matchesPecaQuery(p, query);
          return matchesFornecedor && matchesFabricante && matchesQuery;
        }).toList();

        if (_filtroEstoque != 'todos') {
          pecasFiltradas = pecasFiltradas.where((peca) {
            if (_filtroEstoque == 'em_uso') {
              return peca.unidadesUsadasEmOS != null && peca.unidadesUsadasEmOS! > 0;
            }
            final status = _getStockStatus(peca.quantidadeEstoque, peca.estoqueSeguranca);
            return status['status'] == _filtroEstoque;
          }).toList();
        }

        setState(() {
          _pecasFiltradas = pecasFiltradas;
          _totalPages = resultado['totalPages'] as int;
          _totalElements = resultado['totalElements'] as int;
          _fornecedorIdsComPecas
            ..clear()
            ..addAll(fornecedoresEncontrados);
          _fabricanteIdsComPecas
            ..clear()
            ..addAll(fabricantesEncontrados);

          if (_fornecedorFiltroId != null && !_fornecedorIdsComPecas.contains(_fornecedorFiltroId)) {
            _fornecedorFiltroId = null;
          }
          if (_fabricanteFiltroId != null && !_fabricanteIdsComPecas.contains(_fabricanteFiltroId)) {
            _fabricanteFiltroId = null;
          }

          _fornecedoresFiltroDisponiveis = _fornecedores.where((f) => _fornecedorIdsComPecas.contains(f.id)).toList();
          _fabricantesFiltroDisponiveis = _fabricantes.where((f) => _fabricanteIdsComPecas.contains(f.id)).toList();
        });
      } else {
        if (!mounted) return;
        _showError('Erro ao buscar peças');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Erro ao buscar peças');
    } finally {
      setState(() => _isLoadingPecas = false);
    }
  }

  void _paginaAnterior() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _filtrarPecas();
    }
  }

  void _proximaPagina() {
    if (_currentPage < _totalPages - 1) {
      setState(() => _currentPage++);
      _filtrarPecas();
    }
  }

  void _calcularPrecoFinal() {
    final precoUnitario = double.tryParse(_precoUnitarioController.text.replaceAll(',', '.')) ?? 0.0;
    final margemLucro = _fornecedorSelecionado?.margemLucro ?? 0.0;
    final margemDecimal = margemLucro > 1 ? margemLucro / 100 : margemLucro;

    final precoFinal = precoUnitario * (1 + margemDecimal);
    _precoFinalController.text = "R\$ ${precoFinal.toStringAsFixed(2).replaceAll('.', ',')}";
  }

  double _margemLucroPercentual(double? margemLucro) {
    final margem = margemLucro ?? 0.0;
    return margem > 1 ? margem : margem * 100;
  }

  String _fornecedorComMargem(Fornecedor fornecedor) {
    final percentual = _margemLucroPercentual(fornecedor.margemLucro);
    return "${fornecedor.nome} (+${percentual.toStringAsFixed(2)}%)";
  }

  void _salvar() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

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
        if (!mounted) return;
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
      setState(() {
        _isSaving = false;
      });
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
      final fornecedorDaPeca = peca.fornecedor;
      _fornecedorSelecionado = fornecedorDaPeca != null ? _fornecedores.where((fo) => fo.id == fornecedorDaPeca.id).firstOrNull : null;
      _pecaEmEdicao = peca;
    });
    _showFormModal();
  }

  void _confirmarExclusao(Peca peca) {
    showDialog(
      context: context,
      builder: (_) => Theme(
        data: Theme.of(context).copyWith(
          dialogTheme: DialogThemeData(
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
    }
  }

  void _mostrarDialogoAjusteEstoque(Peca peca) {
    int ajuste = 0;
    final observacoesController = TextEditingController();
    final precoController = TextEditingController(text: peca.precoUnitario.toStringAsFixed(2));
    bool alterarPreco = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.tune, color: primaryColor, size: 28),
              const SizedBox(width: 12),
              const Text('Ajustar Estoque'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peca.nome,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Código: ${peca.codigoFabricante}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estoque Atual:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${peca.quantidadeEstoque} unid.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Ajuste:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setDialogState(() {
                          ajuste--;
                        });
                      },
                      icon: const Icon(Icons.remove_circle),
                      color: errorColor,
                      iconSize: 36,
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: ajuste == 0 ? Colors.grey[100] : (ajuste > 0 ? Colors.green[50] : Colors.red[50]),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ajuste == 0 ? Colors.grey[300]! : (ajuste > 0 ? Colors.green[300]! : Colors.red[300]!),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              ajuste == 0 ? '0' : (ajuste > 0 ? '+$ajuste' : '$ajuste'),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: ajuste == 0 ? Colors.grey[600] : (ajuste > 0 ? successColor : errorColor),
                              ),
                            ),
                            Text(
                              'unidades',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setDialogState(() {
                          ajuste++;
                        });
                      },
                      icon: const Icon(Icons.add_circle),
                      color: successColor,
                      iconSize: 36,
                    ),
                  ],
                ),
                if (ajuste != 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ajuste > 0 ? Colors.green[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ajuste > 0 ? Colors.green[200]! : Colors.red[200]!,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Novo Estoque:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${peca.quantidadeEstoque + ajuste} unid.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: ajuste > 0 ? successColor : errorColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: observacoesController,
                  decoration: const InputDecoration(
                    labelText: 'Observações (opcional)',
                    hintText: 'Motivo do ajuste...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Checkbox(
                      value: alterarPreco,
                      onChanged: (valor) {
                        setDialogState(() {
                          alterarPreco = valor ?? false;
                        });
                      },
                    ),
                    const Text(
                      'Alterar Preço Unitário',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (alterarPreco) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: precoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Novo Preço Unitário',
                      prefixText: 'R\$ ',
                      border: const OutlineInputBorder(),
                      helperText: 'Preço atual: R\$ ${peca.precoUnitario.toStringAsFixed(2)}',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ajuste == 0 ? Colors.grey : primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: ajuste == 0
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _aplicarAjusteEstoque(
                        peca,
                        ajuste,
                        observacoesController.text.trim(),
                        alterarPreco ? double.tryParse(precoController.text.replaceAll(',', '.')) : null,
                      );
                    },
              child: const Text('Aplicar Ajuste'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _aplicarAjusteEstoque(Peca peca, int ajuste, String observacoes, [double? novoPrecoUnitario]) async {
    if (ajuste == 0) return;

    try {
      final resultado = await PecaService.ajustarEstoque(
        pecaId: peca.id!,
        ajuste: ajuste,
        observacoes: observacoes.isEmpty ? null : observacoes,
        novoPrecoUnitario: novoPrecoUnitario,
      );

      if (resultado['sucesso']) {
        await _carregarPecas();
        _showSuccessSnackBar(
          'Estoque ajustado: ${ajuste > 0 ? '+' : ''}$ajuste unidade${ajuste.abs() != 1 ? 's' : ''}',
        );
      } else {
        _showVisibleError(resultado['mensagem']);
      }
    } catch (e) {
      _showVisibleError('Erro ao ajustar estoque: $e');
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

  Future<Fabricante?> _abrirSeletorFabricanteAtualizado() async {
    await _carregarFornecedoresEFabricantes();
    if (!mounted) return null;

    if (_fabricantes.isEmpty) {
      _showVisibleError('Nenhum fabricante cadastrado.');
      return null;
    }

    return showModalBottomSheet<Fabricante>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Selecionar Fabricante',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _fabricantes.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                    itemBuilder: (_, index) {
                      final fabricante = _fabricantes[index];
                      return ListTile(
                        title: Text(fabricante.nome),
                        onTap: () => Navigator.pop(sheetCtx, fabricante),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Fornecedor?> _abrirSeletorFornecedorAtualizado() async {
    await _carregarFornecedoresEFabricantes();
    if (!mounted) return null;

    if (_fornecedores.isEmpty) {
      _showVisibleError('Nenhum fornecedor cadastrado.');
      return null;
    }

    return showModalBottomSheet<Fornecedor>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Selecionar Fornecedor',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _fornecedores.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
                    itemBuilder: (_, index) {
                      final fornecedor = _fornecedores[index];
                      return ListTile(
                        title: Text(_fornecedorComMargem(fornecedor)),
                        onTap: () => Navigator.pop(sheetCtx, fornecedor),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Fabricante?> _abrirGerenciarFabricantes() async {
    Fabricante? fabricanteSelecionadoNoGerenciador;
    bool carregouNoDialog = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setDialogState) {
            Future<void> recarregarFabricantes() async {
              await _carregarFornecedoresEFabricantes();
              if (!mounted) return;

              if (_fabricanteSelecionado != null && !_fabricantes.any((f) => f.id == _fabricanteSelecionado!.id)) {
                setState(() => _fabricanteSelecionado = null);
              }

              setDialogState(() {});
              _rebuildFormModal();
            }

            Future<void> abrirFormulario({Fabricante? fabricante}) async {
              final nomeCtrl = TextEditingController(text: fabricante?.nome ?? '');
              final formKey = GlobalKey<FormState>();
              final isEdicao = fabricante != null;
              const corFabricante = primaryColor;

              await showModalBottomSheet<void>(
                context: ctx2,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (sheetCtx) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
                    child: SafeArea(
                      top: false,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.88),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: const BoxDecoration(
                                    color: corFabricante,
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(isEdicao ? Icons.edit : Icons.add, color: Colors.white, size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          isEdicao ? 'Editar Fabricante' : 'Novo Fabricante',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => Navigator.pop(sheetCtx),
                                        icon: const Icon(Icons.close, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Form(
                                    key: formKey,
                                    child: Column(
                                      children: [
                                        TextFormField(
                                          controller: nomeCtrl,
                                          autovalidateMode: AutovalidateMode.onUserInteraction,
                                          validator: (v) {
                                            final value = (v ?? '').trim();
                                            if (value.isEmpty) return 'Informe o nome do fabricante';
                                            if (value.length < 2) return 'Nome muito curto';
                                            return null;
                                          },
                                          decoration: InputDecoration(
                                            labelText: 'Nome do Fabricante',
                                            prefixIcon: const Icon(Icons.business, color: corFabricante),
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
                                              borderSide: const BorderSide(color: corFabricante, width: 2),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey[50],
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 48,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: corFabricante,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: () async {
                                              if (!formKey.currentState!.validate()) return;

                                              final nome = nomeCtrl.text.trim();
                                              final result = isEdicao
                                                  ? await FabricanteService.atualizarFabricante(
                                                      fabricante.id!,
                                                      Fabricante(id: fabricante.id, nome: nome),
                                                    )
                                                  : await FabricanteService.salvarFabricante(Fabricante(nome: nome));

                                              if (result['success'] == true) {
                                                if (!mounted) return;
                                                if (!sheetCtx.mounted) return;
                                                Navigator.pop(sheetCtx);
                                                _showSuccessSnackBar(
                                                  isEdicao ? 'Fabricante atualizado com sucesso' : 'Fabricante cadastrado com sucesso',
                                                );
                                                await recarregarFabricantes();

                                                if (!isEdicao) {
                                                  final selecionado = _fabricantes
                                                      .where((f) => f.nome.trim().toLowerCase() == nome.toLowerCase())
                                                      .firstOrNull;
                                                  if (selecionado != null) {
                                                    setState(() => _fabricanteSelecionado = selecionado);
                                                    fabricanteSelecionadoNoGerenciador = selecionado;
                                                  }
                                                } else {
                                                  final atualizado = _fabricantes.where((f) => f.id == fabricante.id).firstOrNull;
                                                  if (atualizado != null) {
                                                    fabricanteSelecionadoNoGerenciador = atualizado;
                                                  }
                                                }
                                              } else {
                                                _showVisibleError(result['message'] ?? 'Erro ao salvar fabricante');
                                              }
                                            },
                                            child: Text(
                                              isEdicao ? 'Atualizar Fabricante' : 'Cadastrar Fabricante',
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            Future<void> excluirFabricanteGerenciamento(Fabricante fabricante) async {
              final confirmar = await showDialog<bool>(
                context: ctx2,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Excluir fabricante'),
                  content: Text('Deseja excluir o fabricante "${fabricante.nome}"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancelar')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dCtx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Excluir'),
                    ),
                  ],
                ),
              );
              if (confirmar != true) return;

              final result = await FabricanteService.excluirFabricante(fabricante.id!);
              if (result['success'] == true) {
                _showSuccessSnackBar('Fabricante excluído com sucesso');
                await recarregarFabricantes();
              } else {
                _showVisibleError(result['message'] ?? 'Erro ao excluir fabricante');
              }
            }

            if (!carregouNoDialog) {
              carregouNoDialog = true;
              Future.microtask(recarregarFabricantes);
            }

            final fabricantesOrdenados = List<Fabricante>.from(_fabricantes)
              ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              title: const Row(
                children: [
                  Icon(Icons.business, color: primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Gerenciar Fabricantes',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 540,
                height: 420,
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => abrirFormulario(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Novo Fabricante'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: fabricantesOrdenados.isEmpty
                          ? const Center(child: Text('Nenhum fabricante cadastrado.'))
                          : ListView.separated(
                              itemCount: fabricantesOrdenados.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final fabricante = fabricantesOrdenados[i];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(fabricante.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Editar',
                                        onPressed: () => abrirFormulario(fabricante: fabricante),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Excluir',
                                        onPressed: () => excluirFabricanteGerenciamento(fabricante),
                                        icon: const Icon(Icons.delete_outline),
                                        color: Colors.red,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF475569)),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
      },
    );

    return fabricanteSelecionadoNoGerenciador;
  }

  void _showFormModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          _formModalSetState = setModalState;
          return DraggableScrollableSheet(
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
                            _formModalSetState = null;
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
          );
        },
      ),
    ).whenComplete(() {
      _formModalSetState = null;
    });
  }

  Widget _buildSearchBar() {
    final fornecedoresDropdown = List<Fornecedor>.from(_fornecedoresFiltroDisponiveis);
    if (_fornecedorFiltroId != null && fornecedoresDropdown.every((f) => f.id != _fornecedorFiltroId)) {
      final selected = _fornecedores.firstWhere(
        (f) => f.id == _fornecedorFiltroId,
        orElse: () => Fornecedor(id: _fornecedorFiltroId!, nome: '', cnpj: '', telefone: '', email: ''),
      );
      fornecedoresDropdown.insert(0, selected);
    }

    final fabricantesDropdown = List<Fabricante>.from(_fabricantesFiltroDisponiveis);
    if (_fabricanteFiltroId != null && fabricantesDropdown.every((f) => f.id != _fabricanteFiltroId)) {
      final selected =
          _fabricantes.firstWhere((f) => f.id == _fabricanteFiltroId, orElse: () => Fabricante(id: _fabricanteFiltroId!, nome: ''));
      fabricantesDropdown.insert(0, selected);
    }

    final searchField = TextField(
      controller: _searchController,
      inputFormatters: [],
      decoration: InputDecoration(
        hintText: _pecaSearchMode == 'codigo' ? 'Pesquisar por código...' : 'Pesquisar por nome...',
        prefixIcon: Icon(Icons.search, color: primaryColor),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged(force: true);
                },
              )
            : null,
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
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );

    final searchModeToggle = ToggleButtons(
      isSelected: [_pecaSearchMode == 'codigo', _pecaSearchMode == 'nome'],
      onPressed: (index) {
        final mode = index == 0 ? 'codigo' : 'nome';
        if (_pecaSearchMode == mode) return;
        setState(() {
          _pecaSearchMode = mode;
          _searchController.clear();
          _currentPage = 0;
        });
        _onSearchChanged(force: true);
      },
      borderRadius: BorderRadius.circular(12),
      selectedBorderColor: primaryColor,
      selectedColor: Colors.white,
      fillColor: primaryColor,
      color: Colors.grey[700],
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text('Código'),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text('Nome'),
        ),
      ],
    );

    final fornecedorField = DropdownButtonFormField<int?>(
      initialValue: _fornecedorFiltroId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Fornecedor',
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
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Todos os fornecedores'),
        ),
        ...fornecedoresDropdown.map(
          (fornecedor) => DropdownMenuItem<int?>(
            value: fornecedor.id,
            child: Text(fornecedor.nome),
          ),
        ),
      ],
      onChanged: fornecedoresDropdown.isEmpty
          ? null
          : (value) {
              setState(() {
                _fornecedorFiltroId = value;
                _currentPage = 0;
              });
              _onSearchChanged(force: true);
            },
    );

    final fabricanteField = DropdownButtonFormField<int?>(
      initialValue: _fabricanteFiltroId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Fabricante',
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
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Todos os fabricantes'),
        ),
        ...fabricantesDropdown.map(
          (fabricante) => DropdownMenuItem<int?>(
            value: fabricante.id,
            child: Text(fabricante.nome),
          ),
        ),
      ],
      onChanged: fabricantesDropdown.isEmpty
          ? null
          : (value) {
              setState(() {
                _fabricanteFiltroId = value;
                _currentPage = 0;
              });
              _onSearchChanged(force: true);
            },
    );

    final activeFiltersCount = (_fornecedorFiltroId != null ? 1 : 0) +
        (_fabricanteFiltroId != null ? 1 : 0) +
        (_filtroEstoque != 'todos' ? 1 : 0) +
        (_pecaSearchMode != 'codigo' ? 1 : 0);

    return Container(
      padding: const EdgeInsets.all(12),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1100;

          if (isDesktop) {
            return Row(
              children: [
                Expanded(flex: 3, child: searchField),
                const SizedBox(width: 12),
                searchModeToggle,
                const SizedBox(width: 12),
                Expanded(flex: 2, child: fornecedorField),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: fabricanteField),
              ],
            );
          }

          final isTablet = constraints.maxWidth >= 700;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isTablet) ...[
                searchField,
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    searchModeToggle,
                    const SizedBox(width: 12),
                    Expanded(child: fornecedorField),
                    const SizedBox(width: 12),
                    Expanded(child: fabricanteField),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 8),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: _filtrosExpandidos ? primaryColor : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _filtrosExpandidos ? primaryColor : Colors.grey[300]!,
                            ),
                          ),
                          child: IconButton(
                            onPressed: () => setState(
                              () => _filtrosExpandidos = !_filtrosExpandidos,
                            ),
                            icon: Icon(
                              Icons.tune,
                              color: _filtrosExpandidos ? Colors.white : Colors.grey[700],
                            ),
                            iconSize: 22,
                            padding: const EdgeInsets.all(10),
                            tooltip: _filtrosExpandidos ? 'Ocultar filtros' : 'Mostrar filtros',
                          ),
                        ),
                        if (activeFiltersCount > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Text(
                                '$activeFiltersCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    _buildToolbarActionButton(
                      backgroundColor: primaryColor,
                      shadowBaseColor: primaryColor,
                      icon: Icons.add,
                      compact: true,
                      onPressed: () {
                        _limparFormulario();
                        _showFormModal();
                      },
                      tooltip: 'Nova Peça',
                    ),
                    const SizedBox(width: 8),
                    _buildToolbarActionButton(
                      backgroundColor: successColor,
                      shadowBaseColor: successColor,
                      icon: Icons.add_box,
                      compact: true,
                      onPressed: () async {
                        await EntradaEstoquePage.showModal(context);
                        await _carregarPecas();
                      },
                      tooltip: 'Entrada de Estoque',
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _filtrosExpandidos
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: searchModeToggle,
                              ),
                            ),
                            const SizedBox(height: 10),
                            fornecedorField,
                            const SizedBox(height: 10),
                            fabricanteField,
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _buildToolbarFilterButton(
                                  filterValue: 'critico',
                                  icon: Icons.warning_amber,
                                  activeColor: warningColor,
                                  count: _contarPecasCriticas(),
                                  tooltip: _filtroEstoque == 'critico' ? 'Mostrar todas as peças' : 'Filtrar peças críticas',
                                  onPressed: () {
                                    setState(() {
                                      _filtroEstoque = _filtroEstoque == 'critico' ? 'todos' : 'critico';
                                      _searchController.clear();
                                      _lastSearchQuery = '';
                                      _fornecedorFiltroId = null;
                                      _fabricanteFiltroId = null;
                                      _currentPage = 0;
                                    });
                                    _filtrarPecas();
                                  },
                                ),
                                _buildToolbarFilterButton(
                                  filterValue: 'sem_estoque',
                                  icon: Icons.error,
                                  activeColor: errorColor,
                                  count: _contarPecasSemEstoque(),
                                  tooltip: _filtroEstoque == 'sem_estoque' ? 'Mostrar todas as peças' : 'Filtrar peças sem estoque',
                                  onPressed: () {
                                    setState(() {
                                      _filtroEstoque = _filtroEstoque == 'sem_estoque' ? 'todos' : 'sem_estoque';
                                      _searchController.clear();
                                      _lastSearchQuery = '';
                                      _fornecedorFiltroId = null;
                                      _fabricanteFiltroId = null;
                                      _currentPage = 0;
                                    });
                                    _filtrarPecas();
                                  },
                                ),
                                _buildToolbarFilterButton(
                                  filterValue: 'em_uso',
                                  icon: Icons.pending_actions,
                                  activeColor: primaryColor,
                                  count: _contarPecasEmUso(),
                                  tooltip: _filtroEstoque == 'em_uso' ? 'Mostrar todas as peças' : 'Filtrar peças em uso em OSs',
                                  onPressed: () {
                                    setState(() {
                                      _filtroEstoque = _filtroEstoque == 'em_uso' ? 'todos' : 'em_uso';
                                    });
                                    _filtrarPecas();
                                  },
                                ),
                              ],
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          );
        },
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
      } else if (_filtroEstoque == 'em_uso') {
        emptyMessage = 'Nenhuma peça em uso encontrada';
        emptySubtitle = 'Não há peças sendo utilizadas em Ordens de Serviço abertas';
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
                  color: (_filtroEstoque != 'todos') ? successColor.withValues(alpha: 0.7) : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1100;
        final isTablet = constraints.maxWidth >= 700;
        final crossAxisCount = isDesktop ? 3 : (isTablet ? 2 : 1);

        if (!isDesktop) {
          if (!isTablet) {
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pecasFiltradas.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildPartCard(_pecasFiltradas[index], useFlexibleBody: false),
              ),
            );
          }

          final itemWidth = (constraints.maxWidth - ((crossAxisCount - 1) * 10)) / crossAxisCount;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _pecasFiltradas
                .map((peca) => SizedBox(
                      width: itemWidth,
                      child: _buildPartCard(peca, useFlexibleBody: false),
                    ))
                .toList(),
          );
        }

        final SliverGridDelegate gridDelegate;
        gridDelegate = const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        );

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: gridDelegate,
          itemCount: _pecasFiltradas.length,
          itemBuilder: (context, index) => _buildPartCard(_pecasFiltradas[index]),
        );
      },
    );
  }

  Widget _buildPartCard(Peca peca, {bool useFlexibleBody = true}) {
    final stockStatus = _getStockStatus(peca.quantidadeEstoque, peca.estoqueSeguranca);
    final quantidadeEmOS = _pecasEmOS[peca.codigoFabricante]?['quantidade'] ?? 0;
    final ordensComPeca = _pecasEmOS[peca.codigoFabricante]?['ordens'] as List<String>? ?? [];
    final infoSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildInfoRow(Icons.qr_code, peca.codigoFabricante, maxLines: useFlexibleBody ? 1 : 2),
        _buildInfoRow(Icons.business, peca.fabricante.nome, maxLines: useFlexibleBody ? 1 : 2),
        _buildInfoRow(
          Icons.store,
          peca.fornecedor != null ? _fornecedorComMargem(peca.fornecedor!) : 'Não informado',
          maxLines: useFlexibleBody ? 1 : 2,
        ),
        _buildInfoRow(Icons.attach_money, 'Custo: R\$ ${peca.precoUnitario.toStringAsFixed(2)}', isPrice: true, maxLines: 1),
        _buildInfoRow(Icons.shield, 'Estoque Seg.: ${peca.estoqueSeguranca} unid.', maxLines: 1),
      ],
    );

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
          onTap: () async {
            final isAdmin = await AuthService.isAdmin();
            if (!isAdmin && peca.quantidadeEstoque > 0) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Apenas administradores podem editar peças com estoque'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
            _editarPeca(peca);
          },
          child: Padding(
            padding: EdgeInsets.all(useFlexibleBody ? 10 : 14),
            child: Column(
              mainAxisSize: useFlexibleBody ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
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
                              color: successColor.withValues(alpha: 0.1),
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
                      onSelected: (value) async {
                        if (value == 'edit') {
                          final isAdmin = await AuthService.isAdmin();
                          if (!isAdmin && peca.quantidadeEstoque > 0) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Apenas administradores podem editar peças com estoque'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }
                          _editarPeca(peca);
                        } else if (value == 'ajustar') {
                          final isAdmin = await AuthService.isAdmin();
                          if (!isAdmin) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Apenas administradores podem ajustar estoque'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }
                          _mostrarDialogoAjusteEstoque(peca);
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
                          value: 'ajustar',
                          child: Row(
                            children: [
                              Icon(Icons.tune, size: 18, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Ajustar Estoque', style: TextStyle(color: Colors.blue)),
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
                const SizedBox(height: 8),
                if (useFlexibleBody) Expanded(child: infoSection) else infoSection,
                if (quantidadeEmOS > 0)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: warningColor.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber, size: 14, color: warningColor),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '$quantidadeEmOS unid. em OS abertas',
                                style: TextStyle(
                                  color: warningColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (ordensComPeca.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'OS: ${ordensComPeca.take(3).join(', ')}${ordensComPeca.length > 3 ? '...' : ''}',
                              style: TextStyle(
                                color: warningColor.withValues(alpha: 0.8),
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: useFlexibleBody ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (peca.createdAt != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
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
                      if (useFlexibleBody)
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
                                color: stockStatus['color'].withValues(alpha: 0.2),
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
                        )
                      else
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Icon(Icons.inventory, size: 12, color: stockStatus['color']),
                            Text(
                              'Estoque: ${peca.quantidadeEstoque} unid.',
                              style: TextStyle(
                                color: stockStatus['color'],
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: stockStatus['color'].withValues(alpha: 0.2),
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
    } else if (quantidadeAtual < estoqueSeguranca) {
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

  int _contarPecasEmUso() {
    return _pecas.where((peca) => peca.unidadesUsadasEmOS != null && peca.unidadesUsadasEmOS! > 0).length;
  }

  Widget _buildInfoRow(IconData icon, String text, {bool isPrice = false, bool isFinalPrice = false, int maxLines = 1}) {
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
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarActionButton({
    required Color backgroundColor,
    required Color shadowBaseColor,
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color iconColor = Colors.white,
    bool compact = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: shadowBaseColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor),
        iconSize: compact ? 22 : 28,
        padding: EdgeInsets.all(compact ? 8 : 12),
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildToolbarFilterButton({
    required String filterValue,
    required IconData icon,
    required Color activeColor,
    required int count,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    final isActive = _filtroEstoque == filterValue;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (isActive ? activeColor : Colors.grey).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(
              icon,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
            iconSize: 24,
            padding: const EdgeInsets.all(12),
            tooltip: tooltip,
          ),
        ),
        if (count > 0 && !isActive)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: activeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                '$count',
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
    );
  }

  Widget _buildTopToolbarActions({required bool isDesktop}) {
    final buttons = <Widget>[
      _buildToolbarActionButton(
        backgroundColor: primaryColor,
        shadowBaseColor: primaryColor,
        icon: Icons.add,
        onPressed: () {
          _limparFormulario();
          _showFormModal();
        },
        tooltip: 'Nova Peça',
      ),
      _buildToolbarActionButton(
        backgroundColor: successColor,
        shadowBaseColor: successColor,
        icon: Icons.add_box,
        onPressed: () async {
          await EntradaEstoquePage.showModal(context);
          await _carregarPecas();
        },
        tooltip: 'Entrada de Estoque',
      ),
      _buildToolbarFilterButton(
        filterValue: 'critico',
        icon: Icons.warning_amber,
        activeColor: warningColor,
        count: _contarPecasCriticas(),
        tooltip: _filtroEstoque == 'critico' ? 'Mostrar todas as peças' : 'Filtrar peças críticas',
        onPressed: () {
          setState(() {
            _filtroEstoque = _filtroEstoque == 'critico' ? 'todos' : 'critico';
            _searchController.clear();
            _lastSearchQuery = '';
            _fornecedorFiltroId = null;
            _fabricanteFiltroId = null;
            _currentPage = 0;
          });
          _filtrarPecas();
        },
      ),
      _buildToolbarFilterButton(
        filterValue: 'sem_estoque',
        icon: Icons.error,
        activeColor: errorColor,
        count: _contarPecasSemEstoque(),
        tooltip: _filtroEstoque == 'sem_estoque' ? 'Mostrar todas as peças' : 'Filtrar peças sem estoque',
        onPressed: () {
          setState(() {
            _filtroEstoque = _filtroEstoque == 'sem_estoque' ? 'todos' : 'sem_estoque';
            _searchController.clear();
            _lastSearchQuery = '';
            _fornecedorFiltroId = null;
            _fabricanteFiltroId = null;
            _currentPage = 0;
          });
          _filtrarPecas();
        },
      ),
      _buildToolbarFilterButton(
        filterValue: 'em_uso',
        icon: Icons.pending_actions,
        activeColor: primaryColor,
        count: _contarPecasEmUso(),
        tooltip: _filtroEstoque == 'em_uso' ? 'Mostrar todas as peças' : 'Filtrar peças em uso em OSs',
        onPressed: () {
          setState(() {
            _filtroEstoque = _filtroEstoque == 'em_uso' ? 'todos' : 'em_uso';
          });
          _filtrarPecas();
        },
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          for (int i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            buttons[i],
          ],
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: buttons,
    );
  }

  Widget _buildPaginationControls() {
    final previousButton = ElevatedButton.icon(
      onPressed: _currentPage > 0 ? _paginaAnterior : null,
      icon: const Icon(Icons.chevron_left),
      label: const Text('Anterior'),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[300],
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final pageIndicator = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Página ${_currentPage + 1} de $_totalPages',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
      ),
    );

    final nextButton = ElevatedButton.icon(
      onPressed: _currentPage < _totalPages - 1 ? _proximaPagina : null,
      icon: const Icon(Icons.chevron_right),
      label: const Text('Próxima'),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey[300],
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 700) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                previousButton,
                const SizedBox(width: 16),
                pageIndicator,
                const SizedBox(width: 16),
                nextButton,
              ],
            );
          }

          return Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [previousButton, pageIndicator, nextButton],
          );
        },
      ),
    );
  }

  Widget _buildFormulario() {
    final fabricantesOrdenados = List<Fabricante>.from(_fabricantes)..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    final fabricanteSelecionadoAtual = fabricantesOrdenados.where((f) => f.id == _fabricanteSelecionado?.id).firstOrNull;

    final precoUnitarioField = _buildTextField(
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
    );

    final estoqueSegurancaField = _buildTextField(
      controller: _estoqueSegurancaController,
      label: 'Estoque de Segurança',
      icon: Icons.inventory,
      keyboardType: TextInputType.number,
      inputFormatters: [_numbersOnlyFormatter],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Informe o estoque de segurança';
        }
        if (int.tryParse(value) == null || int.parse(value) < 0) {
          return 'Digite um número válido';
        }
        return null;
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackFields = constraints.maxWidth < 900;

        return Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(
                controller: _nomeController,
                label: 'Nome da Peça',
                icon: Icons.inventory_2,
                validator: (v) => (v == null || v.isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _codigoFabricanteController,
                label: 'Código do Fabricante',
                icon: Icons.qr_code,
                validator: (v) => (v == null || v.isEmpty) ? 'Informe o código' : null,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: FormField<Fabricante>(
                      initialValue: fabricanteSelecionadoAtual,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) => value == null ? 'Selecione um fabricante' : null,
                      builder: (fieldState) {
                        final textoFabricante = _fabricanteSelecionado?.nome ?? 'Selecione um fabricante';

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final selecionado = await _abrirSeletorFabricanteAtualizado();
                            if (selecionado == null) return;

                            setState(() => _fabricanteSelecionado = selecionado);
                            fieldState.didChange(selecionado);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Fabricante',
                              prefixIcon: Icon(Icons.business, color: primaryColor),
                              errorText: fieldState.errorText,
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
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    textoFabricante,
                                    style: TextStyle(
                                      color: _fabricanteSelecionado == null ? Colors.grey[600] : Colors.black87,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 56,
                    child: Tooltip(
                      message: 'Gerenciar fabricantes',
                      child: ElevatedButton(
                        onPressed: () async {
                          final selecionado = await _abrirGerenciarFabricantes();
                          if (!mounted) return;
                          setState(() {
                            if (selecionado != null) {
                              _fabricanteSelecionado = selecionado;
                            } else if (_fabricanteSelecionado != null && !_fabricantes.any((f) => f.id == _fabricanteSelecionado!.id)) {
                              _fabricanteSelecionado = null;
                            }
                          });
                          _rebuildFormModal();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Icon(Icons.add),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (stackFields) ...[
                precoUnitarioField,
                const SizedBox(height: 16),
                estoqueSegurancaField,
              ] else
                Row(
                  children: [
                    Expanded(child: precoUnitarioField),
                    const SizedBox(width: 16),
                    Expanded(child: estoqueSegurancaField),
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
                    FormField<Fornecedor>(
                      initialValue: _fornecedorSelecionado,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) => value == null ? 'Selecione um fornecedor' : null,
                      builder: (fieldState) {
                        final textoFornecedor =
                            _fornecedorSelecionado != null ? _fornecedorComMargem(_fornecedorSelecionado!) : 'Selecione um fornecedor';

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final selecionado = await _abrirSeletorFornecedorAtualizado();
                            if (selecionado == null) return;

                            setState(() {
                              _fornecedorSelecionado = selecionado;
                              _calcularPrecoFinal();
                            });
                            fieldState.didChange(selecionado);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Fornecedor',
                              prefixIcon: Icon(Icons.store, color: primaryColor),
                              errorText: fieldState.errorText,
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
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    textoFornecedor,
                                    style: TextStyle(
                                      color: _fornecedorSelecionado == null ? Colors.grey[600] : Colors.black87,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                              ],
                            ),
                          ),
                        );
                      },
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
                  onPressed: _isSaving ? null : _salvar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isSaving
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
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool enabled = true,
    TextStyle? style,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1100;
              final isTablet = constraints.maxWidth >= 700;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDesktop)
                    Row(
                      children: [
                        Expanded(child: _buildSearchBar()),
                        const SizedBox(width: 12),
                        _buildTopToolbarActions(isDesktop: true),
                      ],
                    )
                  else if (isTablet) ...[
                    _buildSearchBar(),
                    const SizedBox(height: 12),
                    _buildTopToolbarActions(isDesktop: false),
                  ] else
                    _buildSearchBar(),
                  const SizedBox(height: 24),
                  if (_searchController.text.isEmpty && _filtroEstoque == 'todos' && !_isLoadingPecas && _pecasFiltradas.isNotEmpty)
                    Text(
                      'Últimas Peças Cadastradas',
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
                      'Resultados da Busca${_filtroEstoque != 'todos' ? ' - ${_filtroEstoque == 'critico' ? 'Apenas Críticas' : 'Sem Estoque'}' : ''} ($_totalElements)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _filtroEstoque != 'todos' ? (_filtroEstoque == 'critico' ? warningColor : errorColor) : Colors.grey[800],
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildPartGrid(),
                  if (_totalPages > 1) ...[const SizedBox(height: 16), _buildPaginationControls()],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
