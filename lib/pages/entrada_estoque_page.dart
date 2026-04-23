import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../model/fornecedor.dart';
import '../model/peca.dart';
import '../model/tipo_pagamento.dart';
import '../services/fornecedor_service.dart';
import '../services/tipo_pagamento_service.dart';
import '../services/peca_service.dart';
import '../services/movimentacao_estoque_service.dart';
import '../services/ordem_servico_service.dart';

class PecaEntrada {
  final Peca peca;
  int quantidade;
  double precoUnitario;

  PecaEntrada({
    required this.peca,
    required this.quantidade,
    required this.precoUnitario,
  });

  double get valorTotal => quantidade * precoUnitario;
}

class _ParcelaPagamentoDraft {
  _ParcelaPagamentoDraft({
    required this.numero,
    required this.valor,
    required this.vencimento,
  });

  int numero;
  double valor;
  DateTime vencimento;
}

class EntradaEstoquePage extends StatefulWidget {
  const EntradaEstoquePage({super.key});

  @override
  State<EntradaEstoquePage> createState() => _EntradaEstoquePageState();

  static Future<void> showModal(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.95,
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
                decoration: const BoxDecoration(
                  color: Color(0xFF059669),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.add_box,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Entrada de Estoque - Múltiplas Peças',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: const _EntradaEstoqueForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntradaEstoquePageState extends State<EntradaEstoquePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Entrada de Estoque',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF059669),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: _EntradaEstoqueForm(),
      ),
    );
  }
}

class _EntradaEstoqueForm extends StatefulWidget {
  const _EntradaEstoqueForm();

  @override
  State<_EntradaEstoqueForm> createState() => _EntradaEstoqueFormState();
}

