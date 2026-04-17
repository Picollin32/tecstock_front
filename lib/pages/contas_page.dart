import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/categoria_financeira.dart';
import '../model/conta.dart';
import '../model/fornecedor.dart';
import '../services/categoria_financeira_service.dart';
import '../services/conta_service.dart';
import '../services/fornecedor_service.dart';

class _ParcelaDraft {
  _ParcelaDraft({required this.numero, required this.valor, required this.vencimento});

  int numero;
  double valor;
  DateTime vencimento;
}

class ContasPage extends StatefulWidget {
  const ContasPage({super.key});

  @override
  State<ContasPage> createState() => _ContasPageState();
}

class _ContasPageState extends State<ContasPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _abaAtual = 0;

  DateTime _mesAtual = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isLoading = false;

  List<Conta> _contasAPagar = [];
  List<Conta> _contasAReceber = [];
  List<Conta> _contasAtrasadas = [];
  List<CategoriaFinanceira> _categoriasFinanceiras = [];
  List<Fornecedor> _fornecedores = [];
  Map<String, double> _resumo = {};
  String _modoAgrupamentoAPagar = 'TODAS';
  String _ordenacaoAPagar = 'VENCIMENTO';
  String _filtroStatusAPagar = 'TODOS';
  String _ordenacaoAReceber = 'VENCIMENTO';
  String _filtroStatusAReceber = 'TODOS';
  int? _filtroFornecedorId;
  final Set<String> _categoriasExpandidas = <String>{};
  bool _filtrosAPagarExpandidos = false;
  bool _filtrosAReceberExpandidos = false;

  static const Color _corPagar = Color(0xFFDC2626);
  static const Color _corReceber = Color(0xFF16A34A);
  static const Color _corAtrasada = Color(0xFFB45309);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      if (_abaAtual != _tabController.index) {
        setState(() {
          _abaAtual = _tabController.index;
        });
      }
    });
    _tabController.animation?.addListener(() {
      if (!mounted) return;
      final indiceAnimado = _tabController.animation!.value.round().clamp(0, 1);
      if (_abaAtual != indiceAnimado) {
        setState(() {
          _abaAtual = indiceAnimado;
        });
      }
    });
    _carregarDados();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      final mes = _mesAtual.month;
      final ano = _mesAtual.year;
      final results = await Future.wait([
        ContaService.listarAPagarPorMesAno(mes, ano),
        ContaService.listarAReceberPorMesAno(mes, ano),
        ContaService.resumoMes(mes, ano),
        ContaService.listarAtrasadas(),
        CategoriaFinanceiraService.listar(),
        FornecedorService.listarFornecedores(),
      ]);
      setState(() {
        _contasAPagar = results[0] as List<Conta>;
        _contasAReceber = results[1] as List<Conta>;
        _resumo = results[2] as Map<String, double>;
        _contasAtrasadas = results[3] as List<Conta>;
        _categoriasFinanceiras = results[4] as List<CategoriaFinanceira>;
        _fornecedores = results[5] as List<Fornecedor>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarErro('Erro ao carregar contas: $e');
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
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  void _mudarMes(int delta) {
    setState(() {
      _mesAtual = DateTime(_mesAtual.year, _mesAtual.month + delta, 1);
    });
    _carregarDados();
  }

  String get _labelMes {
    return DateFormat('MMMM yyyy', 'pt_BR').format(_mesAtual);
  }

  List<Conta> _ordenarContas(List<Conta> contas, String ordenacao) {
    final ordenadas = [...contas];
    switch (ordenacao) {
      case 'NOME':
        ordenadas.sort((a, b) => a.descricao.toLowerCase().compareTo(b.descricao.toLowerCase()));
        break;
      case 'VALOR':
        ordenadas.sort((a, b) => b.valor.compareTo(a.valor));
        break;
      default:
        ordenadas.sort((a, b) {
          final dataA = a.dataVencimento ?? DateTime(2100);
          final dataB = b.dataVencimento ?? DateTime(2100);
          return dataA.compareTo(dataB);
        });
        break;
    }
    return ordenadas;
  }

  String _mesesAtrasoLabel(List<Conta> contas) {
    final meses = <String>{};
    for (final conta in contas) {
      final data = conta.dataVencimento;
      if (data == null) continue;
      meses.add(DateFormat('MM/yyyy', 'pt_BR').format(data));
    }
    final lista = meses.toList()..sort();
    if (lista.isEmpty) return '-';
    return lista.join(', ');
  }

  String _nomeCategoriaConta(Conta conta) {
    final nome = conta.categoriaNome?.trim();
    if (nome == null || nome.isEmpty) return 'Sem categoria';
    return nome;
  }

  Map<int, Map<String, int>> _fornecedoresComContasAtivasNoMes() {
    final mapa = <int, Map<String, int>>{};
    for (final conta in _contasAPagar) {
      final fornecedorId = conta.fornecedorId;
      if (fornecedorId == null) continue;
      final resumo = mapa.putIfAbsent(
        fornecedorId,
        () => {
          'total': 0,
          'pagos': 0,
          'pendentes': 0,
        },
      );
      resumo['total'] = (resumo['total'] ?? 0) + 1;
      if (conta.pago) {
        resumo['pagos'] = (resumo['pagos'] ?? 0) + 1;
      } else {
        resumo['pendentes'] = (resumo['pendentes'] ?? 0) + 1;
      }
    }
    return mapa;
  }

  Map<String, List<Conta>> _agruparPorCategoria(List<Conta> contas) {
    final mapa = <String, List<Conta>>{};
    for (final conta in contas) {
      final chave = _nomeCategoriaConta(conta);
      mapa.putIfAbsent(chave, () => []);
      mapa[chave]!.add(conta);
    }
    return mapa;
  }

  Future<void> _abrirGerenciarCategorias() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setDialogState) {
            Future<void> recarregarCategorias() async {
              final categorias = await CategoriaFinanceiraService.listar();
              if (!mounted) return;
              setState(() => _categoriasFinanceiras = categorias);
              setDialogState(() {});
            }

            Future<void> abrirFormulario({CategoriaFinanceira? categoria}) async {
              final nomeCtrl = TextEditingController(text: categoria?.nome ?? '');
              final descricaoCtrl = TextEditingController(text: categoria?.descricao ?? '');
              final formKey = GlobalKey<FormState>();

              final isEdicao = categoria != null;

              await showModalBottomSheet<void>(
                context: ctx2,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (sheetCtx) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 20)],
                          ),
                          child: Form(
                            key: formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdicao ? 'Editar Categoria' : 'Nova Categoria',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: nomeCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Nome *',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.6),
                                    ),
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome' : null,
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: descricaoCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Descrição',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.6),
                                    ),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(sheetCtx),
                                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF475569)),
                                      child: const Text('Cancelar'),
                                    ),
                                    const Spacer(),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1565C0),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () async {
                                        if (!formKey.currentState!.validate()) return;
                                        Map<String, dynamic> result;
                                        if (!isEdicao) {
                                          result = await CategoriaFinanceiraService.criar(
                                            nomeCtrl.text.trim(),
                                            descricao: descricaoCtrl.text.trim().isEmpty ? null : descricaoCtrl.text.trim(),
                                          );
                                        } else {
                                          result = await CategoriaFinanceiraService.atualizar(
                                            categoria.id!,
                                            nomeCtrl.text.trim(),
                                            descricao: descricaoCtrl.text.trim().isEmpty ? null : descricaoCtrl.text.trim(),
                                          );
                                        }

                                        if (result['sucesso'] == true) {
                                          if (!mounted) return;
                                          if (!sheetCtx.mounted) return;
                                          Navigator.pop(sheetCtx);
                                          _mostrarSucesso(!isEdicao ? 'Categoria criada!' : 'Categoria atualizada!');
                                          await recarregarCategorias();
                                        } else {
                                          _mostrarErro(result['mensagem'] ?? 'Erro ao salvar categoria');
                                        }
                                      },
                                      child: const Text('Salvar'),
                                    ),
                                  ],
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

            Future<void> excluirCategoria(CategoriaFinanceira categoria) async {
              final confirmar = await showDialog<bool>(
                context: ctx2,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Excluir categoria'),
                  content: Text('Deseja excluir a categoria "${categoria.nome}"?'),
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

              final result = await CategoriaFinanceiraService.deletar(categoria.id!);
              if (result['sucesso'] == true) {
                _mostrarSucesso('Categoria removida!');
                await recarregarCategorias();
              } else {
                _mostrarErro(result['mensagem'] ?? 'Erro ao excluir categoria');
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              title: const Row(
                children: [
                  Icon(Icons.category_outlined, color: Color(0xFF1565C0)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Plano de Contas - Categorias',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 540,
                height: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => abrirFormulario(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nova Categoria'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: _categoriasFinanceiras.isEmpty
                          ? const Center(child: Text('Nenhuma categoria cadastrada.'))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: _categoriasFinanceiras.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final categoria = _categoriasFinanceiras[i];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(categoria.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: (categoria.descricao != null && categoria.descricao!.trim().isNotEmpty)
                                      ? Text(categoria.descricao!)
                                      : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Editar',
                                        onPressed: () => abrirFormulario(categoria: categoria),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Excluir',
                                        onPressed: () => excluirCategoria(categoria),
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
  }

  List<_ParcelaDraft> _gerarParcelasPadrao({
    required double valorTotal,
    required int quantidade,
    required DateTime base,
  }) {
    final parcelas = <_ParcelaDraft>[];
    if (quantidade < 1) return parcelas;

    final valorBase = (valorTotal / quantidade);
    double acumulado = 0;

    for (int i = 0; i < quantidade; i++) {
      final valorParcela =
          i == quantidade - 1 ? ((valorTotal - acumulado) * 100).roundToDouble() / 100 : (valorBase * 100).roundToDouble() / 100;
      acumulado += valorParcela;
      parcelas.add(
        _ParcelaDraft(
          numero: i + 1,
          valor: valorParcela,
          vencimento: DateTime(base.year, base.month + i, base.day),
        ),
      );
    }

    return parcelas;
  }

  Future<Map<String, dynamic>?> _mostrarDialogBaixaConta(Conta conta) async {
    DateTime dataPagamento = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final acrescimoCtrl = TextEditingController();
    final descontoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Baixa da Conta', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conta.descricao, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final hoje = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                    final picked = await showDatePicker(
                      context: ctx2,
                      initialDate: dataPagamento,
                      firstDate: DateTime(2020),
                      lastDate: hoje,
                      locale: const Locale('pt', 'BR'),
                    );
                    if (picked != null) {
                      setDialogState(() => dataPagamento = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data do pagamento *',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(DateFormat('dd/MM/yyyy').format(dataPagamento), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: acrescimoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Acréscimo (R\$) - opcional',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = double.tryParse(v.replaceAll(',', '.'));
                    if (n == null || n < 0) return 'Valor inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: descontoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Desconto (R\$) - opcional',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = double.tryParse(v.replaceAll(',', '.'));
                    if (n == null || n < 0) return 'Valor inválido';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final acrescimo = acrescimoCtrl.text.trim().isEmpty ? null : double.parse(acrescimoCtrl.text.replaceAll(',', '.'));
                final desconto = descontoCtrl.text.trim().isEmpty ? null : double.parse(descontoCtrl.text.replaceAll(',', '.'));
                Navigator.pop(ctx, {
                  'dataPagamento': dataPagamento,
                  'acrescimo': acrescimo,
                  'desconto': desconto,
                });
              },
              child: const Text('Confirmar Baixa'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePago(Conta conta) async {
    if (conta.id == null) return;

    final bool marcando = !conta.pago;

    if (!marcando && conta.isAReceber && !conta.isFiado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não é possível desmarcar recebimentos de OS (apenas fiados podem ser revertidos).'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool precisaConfirmar = conta.isAPagar || conta.isFiado;

    if (precisaConfirmar) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (marcando ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  marcando ? Icons.check_circle_outline : Icons.remove_circle_outline,
                  color: marcando ? Colors.green : Colors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  marcando ? 'Confirmar Pagamento' : 'Desmarcar Pagamento',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conta.descricao,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'Valor: R\$ ${conta.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              if (marcando && conta.isFiado) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFB45309).withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF92400E)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'As parcelas futuras deste fiado serão removidas automaticamente.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!marcando) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'O pagamento será revertido e a conta voltará a aparecer como pendente.',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: marcando ? Colors.green : Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: Icon(marcando ? Icons.check : Icons.undo, size: 18),
              label: Text(marcando ? 'Confirmar' : 'Desmarcar'),
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );

      if (confirmar != true) return;
    }

    Map<String, dynamic> result;
    if (conta.pago) {
      result = await ContaService.desmarcarPagamento(conta.id!);
    } else {
      DateTime dataPagamento = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      double? acrescimo;
      double? desconto;

      if (conta.isAPagar) {
        final baixa = await _mostrarDialogBaixaConta(conta);
        if (baixa == null) return;
        dataPagamento = baixa['dataPagamento'] as DateTime;
        acrescimo = baixa['acrescimo'] as double?;
        desconto = baixa['desconto'] as double?;
      }

      result = await ContaService.marcarComoPago(
        conta.id!,
        dataPagamento: dataPagamento,
        acrescimo: acrescimo,
        desconto: desconto,
      );
    }

    if (result['sucesso'] == true) {
      if (conta.isFiado && !conta.pago) {
        _mostrarSucesso('Fiado marcado como recebido! Entradas futuras removidas automaticamente.');
      } else {
        _mostrarSucesso(conta.pago ? 'Pagamento desmarcado.' : 'Marcado como pago!');
      }
      _carregarDados();
    } else {
      _mostrarErro(result['mensagem'] ?? 'Erro ao alterar status');
    }
  }

  void _editarContaPagar(Conta conta) {
    if (conta.id == null) return;
    final formKey = GlobalKey<FormState>();
    final descricaoCtrl = TextEditingController(text: conta.descricao);
    final valorCtrl = TextEditingController(text: conta.valor.toStringAsFixed(2).replaceAll('.', ','));
    DateTime vencimento = conta.dataVencimento ?? DateTime(_mesAtual.year, _mesAtual.month, 1);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Editar Conta a Pagar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: descricaoCtrl,
                  readOnly: conta.isCompra,
                  decoration: InputDecoration(
                    labelText: 'Descrição',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: conta.isCompra,
                    fillColor: conta.isCompra ? Colors.grey.shade100 : null,
                    helperText: conta.isCompra ? 'Altere o número pelo gerenciador de Notas de Entrada' : null,
                    helperStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                    suffixIcon: conta.isCompra ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey) : null,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe a descrição' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: valorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Valor (R\$)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe o valor';
                    final parsed = double.tryParse(v.replaceAll(',', '.'));
                    if (parsed == null || parsed <= 0) {
                      return 'Valor inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final hoje = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                    final picked = await showDatePicker(
                      context: ctx2,
                      initialDate: vencimento.isBefore(hoje) ? hoje : vencimento,
                      firstDate: hoje,
                      lastDate: DateTime(2100),
                      locale: const Locale('pt', 'BR'),
                    );
                    if (picked != null) {
                      setDialogState(() => vencimento = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Vencimento',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(vencimento),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Salvar'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(ctx);
                final valor = double.parse(valorCtrl.text.replaceAll(',', '.'));
                final result = await ContaService.editarConta(conta.id!, descricaoCtrl.text.trim(), valor, vencimento);
                if (result['sucesso'] == true) {
                  _mostrarSucesso('Conta atualizada!');
                  _carregarDados();
                } else {
                  _mostrarErro(result['mensagem'] ?? 'Erro ao editar conta');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _abrirDialogAdicionarConta() {
    final hoje = DateTime.now();
    final mesAtualInicio = DateTime(hoje.year, hoje.month, 1);
    if (_mesAtual.isBefore(mesAtualInicio)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não é possível adicionar contas em meses passados.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final descricaoCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    DateTime vencimento = DateTime(_mesAtual.year, _mesAtual.month, DateTime(_mesAtual.year, _mesAtual.month + 1, 0).day);

    bool isFrete = false;
    String? formaPagamento;
    int? categoriaFinanceiraId;
    int? fornecedorId;
    int numeroParcelas = 2;
    List<_ParcelaDraft> parcelas = [];
    DateTime? boleto30Vencimento;
    final boleto3060Valor1Ctrl = TextEditingController();
    final boleto3060Valor2Ctrl = TextEditingController();
    DateTime? boleto3060Venc1;
    DateTime? boleto3060Venc2;

    final formas = [
      (key: 'dinheiro', label: 'Dinheiro', backend: 'AVISTA', icon: Icons.payments_outlined),
      (key: 'pix', label: 'Pix', backend: 'AVISTA', icon: Icons.pix),
      (key: 'debito', label: 'Débito', backend: 'AVISTA', icon: Icons.credit_card),
      (key: 'credito', label: 'Cartão de Crédito', backend: 'CREDITO', icon: Icons.credit_score),
      (key: 'boleto30', label: 'Boleto 30 dias', backend: 'BOLETO30', icon: Icons.receipt_long),
      (key: 'boleto30_60', label: 'Boleto 30/60', backend: 'BOLETO30_60', icon: Icons.receipt_long),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
          final fornecedoresServico = _fornecedores.where((f) => f.servico).toList();

          bool isCredito() => formaPagamento == 'credito';

          bool isBoleto30() => formaPagamento == 'boleto30';

          bool isBoleto3060() => formaPagamento == 'boleto30_60';

          bool usaTabelaParcelas() => isCredito();

          double somaParcelas() => parcelas.fold<double>(0, (s, p) => s + p.valor);

          void recalcularParcelas() {
            if (!usaTabelaParcelas()) {
              parcelas = [];
              return;
            }
            final total = double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0;
            if (total <= 0) {
              parcelas = [];
              return;
            }
            parcelas = _gerarParcelasPadrao(valorTotal: total, quantidade: numeroParcelas, base: vencimento);
          }

          bool formularioValido() {
            final valor = double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0;
            if (descricaoCtrl.text.trim().isEmpty || valor <= 0 || formaPagamento == null) return false;
            if (!isFrete && categoriaFinanceiraId == null) return false;
            if (usaTabelaParcelas()) {
              if (parcelas.isEmpty) return false;
              final soma = somaParcelas();
              return (soma - valor).abs() <= 0.02;
            }

            if (isBoleto30()) {
              if (boleto30Vencimento == null) return false;
              return !boleto30Vencimento!.isBefore(hojeSemHora);
            }

            if (isBoleto3060()) {
              final valor1 = double.tryParse(boleto3060Valor1Ctrl.text.replaceAll(',', '.')) ?? 0;
              final valor2 = double.tryParse(boleto3060Valor2Ctrl.text.replaceAll(',', '.')) ?? 0;
              if (valor1 <= 0 || valor2 <= 0) return false;
              if (((valor1 + valor2) - valor).abs() > 0.02) return false;
              if (boleto3060Venc1 == null || boleto3060Venc2 == null) return false;
              if (boleto3060Venc1!.isBefore(hojeSemHora) || boleto3060Venc2!.isBefore(hojeSemHora)) return false;
              if (!boleto3060Venc2!.isAfter(boleto3060Venc1!)) return false;
            }

            return true;
          }

          Future<void> editarValorParcela(int idx) async {
            final ctrl = TextEditingController(text: parcelas[idx].valor.toStringAsFixed(2).replaceAll('.', ','));
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
              setDialogState(() => parcelas[idx].valor = novo);
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isFrete ? Colors.orange.shade700 : _corPagar).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isFrete ? Icons.local_shipping_outlined : Icons.add_card,
                    color: isFrete ? Colors.orange.shade700 : _corPagar,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isFrete ? 'Novo Frete a Pagar' : 'Nova Conta a Pagar',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() {
                              if (!isFrete) return;
                              isFrete = false;
                              descricaoCtrl.clear();
                              valorCtrl.clear();
                              formaPagamento = null;
                              categoriaFinanceiraId = null;
                              fornecedorId = null;
                              numeroParcelas = 2;
                              parcelas = [];
                              boleto30Vencimento = null;
                              boleto3060Valor1Ctrl.clear();
                              boleto3060Valor2Ctrl.clear();
                              boleto3060Venc1 = null;
                              boleto3060Venc2 = null;
                              vencimento = DateTime(_mesAtual.year, _mesAtual.month, DateTime(_mesAtual.year, _mesAtual.month + 1, 0).day);
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isFrete ? _corPagar : Colors.grey.shade100,
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                border: Border.all(color: !isFrete ? _corPagar : Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_outlined, size: 16, color: !isFrete ? Colors.white : Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  Text('Despesa',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: !isFrete ? Colors.white : Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() {
                              if (isFrete) return;
                              isFrete = true;
                              descricaoCtrl.clear();
                              valorCtrl.clear();
                              formaPagamento = null;
                              categoriaFinanceiraId = null;
                              fornecedorId = null;
                              numeroParcelas = 2;
                              parcelas = [];
                              boleto30Vencimento = null;
                              boleto3060Valor1Ctrl.clear();
                              boleto3060Valor2Ctrl.clear();
                              boleto3060Venc1 = null;
                              boleto3060Venc2 = null;
                              vencimento = DateTime(_mesAtual.year, _mesAtual.month, DateTime(_mesAtual.year, _mesAtual.month + 1, 0).day);
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isFrete ? Colors.orange.shade700 : Colors.grey.shade100,
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                border: Border.all(color: isFrete ? Colors.orange.shade700 : Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.local_shipping_outlined, size: 16, color: isFrete ? Colors.white : Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  Text('Frete',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600, fontSize: 13, color: isFrete ? Colors.white : Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descricaoCtrl,
                      decoration: InputDecoration(
                        labelText: isFrete ? 'Descrição do Frete *' : 'Nome / Descrição *',
                        prefixIcon: Icon(isFrete ? Icons.local_shipping_outlined : Icons.label_outline),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
                    ),
                    if (!isFrete) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: categoriaFinanceiraId,
                        decoration: InputDecoration(
                          labelText: 'Categoria financeira *',
                          prefixIcon: const Icon(Icons.category_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: _categoriasFinanceiras
                            .map(
                              (c) => DropdownMenuItem<int>(
                                value: c.id,
                                child: Text(c.nome),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setDialogState(() => categoriaFinanceiraId = v),
                        validator: (v) => v == null ? 'Selecione uma categoria' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        initialValue: fornecedorId,
                        decoration: InputDecoration(
                          labelText: 'Fornecedor (opcional)',
                          prefixIcon: const Icon(Icons.store_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(value: null, child: Text('Sem fornecedor')),
                          ...fornecedoresServico.map(
                            (f) => DropdownMenuItem<int?>(
                              value: f.id,
                              child: Text(f.nome),
                            ),
                          ),
                        ],
                        onChanged: (v) => setDialogState(() => fornecedorId = v),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setDialogState(recalcularParcelas),
                      decoration: const InputDecoration(
                        labelText: 'Valor (R\$) *',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
                        final n = double.tryParse(v.replaceAll(',', '.'));
                        if (n == null || n <= 0) return 'Informe um valor válido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx2,
                          initialDate: vencimento,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                          locale: const Locale('pt', 'BR'),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            vencimento = picked;
                            recalcularParcelas();
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, color: Colors.grey),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Vencimento base', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(vencimento),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: formaPagamento,
                      decoration: InputDecoration(
                        labelText: 'Forma de Pagamento *',
                        prefixIcon: Icon(Icons.payment, color: isFrete ? Colors.orange.shade700 : _corPagar),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: formas.map((f) {
                        return DropdownMenuItem<String>(
                          value: f.key,
                          child: Row(
                            children: [
                              Icon(f.icon, size: 18, color: isFrete ? Colors.orange.shade700 : _corPagar),
                              const SizedBox(width: 8),
                              Text(f.label),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() {
                        formaPagamento = v;
                        numeroParcelas = 2;
                        boleto30Vencimento = null;
                        boleto3060Valor1Ctrl.clear();
                        boleto3060Valor2Ctrl.clear();
                        boleto3060Venc1 = null;
                        boleto3060Venc2 = null;
                        recalcularParcelas();
                      }),
                      validator: (v) => v == null ? 'Selecione a forma de pagamento' : null,
                    ),
                    if (isBoleto30()) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx2,
                            initialDate: vencimento,
                            firstDate: hojeSemHora,
                            lastDate: DateTime(2035),
                            locale: const Locale('pt', 'BR'),
                          );
                          if (picked != null) {
                            setDialogState(() => boleto30Vencimento = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Vencimento do Boleto *',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          child: Text(
                            boleto30Vencimento != null ? DateFormat('dd/MM/yyyy').format(boleto30Vencimento!) : 'Selecionar data',
                            style: TextStyle(
                              color: boleto30Vencimento != null ? Colors.black87 : Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (isBoleto3060()) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: boleto3060Valor1Ctrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Parcela 1 (R\$) *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx2,
                                  initialDate: vencimento,
                                  firstDate: hojeSemHora,
                                  lastDate: DateTime(2035),
                                  locale: const Locale('pt', 'BR'),
                                );
                                if (picked != null) {
                                  setDialogState(() => boleto3060Venc1 = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Venc. 1 *',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  boleto3060Venc1 != null ? DateFormat('dd/MM/yyyy').format(boleto3060Venc1!) : 'Selecionar',
                                  style: TextStyle(color: boleto3060Venc1 != null ? Colors.black87 : Colors.grey.shade500),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: boleto3060Valor2Ctrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Parcela 2 (R\$) *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final inicial = (boleto3060Venc1 ?? vencimento).add(const Duration(days: 1));
                                final picked = await showDatePicker(
                                  context: ctx2,
                                  initialDate: inicial,
                                  firstDate: hojeSemHora,
                                  lastDate: DateTime(2035),
                                  locale: const Locale('pt', 'BR'),
                                );
                                if (picked != null) {
                                  setDialogState(() => boleto3060Venc2 = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Venc. 2 *',
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  boleto3060Venc2 != null ? DateFormat('dd/MM/yyyy').format(boleto3060Venc2!) : 'Selecionar',
                                  style: TextStyle(color: boleto3060Venc2 != null ? Colors.black87 : Colors.grey.shade500),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Builder(
                          builder: (_) {
                            final valor = double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0;
                            final valor1 = double.tryParse(boleto3060Valor1Ctrl.text.replaceAll(',', '.')) ?? 0;
                            final valor2 = double.tryParse(boleto3060Valor2Ctrl.text.replaceAll(',', '.')) ?? 0;
                            final okSoma = ((valor1 + valor2) - valor).abs() <= 0.02;
                            return Text(
                              'Soma 30/60: R\$ ${(valor1 + valor2).toStringAsFixed(2).replaceAll('.', ',')}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: okSoma ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    if (usaTabelaParcelas()) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: numeroParcelas,
                        decoration: const InputDecoration(
                          labelText: 'Número de Parcelas',
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(12, (i) => i + 2)
                            .map((n) => DropdownMenuItem<int>(value: n, child: Text('$n parcelas')))
                            .toList(),
                        onChanged: (v) => setDialogState(() {
                          numeroParcelas = v ?? 2;
                          recalcularParcelas();
                        }),
                      ),
                      const SizedBox(height: 10),
                      if (parcelas.isNotEmpty)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Parcela')),
                              DataColumn(label: Text('Vencimento')),
                              DataColumn(label: Text('Valor')),
                              DataColumn(label: Text('Ações')),
                            ],
                            rows: parcelas.map((p) {
                              final idx = p.numero - 1;
                              return DataRow(
                                cells: [
                                  DataCell(Text('${p.numero}/$numeroParcelas')),
                                  DataCell(
                                    InkWell(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: ctx2,
                                          initialDate: p.vencimento,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2035),
                                          locale: const Locale('pt', 'BR'),
                                        );
                                        if (picked != null) {
                                          setDialogState(() => parcelas[idx].vencimento = picked);
                                        }
                                      },
                                      child: Text(DateFormat('dd/MM/yyyy').format(p.vencimento)),
                                    ),
                                  ),
                                  DataCell(Text('R\$ ${p.valor.toStringAsFixed(2).replaceAll('.', ',')}')),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () => editarValorParcela(idx),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Soma: R\$ ${somaParcelas().toStringAsFixed(2).replaceAll('.', ',')}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: (somaParcelas() - (double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0)).abs() <= 0.02
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFrete ? Colors.orange.shade700 : _corPagar,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Adicionar'),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  if (!formularioValido()) {
                    _mostrarErro('Confira forma de pagamento e parcelas.');
                    return;
                  }
                  Navigator.pop(ctx);

                  final valor = double.parse(valorCtrl.text.replaceAll(',', '.'));
                  final backend = formas.firstWhere((f) => f.key == formaPagamento).backend;
                  final pagamentoData = <String, dynamic>{
                    'formaPagamento': backend,
                  };

                  if (isCredito()) {
                    pagamentoData['parcelasDetalhadas'] = parcelas
                        .map((p) => {
                              'numero': p.numero,
                              'valor': p.valor,
                              'vencimento': p.vencimento.toIso8601String().substring(0, 10),
                            })
                        .toList();
                    pagamentoData['numeroParcelas'] = parcelas.length;
                  } else if (isBoleto30()) {
                    pagamentoData['boleto30Vencimento'] = boleto30Vencimento!.toIso8601String().substring(0, 10);
                  } else if (isBoleto3060()) {
                    pagamentoData['boleto30_60Parcela1Valor'] = double.parse(boleto3060Valor1Ctrl.text.replaceAll(',', '.'));
                    pagamentoData['boleto30_60Parcela1Vencimento'] = boleto3060Venc1!.toIso8601String().substring(0, 10);
                    pagamentoData['boleto30_60Parcela2Valor'] = double.parse(boleto3060Valor2Ctrl.text.replaceAll(',', '.'));
                    pagamentoData['boleto30_60Parcela2Vencimento'] = boleto3060Venc2!.toIso8601String().substring(0, 10);
                  } else {
                    pagamentoData['boleto30Vencimento'] = vencimento.toIso8601String().substring(0, 10);
                  }

                  final result = await ContaService.adicionarLancamentoAPagar(
                    descricao: descricaoCtrl.text.trim(),
                    valor: valor,
                    origem: isFrete ? 'FRETE' : 'DESPESA',
                    pagamento: pagamentoData,
                    categoriaFinanceiraId: isFrete ? null : categoriaFinanceiraId,
                    fornecedorId: isFrete ? null : fornecedorId,
                  );

                  if (result['sucesso'] == true) {
                    _mostrarSucesso(isFrete ? 'Frete adicionado com sucesso!' : 'Despesa adicionada com sucesso!');
                    _carregarDados();
                  } else {
                    _mostrarErro(result['mensagem'] ?? 'Erro ao adicionar lançamento');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _mostrarDialogPagamentoParcial(Conta conta) {
    final formKey = GlobalKey<FormState>();
    final valorCtrl = TextEditingController();
    final saldoDevedor = conta.valorPendente;
    const corFiado = Color(0xFF7C3AED);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: corFiado.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.payments_outlined, color: corFiado, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Pagamento Parcial', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conta.descricao,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Saldo devedor:', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    Text(
                      'R\$ ${saldoDevedor.toStringAsFixed(2).replaceAll(".", ",")}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: corFiado),
                    ),
                  ],
                ),
              ),
              if (conta.temPagamentoParcial) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Já pago anteriormente:', style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                      Text(
                        'R\$ ${conta.valorPagoParcial.toStringAsFixed(2).replaceAll(".", ",")}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: valorCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor recebido agora (R\$)',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o valor';
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  if (n == null || n <= 0) return 'Valor inválido';
                  if (n > saldoDevedor + 0.001) {
                    return 'Maior que o saldo (R\$ ${saldoDevedor.toStringAsFixed(2).replaceAll(".", ",")})';
                  }
                  return null;
                },
              ),
              if (conta.isAtrasada) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFB45309).withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFF92400E)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Este fiado está com vencimento em atraso.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: corFiado,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Registrar'),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              final valor = double.parse(valorCtrl.text.replaceAll(',', '.'));
              final result = await ContaService.registrarPagamentoParcial(conta.id!, valor);
              if (result['sucesso'] == true) {
                final contaAtualizada = result['conta'] as Conta?;
                if (contaAtualizada?.pago == true) {
                  _mostrarSucesso('Fiado quitado! Entradas futuras removidas automaticamente.');
                } else {
                  final restante = contaAtualizada?.valorPendente ?? 0;
                  _mostrarSucesso('R\$ ${valor.toStringAsFixed(2).replaceAll(".", ",")} registrado. '
                      'Saldo restante: R\$ ${restante.toStringAsFixed(2).replaceAll(".", ",")}');
                }
                _carregarDados();
              } else {
                _mostrarErro(result['mensagem'] ?? 'Erro ao registrar pagamento');
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarExclusao(Conta conta) async {
    if (conta.isCompra) {
      _mostrarErro('Contas de compra não podem ser excluídas aqui. Gerencie pela página de Notas de Entrada.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja remover "${conta.descricao}"?\n'
            '${conta.isFiado ? 'Todas as entradas mensais deste fiado serão removidas.' : ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true && conta.id != null) {
      final ok = await ContaService.deletarConta(conta.id!);
      if (ok) {
        _mostrarSucesso('Conta removida.');
        _carregarDados();
      } else {
        _mostrarErro('Erro ao remover conta.');
      }
    }
  }

  Future<void> _abrirAcoesRapidasMobile() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline, color: _corPagar),
                title: const Text('Nova Conta', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(ctx);
                  _abrirDialogAdicionarConta();
                },
              ),
              ListTile(
                leading: const Icon(Icons.category_outlined, color: Color(0xFF334155)),
                title: const Text('Gerenciar Categorias', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(ctx);
                  _abrirGerenciarCategorias();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFabAcoes() {
    if (_isTelaCompacta()) {
      return FloatingActionButton(
        heroTag: 'fab_acoes_mobile',
        backgroundColor: _corPagar,
        foregroundColor: Colors.white,
        onPressed: _abrirAcoesRapidasMobile,
        child: const Icon(Icons.add),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: 'fab_categorias',
          backgroundColor: const Color(0xFF334155),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.category_outlined),
          label: const Text('Gerenciar Categorias'),
          onPressed: _abrirGerenciarCategorias,
        ),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
          heroTag: 'fab_nova_conta',
          backgroundColor: _corPagar,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Nova Conta'),
          onPressed: _abrirDialogAdicionarConta,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: _abaAtual == 0 ? _buildFabAcoes() : null,
      body: Column(
        children: [
          _buildHeader(),
          if (_abaAtual == 0 && _contasAtrasadas.any((c) => c.isAPagar))
            _buildAlertaAtrasadasTipo('A_PAGAR')
          else if (_abaAtual == 1 && _contasAtrasadas.any((c) => c.isAReceber))
            _buildAlertaAtrasadasTipo('A_RECEBER'),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildListaContas(_contasAPagar, 'A_PAGAR'),
                      _buildListaContas(_contasAReceber, 'A_RECEBER'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertaAtrasadasTipo(String tipo) {
    final atrasadas =
        tipo == 'A_PAGAR' ? _contasAtrasadas.where((c) => c.isAPagar).toList() : _contasAtrasadas.where((c) => c.isAReceber).toList();
    final total =
        tipo == 'A_PAGAR' ? atrasadas.fold<double>(0, (s, c) => s + c.valor) : atrasadas.fold<double>(0, (s, c) => s + c.valorPendente);
    final tituloTipo = tipo == 'A_PAGAR' ? 'A Pagar' : 'A Receber';
    final corTipo = tipo == 'A_PAGAR' ? const Color(0xFFDC2626) : const Color(0xFF059669);
    final mesesAtraso = _mesesAtrasoLabel(atrasadas);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB45309).withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(color: const Color(0xFFB45309).withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${atrasadas.length} conta${atrasadas.length != 1 ? "s" : ""} com vencimento passado',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFB45309), height: 1),
          const SizedBox(height: 8),
          _buildAlertaLinha('$tituloTipo (${atrasadas.length})', total, corTipo,
              tipo == 'A_PAGAR' ? Icons.arrow_circle_up_outlined : Icons.arrow_circle_down_outlined),
          const SizedBox(height: 6),
          Text(
            'Mês(es) em atraso: $mesesAtraso',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertaLinha(String titulo, double total, Color cor, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: cor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(titulo, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cor)),
        ),
        Text(
          'R\$ ${total.toStringAsFixed(2).replaceAll('.', ',')}',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cor),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _mudarMes(-1),
                icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
              ),
              Column(
                children: [
                  const Text('Contas', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w400)),
                  Text(
                    _labelMes[0].toUpperCase() + _labelMes.substring(1),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => _mudarMes(1),
                icon: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildResumoCard(
                'A Receber',
                _resumo['totalAReceber'] ?? 0,
                Icons.trending_up,
                Colors.greenAccent,
              ),
              const SizedBox(width: 10),
              _buildResumoCard(
                'A Pagar',
                _resumo['totalAPagar'] ?? 0,
                Icons.trending_down,
                Colors.redAccent,
              ),
              const SizedBox(width: 10),
              _buildResumoCard(
                'Saldo',
                _resumo['saldo'] ?? 0,
                Icons.account_balance_wallet,
                Colors.amberAccent,
                negativeWarning: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumoCard(String label, double valor, IconData icon, Color cor, {bool negativeWarning = false}) {
    final isNegative = negativeWarning && valor < 0;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isNegative ? 0.15 : 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isNegative ? Colors.red.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cor, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(label,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
              style: TextStyle(color: isNegative ? Colors.redAccent.shade100 : Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: _abaAtual == 0 ? _corPagar : _corReceber,
        unselectedLabelColor: Colors.grey,
        indicatorColor: _abaAtual == 0 ? _corPagar : _corReceber,
        indicatorWeight: 3,
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_circle_up, size: 18),
                const SizedBox(width: 6),
                const Text('A Pagar', style: TextStyle(fontWeight: FontWeight.w700)),
                if (_contasAPagar.any((c) => c.isAtrasada)) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: _corAtrasada, shape: BoxShape.circle),
                    child: Text('${_contasAPagar.where((c) => c.isAtrasada).length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_circle_down, size: 18),
                const SizedBox(width: 6),
                const Text('A Receber', style: TextStyle(fontWeight: FontWeight.w700)),
                if (_contasAReceber.any((c) => c.isAtrasada)) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: _corAtrasada, shape: BoxShape.circle),
                    child: Text('${_contasAReceber.where((c) => c.isAtrasada).length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
        ],
        onTap: (index) => setState(() => _abaAtual = index),
      ),
    );
  }

  bool _isTelaCompacta() => MediaQuery.of(context).size.width <= 700;

  String _labelOrdenacao(String valor) {
    switch (valor) {
      case 'NOME':
        return 'Nome';
      case 'VALOR':
        return 'Valor';
      default:
        return 'Vencimento';
    }
  }

  String _labelStatusAPagar(String valor) {
    switch (valor) {
      case 'PENDENTES':
        return 'Pendentes';
      case 'ATRASADAS':
        return 'Atrasadas';
      case 'PAGAS':
        return 'Pagas';
      default:
        return 'Todos';
    }
  }

  String _labelStatusAReceber(String valor) {
    switch (valor) {
      case 'PENDENTES':
        return 'Pendentes';
      case 'RECEBIDAS':
        return 'Recebidas';
      case 'ATRASADAS':
        return 'Atrasadas';
      default:
        return 'Todas';
    }
  }

  String _nomeFornecedorSelecionado() {
    if (_filtroFornecedorId == null) return 'Todos';
    for (final fornecedor in _fornecedores) {
      if (fornecedor.id == _filtroFornecedorId) {
        return fornecedor.nome;
      }
    }
    return 'Todos';
  }

  String _resumoFiltros(String tipo) {
    if (tipo == 'A_PAGAR') {
      final partes = <String>[
        'Status: ${_labelStatusAPagar(_filtroStatusAPagar)}',
        'Ordenar: ${_labelOrdenacao(_ordenacaoAPagar)}',
      ];
      if (_modoAgrupamentoAPagar != 'TODAS') {
        partes.add('Visão: Categorias');
      }
      if (_filtroFornecedorId != null) {
        partes.add('Forn.: ${_nomeFornecedorSelecionado()}');
      }
      return partes.join(' | ');
    }

    return 'Status: ${_labelStatusAReceber(_filtroStatusAReceber)} | Ordenar: ${_labelOrdenacao(_ordenacaoAReceber)}';
  }

  Widget _buildPainelFiltros(String tipo) {
    final compacto = _isTelaCompacta();
    final conteudo = tipo == 'A_PAGAR' ? _buildFiltrosAPagar() : _buildFiltrosAReceber();

    if (!compacto) return conteudo;

    final expandido = tipo == 'A_PAGAR' ? _filtrosAPagarExpandidos : _filtrosAReceberExpandidos;
    final subtitulo = tipo == 'A_PAGAR' ? 'Visualização, ordenação, status e fornecedor' : 'Ordenação e status';
    final resumo = _resumoFiltros(tipo);
    final corAtiva = tipo == 'A_PAGAR' ? _corPagar : _corReceber;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  if (tipo == 'A_PAGAR') {
                    _filtrosAPagarExpandidos = !_filtrosAPagarExpandidos;
                  } else {
                    _filtrosAReceberExpandidos = !_filtrosAReceberExpandidos;
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 18, color: expandido ? corAtiva : Colors.grey.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Filtros',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: expandido ? corAtiva : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            expandido ? subtitulo : resumo,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expandido ? 0.5 : 0,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOutCubic,
                      child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubicEmphasized,
            alignment: Alignment.topCenter,
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: expandido
                    ? Padding(
                        key: ValueKey('filtros_abertos_$tipo'),
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: conteudo,
                      )
                    : const SizedBox(
                        key: ValueKey('filtros_fechados'),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaContas(List<Conta> contas, String tipo) {
    final cor = tipo == 'A_PAGAR' ? _corPagar : _corReceber;
    List<Conta> contasBase = List<Conta>.from(contas);

    if (tipo == 'A_PAGAR') {
      if (_filtroStatusAPagar == 'PENDENTES') {
        contasBase = contasBase.where((c) => !c.pago && !c.isAtrasada).toList();
      } else if (_filtroStatusAPagar == 'ATRASADAS') {
        contasBase = contasBase.where((c) => !c.pago && c.isAtrasada).toList();
      } else if (_filtroStatusAPagar == 'PAGAS') {
        contasBase = contasBase.where((c) => c.pago).toList();
      }
    } else {
      if (_filtroStatusAReceber == 'PENDENTES') {
        contasBase = contasBase.where((c) => !c.pago && !c.isAtrasada).toList();
      } else if (_filtroStatusAReceber == 'ATRASADAS') {
        contasBase = contasBase.where((c) => !c.pago && c.isAtrasada).toList();
      } else if (_filtroStatusAReceber == 'RECEBIDAS') {
        contasBase = contasBase.where((c) => c.pago).toList();
      }
    }

    final fornecedoresAtivosNoMes = _fornecedoresComContasAtivasNoMes();
    final filtroFornecedorValido = _filtroFornecedorId != null && fornecedoresAtivosNoMes.containsKey(_filtroFornecedorId);
    if (tipo == 'A_PAGAR' && filtroFornecedorValido) {
      contasBase = contasBase.where((c) => c.fornecedorId == _filtroFornecedorId).toList();
    }
    final contasOrdenadas = _ordenarContas(contasBase, tipo == 'A_PAGAR' ? _ordenacaoAPagar : _ordenacaoAReceber);
    final semResultadosComFiltro = contas.isNotEmpty && contasOrdenadas.isEmpty;

    if (contas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              tipo == 'A_PAGAR' ? Icons.receipt_long : Icons.payments_outlined,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              tipo == 'A_PAGAR' ? 'Nenhuma conta a pagar\nneste mês' : 'Nenhuma conta a receber\nneste mês',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15, fontWeight: FontWeight.w500),
            ),
            if (tipo == 'A_PAGAR') ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _abrirDialogAdicionarConta,
                style: ElevatedButton.styleFrom(
                    backgroundColor: cor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar Conta'),
              ),
            ],
          ],
        ),
      );
    }

    if (tipo == 'A_PAGAR' && _modoAgrupamentoAPagar == 'CATEGORIAS') {
      return RefreshIndicator(
        onRefresh: _carregarDados,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            _buildAbaResumo(contasOrdenadas, tipo),
            const SizedBox(height: 12),
            _buildPainelFiltros('A_PAGAR'),
            const SizedBox(height: 12),
            _buildVisaoCategorias(contasOrdenadas),
          ],
        ),
      );
    }

    final atrasadas = contasOrdenadas.where((c) => c.isAtrasada).toList();
    final pendentes = contasOrdenadas.where((c) => !c.pago && !c.isAtrasada).toList();
    final pagas = contasOrdenadas.where((c) => c.pago).toList();

    return RefreshIndicator(
      onRefresh: _carregarDados,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          _buildAbaResumo(contasOrdenadas, tipo),
          if (tipo == 'A_PAGAR') ...[
            const SizedBox(height: 12),
            _buildPainelFiltros('A_PAGAR'),
          ] else ...[
            const SizedBox(height: 12),
            _buildPainelFiltros('A_RECEBER'),
          ],
          if (semResultadosComFiltro) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'Nenhuma conta encontrada com os filtros selecionados.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            if (atrasadas.isNotEmpty) ...[
              _buildSecaoLabel('ATRASADAS', _corAtrasada, Icons.warning_amber_rounded),
              const SizedBox(height: 6),
              ...atrasadas.map((c) => _buildContaCard(c, cor)),
              const SizedBox(height: 12),
            ],
            if (pendentes.isNotEmpty) ...[
              _buildSecaoLabel(tipo == 'A_PAGAR' ? 'PENDENTES' : 'A RECEBER', cor, Icons.radio_button_unchecked),
              const SizedBox(height: 6),
              ...pendentes.map((c) => _buildContaCard(c, cor)),
              const SizedBox(height: 12),
            ],
            if (pagas.isNotEmpty) ...[
              _buildSecaoLabel(tipo == 'A_PAGAR' ? 'PAGAS' : 'RECEBIDAS', Colors.grey, Icons.check_circle_outline),
              const SizedBox(height: 6),
              ...pagas.map((c) => _buildContaCard(c, cor)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildFiltrosAPagar() {
    final compacto = _isTelaCompacta();
    final fornecedoresAtivosNoMes = _fornecedoresComContasAtivasNoMes();
    final fornecedoresFiltraveis = _fornecedores.where((f) => f.id != null && fornecedoresAtivosNoMes.containsKey(f.id!)).toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    final int? filtroFornecedorAtual =
        (_filtroFornecedorId != null && fornecedoresAtivosNoMes.containsKey(_filtroFornecedorId)) ? _filtroFornecedorId : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: compacto ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: compacto
          ? Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    initialValue: _modoAgrupamentoAPagar,
                    decoration: const InputDecoration(
                      labelText: 'Visualização',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'TODAS', child: Text('Todas as contas')),
                      DropdownMenuItem(value: 'CATEGORIAS', child: Text('Por categorias')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _modoAgrupamentoAPagar = v);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    initialValue: _ordenacaoAPagar,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ordenar por',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'VENCIMENTO', child: Text('Vencimento')),
                      DropdownMenuItem(value: 'NOME', child: Text('Nome')),
                      DropdownMenuItem(value: 'VALOR', child: Text('Valor')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _ordenacaoAPagar = v);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    initialValue: _filtroStatusAPagar,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'TODOS', child: Text('Todos')),
                      DropdownMenuItem(value: 'PENDENTES', child: Text('Pendentes')),
                      DropdownMenuItem(value: 'ATRASADAS', child: Text('Atrasadas')),
                      DropdownMenuItem(value: 'PAGAS', child: Text('Pagas')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _filtroStatusAPagar = v);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<int?>(
                    initialValue: filtroFornecedorAtual,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Fornecedor',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Todos os fornecedores')),
                      ...fornecedoresFiltraveis.map(
                        (f) {
                          final resumo = fornecedoresAtivosNoMes[f.id] ?? const {'total': 0, 'pagos': 0, 'pendentes': 0};
                          final total = resumo['total'] ?? 0;
                          return DropdownMenuItem<int?>(
                            value: f.id,
                            child: Text('${f.nome} ($total)'),
                          );
                        },
                      ),
                    ],
                    onChanged: (v) => setState(() => _filtroFornecedorId = v),
                  ),
                ),
              ],
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String>(
                    initialValue: _modoAgrupamentoAPagar,
                    decoration: const InputDecoration(
                      labelText: 'Visualização',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'TODAS', child: Text('Todas as contas')),
                      DropdownMenuItem(value: 'CATEGORIAS', child: Text('Por categorias')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _modoAgrupamentoAPagar = v);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _ordenacaoAPagar,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ordenar por',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'VENCIMENTO', child: Text('Vencimento')),
                      DropdownMenuItem(value: 'NOME', child: Text('Nome')),
                      DropdownMenuItem(value: 'VALOR', child: Text('Valor')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _ordenacaoAPagar = v);
                    },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    initialValue: _filtroStatusAPagar,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'TODOS', child: Text('Todos')),
                      DropdownMenuItem(value: 'PENDENTES', child: Text('Pendentes')),
                      DropdownMenuItem(value: 'ATRASADAS', child: Text('Atrasadas')),
                      DropdownMenuItem(value: 'PAGAS', child: Text('Pagas')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _filtroStatusAPagar = v);
                    },
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<int?>(
                    initialValue: filtroFornecedorAtual,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Fornecedor',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Todos os fornecedores')),
                      ...fornecedoresFiltraveis.map(
                        (f) {
                          final resumo = fornecedoresAtivosNoMes[f.id] ?? const {'total': 0, 'pagos': 0, 'pendentes': 0};
                          final total = resumo['total'] ?? 0;
                          return DropdownMenuItem<int?>(
                            value: f.id,
                            child: Text('${f.nome} ($total)'),
                          );
                        },
                      ),
                    ],
                    onChanged: (v) => setState(() => _filtroFornecedorId = v),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFiltrosAReceber() {
    final compacto = _isTelaCompacta();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: compacto ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: compacto
          ? Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    initialValue: _ordenacaoAReceber,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ordenar por',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'VENCIMENTO', child: Text('Vencimento')),
                      DropdownMenuItem(value: 'NOME', child: Text('Nome')),
                      DropdownMenuItem(value: 'VALOR', child: Text('Valor')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _ordenacaoAReceber = v);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    initialValue: _filtroStatusAReceber,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'TODOS', child: Text('Todas')),
                      DropdownMenuItem(value: 'PENDENTES', child: Text('Pendentes')),
                      DropdownMenuItem(value: 'RECEBIDAS', child: Text('Recebidas')),
                      DropdownMenuItem(value: 'ATRASADAS', child: Text('Atrasadas')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _filtroStatusAReceber = v);
                    },
                  ),
                ),
              ],
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _ordenacaoAReceber,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ordenar por',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'VENCIMENTO', child: Text('Vencimento')),
                      DropdownMenuItem(value: 'NOME', child: Text('Nome')),
                      DropdownMenuItem(value: 'VALOR', child: Text('Valor')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _ordenacaoAReceber = v);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: _filtroStatusAReceber,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'TODOS', child: Text('Todas')),
                      DropdownMenuItem(value: 'PENDENTES', child: Text('Pendentes')),
                      DropdownMenuItem(value: 'RECEBIDAS', child: Text('Recebidas')),
                      DropdownMenuItem(value: 'ATRASADAS', child: Text('Atrasadas')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _filtroStatusAReceber = v);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVisaoCategorias(List<Conta> contasAPagar) {
    final agrupado = _agruparPorCategoria(contasAPagar);
    final categorias = agrupado.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (categorias.isEmpty) {
      return const Center(child: Text('Nenhuma conta disponível para agrupar.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categorias.map((nomeCategoria) {
        final expandida = _categoriasExpandidas.contains(nomeCategoria);
        final contasCategoria = _ordenarContas(agrupado[nomeCategoria] ?? [], _ordenacaoAPagar);
        final totalCategoria = contasCategoria.fold<double>(0, (s, c) => s + c.valor);
        final atrasadas = contasCategoria.where((c) => c.isAtrasada && !c.pago).toList();
        final pendentes = contasCategoria.where((c) => !c.pago && !c.isAtrasada).toList();
        final pagas = contasCategoria.where((c) => c.pago).toList();
        final totalPendentes = atrasadas.length + pendentes.length;
        final totalPagas = pagas.length;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    if (expandida) {
                      _categoriasExpandidas.remove(nomeCategoria);
                    } else {
                      _categoriasExpandidas.add(nomeCategoria);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _corPagar.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          nomeCategoria,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        '$totalPendentes pend. | $totalPagas pag.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'R\$ ${totalCategoria.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _corPagar),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        expandida ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                        color: Colors.grey.shade700,
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                crossFadeState: expandida ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (atrasadas.isNotEmpty) ...[
                        _buildSecaoLabel('ATRASADAS', _corAtrasada, Icons.warning_amber_rounded),
                        const SizedBox(height: 6),
                        ...atrasadas.map((conta) => _buildContaCard(conta, _corPagar)),
                        const SizedBox(height: 10),
                      ],
                      if (pendentes.isNotEmpty) ...[
                        _buildSecaoLabel('PENDENTES', _corPagar, Icons.radio_button_unchecked),
                        const SizedBox(height: 6),
                        ...pendentes.map((conta) => _buildContaCard(conta, _corPagar)),
                        const SizedBox(height: 10),
                      ],
                      if (pagas.isNotEmpty) ...[
                        _buildSecaoLabel('PAGAS', Colors.grey, Icons.check_circle_outline),
                        const SizedBox(height: 6),
                        ...pagas.map((conta) => _buildContaCard(conta, _corPagar)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAbaResumo(List<Conta> contas, String tipo) {
    final total = contas.fold<double>(0, (s, c) => s + c.valor);

    final pagoTotal = contas.where((c) => c.pago).fold<double>(0, (s, c) => s + c.valor) +
        contas.where((c) => !c.pago && c.temPagamentoParcial).fold<double>(0, (s, c) => s + c.valorPagoParcial);
    final pendenteTotal = total - pagoTotal;
    final cor = tipo == 'A_PAGAR' ? _corPagar : _corReceber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          _buildMiniCard(tipo == 'A_PAGAR' ? 'Total a Pagar' : 'Total Esperado', total, cor),
          _buildDivider(),
          _buildMiniCard(tipo == 'A_PAGAR' ? 'Pago' : 'Recebido', pagoTotal, Colors.green.shade600),
          _buildDivider(),
          _buildMiniCard(tipo == 'A_PAGAR' ? 'Pendente' : 'Pendente', pendenteTotal, pendenteTotal > 0 ? _corAtrasada : Colors.grey),
        ],
      ),
    );
  }

  Widget _buildMiniCard(String label, double valor, Color cor) {
    return Expanded(
      child: Column(
        children: [
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(
            'R\$ ${valor.toStringAsFixed(2).replaceAll('.', ',')}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 36, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 4));
  }

  Widget _buildSecaoLabel(String label, Color cor, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: cor),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cor, letterSpacing: 0.8)),
      ],
    );
  }

  Widget _buildContaCard(Conta conta, Color corBase) {
    final isAtrasada = conta.isAtrasada;
    final corCard = conta.pago
        ? Colors.grey.shade100
        : isAtrasada
            ? const Color(0xFFFFF3CD)
            : Colors.white;
    final corBorda = conta.pago
        ? Colors.grey.shade300
        : isAtrasada
            ? _corAtrasada.withValues(alpha: 0.6)
            : corBase.withValues(alpha: 0.25);

    return Dismissible(
      key: Key('conta_${conta.id}'),
      direction: DismissDirection.none,
      onDismissed: (_) async {
        if (!conta.isManual || conta.id == null) return;
        final ok = await ContaService.deletarConta(conta.id!);
        if (ok) {
          _mostrarSucesso('Conta removida.');
          _carregarDados();
        } else {
          _mostrarErro('Erro ao remover conta.');
          _carregarDados();
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: corCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: corBorda),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onLongPress: conta.isManual ? () => _confirmarExclusao(conta) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _togglePago(conta),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: conta.pago ? corBase : Colors.transparent,
                      border: Border.all(color: isAtrasada && !conta.pago ? _corAtrasada : corBase, width: 2),
                    ),
                    child: conta.pago ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conta.descricao,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: conta.pago ? Colors.grey.shade500 : Colors.grey.shade900,
                                decoration: conta.pago ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          _buildOrigemBadge(conta),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 11, color: isAtrasada && !conta.pago ? _corAtrasada : Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            conta.dataVencimento != null
                                ? 'Vence: ${DateFormat('dd/MM/yyyy').format(conta.dataVencimento!)}'
                                : 'Sem vencimento',
                            style: TextStyle(
                              fontSize: 11,
                              color: isAtrasada && !conta.pago ? _corAtrasada : Colors.grey.shade500,
                              fontWeight: isAtrasada && !conta.pago ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          if (isAtrasada && !conta.pago) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: _corAtrasada, borderRadius: BorderRadius.circular(4)),
                              child:
                                  const Text('ATRASADA', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                            ),
                          ],
                          if (conta.pago && conta.dataPagamento != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              'Pago: ${DateFormat('dd/MM').format(conta.dataPagamento!)}',
                              style: TextStyle(fontSize: 10, color: Colors.green.shade600),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Categoria: ${_nomeCategoriaConta(conta)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      ),
                      if (conta.fornecedorNome != null && conta.fornecedorNome!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Fornecedor: ${conta.fornecedorNome}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                      ],
                      if (conta.pago && ((conta.acrescimo ?? 0) > 0 || (conta.desconto ?? 0) > 0)) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Acr.: R\$ ${(conta.acrescimo ?? 0).toStringAsFixed(2).replaceAll('.', ',')} | Desc.: R\$ ${(conta.desconto ?? 0).toStringAsFixed(2).replaceAll('.', ',')}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                      ],
                      if (conta.isCredito && conta.parcelaNumero != null && conta.totalParcelas != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Parcela ${conta.parcelaNumero}/${conta.totalParcelas}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (conta.isAPagar && !conta.pago)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'R\$ ${conta.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isAtrasada ? _corAtrasada : corBase,
                        ),
                      ),
                      if (conta.isCompra) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline, size: 12, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text('Notas de Entrada', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      ],
                      if (!conta.isCompra) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Tooltip(
                              message: 'Editar',
                              child: IconButton(
                                onPressed: () => _editarContaPagar(conta),
                                icon: const Icon(Icons.edit_outlined),
                                iconSize: 20,
                                color: Colors.orange,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.orange.withValues(alpha: 0.12),
                                  minimumSize: const Size(36, 36),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Tooltip(
                              message: 'Excluir',
                              child: IconButton(
                                onPressed: () => _confirmarExclusao(conta),
                                icon: const Icon(Icons.delete_outline),
                                iconSize: 20,
                                color: Colors.red,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                                  minimumSize: const Size(36, 36),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  )
                else if (conta.isFiado && !conta.pago)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (conta.temPagamentoParcial) ...[
                        Text(
                          'R\$ ${conta.valorPendente.toStringAsFixed(2).replaceAll(".", ",")}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isAtrasada ? _corAtrasada : const Color(0xFF7C3AED),
                          ),
                        ),
                        Text(
                          'total: R\$ ${conta.valor.toStringAsFixed(2).replaceAll(".", ",")}',
                          style: TextStyle(fontSize: 9, color: Colors.grey.shade400, decoration: TextDecoration.lineThrough),
                        ),
                      ] else
                        Text(
                          'R\$ ${conta.valor.toStringAsFixed(2).replaceAll(".", ",")}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isAtrasada ? _corAtrasada : const Color(0xFF7C3AED),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Tooltip(
                        message: 'Registrar pagamento parcial',
                        child: IconButton(
                          onPressed: () => _mostrarDialogPagamentoParcial(conta),
                          icon: const Icon(Icons.payments_outlined),
                          iconSize: 20,
                          color: const Color(0xFF7C3AED),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                            minimumSize: const Size(36, 36),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'R\$ ${conta.valor.toStringAsFixed(2).replaceAll(".", ",")}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: conta.pago
                          ? Colors.grey.shade400
                          : isAtrasada
                              ? _corAtrasada
                              : corBase,
                      decoration: conta.pago ? TextDecoration.lineThrough : null,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrigemBadge(Conta conta) {
    String? label;
    Color? cor;
    if (conta.isFiado) {
      label = 'FIADO';
      cor = const Color(0xFF7C3AED);
    } else if (conta.isCredito) {
      label = 'CRÉDITO';
      cor = const Color(0xFF1565C0);
    } else if (conta.isAvista) {
      label = 'À VISTA';
      cor = Colors.teal.shade700;
    }

    if (label == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: cor!.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: cor.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(color: cor, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}
