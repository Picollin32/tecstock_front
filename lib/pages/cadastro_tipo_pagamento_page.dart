import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tecstock/model/tipo_pagamento.dart';
import 'package:intl/intl.dart';
import '../services/tipo_pagamento_service.dart';
import '../widgets/pagination_controls.dart';

class CadastroTipoPagamentoPage extends StatefulWidget {
  const CadastroTipoPagamentoPage({super.key});

  @override
  State<CadastroTipoPagamentoPage> createState() => _CadastroTipoPagamentoPageState();
}

class _CadastroTipoPagamentoPageState extends State<CadastroTipoPagamentoPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _quantidadeParcelasController = TextEditingController();
  final TextEditingController _diasEntreParcelasController = TextEditingController();
  final TextEditingController _mesesBoletoController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _pagamentoAVista = true;
  int _formaNaoVista = 2;

  List<TipoPagamento> _tiposPagamento = [];
  List<TipoPagamento> _tiposPagamentoFiltrados = [];
  TipoPagamento? _tipoPagamentoEmEdicao;

  bool _isLoading = false;
  bool _isLoadingTipos = true;

  Timer? _debounceTimer;
  int _currentPage = 0;
  int _totalPages = 0;
  int _totalElements = 0;
  String _lastSearchQuery = '';
  int _pageSize = 30;
  final List<int> _pageSizeOptions = [30, 50, 100];

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
    _carregarTiposPagamento();
    _searchController.addListener(_onSearchChanged);
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
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _nomeController.dispose();
    _quantidadeParcelasController.dispose();
    _diasEntreParcelasController.dispose();
    _mesesBoletoController.dispose();
    super.dispose();
  }

  void _onSearchChanged({bool force = false}) {
    final query = _searchController.text.trim();
    if (!force && query == _lastSearchQuery) return;
    _lastSearchQuery = query;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _currentPage = 0;
      });
      _filtrarTiposPagamento();
    });
  }

  Future<void> _filtrarTiposPagamento() async {
    final query = _searchController.text;
    setState(() => _isLoadingTipos = true);

    try {
      final resultado = await TipoPagamentoService.buscarPaginado(query, _currentPage, size: _pageSize);

      if (resultado['success']) {
        setState(() {
          _tiposPagamentoFiltrados = resultado['content'] as List<TipoPagamento>;
          _totalPages = resultado['totalPages'] as int;
          _totalElements = resultado['totalElements'] as int;
        });
      } else {
        _showVisibleError('Erro ao buscar tipos de pagamento');
      }
    } catch (e) {
      _showVisibleError('Erro ao buscar tipos de pagamento');
    } finally {
      setState(() => _isLoadingTipos = false);
    }
  }

  void _irParaPagina(int page) {
    if (page < 0 || page >= _totalPages) return;
    setState(() => _currentPage = page);
    _filtrarTiposPagamento();
  }

  void _alterarPageSize(int size) {
    setState(() {
      _pageSize = size;
      _currentPage = 0;
    });
    _filtrarTiposPagamento();
  }

  Future<void> _carregarTiposPagamento() async {
    setState(() => _isLoadingTipos = true);
    try {
      final resultado = await TipoPagamentoService.buscarPaginado('', 0, size: _pageSize);

      if (resultado['success']) {
        setState(() {
          _tiposPagamento = resultado['content'] as List<TipoPagamento>;
          _tiposPagamentoFiltrados = _tiposPagamento;
          _totalPages = resultado['totalPages'] as int;
          _totalElements = resultado['totalElements'] as int;
          _currentPage = 0;
        });
      } else {
        _showVisibleError('Erro ao carregar tipos de pagamento');
      }
    } catch (e) {
      _showVisibleError('Erro ao carregar tipos de pagamento');
    } finally {
      setState(() => _isLoadingTipos = false);
    }
  }

  Future<void> _salvarTipoPagamento() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final mesesBoleto = (int.tryParse(_mesesBoletoController.text.trim()) ?? 1).clamp(1, 12);
      final textoDiasBoleto = _diasEntreParcelasController.text.trim();
      final diasBoletoInformado = int.tryParse(textoDiasBoleto);
      final diasBoleto =
          textoDiasBoleto.isEmpty ? 30 : ((diasBoletoInformado == null || diasBoletoInformado < 1) ? 1 : diasBoletoInformado);
      final nomeBase = _nomeController.text.trim();
      final formaSelecionada = _pagamentoAVista ? 1 : _formaNaoVista;
      final bool ehBoleto = formaSelecionada == 3;
      final bool ehCartaoParcelado = formaSelecionada == 2;
      final nomeFinal = (!_pagamentoAVista && ehBoleto) ? _nomeComPrazoBoleto(nomeBase, mesesBoleto, diasBoleto) : nomeBase;

      final tipoPagamento = TipoPagamento(
        id: _tipoPagamentoEmEdicao?.id,
        nome: nomeFinal,
        idFormaPagamento: formaSelecionada,
        quantidadeParcelas:
            _pagamentoAVista ? 1 : (ehBoleto ? mesesBoleto : (int.tryParse(_quantidadeParcelasController.text.trim()) ?? 1)),
        diasEntreParcelas: _pagamentoAVista
            ? 0
            : (ehCartaoParcelado ? 30 : (ehBoleto ? diasBoleto : (int.tryParse(_diasEntreParcelasController.text.trim()) ?? 0))),
      );

      Map<String, dynamic> resultado;
      if (_tipoPagamentoEmEdicao != null) {
        resultado = await TipoPagamentoService.atualizarTipoPagamento(_tipoPagamentoEmEdicao!.id!, tipoPagamento);
      } else {
        resultado = await TipoPagamentoService.salvarTipoPagamento(tipoPagamento);
      }

      if (resultado['success']) {
        if (!mounted) return;
        Navigator.pop(context);
        await _carregarTiposPagamento();
        _showSuccessSnackBar(resultado['message']);
        _limparFormulario();
      } else {
        _showVisibleError(resultado['message']);
      }
    } catch (e) {
      _showVisibleError('Erro inesperado ao salvar tipo de pagamento');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _editarTipoPagamento(TipoPagamento tipoPagamento) {
    final quantidade = tipoPagamento.quantidadeParcelas ?? 1;
    final dias = tipoPagamento.diasEntreParcelas ?? 0;
    final forma = tipoPagamento.idFormaPagamento ?? ((quantidade == 1 && dias == 0) ? 1 : 2);

    setState(() {
      _tipoPagamentoEmEdicao = tipoPagamento;
      _nomeController.text = tipoPagamento.nome;
      _quantidadeParcelasController.text = quantidade.toString();
      _diasEntreParcelasController.text = dias.toString();
      _pagamentoAVista = forma == 1;
      _formaNaoVista = (forma == 2 || forma == 3 || forma == 4) ? forma : 2;
      _mesesBoletoController.text = quantidade.clamp(1, 12).toString();
    });
    _showFormModal();
  }

  Future<void> _confirmarExclusao(TipoPagamento tipoPagamento) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: errorColor, size: 28),
            const SizedBox(width: 12),
            const Text('Confirmar Exclusão'),
          ],
        ),
        content: Text('Deseja excluir o tipo de pagamento ${tipoPagamento.nome}?'),
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
              await _excluirTipoPagamento(tipoPagamento);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _excluirTipoPagamento(TipoPagamento tipoPagamento) async {
    setState(() => _isLoading = true);
    try {
      final resultado = await TipoPagamentoService.excluirTipoPagamento(tipoPagamento.id!);
      if (resultado['success']) {
        await _carregarTiposPagamento();
        _showSuccessSnackBar(resultado['message']);
      } else {
        _showVisibleError(resultado['message']);
      }
    } catch (e) {
      _showVisibleError('Erro inesperado ao excluir tipo de pagamento: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    _nomeController.clear();
    _quantidadeParcelasController.text = '1';
    _diasEntreParcelasController.text = '0';
    _mesesBoletoController.text = '1';
    _pagamentoAVista = true;
    _formaNaoVista = 2;
    _tipoPagamentoEmEdicao = null;
  }

  String _resumoPrazosBoleto(int meses, int diasEntreParcelas) {
    final intervalo = diasEntreParcelas < 1 ? 30 : diasEntreParcelas;
    final valores = List.generate(meses, (i) => '${(i + 1) * intervalo}');
    return valores.join('/');
  }

  String _nomeComPrazoBoleto(String nomeBase, int meses, int diasEntreParcelas) {
    final semSufixo = nomeBase.trim().replaceFirst(RegExp(r'\s*\((\d{1,3}(?:/\d{1,3})*)\)\s*$'), '');
    return '$semSufixo (${_resumoPrazosBoleto(meses, diasEntreParcelas)})';
  }

  Widget _buildOpcaoBooleana({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? primaryColor.withValues(alpha: 0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? primaryColor : Colors.grey.shade300,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? primaryColor : Colors.grey.shade600,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: selected ? primaryColor : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpcaoFormaNaoVista({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? primaryColor.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? primaryColor : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? primaryColor : Colors.grey.shade600, size: 20),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? primaryColor : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: selected ? primaryColor : Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          hintText: 'Buscar tipos de pagamento...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildMobileTipoPagamentoCard(TipoPagamento tipoPagamento) {
    final int forma = tipoPagamento.idFormaPagamento ?? 1;
    final bool parcelado = forma == 2;
    final bool boleto = forma == 3;
    final bool fiado = forma == 4;
    final String formaLabel = boleto ? 'Boleto' : (fiado ? 'Crediário Próprio' : (parcelado ? 'Parcelado' : 'À vista'));
    final int parcelas = tipoPagamento.quantidadeParcelas ?? 1;
    final int intervalo = tipoPagamento.diasEntreParcelas ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _editarTipoPagamento(tipoPagamento),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.payment, color: primaryColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        tipoPagamento.nome,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'editar') _editarTipoPagamento(tipoPagamento);
                        if (value == 'excluir') _confirmarExclusao(tipoPagamento);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'editar',
                          child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar')]),
                        ),
                        const PopupMenuItem(
                          value: 'excluir',
                          child: Row(children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Excluir', style: TextStyle(color: Colors.red)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
                if (tipoPagamento.createdAt != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          'Cadastrado: ${DateFormat("dd/MM/yyyy").format(tipoPagamento.createdAt!)}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Forma: $formaLabel',
                        style: TextStyle(color: Colors.grey[700], fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Parcelas: $parcelas',
                        style: TextStyle(color: Colors.grey[700], fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        boleto ? 'Prazos: ${_resumoPrazosBoleto(parcelas.clamp(1, 12), intervalo)}' : 'Intervalo: $intervalo dias',
                        style: TextStyle(color: Colors.grey[700], fontSize: 11, fontWeight: FontWeight.w600),
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

  Widget _buildTiposPagamentoGrid({bool isMobile = false}) {
    if (_isLoadingTipos) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    if (_tiposPagamentoFiltrados.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.payment, color: Colors.grey[400], size: 64),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty ? 'Nenhum tipo de pagamento cadastrado' : 'Nenhum tipo de pagamento encontrado',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (isMobile) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _tiposPagamentoFiltrados.length,
        itemBuilder: (context, index) {
          final tipoPagamento = _tiposPagamentoFiltrados[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildMobileTipoPagamentoCard(tipoPagamento),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount;
        if (constraints.maxWidth >= 1200) {
          crossAxisCount = 6;
        } else if (constraints.maxWidth >= 800) {
          crossAxisCount = 4;
        } else {
          crossAxisCount = 3;
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 178,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _tiposPagamentoFiltrados.length,
          itemBuilder: (context, index) {
            final tipoPagamento = _tiposPagamentoFiltrados[index];
            return _buildTipoPagamentoCard(tipoPagamento);
          },
        );
      },
    );
  }

  Widget _buildTipoPagamentoCard(TipoPagamento tipoPagamento) {
    final int forma = tipoPagamento.idFormaPagamento ?? 1;
    final bool parcelado = forma == 2;
    final bool boleto = forma == 3;
    final bool fiado = forma == 4;
    final String formaLabel = boleto ? 'Boleto' : (fiado ? 'Crediário Próprio' : (parcelado ? 'Parcelado' : 'À vista'));
    final int parcelas = tipoPagamento.quantidadeParcelas ?? 1;
    final int intervalo = tipoPagamento.diasEntreParcelas ?? 0;

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
          onTap: () => _editarTipoPagamento(tipoPagamento),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.payment,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tipoPagamento.nome,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'editar') {
                          _editarTipoPagamento(tipoPagamento);
                        } else if (value == 'excluir') {
                          _confirmarExclusao(tipoPagamento);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'editar',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'excluir',
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
                      Row(
                        children: [
                          Icon(
                            boleto
                                ? Icons.receipt_long
                                : (fiado ? Icons.handshake_outlined : (parcelado ? Icons.credit_card : Icons.payments_outlined)),
                            size: 12,
                            color: boleto
                                ? Colors.blue[700]
                                : (fiado ? Colors.teal[700] : (parcelado ? Colors.orange[700] : Colors.green[700])),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Forma: $formaLabel',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.format_list_numbered, size: 12, color: Colors.grey[700]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Parcelas: $parcelas',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.numbers, size: 12, color: Colors.grey[700]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              boleto ? 'Prazos: ${_resumoPrazosBoleto(parcelas.clamp(1, 12), intervalo)}' : 'Intervalo: $intervalo dias',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (tipoPagamento.createdAt != null) const SizedBox(height: 4),
                      if (tipoPagamento.createdAt != null)
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              'Cadastrado: ${DateFormat('dd/MM/yyyy').format(tipoPagamento.createdAt!)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
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

  void _showFormModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
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
                  color: primaryColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Icon(
                      _tipoPagamentoEmEdicao != null ? Icons.edit : Icons.add,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _tipoPagamentoEmEdicao != null ? 'Editar Tipo de Pagamento' : 'Novo Tipo de Pagamento',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
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
                  child: StatefulBuilder(
                    builder: (context, setModalState) => Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _nomeController,
                            decoration: InputDecoration(
                              labelText: 'Nome do Tipo de Pagamento',
                              hintText: 'Ex: PIX, Cartão de Débito, Dinheiro',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: primaryColor, width: 2),
                              ),
                              prefixIcon: const Icon(Icons.payment),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Nome é obrigatório';
                              }
                              if (value.trim().length < 2) {
                                return 'Nome deve ter pelo menos 2 caracteres';
                              }
                              return null;
                            },
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pagamento à vista?',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildOpcaoBooleana(
                                      label: 'Sim',
                                      selected: _pagamentoAVista,
                                      onTap: () {
                                        setModalState(() {
                                          _pagamentoAVista = true;
                                          _formaNaoVista = 2;
                                          _quantidadeParcelasController.text = '1';
                                          _diasEntreParcelasController.text = '0';
                                          _mesesBoletoController.text = '1';
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 10),
                                    _buildOpcaoBooleana(
                                      label: 'Não',
                                      selected: !_pagamentoAVista,
                                      onTap: () {
                                        setModalState(() {
                                          _pagamentoAVista = false;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!_pagamentoAVista) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Qual outra forma?',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Escolha como o pagamento será parcelado.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 8),
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final bool unicaColuna = constraints.maxWidth < 700;
                                      final larguraItem = unicaColuna ? constraints.maxWidth : (constraints.maxWidth - 20) / 3;

                                      return Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          SizedBox(
                                            width: larguraItem,
                                            child: _buildOpcaoFormaNaoVista(
                                              label: 'Cartão Parcelado',
                                              icon: Icons.credit_card,
                                              selected: _formaNaoVista == 2,
                                              onTap: () {
                                                setModalState(() {
                                                  _formaNaoVista = 2;
                                                  _diasEntreParcelasController.text = '30';
                                                });
                                              },
                                            ),
                                          ),
                                          SizedBox(
                                            width: larguraItem,
                                            child: _buildOpcaoFormaNaoVista(
                                              label: 'Boleto',
                                              icon: Icons.receipt_long,
                                              selected: _formaNaoVista == 3,
                                              onTap: () {
                                                setModalState(() {
                                                  _formaNaoVista = 3;
                                                  final diasEdit = _tipoPagamentoEmEdicao?.diasEntreParcelas;
                                                  _diasEntreParcelasController.text =
                                                      (diasEdit == null ? 30 : (diasEdit < 1 ? 1 : diasEdit)).toString();
                                                  _mesesBoletoController.text =
                                                      (_tipoPagamentoEmEdicao?.quantidadeParcelas ?? 1).clamp(1, 12).toString();
                                                });
                                              },
                                            ),
                                          ),
                                          SizedBox(
                                            width: larguraItem,
                                            child: _buildOpcaoFormaNaoVista(
                                              label: 'Crediário Próprio',
                                              icon: Icons.handshake_outlined,
                                              selected: _formaNaoVista == 4,
                                              onTap: () {
                                                setModalState(() {
                                                  _formaNaoVista = 4;
                                                });
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (!_pagamentoAVista) ...[
                            const SizedBox(height: 16),
                            if (_formaNaoVista == 3)
                              TextFormField(
                                controller: _mesesBoletoController,
                                decoration: InputDecoration(
                                  labelText: 'Quantidade de Parcelas',
                                  hintText: 'Ex: 1, 2, 3... até 12',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: primaryColor, width: 2),
                                  ),
                                  prefixIcon: const Icon(Icons.receipt_long),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (_pagamentoAVista || _formaNaoVista != 3) return null;
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Quantidade de parcelas é obrigatória';
                                  }
                                  final parsed = int.tryParse(value.trim());
                                  if (parsed == null || parsed < 1 || parsed > 12) {
                                    return 'Informe um número entre 1 e 12';
                                  }
                                  return null;
                                },
                              )
                            else
                              TextFormField(
                                controller: _quantidadeParcelasController,
                                decoration: InputDecoration(
                                  labelText: 'Quantidade de Parcelas',
                                  hintText: _formaNaoVista == 2 ? 'Ex: 2, 3, 4... ' : 'Ex: 1, 2, 3... ',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: primaryColor, width: 2),
                                  ),
                                  prefixIcon: const Icon(Icons.format_list_numbered),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (_pagamentoAVista || _formaNaoVista == 3) return null;
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Quantidade de parcelas é obrigatória';
                                  }
                                  final parsed = int.tryParse(value.trim());
                                  if (_formaNaoVista == 2) {
                                    if (parsed == null || parsed < 2) {
                                      return 'Informe um número inteiro maior ou igual a 2';
                                    }
                                  } else if (parsed == null || parsed < 1) {
                                    return 'Informe um número inteiro maior ou igual a 1';
                                  }
                                  return null;
                                },
                              ),
                            if (_formaNaoVista == 3) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _diasEntreParcelasController,
                                decoration: InputDecoration(
                                  labelText: 'Intervalo de dias entre parcelas',
                                  hintText: 'Ex: 15, 30',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: primaryColor, width: 2),
                                  ),
                                  prefixIcon: const Icon(Icons.numbers_outlined),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (_pagamentoAVista || _formaNaoVista != 3) return null;
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Intervalo de dias entre parcelas é obrigatório';
                                  }
                                  final parsed = int.tryParse(value.trim());
                                  if (parsed == null || parsed < 1) {
                                    return 'Informe um número inteiro maior ou igual a 1';
                                  }
                                  return null;
                                },
                              ),
                            ] else ...[
                              if (_formaNaoVista != 2) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _diasEntreParcelasController,
                                  decoration: InputDecoration(
                                    labelText: 'Intervalo de dias entre parcelas',
                                    hintText: 'Ex: 15, 30',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: primaryColor, width: 2),
                                    ),
                                    prefixIcon: const Icon(Icons.numbers_outlined),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (_pagamentoAVista || _formaNaoVista == 3 || _formaNaoVista == 2) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Intervalo de dias entre parcelas é obrigatório';
                                    }
                                    final parsed = int.tryParse(value.trim());
                                    if (parsed == null || parsed < 1) {
                                      return 'Informe um número inteiro maior ou igual a 1';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ],
                          ],
                          const SizedBox(height: 24),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _salvarTipoPagamento,
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
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _tipoPagamentoEmEdicao != null ? 'Atualizar' : 'Salvar',
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls({bool compact = false}) {
    return PaginationControls(
      currentPage: _currentPage,
      totalPages: _totalPages,
      pageSize: _pageSize,
      pageSizeOptions: _pageSizeOptions,
      onPageChange: _irParaPagina,
      onPageSizeChange: _alterarPageSize,
      primaryColor: primaryColor,
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) return _buildMobileLayout();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Tipos de Pagamento',
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
                          color: primaryColor.withValues(alpha: 0.3),
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
              if (_searchController.text.isEmpty && !_isLoadingTipos && _tiposPagamentoFiltrados.isNotEmpty)
                Text(
                  'Tipos de Pagamento Cadastrados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              if (_searchController.text.isNotEmpty && !_isLoadingTipos)
                Text(
                  'Resultados da Busca ($_totalElements)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              const SizedBox(height: 16),
              if (_searchController.text.isNotEmpty && _totalElements > _pageSize) ...[
                _buildPaginationControls(compact: true),
                const SizedBox(height: 10),
              ],
              _buildTiposPagamentoGrid(),
              if (_searchController.text.isNotEmpty && _totalElements > _pageSize) ...[
                const SizedBox(height: 16),
                _buildPaginationControls(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Tipos de Pagamento',
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _limparFormulario();
          _showFormModal();
        },
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                boxShadow: [
                  BoxShadow(color: shadowColor, blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: _buildSearchBar(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_searchController.text.isEmpty && !_isLoadingTipos && _tiposPagamentoFiltrados.isNotEmpty)
                      Text(
                        'Tipos de Pagamento Cadastrados',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                      ),
                    if (_searchController.text.isNotEmpty && !_isLoadingTipos)
                      Text(
                        'Resultados da Busca ($_totalElements)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                      ),
                    const SizedBox(height: 12),
                    _buildTiposPagamentoGrid(isMobile: true),
                    if (_searchController.text.isNotEmpty && _totalElements > _pageSize) ...[
                      const SizedBox(height: 16),
                      _buildPaginationControls(),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
