import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../model/tipo_pagamento.dart';
import '../services/movimentacao_estoque_service.dart';
import '../services/tipo_pagamento_service.dart';

class _ParcelaNotaDraft {
  _ParcelaNotaDraft({
    required this.numero,
    required this.valor,
    required this.vencimento,
  });

  int numero;
  double valor;
  DateTime vencimento;
}

class NotasEntradaPage extends StatefulWidget {
  const NotasEntradaPage({super.key});

  @override
  State<NotasEntradaPage> createState() => _NotasEntradaPageState();
}

class _NotasEntradaPageState extends State<NotasEntradaPage> {
  static const Color _primaryColor = Color(0xFF059669);
  static const Color _accentColor = Color(0xFF6366F1);
  static const Color _bgColor = Color(0xFFF5F7FA);

  List<Map<String, dynamic>> _notas = [];
  List<Map<String, dynamic>> _notasFiltradas = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expanded = {};

  int? _fornecedorFiltroId;
  List<Map<String, dynamic>> _fornecedoresDisponiveis = [];
  Timer? _debounceTimer;
  List<TipoPagamento> _tiposPagamento = [];
  DateTime _mesAtual = DateTime(DateTime.now().year, DateTime.now().month, 1);

  int _currentPage = 0;
  static const int _pageSize = 20;

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

  List<_ParcelaNotaDraft> _gerarParcelasPadrao(double valorTotal, int quantidade) {
    final parcelas = <_ParcelaNotaDraft>[];
    if (quantidade < 1) return parcelas;

    final valorBase = valorTotal / quantidade;
    double acumulado = 0;
    final hoje = DateTime.now();

    for (int i = 0; i < quantidade; i++) {
      final valorParcela =
          i == quantidade - 1 ? ((valorTotal - acumulado) * 100).roundToDouble() / 100 : (valorBase * 100).roundToDouble() / 100;
      acumulado += valorParcela;
      parcelas.add(
        _ParcelaNotaDraft(
          numero: i + 1,
          valor: valorParcela,
          vencimento: DateTime(hoje.year, hoje.month + i + 1, hoje.day),
        ),
      );
    }
    return parcelas;
  }

  double _somaParcelasNota(List<_ParcelaNotaDraft> parcelas) {
    return parcelas.fold<double>(0, (sum, p) => sum + p.valor);
  }

  TipoPagamento? _primeiroTipoPorForma(int idForma, {int? quantidadeParcelas}) {
    for (final t in _tiposPagamento) {
      if (_idFormaPagamento(t) != idForma) continue;
      if (quantidadeParcelas == null || _quantidadeParcelasTipo(t) == quantidadeParcelas) {
        return t;
      }
    }
    return null;
  }

  int get _totalPages => (_notasFiltradas.length / _pageSize).ceil().clamp(1, 999999);