class _EntradaEstoqueFormState extends State<_EntradaEstoqueForm> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _numeroNotaFiscalController = TextEditingController();
  final _observacoesController = TextEditingController();
  final _searchController = TextEditingController();

  TipoPagamento? _formaPagamento;
  List<TipoPagamento> _tiposPagamento = [];
  int _numeroParcelas = 1;
  DateTime? _boletoVencimento;
  List<_ParcelaPagamentoDraft> _boletoParcelasCompra = [];

  bool _freteAtivo = false;
  final _freteValorController = TextEditingController();
  TipoPagamento? _fretePagamento;
  int _freteNumeroParcelas = 1;
  DateTime? _freteBoletoVencimento;
  List<_ParcelaPagamentoDraft> _boletoParcelasFrete = [];
  Fornecedor? _fornecedorSelecionado;
  List<Fornecedor> _fornecedores = [];
  List<Peca> _pecasDisponiveis = [];
  List<Peca> _pecasFiltradas = [];
  final List<PecaEntrada> _pecasAdicionadas = [];
  final Map<String, TextEditingController> _quantidadeControllers = {};
  Map<String, Map<String, dynamic>> _pecasEmOS = {};

  bool _isLoading = false;
  bool _isLoadingPecas = false;
  bool _canSubmit = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF059669);
  static const Color warningColor = Color(0xFFF59E0B);

  int _idFormaPagamento(TipoPagamento? tipo) => tipo?.idFormaPagamento ?? 1;

  int _quantidadeParcelasTipo(TipoPagamento? tipo) {
    final qtd = tipo?.quantidadeParcelas ?? 1;
    return qtd < 1 ? 1 : qtd;
  }

  bool _isCredito(TipoPagamento? tipo) => _idFormaPagamento(tipo) == 2;

  bool _isBoleto(TipoPagamento? tipo) => _idFormaPagamento(tipo) == 3;

  bool _isBoletoUnico(TipoPagamento? tipo) => _isBoleto(tipo) && _quantidadeParcelasTipo(tipo) == 1;

  bool _isBoletoParcelado(TipoPagamento? tipo) => _isBoleto(tipo) && _quantidadeParcelasTipo(tipo) > 1;

  IconData _iconeTipoPagamento(TipoPagamento tipo) {
    if (_isCredito(tipo)) return Icons.credit_score;
    if (_isBoleto(tipo)) return Icons.receipt_long;
    return Icons.payments_outlined;
  }

  String _backendFormaPagamento(TipoPagamento tipo) {
    if (_isCredito(tipo)) return 'CREDITO';
    if (_isBoleto(tipo)) return 'BOLETO';
    return 'AVISTA';
  }

  List<_ParcelaPagamentoDraft> _gerarParcelasPadrao({
    required double valorTotal,
    required int quantidade,
    required DateTime base,
  }) {
    final parcelas = <_ParcelaPagamentoDraft>[];
    if (quantidade < 1) return parcelas;

    final valorBase = (valorTotal / quantidade);
    double acumulado = 0;

    for (int i = 0; i < quantidade; i++) {
      final valorParcela =
          i == quantidade - 1 ? ((valorTotal - acumulado) * 100).roundToDouble() / 100 : (valorBase * 100).roundToDouble() / 100;
      acumulado += valorParcela;
      parcelas.add(
        _ParcelaPagamentoDraft(
          numero: i + 1,
          valor: valorParcela,
          vencimento: DateTime(base.year, base.month + i + 1, base.day),
        ),
      );
    }

    return parcelas;
  }

  double _somaParcelas(List<_ParcelaPagamentoDraft> parcelas) {
    return parcelas.fold<double>(0, (sum, p) => sum + p.valor);
  }

  bool _parcelasValidas({
    required List<_ParcelaPagamentoDraft> parcelas,
    required double valorTotal,
    required int quantidadeEsperada,
    required DateTime hojeSemHora,
  }) {
    if (quantidadeEsperada < 1 || parcelas.length != quantidadeEsperada) return false;
    for (final p in parcelas) {
      if (p.valor <= 0) return false;
      final vencSemHora = DateTime(p.vencimento.year, p.vencimento.month, p.vencimento.day);
      if (vencSemHora.isBefore(hojeSemHora)) return false;
    }
    return (_somaParcelas(parcelas) - valorTotal).abs() <= 0.02;
  }

  void _sincronizarParcelasCompra(double totalCompra) {
    if (!_isBoletoParcelado(_formaPagamento)) {
      _boletoParcelasCompra = [];
      return;
    }
    final quantidade = _quantidadeParcelasTipo(_formaPagamento);
    if (quantidade < 1 || totalCompra <= 0) {
      _boletoParcelasCompra = [];
      return;
    }
    if (_boletoParcelasCompra.length != quantidade) {
      _boletoParcelasCompra = _gerarParcelasPadrao(
        valorTotal: totalCompra,
        quantidade: quantidade,
        base: DateTime.now(),
      );
    }
  }

  void _sincronizarParcelasFrete(double valorFrete) {
    if (!_isBoletoParcelado(_fretePagamento)) {
      _boletoParcelasFrete = [];
      return;
    }
    final quantidade = _quantidadeParcelasTipo(_fretePagamento);
    if (quantidade < 1 || valorFrete <= 0) {
      _boletoParcelasFrete = [];
      return;
    }
    if (_boletoParcelasFrete.length != quantidade) {
      _boletoParcelasFrete = _gerarParcelasPadrao(
        valorTotal: valorFrete,
        quantidade: quantidade,
        base: DateTime.now(),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _carregarDados();
    _numeroNotaFiscalController.addListener(_updateSubmitState);
    _searchController.addListener(_filtrarPecas);
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
    _numeroNotaFiscalController.removeListener(_updateSubmitState);
    _searchController.removeListener(_filtrarPecas);
    _numeroNotaFiscalController.dispose();
    _observacoesController.dispose();
    _searchController.dispose();
    _freteValorController.dispose();
    for (var c in _quantidadeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoadingPecas = true);
    try {
      final results = await Future.wait([
        FornecedorService.listarFornecedores(),
        PecaService.listarPecas(),
        OrdemServicoService.buscarPecasEmOSAbertas(),
        TipoPagamentoService.listarTiposPagamento(),
      ]);

      final tiposPagamentoOrdenados = List<TipoPagamento>.from(results[3] as List<TipoPagamento>)
        ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

      setState(() {
        _fornecedores = results[0] as List<Fornecedor>;
        _pecasDisponiveis = results[1] as List<Peca>;
        _pecasEmOS = results[2] as Map<String, Map<String, dynamic>>;
        _tiposPagamento = tiposPagamentoOrdenados;
        _filtrarPecas();
      });
    } catch (e) {
      _showError('Erro ao carregar dados');
    } finally {
      setState(() => _isLoadingPecas = false);
    }
  }

  void _filtrarPecas() {
    if (_fornecedorSelecionado == null) {
      setState(() {
        _pecasFiltradas = [];
      });
      return;
    }

    final query = _searchController.text.toLowerCase();
    final pecasFornecedor = _pecasDisponiveis.where((p) => p.fornecedor?.id == _fornecedorSelecionado!.id).toList();

    if (query.isEmpty) {
      setState(() {
        _pecasFiltradas = pecasFornecedor;
      });
    } else {
      setState(() {
        _pecasFiltradas = pecasFornecedor.where((peca) {
          return peca.codigoFabricante.toLowerCase().contains(query) ||
              peca.nome.toLowerCase().contains(query) ||
              peca.fabricante.nome.toLowerCase().contains(query);
        }).toList();
      });
    }
  }

  void _updateSubmitState() {
    final hoje = DateTime.now();
    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
    final totalCompra = _pecasAdicionadas.fold(0.0, (s, p) => s + p.valorTotal);
    _sincronizarParcelasCompra(totalCompra);

    bool pagamentoValido = _formaPagamento != null;
    if (pagamentoValido && _isBoletoUnico(_formaPagamento)) {
      pagamentoValido = _boletoVencimento != null;
    } else if (pagamentoValido && _isBoletoParcelado(_formaPagamento)) {
      pagamentoValido = _parcelasValidas(
        parcelas: _boletoParcelasCompra,
        valorTotal: totalCompra,
        quantidadeEsperada: _quantidadeParcelasTipo(_formaPagamento),
        hojeSemHora: hojeSemHora,
      );
    }

    bool freteValido = true;
    if (_freteAtivo) {
      final freteValor = double.tryParse(_freteValorController.text.replaceAll(',', '.')) ?? 0;
      _sincronizarParcelasFrete(freteValor);
      freteValido = freteValor > 0 && _fretePagamento != null;
      if (freteValido && _isBoletoUnico(_fretePagamento)) {
        freteValido = _freteBoletoVencimento != null;
      } else if (freteValido && _isBoletoParcelado(_fretePagamento)) {
        freteValido = _parcelasValidas(
          parcelas: _boletoParcelasFrete,
          valorTotal: freteValor,
          quantidadeEsperada: _quantidadeParcelasTipo(_fretePagamento),
          hojeSemHora: hojeSemHora,
        );
      }
    }

    final canSubmit = _fornecedorSelecionado != null &&
        _numeroNotaFiscalController.text.trim().isNotEmpty &&
        _pecasAdicionadas.isNotEmpty &&
        _pecasAdicionadas.every((p) => p.quantidade > 0 && p.precoUnitario > 0) &&
        pagamentoValido &&
        freteValido &&
        !_isLoading;

    if (_canSubmit != canSubmit) {
      setState(() {
        _canSubmit = canSubmit;
      });
    }
  }

  void _adicionarPeca(Peca peca) {
    final jaAdicionada = _pecasAdicionadas.any((p) => p.peca.id == peca.id);
    if (jaAdicionada) {
      _showError('Esta peça já foi adicionada à lista');
      return;
    }

    setState(() {
      _pecasAdicionadas.add(PecaEntrada(
        peca: peca,
        quantidade: 1,
        precoUnitario: peca.precoUnitario,
      ));
      _quantidadeControllers[peca.codigoFabricante] = TextEditingController(text: '1');
    });
    _updateSubmitState();
  }

  void _removerPeca(int index) {
    if (index >= 0 && index < _pecasAdicionadas.length) {
      final codigo = _pecasAdicionadas[index].peca.codigoFabricante;
      final removedController = _quantidadeControllers.remove(codigo);
      setState(() {
        _pecasAdicionadas.removeAt(index);
      });
      if (removedController != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            removedController.dispose();
          } catch (_) {}
        });
      }
      _updateSubmitState();
    }
  }

  void _atualizarQuantidade(int index, int novaQuantidade) {
    if (index >= 0 && index < _pecasAdicionadas.length && novaQuantidade > 0) {
      setState(() {
        _pecasAdicionadas[index].quantidade = novaQuantidade;
      });
      _updateSubmitState();
    }
  }

  void _setQuantidadeAndController(int index, int novaQuantidade) {
    if (index < 0 || index >= _pecasAdicionadas.length || novaQuantidade <= 0) return;
    final codigo = _pecasAdicionadas[index].peca.codigoFabricante;
    setState(() {
      _pecasAdicionadas[index].quantidade = novaQuantidade;
      final c = _quantidadeControllers[codigo];
      if (c != null) {
        c.text = novaQuantidade.toString();
        c.selection = TextSelection.collapsed(offset: c.text.length);
      }
    });
    _updateSubmitState();
  }

  void _atualizarPreco(int index, double novoPreco) {
    if (index >= 0 && index < _pecasAdicionadas.length && novoPreco > 0) {
      setState(() {
        _pecasAdicionadas[index].precoUnitario = novoPreco;
      });
      _updateSubmitState();
    }
  }

  void _registrarEntradas() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pecasAdicionadas.isEmpty) {
      _showError('Adicione pelo menos uma peça à lista');
      return;
    }

    setState(() {
      _isLoading = true;
      _canSubmit = false;
    });

    try {
      final freteValor = _freteAtivo ? (double.tryParse(_freteValorController.text.replaceAll(',', '.')) ?? 0.0) : 0.0;
      final fretePerItem = (freteValor > 0 && _pecasAdicionadas.isNotEmpty) ? freteValor / _pecasAdicionadas.length : 0.0;

      List<Map<String, dynamic>> pecasData = _pecasAdicionadas
          .map((pecaEntrada) => {
                'codigoPeca': pecaEntrada.peca.codigoFabricante,
                'quantidade': pecaEntrada.quantidade,
                'precoUnitario': pecaEntrada.precoUnitario + fretePerItem,
              })
          .toList();

      Map<String, dynamic>? pagamentoData;
      if (_formaPagamento != null) {
        pagamentoData = {
          'formaPagamento': _backendFormaPagamento(_formaPagamento!),
          'diasEntreParcelas': _formaPagamento?.diasEntreParcelas ?? 30,
          'origemTipoBase': 'COMPRA',
          'fornecedorId': _fornecedorSelecionado!.id,
        };
        if (_isCredito(_formaPagamento)) {
          pagamentoData['numeroParcelas'] = _numeroParcelas;
        } else if (_isBoletoUnico(_formaPagamento) && _boletoVencimento != null) {
          pagamentoData['boletoVencimento'] = _boletoVencimento!.toIso8601String().substring(0, 10);
        } else if (_isBoletoParcelado(_formaPagamento)) {
          pagamentoData['parcelasDetalhadas'] = _boletoParcelasCompra
              .map((p) => {
                    'numero': p.numero,
                    'valor': p.valor,
                    'vencimento': p.vencimento.toIso8601String().substring(0, 10),
                  })
              .toList();
          pagamentoData['numeroParcelas'] = _boletoParcelasCompra.length;
        }
      }

      Map<String, dynamic>? freteData;
      if (_freteAtivo && _fretePagamento != null && freteValor > 0) {
        final fretePagData = <String, dynamic>{
          'formaPagamento': _backendFormaPagamento(_fretePagamento!),
          'diasEntreParcelas': _fretePagamento?.diasEntreParcelas ?? 30,
          'origemTipoBase': 'FRETE',
          'fornecedorId': _fornecedorSelecionado!.id,
        };
        if (_isCredito(_fretePagamento)) {
          fretePagData['numeroParcelas'] = _freteNumeroParcelas;
        } else if (_isBoletoUnico(_fretePagamento) && _freteBoletoVencimento != null) {
          fretePagData['boletoVencimento'] = _freteBoletoVencimento!.toIso8601String().substring(0, 10);
        } else if (_isBoletoParcelado(_fretePagamento)) {
          fretePagData['parcelasDetalhadas'] = _boletoParcelasFrete
              .map((p) => {
                    'numero': p.numero,
                    'valor': p.valor,
                    'vencimento': p.vencimento.toIso8601String().substring(0, 10),
                  })
              .toList();
          fretePagData['numeroParcelas'] = _boletoParcelasFrete.length;
        }
        freteData = {'valor': freteValor, 'pagamento': fretePagData};
      }

      final resultado = await MovimentacaoEstoqueService.registrarEntradasMultiplas(
        fornecedorId: _fornecedorSelecionado!.id!,
        numeroNotaFiscal: _numeroNotaFiscalController.text.trim(),
        pecas: pecasData,
        observacoes: _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(),
        pagamento: pagamentoData,
        frete: freteData,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      if (resultado['sucesso']) {
        final sucessos = resultado['sucessos'] ?? 0;
        final falhas = resultado['falhas'] ?? 0;
        final resultadosRaw = resultado['resultados'] ?? [];
        final List<String> resultados = List<String>.from(resultadosRaw);

        if (sucessos > 0 && falhas == 0) {
          _showSuccessDialog('Todas as $sucessos peças foram registradas com sucesso!', resultados);
        } else if (sucessos > 0 && falhas > 0) {
          _showMixedResultDialog('$sucessos peças registradas, $falhas falharam', resultados);
        } else {
          _showErrorDialog('Nenhuma peça foi registrada com sucesso', resultados);
        }
      } else {
        _showError(resultado['mensagem'] ?? 'Erro desconhecido');
      }

      _limparFormulario();
    } catch (e) {
      _showVisibleError("Erro inesperado: $e");
    } finally {
      setState(() => _isLoading = false);
      _updateSubmitState();
    }
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    _numeroNotaFiscalController.clear();
    _observacoesController.clear();
    _freteValorController.clear();
    final controllersToDispose = _quantidadeControllers.values.toList();
    setState(() {
      _fornecedorSelecionado = null;
      _pecasAdicionadas.clear();
      _quantidadeControllers.clear();
      _formaPagamento = null;
      _numeroParcelas = 1;
      _boletoVencimento = null;
      _boletoParcelasCompra = [];
      _freteAtivo = false;
      _fretePagamento = null;
      _freteNumeroParcelas = 1;
      _freteBoletoVencimento = null;
      _boletoParcelasFrete = [];
      _canSubmit = false;
    });
    if (controllersToDispose.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (var c in controllersToDispose) {
          try {
            c.dispose();
          } catch (_) {}
        }
      });
    }
  }

  void _showSuccessDialog(String titulo, List<String> detalhes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: successColor, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: detalhes
              .map((det) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(det, style: const TextStyle(fontSize: 14)),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: successColor),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showMixedResultDialog(String titulo, List<String> detalhes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: warningColor, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: detalhes
                .map((det) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(det,
                          style: TextStyle(
                            fontSize: 14,
                            color: det.startsWith('✓') ? successColor : errorColor,
                          )),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: warningColor),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String titulo, List<String> detalhes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error, color: errorColor, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: detalhes
                .map((det) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(det, style: const TextStyle(fontSize: 14)),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: errorColor),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
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
    int? maxLines,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      style: style,
      maxLines: maxLines,
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
      initialValue: value,
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

  Widget _buildPecaSelector() {
    if (_isLoadingPecas) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_fornecedorSelecionado == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Selecione um fornecedor para ver as peças disponíveis.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    if (_pecasFiltradas.isEmpty && _searchController.text.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_outlined, color: Colors.orange[700], size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Nenhuma peça encontrada para este fornecedor.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    if (_pecasFiltradas.isEmpty && _searchController.text.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchField(),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.search_off, color: Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Nenhuma peça encontrada com este termo de busca.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchField(),
        const SizedBox(height: 12),
        Text(
          'Peças Disponíveis (${_pecasFiltradas.length})',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: primaryColor,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            itemCount: _pecasFiltradas.length,
            itemBuilder: (context, index) {
              final peca = _pecasFiltradas[index];
              final jaAdicionada = _pecasAdicionadas.any((p) => p.peca.id == peca.id);
              final quantidadeEmOS = _pecasEmOS[peca.codigoFabricante]?['quantidade'] ?? 0;
              final bool semEstoque = peca.quantidadeEstoque <= 0;
              final bool estoqueCritico = !semEstoque && peca.quantidadeEstoque < peca.estoqueSeguranca;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: jaAdicionada ? Colors.grey[100] : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: jaAdicionada ? Colors.grey[300]! : Colors.grey[200]!),
                ),
                child: ListTile(
                  enabled: !jaAdicionada,
                  leading: Container(
                    width: 50,
                    height: 40,
                    decoration: BoxDecoration(
                      color: semEstoque
                          ? Colors.red[100]
                          : estoqueCritico
                              ? Colors.orange[100]
                              : Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${peca.quantidadeEstoque}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: semEstoque
                              ? Colors.red[700]
                              : estoqueCritico
                                  ? Colors.orange[700]
                                  : Colors.green[700],
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    '${peca.codigoFabricante} - ${peca.nome}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: jaAdicionada ? Colors.grey[600] : Colors.black,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fabricante: ${peca.fabricante.nome}'),
                      Text(
                        'Preço: R\$ ${peca.precoUnitario.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      if (quantidadeEmOS > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: warningColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$quantidadeEmOS unid. em OS abertas',
                            style: TextStyle(
                              fontSize: 11,
                              color: warningColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: jaAdicionada ? Icon(Icons.check, color: Colors.green[600]) : Icon(Icons.add, color: primaryColor),
                  onTap: jaAdicionada ? null : () => _adicionarPeca(peca),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Pesquisar por código, nome ou fabricante...',
          prefixIcon: Icon(Icons.search, color: primaryColor),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filtrarPecas();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: (value) => _filtrarPecas(),
      ),
    );
  }

  Widget _buildPecasAdicionadas() {
    if (_pecasAdicionadas.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'Peças para Entrada (${_pecasAdicionadas.length})',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: primaryColor,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Text(
              'Total: R\$ ${_pecasAdicionadas.fold(0.0, (sum, p) => sum + p.valorTotal).toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: successColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pecasAdicionadas.length,
            itemBuilder: (context, index) {
              final pecaEntrada = _pecasAdicionadas[index];
              return Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${pecaEntrada.peca.codigoFabricante} - ${pecaEntrada.peca.nome}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _removerPeca(index),
                            icon: const Icon(Icons.delete, color: Colors.red),
                            iconSize: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Quantidade:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: pecaEntrada.quantidade > 1
                                          ? () => _setQuantidadeAndController(index, pecaEntrada.quantidade - 1)
                                          : null,
                                      icon: const Icon(Icons.remove),
                                      iconSize: 16,
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: TextFormField(
                                        controller: _quantidadeControllers[pecaEntrada.peca.codigoFabricante] ??=
                                            TextEditingController(text: pecaEntrada.quantidade.toString()),
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        onChanged: (value) {
                                          final v = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                                          if (v > 0) {
                                            _atualizarQuantidade(index, v);
                                          } else {}
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _setQuantidadeAndController(index, pecaEntrada.quantidade + 1),
                                      icon: const Icon(Icons.add),
                                      iconSize: 16,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Preço Unit.:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                TextFormField(
                                  initialValue: pecaEntrada.precoUnitario.toStringAsFixed(2).replaceAll('.', ','),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(fontSize: 14),
                                  onChanged: (value) {
                                    final preco = double.tryParse(value.replaceAll(',', '.'));
                                    if (preco != null && preco > 0) {
                                      _atualizarPreco(index, preco);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    prefixText: 'R\$ ',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: successColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total:', style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              'R\$ ${pecaEntrada.valorTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: successColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Selecione o fornecedor e adicione múltiplas peças para entrada em estoque.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildDropdownField(
              value: _fornecedorSelecionado,
              label: 'Fornecedor',
              icon: Icons.store,
              items: (() {
                final lista = _fornecedores.where((f) => !f.servico).toList();
                lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
                return lista
                    .map<DropdownMenuItem<Fornecedor>>((fornecedor) => DropdownMenuItem<Fornecedor>(
                          value: fornecedor,
                          child: Text(fornecedor.nome),
                        ))
                    .toList();
              })(),
              onChanged: (value) {
                final controllersToDispose = _quantidadeControllers.values.toList();
                setState(() {
                  _fornecedorSelecionado = value;
                  _pecasAdicionadas.clear();
                  _quantidadeControllers.clear();
                  _searchController.clear();
                });
                if (controllersToDispose.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    for (var c in controllersToDispose) {
                      try {
                        c.dispose();
                      } catch (_) {}
                    }
                  });
                }
                _filtrarPecas();
                _updateSubmitState();
              },
              validator: (value) => value == null ? 'Selecione um fornecedor' : null,
            ),
            const SizedBox(height: 24),
            _buildPecaSelector(),
            _buildPecasAdicionadas(),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.yellow[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow[200]!),
              ),
              child: const Text(
                'Se o valor declarado for diferente do valor unitário, o valor será ajustado',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _numeroNotaFiscalController,
              label: 'Número da Nota Fiscal',
              icon: Icons.receipt,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9./-]'))],
              validator: (v) => v!.isEmpty ? 'Informe o número da nota fiscal' : null,
            ),
            const SizedBox(height: 16),
            _buildFormaPagamento(),
            const SizedBox(height: 16),
            _buildFrete(),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _observacoesController,
              label: 'Observações (opcional)',
              icon: Icons.notes,
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _canSubmit ? _registrarEntradas : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: successColor,
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
                        'Registrar Entradas (${_pecasAdicionadas.length})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormaPagamento() {
    final totalCompra = _pecasAdicionadas.fold(0.0, (s, p) => s + p.valorTotal);
    final tiposOrdenados = List<TipoPagamento>.from(_tiposPagamento)..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    final maxParcelasTipo = _quantidadeParcelasTipo(_formaPagamento);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<TipoPagamento>(
          initialValue: _formaPagamento,
          decoration: InputDecoration(
            labelText: 'Forma de Pagamento',
            prefixIcon: Icon(Icons.payment, color: primaryColor),
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
          items: tiposOrdenados.map((f) {
            return DropdownMenuItem(
              value: f,
              child: Row(
                children: [
                  Icon(_iconeTipoPagamento(f), size: 18, color: primaryColor),
                  const SizedBox(width: 8),
                  Text(f.nome),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _formaPagamento = value;
              _numeroParcelas = 1;
              _boletoVencimento = null;
              _boletoParcelasCompra = [];
              if (_isBoletoParcelado(_formaPagamento) && totalCompra > 0) {
                _boletoParcelasCompra = _gerarParcelasPadrao(
                  valorTotal: totalCompra,
                  quantidade: _quantidadeParcelasTipo(_formaPagamento),
                  base: DateTime.now(),
                );
              }
            });
            _updateSubmitState();
          },
        ),
        if (_isCredito(_formaPagamento)) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _numeroParcelas.clamp(1, maxParcelasTipo > 0 ? maxParcelasTipo : 1),
            decoration: InputDecoration(
              labelText: 'Número de Parcelas',
              prefixIcon: Icon(Icons.format_list_numbered, color: primaryColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            items: List.generate(maxParcelasTipo > 0 ? maxParcelasTipo : 1, (i) => i + 1).map((n) {
              final vp = totalCompra > 0 ? totalCompra / n : 0.0;
              return DropdownMenuItem(
                value: n,
                child: Text('${n}x  (parcela ~R\$ ${vp.toStringAsFixed(2)})'),
              );
            }).toList(),
            onChanged: (v) {
              setState(() => _numeroParcelas = v ?? 2);
              _updateSubmitState();
            },
          ),
        ],
        if (_isBoletoUnico(_formaPagamento)) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                locale: const Locale('pt', 'BR'),
              );
              if (picked != null) {
                setState(() => _boletoVencimento = picked);
                _updateSubmitState();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Data de Vencimento',
                prefixIcon: Icon(Icons.calendar_today, color: primaryColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              child: Text(
                _boletoVencimento != null
                    ? '${_boletoVencimento!.day.toString().padLeft(2, '0')}/${_boletoVencimento!.month.toString().padLeft(2, '0')}/${_boletoVencimento!.year}'
                    : 'Selecionar data',
                style: TextStyle(
                  color: _boletoVencimento != null ? Colors.black87 : Colors.grey[500],
                ),
              ),
            ),
          ),
        ],
        if (_isBoletoParcelado(_formaPagamento)) ...[
          const SizedBox(height: 12),
          _buildParcelasEditor(
            titulo: 'Parcelas do boleto (${_quantidadeParcelasTipo(_formaPagamento)}x)',
            parcelas: _boletoParcelasCompra,
            valorTotal: totalCompra,
            accentColor: primaryColor,
            onValorChanged: (idx, novoValor) {
              setState(() => _boletoParcelasCompra[idx].valor = novoValor);
              _updateSubmitState();
            },
            onVencimentoChanged: (idx, novaData) {
              setState(() => _boletoParcelasCompra[idx].vencimento = novaData);
              _updateSubmitState();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildFrete() {
    final freteColor = Colors.orange[700]!;
    final freteBorder = Colors.orange[300]!;
    final freteFill = Colors.orange[50]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _freteAtivo = !_freteAtivo;
              if (!_freteAtivo) {
                _freteValorController.clear();
                _fretePagamento = null;
                _freteNumeroParcelas = 1;
                _freteBoletoVencimento = null;
                _boletoParcelasFrete = [];
              }
            });
            _updateSubmitState();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _freteAtivo ? freteFill : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _freteAtivo ? freteBorder : Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _freteAtivo,
                  onChanged: (v) {
                    setState(() {
                      _freteAtivo = v ?? false;
                      if (!_freteAtivo) {
                        _freteValorController.clear();
                        _fretePagamento = null;
                        _freteNumeroParcelas = 1;
                        _freteBoletoVencimento = null;
                        _boletoParcelasFrete = [];
                      }
                    });
                    _updateSubmitState();
                  },
                  activeColor: freteColor,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                Icon(Icons.local_shipping_outlined, color: freteColor, size: 20),
                const SizedBox(width: 8),
                const Text('Frete', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                if (_freteAtivo) ...[
                  const Spacer(),
                  Builder(builder: (_) {
                    final v = double.tryParse(_freteValorController.text.replaceAll(',', '.')) ?? 0;
                    if (v <= 0) return const SizedBox.shrink();
                    return Text(
                      'R\$ ${v.toStringAsFixed(2)}',
                      style: TextStyle(color: freteColor, fontWeight: FontWeight.w600, fontSize: 13),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        if (_freteAtivo) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _freteValorController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) {
              setState(() {});
              _updateSubmitState();
            },
            decoration: InputDecoration(
              labelText: 'Valor do Frete',
              prefixText: 'R\$ ',
              prefixIcon: Icon(Icons.local_shipping, color: freteColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: freteBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: freteColor, width: 2),
              ),
              filled: true,
              fillColor: freteFill,
            ),
          ),
          if (_pecasAdicionadas.isNotEmpty)
            Builder(builder: (_) {
              final v = double.tryParse(_freteValorController.text.replaceAll(',', '.')) ?? 0;
              if (v <= 0) return const SizedBox.shrink();
              final perItem = v / _pecasAdicionadas.length;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: freteColor),
                    const SizedBox(width: 4),
                    Text(
                      'Rateio: +R\$ ${perItem.toStringAsFixed(2)} por item (${_pecasAdicionadas.length} item(ns))',
                      style: TextStyle(fontSize: 12, color: freteColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 12),
          Builder(builder: (_) {
            final tiposFreteOrdenados = List<TipoPagamento>.from(_tiposPagamento)
              ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

            return DropdownButtonFormField<TipoPagamento>(
              initialValue: _fretePagamento,
              decoration: InputDecoration(
                labelText: 'Forma de Pagamento do Frete',
                prefixIcon: Icon(Icons.payment, color: freteColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: freteBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: freteColor, width: 2),
                ),
                filled: true,
                fillColor: freteFill,
              ),
              items: tiposFreteOrdenados
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Row(
                          children: [
                            Icon(_iconeTipoPagamento(f), size: 18, color: freteColor),
                            const SizedBox(width: 8),
                            Text(f.nome),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                final valorFrete = double.tryParse(_freteValorController.text.replaceAll(',', '.')) ?? 0;
                setState(() {
                  _fretePagamento = v;
                  _freteBoletoVencimento = null;
                  _freteNumeroParcelas = 1;
                  _boletoParcelasFrete = [];
                  if (_isBoletoParcelado(_fretePagamento) && valorFrete > 0) {
                    _boletoParcelasFrete = _gerarParcelasPadrao(
                      valorTotal: valorFrete,
                      quantidade: _quantidadeParcelasTipo(_fretePagamento),
                      base: DateTime.now(),
                    );
                  }
                });
                _updateSubmitState();
              },
            );
          }),
          if (_isCredito(_fretePagamento)) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _freteNumeroParcelas,
              decoration: InputDecoration(
                labelText: 'Parcelas do Frete',
                prefixIcon: Icon(Icons.format_list_numbered, color: freteColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: freteBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: freteColor, width: 2),
                ),
                filled: true,
                fillColor: freteFill,
              ),
              items: List.generate(
                _quantidadeParcelasTipo(_fretePagamento) > 0 ? _quantidadeParcelasTipo(_fretePagamento) : 1,
                (i) => i + 1,
              ).map((n) {
                final vFrete = double.tryParse(_freteValorController.text.replaceAll(',', '.')) ?? 0;
                final vp = vFrete > 0 ? vFrete / n : 0.0;
                return DropdownMenuItem(
                  value: n,
                  child: Text('${n}x  (parcela ~R\$ ${vp.toStringAsFixed(2)})'),
                );
              }).toList(),
              onChanged: (v) {
                setState(() => _freteNumeroParcelas = v ?? 2);
                _updateSubmitState();
              },
            ),
          ],
          if (_isBoletoUnico(_fretePagamento)) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final hoje = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime(hoje.year, hoje.month, 1),
                  firstDate: DateTime(hoje.year, hoje.month, 1),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  locale: const Locale('pt', 'BR'),
                );
                if (picked != null) {
                  setState(() => _freteBoletoVencimento = picked);
                  _updateSubmitState();
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Vencimento do Frete',
                  prefixIcon: Icon(Icons.calendar_today, color: freteColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: freteBorder),
                  ),
                  filled: true,
                  fillColor: freteFill,
                ),
                child: Text(
                  _freteBoletoVencimento != null
                      ? '${_freteBoletoVencimento!.day.toString().padLeft(2, '0')}/${_freteBoletoVencimento!.month.toString().padLeft(2, '0')}/${_freteBoletoVencimento!.year}'
                      : 'Selecionar data',
                  style: TextStyle(
                    color: _freteBoletoVencimento != null ? Colors.black87 : Colors.grey[500],
                  ),
                ),
              ),
            ),
          ],
          if (_isBoletoParcelado(_fretePagamento)) ...[
            const SizedBox(height: 12),
            _buildParcelasEditor(
              titulo: 'Parcelas do frete (${_quantidadeParcelasTipo(_fretePagamento)}x)',
              parcelas: _boletoParcelasFrete,
              valorTotal: double.tryParse(_freteValorController.text.replaceAll(',', '.')) ?? 0,
              accentColor: freteColor,
              onValorChanged: (idx, novoValor) {
                setState(() => _boletoParcelasFrete[idx].valor = novoValor);
                _updateSubmitState();
              },
              onVencimentoChanged: (idx, novaData) {
                setState(() => _boletoParcelasFrete[idx].vencimento = novaData);
                _updateSubmitState();
              },
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildParcelasEditor({
    required String titulo,
    required List<_ParcelaPagamentoDraft> parcelas,
    required double valorTotal,
    required Color accentColor,
    required void Function(int idx, double novoValor) onValorChanged,
    required void Function(int idx, DateTime novaData) onVencimentoChanged,
  }) {
    final soma = _somaParcelas(parcelas);
    final ok = valorTotal > 0 && parcelas.isNotEmpty && (soma - valorTotal).abs() <= 0.02;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accentColor),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < parcelas.length; i++) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${parcelas[i].numero}ª parcela',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Text(
                    DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
                            .isAfter(DateTime(parcelas[i].vencimento.year, parcelas[i].vencimento.month, parcelas[i].vencimento.day))
                        ? 'Vencido'
                        : '${parcelas[i].vencimento.day.toString().padLeft(2, '0')}/${parcelas[i].vencimento.month.toString().padLeft(2, '0')}/${parcelas[i].vencimento.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Text(
                    'R\$ ${parcelas[i].valor.toStringAsFixed(2)}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Editar valor',
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () async {
                    final ctrl = TextEditingController(text: parcelas[i].valor.toStringAsFixed(2).replaceAll('.', ','));
                    final novoValor = await showDialog<double>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('${parcelas[i].numero}ª parcela'),
                        content: TextField(
                          controller: ctrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                          TextButton(
                            onPressed: () {
                              final parsed = double.tryParse(ctrl.text.replaceAll(',', '.'));
                              if (parsed == null || parsed <= 0) return;
                              Navigator.pop(ctx, parsed);
                            },
                            child: const Text('Salvar'),
                          ),
                        ],
                      ),
                    );
                    if (novoValor != null) {
                      onValorChanged(i, novoValor);
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Editar vencimento',
                  icon: const Icon(Icons.event, size: 18),
                  onPressed: () async {
                    final hoje = DateTime.now();
                    final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: parcelas[i].vencimento,
                      firstDate: hojeSemHora,
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      locale: const Locale('pt', 'BR'),
                    );
                    if (picked != null) {
                      onVencimentoChanged(i, picked);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
        if (parcelas.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Soma: R\$ ${soma.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: ok ? successColor : errorColor,
              ),
            ),
          ),
      ],
    );
  }
}