  static const List<String> _mesesPtBr = [
    'Janeiro',
    'Fevereiro',
    'Marco',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  String get _labelMesAtual => '${_mesesPtBr[_mesAtual.month - 1]} de ${_mesAtual.year}';

  List<Map<String, dynamic>> get _notasPaginadas {
    final start = _currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, _notasFiltradas.length);
    if (start >= _notasFiltradas.length) return [];
    return _notasFiltradas.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _carregarDados();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        MovimentacaoEstoqueService.listarNotasEntrada(),
        TipoPagamentoService.listarTiposPagamento(),
      ]);
      final notas = results[0] as List<Map<String, dynamic>>;
      final tipos = results[1] as List<TipoPagamento>;
      setState(() {
        _notas = notas;
        _tiposPagamento = tipos;

        final seen = <int>{};
        _fornecedoresDisponiveis = notas.map((n) => n['fornecedor'] as Map<String, dynamic>?).whereType<Map<String, dynamic>>().where((f) {
          final id = f['id'] as int?;
          return id != null && seen.add(id);
        }).toList()
          ..sort((a, b) => (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));

        if (_fornecedorFiltroId != null && !_fornecedoresDisponiveis.any((f) => f['id'] == _fornecedorFiltroId)) {
          _fornecedorFiltroId = null;
        }
        _filtrar();
      });
    } catch (e) {
      _mostrarErro('Erro ao carregar notas de entrada: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _filtrar);
  }

  void _filtrar() {
    final q = _searchController.text.toLowerCase().trim();
    final mesSelecionado = DateTime(_mesAtual.year, _mesAtual.month, 1);

    setState(() {
      _notasFiltradas = _notas.where((n) {
        final numero = (n['numeroNotaFiscal'] ?? '').toString().toLowerCase();
        final fId = (n['fornecedor'] as Map?)?['id'] as int?;
        final dataNota = _extrairDataNota(n);
        final matchesNumero = q.isEmpty || numero.startsWith(q);
        final matchesFornecedor = _fornecedorFiltroId == null || fId == _fornecedorFiltroId;
        final matchesMes = dataNota != null && dataNota.year == mesSelecionado.year && dataNota.month == mesSelecionado.month;
        return matchesNumero && matchesFornecedor && matchesMes;
      }).toList()
        ..sort((a, b) {
          final da = _extrairDataNota(a) ?? DateTime(1900);
          final db = _extrairDataNota(b) ?? DateTime(1900);
          return db.compareTo(da);
        });
      _currentPage = 0;
    });
  }

  DateTime? _extrairDataNota(Map<String, dynamic> nota) {
    final candidato = nota['dataEntrada'] ?? nota['dataEmissao'] ?? nota['createdAt'];
    if (candidato == null) return null;
    return DateTime.tryParse(candidato.toString());
  }

  void _mudarMes(int delta) {
    setState(() {
      _mesAtual = DateTime(_mesAtual.year, _mesAtual.month + delta, 1);
    });
    _filtrar();
  }

  void _paginaAnterior() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
    }
  }

  void _proximaPagina() {
    if (_currentPage < _totalPages - 1) {
      setState(() => _currentPage++);
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _mostrarSucesso(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: _primaryColor),
    );
  }

  double get _totalGeral => _notasFiltradas.fold(0.0, (s, n) => s + ((n['valorTotal'] as num?)?.toDouble() ?? 0.0));

  int get _totalContas => _notasFiltradas.fold(0, (s, n) {
        final contas = (n['contas'] as List?) ?? [];
        return s + contas.where((c) => (c['pago'] == false)).length;
      });

  String _labelPagamento(Map<String, dynamic> nota) {
    final contas = (nota['contas'] as List?) ?? [];
    if (contas.isEmpty) return 'À Vista';
    final origens = contas.map((c) => c['origemTipo']?.toString() ?? '').toSet();
    if (origens.contains('COMPRA_CREDITO')) {
      final total = contas.length;
      return 'Crédito ($total parcela${total > 1 ? 's' : ''})';
    }
    if (origens.contains('COMPRA_BOLETO')) {
      return contas.length == 1 ? 'Boleto 30 dias' : 'Boleto (${contas.length} parcelas)';
    }
    return 'À Vista';
  }

  bool _temContaPendente(Map<String, dynamic> nota) {
    final contas = (nota['contas'] as List?) ?? [];
    return contas.any((c) => c['pago'] == false);
  }

  void _abrirEdicao(Map<String, dynamic> nota) {
    final fornecedor = (nota['fornecedor'] as Map?) ?? {};
    final fornecedorId = fornecedor['id'] as int?;
    final numeroAtual = nota['numeroNotaFiscal']?.toString() ?? '';
    final valorTotal = (nota['valorTotal'] as num?)?.toDouble() ?? 0.0;

    final formKey = GlobalKey<FormState>();
    final numeroCtrl = TextEditingController(text: numeroAtual);
    final tiposOrdenados = List<TipoPagamento>.from(_tiposPagamento)..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

    final contas = (nota['contas'] as List?) ?? [];
    TipoPagamento? formaPagamentoAtual;
    if (contas.isNotEmpty) {
      final origem = contas.first['origemTipo']?.toString() ?? '';
      if (origem == 'COMPRA_CREDITO') {
        formaPagamentoAtual = _primeiroTipoPorForma(2);
      } else if (origem == 'COMPRA_BOLETO') {
        formaPagamentoAtual = _primeiroTipoPorForma(3, quantidadeParcelas: contas.length);
        formaPagamentoAtual ??= _primeiroTipoPorForma(3);
      }
    }
    formaPagamentoAtual ??= _primeiroTipoPorForma(1);

    TipoPagamento? novaForma = formaPagamentoAtual;
    int numeroParcelas = contas.isNotEmpty ? contas.length : 1;
    DateTime? boletoVencimento;
    List<_ParcelaNotaDraft> parcelasBoleto = [];

    if (contas.isNotEmpty && contas[0]['dataVencimento'] != null) {
      try {
        boletoVencimento = DateTime.parse(contas[0]['dataVencimento']);
      } catch (_) {}
    }

    for (int i = 0; i < contas.length; i++) {
      final item = contas[i];
      if (item['dataVencimento'] == null) continue;
      try {
        parcelasBoleto.add(
          _ParcelaNotaDraft(
            numero: i + 1,
            valor: (item['valor'] as num?)?.toDouble() ?? 0,
            vencimento: DateTime.parse(item['dataVencimento']),
          ),
        );
      } catch (_) {}
    }

    if (_isCredito(novaForma)) {
      final max = _quantidadeParcelasTipo(novaForma);
      numeroParcelas = numeroParcelas.clamp(1, max > 0 ? max : 1);
    }
    if (_isBoletoParcelado(novaForma)) {
      final quantidade = _quantidadeParcelasTipo(novaForma);
      if (parcelasBoleto.length != quantidade) {
        parcelasBoleto = _gerarParcelasPadrao(valorTotal, quantidade);
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlg) {
          Future<void> pickDateBoleto() async {
            final picked = await showDatePicker(
              context: ctx2,
              initialDate: DateTime.now().add(const Duration(days: 30)),
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
              locale: const Locale('pt', 'BR'),
            );
            if (picked != null) {
              setDlg(() => boletoVencimento = picked);
            }
          }

          Future<void> pickDateParcela(int idx) async {
            final picked = await showDatePicker(
              context: ctx2,
              initialDate: parcelasBoleto[idx].vencimento,
              firstDate: DateTime(2024),
              lastDate: DateTime(2030),
              locale: const Locale('pt', 'BR'),
            );
            if (picked != null) {
              setDlg(() => parcelasBoleto[idx].vencimento = picked);
            }
          }

          Future<void> editarValorParcela(int idx) async {
            final ctrl = TextEditingController(text: parcelasBoleto[idx].valor.toStringAsFixed(2).replaceAll('.', ','));
            final novo = await showDialog<double>(
              context: ctx2,
              builder: (dialogCtx) => AlertDialog(
                title: Text('Parcela ${idx + 1}'),
                content: TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancelar')),
                  TextButton(
                    onPressed: () {
                      final parsed = double.tryParse(ctrl.text.replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) return;
                      Navigator.pop(dialogCtx, parsed);
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              ),
            );
            if (novo != null) {
              setDlg(() => parcelasBoleto[idx].valor = novo);
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_note, color: _primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Editar Nota de Entrada', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: numeroCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9./-]'))],
                      decoration: const InputDecoration(
                        labelText: 'Número da Nota Fiscal',
                        prefixIcon: Icon(Icons.receipt_long, size: 20),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Informe o número da nota' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('Forma de Pagamento', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tiposOrdenados.map((f) {
                        final sel = novaForma == f;
                        return GestureDetector(
                          onTap: () => setDlg(() {
                            novaForma = f;
                            numeroParcelas = 1;
                            if (_isCredito(novaForma)) {
                              numeroParcelas = 1;
                            }
                            if (_isBoletoParcelado(novaForma)) {
                              final quantidade = _quantidadeParcelasTipo(novaForma);
                              if (parcelasBoleto.length != quantidade) {
                                parcelasBoleto = _gerarParcelasPadrao(valorTotal, quantidade);
                              }
                            } else {
                              parcelasBoleto = [];
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? _primaryColor : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: sel ? _primaryColor : Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_iconeTipoPagamento(f), size: 16, color: sel ? Colors.white : Colors.grey.shade700),
                                const SizedBox(width: 6),
                                Text(f.nome,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: sel ? Colors.white : Colors.grey.shade800,
                                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_isCredito(novaForma)) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Parcelas: ', style: TextStyle(fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: numeroParcelas,
                            items: List.generate(
                              _quantidadeParcelasTipo(novaForma) > 0 ? _quantidadeParcelasTipo(novaForma) : 1,
                              (i) => i + 1,
                            ).map((n) => DropdownMenuItem(value: n, child: Text('${n}x'))).toList(),
                            onChanged: (v) => setDlg(() => numeroParcelas = v!),
                            underline: Container(height: 1, color: Colors.grey),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Total: R\$ ${valorTotal.toStringAsFixed(2).replaceAll('.', ',')} '
                          '– R\$ ${(valorTotal / numeroParcelas).toStringAsFixed(2).replaceAll('.', ',')} por parcela',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ],
                    if (_isBoletoUnico(novaForma)) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: pickDateBoleto,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Vencimento',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                boletoVencimento != null ? DateFormat('dd/MM/yyyy').format(boletoVencimento!) : 'Selecionar data',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_isBoletoParcelado(novaForma)) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Boleto em ${_quantidadeParcelasTipo(novaForma)} parcelas',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      for (int i = 0; i < parcelasBoleto.length; i++) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${parcelasBoleto[i].numero}ª parcela',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  DateFormat('dd/MM/yyyy').format(parcelasBoleto[i].vencimento),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'R\$ ${parcelasBoleto[i].valor.toStringAsFixed(2).replaceAll('.', ',')}',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => editarValorParcela(i),
                              ),
                              IconButton(
                                icon: const Icon(Icons.event, size: 18),
                                onPressed: () => pickDateParcela(i),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Builder(builder: (_) {
                        final soma = _somaParcelasNota(parcelasBoleto);
                        final diff = (soma - valorTotal).abs();
                        final ok = diff < 0.02;
                        return Text(
                          'Total: R\$ ${soma.toStringAsFixed(2).replaceAll('.', ',')} '
                          '(esperado: R\$ ${valorTotal.toStringAsFixed(2).replaceAll('.', ',')})',
                          style: TextStyle(fontSize: 12, color: ok ? _primaryColor : Colors.red, fontWeight: FontWeight.w500),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  numeroParcelas = 1;
                  Navigator.pop(ctx);
                },
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Salvar'),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  Map<String, dynamic>? pagamentoData;
                  if (novaForma != null && (novaForma != formaPagamentoAtual || _isCredito(novaForma) || _isBoleto(novaForma))) {
                    if (_isBoletoUnico(novaForma) && boletoVencimento == null) {
                      _mostrarErro('Selecione a data de vencimento do boleto');
                      return;
                    }
                    if (_isBoletoParcelado(novaForma)) {
                      final quantidadeEsperada = _quantidadeParcelasTipo(novaForma);
                      if (parcelasBoleto.length != quantidadeEsperada) {
                        _mostrarErro('Quantidade de parcelas do boleto inválida');
                        return;
                      }
                      if (parcelasBoleto.any((p) => p.valor <= 0)) {
                        _mostrarErro('Preencha os valores das parcelas do boleto');
                        return;
                      }
                      if ((_somaParcelasNota(parcelasBoleto) - valorTotal).abs() > 0.02) {
                        _mostrarErro('A soma das parcelas deve ser igual ao valor total da nota');
                        return;
                      }
                    }
                    pagamentoData = {
                      'formaPagamento': _backendFormaPagamento(novaForma!),
                      'diasEntreParcelas': novaForma?.diasEntreParcelas ?? 30,
                    };
                    if (_isCredito(novaForma)) {
                      pagamentoData['numeroParcelas'] = numeroParcelas;
                    } else if (_isBoletoUnico(novaForma)) {
                      pagamentoData['boletoVencimento'] = boletoVencimento!.toIso8601String().substring(0, 10);
                    } else if (_isBoletoParcelado(novaForma)) {
                      pagamentoData['parcelasDetalhadas'] = parcelasBoleto
                          .map((p) => {
                                'numero': p.numero,
                                'valor': p.valor,
                                'vencimento': p.vencimento.toIso8601String().substring(0, 10),
                              })
                          .toList();
                      pagamentoData['numeroParcelas'] = parcelasBoleto.length;
                    }
                  }

                  final novoNumero = numeroCtrl.text.trim();
                  final mudouNumero = novoNumero != numeroAtual;

                  if (!mudouNumero && pagamentoData == null) {
                    Navigator.pop(ctx);
                    return;
                  }

                  Navigator.pop(ctx);

                  final result = await MovimentacaoEstoqueService.atualizarNota(
                    fornecedorId: fornecedorId!,
                    numeroNota: numeroAtual,
                    novoNumero: mudouNumero ? novoNumero : null,
                    pagamento: pagamentoData,
                  );

                  if (result['sucesso'] == true) {
                    _mostrarSucesso('Nota atualizada com sucesso!');
                    _carregarDados();
                  } else {
                    _mostrarErro(result['mensagem'] ?? 'Erro ao atualizar nota');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmarExclusao(Map<String, dynamic> nota) {
    final fornecedor = (nota['fornecedor'] as Map?) ?? {};
    final fornecedorId = fornecedor['id'] as int?;
    final numero = nota['numeroNotaFiscal']?.toString() ?? '';
    final valor = (nota['valorTotal'] as num?)?.toDouble() ?? 0.0;
    final itens = (nota['itens'] as List?) ?? [];
    final contas = (nota['contas'] as List?) ?? [];
    final contasPendentes = contas.where((c) => c['pago'] == false).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Excluir Nota de Entrada', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nota: $numero', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text('Fornecedor: ${fornecedor['nome'] ?? '-'}', style: const TextStyle(fontSize: 14, color: Colors.black54)),
            Text(
              'Valor total: R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber, size: 16, color: Colors.red),
                      SizedBox(width: 6),
                      Text('Esta ação é irreversível!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• ${itens.length} item(ns) de estoque serão descontados',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                  if (contasPendentes > 0)
                    Text(
                      '• $contasPendentes conta(s) a pagar vinculada(s) serão removidas',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('Excluir'),
            onPressed: () async {
              Navigator.pop(ctx);
              final result = await MovimentacaoEstoqueService.deletarNota(
                fornecedorId: fornecedorId!,
                numeroNota: numero,
              );
              if (result['sucesso'] == true) {
                _mostrarSucesso('Nota excluída com sucesso!');
                _carregarDados();
              } else {
                _mostrarErro(result['mensagem'] ?? 'Erro ao excluir nota');
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          'Notas de Entrada',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            color: _primaryColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.receipt_long,
                    label: 'Notas',
                    value: _notasFiltradas.length.toString(),
                    bgColor: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.attach_money,
                    label: 'Total Geral',
                    value: 'R\$ ${_totalGeral.toStringAsFixed(2).replaceAll('.', ',')}',
                    bgColor: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.pending_actions,
                    label: 'Contas Pendentes',
                    value: _totalContas.toString(),
                    bgColor: _totalContas > 0 ? Colors.orange.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: _primaryColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _mudarMes(-1),
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                    tooltip: 'Mes anterior',
                    visualDensity: VisualDensity.compact,
                  ),
                  Expanded(
                    child: Text(
                      _labelMesAtual,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _mudarMes(1),
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                    tooltip: 'Proximo mes',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Número da nota...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _filtrar();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _fornecedorFiltroId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Fornecedor',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _primaryColor, width: 1.5),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Todos os fornecedores'),
                      ),
                      ..._fornecedoresDisponiveis.map(
                        (f) => DropdownMenuItem<int?>(
                          value: f['id'] as int?,
                          child: Text(
                            (f['nome'] ?? '-').toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _fornecedorFiltroId = value);
                      _filtrar();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  )
                : _notasFiltradas.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        color: _primaryColor,
                        onRefresh: _carregarDados,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          itemCount: _notasPaginadas.length,
                          itemBuilder: (ctx, i) => _buildNotaCard(_notasPaginadas[i]),
                        ),
                      ),
          ),
          if (!_isLoading && _notasFiltradas.isNotEmpty) _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _currentPage > 0 ? _paginaAnterior : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Anterior'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Página ${_currentPage + 1} de $_totalPages',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _currentPage < _totalPages - 1 ? _proximaPagina : null,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Próxima'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color bgColor,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: isMobile ? 18 : 20),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: isMobile ? 10 : 11),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'Nenhuma nota de entrada em $_labelMesAtual'
                : 'Nenhuma nota corresponde aos filtros em $_labelMesAtual',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildNotaCard(Map<String, dynamic> nota) {
    final numero = nota['numeroNotaFiscal']?.toString() ?? '-';
    final fornecedor = (nota['fornecedor'] as Map?) ?? {};
    final nomeFornecedor = fornecedor['nome']?.toString() ?? '-';
    final dataEntrada = nota['dataEntrada'] != null ? DateTime.tryParse(nota['dataEntrada'].toString()) : null;
    final valorTotal = (nota['valorTotal'] as num?)?.toDouble() ?? 0.0;
    final itens = (nota['itens'] as List?) ?? [];
    final contas = (nota['contas'] as List?) ?? [];
    final pendente = _temContaPendente(nota);
    final key = '${fornecedor['id']}||$numero';
    final isExpanded = _expanded.contains(key);
    final labelPagamento = _labelPagamento(nota);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() {
              if (isExpanded) {
                _expanded.remove(key);
              } else {
                _expanded.add(key);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long, color: _primaryColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'NF: $numero',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                                ),
                                if (pendente) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Pendente',
                                        style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              nomeFornecedor,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'R\$ ${valorTotal.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _primaryColor),
                          ),
                          if (dataEntrada != null)
                            Text(
                              DateFormat('dd/MM/yyyy').format(dataEntrada),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildChip(icon: Icons.shopping_bag_outlined, label: '${itens.length} item(ns)', color: _accentColor),
                      const SizedBox(width: 8),
                      _buildChip(
                          icon: Icons.payment_outlined, label: labelPagamento, color: pendente ? Colors.orange : Colors.grey.shade600),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ITENS DA NOTA',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black38, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  ...itens.map((item) => _buildItemRow(item)),
                  if (contas.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('CONTAS A PAGAR',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black38, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    ...contas.map((c) => _buildContaRow(c)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => _confirmarExclusao(nota),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Excluir', style: TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => _abrirEdicao(nota),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Editar', style: TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildItemRow(dynamic item) {
    final codigo = item['codigoPeca']?.toString() ?? '-';
    final qty = item['quantidade']?.toString() ?? '-';
    final preco = (item['precoUnitario'] as num?)?.toDouble() ?? 0.0;
    final valorItem = (item['valorItem'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(codigo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 1,
            child: Text('${qty}x', style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'R\$ ${preco.toStringAsFixed(2).replaceAll('.', ',')}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'R\$ ${valorItem.toStringAsFixed(2).replaceAll('.', ',')}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _primaryColor),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContaRow(dynamic conta) {
    final descricao = conta['descricao']?.toString() ?? '-';
    final valor = (conta['valor'] as num?)?.toDouble() ?? 0.0;
    final pago = conta['pago'] == true;
    final venc = conta['dataVencimento'] != null ? DateTime.tryParse(conta['dataVencimento'].toString()) : null;
    late final bool atrasada;
    if (venc != null && !pago) {
      final hoje = DateTime.now();
      atrasada = DateTime(venc.year, venc.month, venc.day).isBefore(DateTime(hoje.year, hoje.month, hoje.day));
    } else {
      atrasada = false;
    }

    final statusColor = pago ? Colors.green : (atrasada ? Colors.red : Colors.orange);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            pago ? Icons.check_circle_outline : Icons.schedule,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(descricao, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: statusColor),
              ),
              if (venc != null)
                Text(
                  DateFormat('dd/MM/yyyy').format(venc),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
