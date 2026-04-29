import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../model/categoria_financeira.dart';
import '../model/conta.dart';
import '../model/fornecedor.dart';
import '../model/tipo_pagamento.dart';
import '../services/categoria_financeira_service.dart';
import '../services/conta_service.dart';
import '../services/fornecedor_service.dart';
import '../services/tipo_pagamento_service.dart';

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
  List<TipoPagamento> _tiposPagamento = [];
  Map<String, double> _resumo = {};
  String _modoAgrupamentoAPagar = 'TODAS';
  String _ordenacaoAPagar = 'VENCIMENTO';
  String _filtroStatusAPagar = 'TODOS';
  String _ordenacaoAReceber = 'VENCIMENTO';
  String _filtroStatusAReceber = 'TODOS';
  int? _filtroFornecedorId;
  int? _ultimaCategoriaFinanceiraIdSelecionada;
  final Set<String> _categoriasExpandidas = <String>{};
  bool _filtrosAPagarExpandidos = false;
  bool _filtrosAReceberExpandidos = false;

  static const Color _corPagar = Color(0xFFDC2626);
  static const Color _corReceber = Color(0xFF16A34A);
  static const Color _corAtrasada = Color(0xFFB45309);

  List<CategoriaFinanceira> _normalizarCategoriasFinanceiras(List<CategoriaFinanceira> categorias) {
    final porId = <int, CategoriaFinanceira>{};
    for (final categoria in categorias) {
      final id = categoria.id;
      if (id == null) continue;
      porId[id] = categoria;
    }
    return porId.values.toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!mounted) return;
      if (_tabController.indexIsChanging) return;
      if (_abaAtual != _tabController.index) {
        setState(() {
          _abaAtual = _tabController.index;
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
        TipoPagamentoService.listarTiposPagamento(),
      ]);
      setState(() {
        _contasAPagar = results[0] as List<Conta>;
        _contasAReceber = results[1] as List<Conta>;
        _resumo = results[2] as Map<String, double>;
        _contasAtrasadas = results[3] as List<Conta>;
        _categoriasFinanceiras = _normalizarCategoriasFinanceiras(results[4] as List<CategoriaFinanceira>);
        _fornecedores = results[5] as List<Fornecedor>;
        _tiposPagamento = results[6] as List<TipoPagamento>;
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
    final indiceVisual = _indiceAbaAtual();
    if (_tabController.index != indiceVisual) {
      _tabController.animateTo(indiceVisual, duration: Duration.zero);
    }
    setState(() {
      _abaAtual = indiceVisual;
      _mesAtual = DateTime(_mesAtual.year, _mesAtual.month + delta, 1);
    });
    _carregarDados();
  }

  int _indiceAbaAtual() {
    final anim = _tabController.animation;
    if (anim != null) {
      return anim.value.round().clamp(0, 1);
    }
    return _tabController.index.clamp(0, 1);
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
    if (nome == null || nome.isEmpty) {
      final origem = (conta.origemTipo ?? '').toUpperCase();
      if (origem.startsWith('OS_')) {
        return 'OS';
      }
      return 'Sem categoria';
    }
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

  Future<int?> _abrirGerenciarCategorias() async {
    int? categoriaSelecionada;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setDialogState) {
            Future<void> recarregarCategorias() async {
              final categorias = await CategoriaFinanceiraService.listar();
              if (!mounted) return;
              setState(() => _categoriasFinanceiras = _normalizarCategoriasFinanceiras(categorias));
              setDialogState(() {});
            }

            Future<void> abrirFormulario({CategoriaFinanceira? categoria}) async {
              final nomeCtrl = TextEditingController(text: categoria?.nome ?? '');
              final descricaoCtrl = TextEditingController(text: categoria?.descricao ?? '');
              final formKey = GlobalKey<FormState>();

              final isEdicao = categoria != null;
              const corCategoria = Color(0xFF1565C0);

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
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(sheetCtx).size.height * 0.88,
                        ),
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
                                    color: corCategoria,
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isEdicao ? Icons.edit : Icons.add,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          isEdicao ? 'Editar Categoria Financeira' : 'Nova Categoria Financeira',
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
                                          validator: (v) {
                                            final value = (v ?? '').trim();
                                            if (value.isEmpty) return 'Informe o nome da categoria';
                                            if (value.length < 2) return 'Nome muito curto';
                                            return null;
                                          },
                                          autovalidateMode: AutovalidateMode.onUserInteraction,
                                          decoration: InputDecoration(
                                            labelText: 'Nome da Categoria',
                                            prefixIcon: const Icon(Icons.category_outlined, color: corCategoria),
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
                                              borderSide: const BorderSide(color: corCategoria, width: 2),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey[50],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller: descricaoCtrl,
                                          maxLines: 3,
                                          autovalidateMode: AutovalidateMode.onUserInteraction,
                                          decoration: InputDecoration(
                                            labelText: 'Descrição (opcional)',
                                            alignLabelWithHint: true,
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
                                              borderSide: const BorderSide(color: corCategoria, width: 2),
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
                                              backgroundColor: corCategoria,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                                final categoriaSalva = result['categoria'];
                                                if (categoriaSalva is CategoriaFinanceira) {
                                                  categoriaSelecionada = categoriaSalva.id;
                                                }
                                                if (!mounted) return;
                                                if (!sheetCtx.mounted) return;
                                                Navigator.pop(sheetCtx);
                                                _mostrarSucesso(!isEdicao ? 'Categoria criada!' : 'Categoria atualizada!');
                                                await recarregarCategorias();
                                              } else {
                                                _mostrarErro(result['mensagem'] ?? 'Erro ao salvar categoria');
                                              }
                                            },
                                            child: Text(
                                              isEdicao ? 'Atualizar Categoria' : 'Cadastrar Categoria',
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
    return categoriaSelecionada;
  }

  Future<Fornecedor?> _abrirCadastroRapidoFornecedorServico(BuildContext parentContext) async {
    Fornecedor? fornecedorSelecionadoNoGerenciador;
    bool carregouNoDialog = false;
    const corFornecedor = Color(0xFF0F766E);

    await showDialog<void>(
      context: parentContext,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setDialogState) {
            Future<void> recarregarFornecedores() async {
              final fornecedoresAtualizados = await FornecedorService.listarFornecedores();
              if (!mounted) return;
              setState(() {
                _fornecedores = fornecedoresAtualizados;
              });
              setDialogState(() {});
            }

            Future<void> abrirFormulario({Fornecedor? fornecedor}) async {
              final nomeCtrl = TextEditingController(text: fornecedor?.nome ?? '');
              final formKey = GlobalKey<FormState>();
              final isEdicao = fornecedor != null;

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
                                    color: corFornecedor,
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(isEdicao ? Icons.edit : Icons.add, color: Colors.white, size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          isEdicao ? 'Editar Fornecedor de Serviço' : 'Novo Fornecedor de Serviço',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
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
                                            if (value.isEmpty) return 'Informe o nome do fornecedor';
                                            if (value.length < 2) return 'Nome muito curto';
                                            return null;
                                          },
                                          decoration: InputDecoration(
                                            labelText: 'Nome do Fornecedor *',
                                            prefixIcon: const Icon(Icons.store_outlined, color: corFornecedor),
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
                                              borderSide: const BorderSide(color: corFornecedor, width: 2),
                                            ),
                                            filled: true,
                                            fillColor: Colors.grey[50],
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 48,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: corFornecedor,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: () async {
                                              if (!formKey.currentState!.validate()) return;

                                              final nome = nomeCtrl.text.trim();

                                              final resultado = isEdicao
                                                  ? await FornecedorService.atualizarFornecedor(
                                                      fornecedor.id!,
                                                      Fornecedor(
                                                        id: fornecedor.id,
                                                        nome: nome,
                                                        cnpj: fornecedor.cnpj,
                                                        telefone: fornecedor.telefone,
                                                        email: fornecedor.email,
                                                        servico: true,
                                                        margemLucro: fornecedor.margemLucro,
                                                        cep: fornecedor.cep,
                                                        rua: fornecedor.rua,
                                                        numeroCasa: fornecedor.numeroCasa,
                                                        complemento: fornecedor.complemento,
                                                        bairro: fornecedor.bairro,
                                                        cidade: fornecedor.cidade,
                                                        uf: fornecedor.uf,
                                                        codigoMunicipio: fornecedor.codigoMunicipio,
                                                      ),
                                                    )
                                                  : await FornecedorService.salvarFornecedor(
                                                      Fornecedor(
                                                        nome: nome,
                                                        cnpj: '',
                                                        telefone: '',
                                                        email: '',
                                                        servico: true,
                                                      ),
                                                    );

                                              if (resultado['success'] == true) {
                                                if (!mounted) return;
                                                if (!sheetCtx.mounted) return;

                                                Navigator.pop(sheetCtx);
                                                _mostrarSucesso(
                                                  isEdicao
                                                      ? 'Fornecedor de serviço atualizado com sucesso!'
                                                      : 'Fornecedor de serviço cadastrado com sucesso!',
                                                );

                                                await recarregarFornecedores();

                                                if (!isEdicao) {
                                                  final fornecedorRetornado =
                                                      resultado['fornecedor'] is Fornecedor ? resultado['fornecedor'] as Fornecedor : null;

                                                  final selecionado = fornecedorRetornado?.id != null
                                                      ? _fornecedores.where((f) => f.id == fornecedorRetornado!.id).firstOrNull
                                                      : _fornecedores
                                                          .where((f) => f.servico && f.nome.trim().toLowerCase() == nome.toLowerCase())
                                                          .firstOrNull;

                                                  if (selecionado != null) {
                                                    fornecedorSelecionadoNoGerenciador = selecionado;
                                                  }
                                                } else {
                                                  final atualizado = _fornecedores.where((f) => f.id == fornecedor.id).firstOrNull;
                                                  if (atualizado != null) {
                                                    fornecedorSelecionadoNoGerenciador = atualizado;
                                                  }
                                                }
                                              } else {
                                                _mostrarErro(resultado['message'] ?? 'Erro ao salvar fornecedor');
                                              }
                                            },
                                            child: Text(
                                              isEdicao ? 'Atualizar Fornecedor' : 'Cadastrar Fornecedor',
                                              style: const TextStyle(fontWeight: FontWeight.w700),
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

            Future<void> excluirFornecedorGerenciamento(Fornecedor fornecedor) async {
              final confirmar = await showDialog<bool>(
                context: ctx2,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Excluir fornecedor'),
                  content: Text('Deseja excluir o fornecedor "${fornecedor.nome}"?'),
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

              final resultado = await FornecedorService.excluirFornecedor(fornecedor.id!);
              if (resultado['success'] == true) {
                _mostrarSucesso('Fornecedor de serviço excluído com sucesso!');
                await recarregarFornecedores();
              } else {
                _mostrarErro(resultado['message'] ?? 'Erro ao excluir fornecedor');
              }
            }

            if (!carregouNoDialog) {
              carregouNoDialog = true;
              Future.microtask(recarregarFornecedores);
            }

            final fornecedoresServico = _fornecedores.where((f) => f.servico).toList()
              ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              title: const Row(
                children: [
                  Icon(Icons.store_outlined, color: corFornecedor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fornecedores de Serviço',
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
                          backgroundColor: corFornecedor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => abrirFormulario(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Novo Fornecedor'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: fornecedoresServico.isEmpty
                          ? const Center(child: Text('Nenhum fornecedor de serviço cadastrado.'))
                          : ListView.separated(
                              itemCount: fornecedoresServico.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final fornecedor = fornecedoresServico[i];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(fornecedor.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Editar',
                                        onPressed: () => abrirFormulario(fornecedor: fornecedor),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Excluir',
                                        onPressed: () => excluirFornecedorGerenciamento(fornecedor),
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

    return fornecedorSelecionadoNoGerenciador;
  }

  List<_ParcelaDraft> _gerarParcelasPadrao({
    required double valorTotal,
    required int quantidade,
    required DateTime base,
    required int diasEntreParcelas,
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
          vencimento: DateTime(base.year, base.month, base.day).add(Duration(days: diasEntreParcelas * i)),
        ),
      );
    }

    return parcelas;
  }

  int _formaPorOrigemTipo(String? origemTipo) {
    final origem = (origemTipo ?? '').toUpperCase();
    if (origem.contains('FIADO')) return 4;
    if (origem.contains('BOLETO')) return 3;
    if (origem.contains('ASSINATURA')) return 2;
    if (origem.contains('CREDITO') || origem.contains('PARCELADO')) return 2;
    if (origem.contains('AVISTA')) return 1;
    return 1;
  }

  bool _permiteJurosDescontoNaBaixa(Conta conta) {
    final forma = _formaPorOrigemTipo(conta.origemTipo);
    return forma == 3 || forma == 4;
  }

  Future<Map<String, dynamic>?> _mostrarDialogBaixaConta(Conta conta, {required bool permitirJurosDesconto}) async {
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
                if (permitirJurosDesconto) ...[
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
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final acrescimo = permitirJurosDesconto && acrescimoCtrl.text.trim().isNotEmpty
                    ? double.parse(acrescimoCtrl.text.replaceAll(',', '.'))
                    : null;
                final desconto = permitirJurosDesconto && descontoCtrl.text.trim().isNotEmpty
                    ? double.parse(descontoCtrl.text.replaceAll(',', '.'))
                    : null;
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
          content: Text('Não é possível desmarcar recebimentos de OS (apenas crediário próprio pode ser revertido).'),
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
                          'As parcelas futuras deste crediário próprio serão removidas automaticamente.',
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
      result = await ContaService.desmarcarPagamento(conta.id!, isParcela: conta.isParcela);
    } else {
      DateTime dataPagamento = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      double? acrescimo;
      double? desconto;

      if (conta.isAPagar) {
        final baixa = await _mostrarDialogBaixaConta(
          conta,
          permitirJurosDesconto: _permiteJurosDescontoNaBaixa(conta),
        );
        if (baixa == null) return;
        dataPagamento = baixa['dataPagamento'] as DateTime;
        acrescimo = baixa['acrescimo'] as double?;
        desconto = baixa['desconto'] as double?;
      }

      result = await ContaService.marcarComoPago(
        conta.id!,
        isParcela: conta.isParcela,
        dataPagamento: dataPagamento,
        acrescimo: acrescimo,
        desconto: desconto,
      );
    }

    if (result['sucesso'] == true) {
      if (conta.isFiado && !conta.pago) {
        _mostrarSucesso('Crediário Próprio marcado como recebido! Entradas futuras removidas automaticamente.');
      } else {
        _mostrarSucesso(conta.pago ? 'Pagamento desmarcado.' : 'Marcado como pago!');
      }
      _carregarDados();
    } else {
      _mostrarErro(result['mensagem'] ?? 'Erro ao alterar status');
    }
  }

  String _descricaoLimpaParaCard(Conta conta) {
    final descricao = conta.descricao.trim();
    final regexDoc = RegExp(r'\s*\[Doc\.?\s*[^\]]+\]\s*$', caseSensitive: false);
    final semDoc = descricao.replaceAll(regexDoc, '').trim();

    final regexPagamento = RegExp(
      r'\s*\((Crédito|Boleto|Fiado|Crediário Próprio|AVISTA|A_VISTA|À vista|AVista|PIX|Dinheiro|Débito).+\)\s*$',
      caseSensitive: false,
    );
    final descricaoNormalizada = semDoc.replaceAll(regexPagamento, '').trim();
    return descricaoNormalizada.replaceAll(RegExp(r'\bfiado\b', caseSensitive: false), 'Crediário Próprio');
  }

  String? _labelPagamentoConta(Conta conta) {
    final origem = (conta.origemTipo ?? '').toUpperCase();
    final total = conta.totalParcelas;
    final docMatch = RegExp(r'\[Doc\.?\s*([^\]]+)\]', caseSensitive: false).firstMatch(conta.descricao);
    final doc = docMatch?.group(1)?.trim();
    final assinaturaFreq = (conta.assinaturaFrequencia ?? '').trim().toUpperCase();

    String? base;
    if (conta.assinatura || origem.contains('ASSINATURA')) {
      final freqLabel = switch (assinaturaFreq) {
        'DIARIA' => 'Diária',
        'SEMANAL' => 'Semanal',
        'MENSAL' => 'Mensal',
        'ANUAL' => 'Anual',
        _ => null,
      };
      base = freqLabel != null ? 'Assinatura ($freqLabel)' : 'Assinatura';
    } else if (origem.contains('BOLETO')) {
      base = total != null && total > 1 ? 'Boleto (${total}x)' : 'Boleto';
    } else if (origem.contains('FIADO')) {
      base = total != null && total > 1 ? 'Crediário Próprio ($total meses)' : 'Crediário Próprio';
    } else if (origem.contains('CREDITO') || origem.contains('PARCELADO')) {
      base = total != null && total > 1 ? 'Crédito (${total}x)' : 'Crédito';
    } else if (origem.contains('AVISTA')) {
      base = 'À vista';
    }

    if (base == null) return null;
    if (doc != null && doc.isNotEmpty) {
      return '$base | Doc: $doc';
    }
    return base;
  }

  String? _extrairNumeroDocBoleto(String texto) {
    final docMatch = RegExp(r'\[Doc\.?\s*([^\]]+)\]', caseSensitive: false).firstMatch(texto);
    return docMatch?.group(1)?.trim();
  }

  void _editarContaPagar(Conta conta) {
    if (conta.id == null) return;
    final isParcela = conta.isParcela;
    final isParcelaBoletoBloqueada = isParcela && conta.isBoleto;

    if (isParcelaBoletoBloqueada) {
      _mostrarErro('Parcelas de boleto não podem ser editadas. Exclua e lance novamente.');
      return;
    }
    _abrirDialogAdicionarConta(conta: conta);
  }

  void _abrirDialogAdicionarConta({Conta? conta}) {
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
    final isEditing = conta != null;
    final contaInicial = conta;
    final descricaoCtrl = TextEditingController(text: contaInicial?.descricao ?? '');
    final valorCtrl = TextEditingController(text: contaInicial?.valor.toStringAsFixed(2).replaceAll('.', ',') ?? '');
    final boletoDocCtrl = TextEditingController(text: contaInicial != null ? _extrairNumeroDocBoleto(contaInicial.descricao) ?? '' : '');
    final fornecedoresServico = _fornecedores.where((f) => f.servico).toList();
    final tiposPagamentoOrdenados = List<TipoPagamento>.from(_tiposPagamento)
      .where((t) => t.idFormaPagamento != 4).toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

    bool isFrete = contaInicial?.origemTipo?.contains('FRETE') == true;
    int? tipoPagamentoId;
    final contaOrigem = (contaInicial?.origemTipo ?? '').toUpperCase();
    if (contaInicial != null) {
      if (contaOrigem.contains('BOLETO')) {
        tipoPagamentoId = tiposPagamentoOrdenados
            .where((t) => t.idFormaPagamento == 3)
            .map((t) => t.id)
            .cast<int?>()
            .firstWhere((id) => id != null, orElse: () => null);
      } else if (contaOrigem.contains('FIADO')) {
        tipoPagamentoId = tiposPagamentoOrdenados
            .where((t) => t.idFormaPagamento == 4)
            .map((t) => t.id)
            .cast<int?>()
            .firstWhere((id) => id != null, orElse: () => null);
      } else if (contaOrigem.contains('CREDITO') || contaOrigem.contains('PARCELADO')) {
        tipoPagamentoId = tiposPagamentoOrdenados
            .where((t) => t.idFormaPagamento == 2)
            .map((t) => t.id)
            .cast<int?>()
            .firstWhere((id) => id != null, orElse: () => null);
      } else if (contaOrigem.contains('AVISTA')) {
        tipoPagamentoId = tiposPagamentoOrdenados
            .where((t) => (t.idFormaPagamento ?? 1) == 1)
            .map((t) => t.id)
            .cast<int?>()
            .firstWhere((id) => id != null, orElse: () => null);
      }
    }

    int? categoriaFinanceiraId = contaInicial?.categoriaId;
    int? fornecedorId = contaInicial?.fornecedorId;
    int numeroParcelas = 1;
    List<_ParcelaDraft> parcelas = [];
    DateTime vencimento = contaInicial?.dataVencimento ?? DateTime(hoje.year, hoje.month, hoje.day);
    bool isAssinatura = contaInicial?.assinatura ?? contaOrigem.contains('ASSINATURA');
    String? assinaturaFrequencia = contaInicial?.assinaturaFrequencia ?? (isAssinatura ? 'MENSAL' : null);
    DateTime assinaturaDataInicio = contaInicial?.assinaturaDataInicio ?? DateTime(hoje.year, hoje.month, hoje.day);
    DateTime? assinaturaDataFim = contaInicial?.assinaturaDataFim;
    final opcoesFrequenciaAssinatura = <String, String>{
      'DIARIA': 'Diária',
      'SEMANAL': 'Semanal',
      'MENSAL': 'Mensal',
      'ANUAL': 'Anual',
    };
    if (isAssinatura && tipoPagamentoId == null) {
      tipoPagamentoId = tiposPagamentoOrdenados.where((t) => t.idFormaPagamento == 2).map((t) => t.id).cast<int?>().firstWhere(
            (id) => id != null,
            orElse: () => null,
          );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          final categoriaFinanceiraIdValido =
              categoriaFinanceiraId != null && _categoriasFinanceiras.any((c) => c.id == categoriaFinanceiraId);
          final categoriaFinanceiraIdDropdown = categoriaFinanceiraIdValido ? categoriaFinanceiraId : null;
          final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
          final podeAlterarOrigem = !isEditing;

          TipoPagamento? tipoCredito() {
            for (final tipo in tiposPagamentoOrdenados) {
              if (tipo.idFormaPagamento == 2) {
                return tipo;
              }
            }
            return null;
          }

          TipoPagamento? tipoSelecionado() {
            if (tipoPagamentoId == null) return null;
            for (final t in tiposPagamentoOrdenados) {
              if (t.id == tipoPagamentoId) return t;
            }
            return null;
          }

          int idFormaPagamentoSelecionada() => tipoSelecionado()?.idFormaPagamento ?? 1;

          int totalParcelasTipo() {
            final qtd = tipoSelecionado()?.quantidadeParcelas ?? 1;
            return qtd < 1 ? 1 : qtd;
          }

          IconData iconeTipoPagamento(TipoPagamento tipo) {
            final forma = tipo.idFormaPagamento ?? 1;
            if (forma == 2) return Icons.credit_score;
            if (forma == 3) return Icons.receipt_long;
            if (forma == 4) return Icons.handshake_outlined;
            return Icons.payments_outlined;
          }

          bool isCredito() => idFormaPagamentoSelecionada() == 2;

          bool isFiado() => idFormaPagamentoSelecionada() == 4;

          bool isBoletoParcelado() => idFormaPagamentoSelecionada() == 3 && totalParcelasTipo() > 1;

          bool isBoleto() => idFormaPagamentoSelecionada() == 3;

          bool usaTabelaParcelas() => isCredito() || isFiado() || isBoletoParcelado();

          int quantidadeParcelasTabela() => isBoletoParcelado() ? totalParcelasTipo() : numeroParcelas;

          double somaParcelas() => parcelas.fold<double>(0, (s, p) => s + p.valor);

          void recalcularParcelas() {
            if (!usaTabelaParcelas()) {
              parcelas = [];
              return;
            }

            final quantidade = quantidadeParcelasTabela();
            if (quantidade < 1) {
              parcelas = [];
              return;
            }

            final total = double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0;
            if (total <= 0) {
              parcelas = [];
              return;
            }
            final diasTipo = tipoSelecionado()?.diasEntreParcelas ?? 30;
            final diasEntreParcelas = diasTipo >= 0 ? diasTipo : 30;
            parcelas = _gerarParcelasPadrao(
              valorTotal: total,
              quantidade: quantidade,
              base: vencimento,
              diasEntreParcelas: diasEntreParcelas,
            );
          }

          bool formularioValido() {
            final valor = double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0;
            if (descricaoCtrl.text.trim().isEmpty || valor <= 0 || tipoPagamentoId == null) return false;
            if (isAssinatura) {
              if (idFormaPagamentoSelecionada() != 2) return false;
              if (assinaturaFrequencia == null || assinaturaFrequencia!.isEmpty) return false;
              if (assinaturaDataFim != null && assinaturaDataFim!.isBefore(assinaturaDataInicio)) return false;
              return true;
            }
            if (isBoleto()) {
              final doc = boletoDocCtrl.text.trim();
              if (doc.isEmpty) return false;
              if (vencimento.isBefore(hojeSemHora)) return false;
            }
            if (usaTabelaParcelas()) {
              if (parcelas.isEmpty) return false;
              final soma = somaParcelas();
              return (soma - valor).abs() <= 0.02;
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

          const dialogPrimary = Color(0xFF2E90DE);

          return Theme(
            data: Theme.of(ctx2).copyWith(
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: dialogPrimary, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            child: SafeArea(
              top: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx2).size.height * 0.92,
                ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: const BoxDecoration(
                            color: dialogPrimary,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          child: Row(
                            children: [
                              Icon(isEditing ? Icons.edit : Icons.add, color: Colors.white, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isEditing
                                      ? (isFrete ? 'Editar Frete a Pagar' : 'Editar Conta a Pagar')
                                      : (isFrete ? 'Novo Frete a Pagar' : 'Nova Conta a Pagar'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx2),
                                icon: const Icon(Icons.close, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Form(
                            key: formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: podeAlterarOrigem
                                            ? () => setDialogState(() {
                                                  if (!isFrete) return;
                                                  isFrete = false;
                                                  descricaoCtrl.clear();
                                                  valorCtrl.clear();
                                                  tipoPagamentoId = null;
                                                  fornecedorId = null;
                                                  isAssinatura = false;
                                                  numeroParcelas = 1;
                                                  parcelas = [];
                                                  boletoDocCtrl.clear();
                                                  vencimento = DateTime(hoje.year, hoje.month, hoje.day);
                                                })
                                            : null,
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
                                        onTap: podeAlterarOrigem
                                            ? () => setDialogState(() {
                                                  if (isFrete) return;
                                                  isFrete = true;
                                                  descricaoCtrl.clear();
                                                  valorCtrl.clear();
                                                  tipoPagamentoId = null;
                                                  fornecedorId = null;
                                                  isAssinatura = false;
                                                  numeroParcelas = 1;
                                                  parcelas = [];
                                                  boletoDocCtrl.clear();
                                                  vencimento = DateTime(hoje.year, hoje.month, hoje.day);
                                                })
                                            : null,
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
                                              Icon(Icons.local_shipping_outlined,
                                                  size: 16, color: isFrete ? Colors.white : Colors.grey.shade600),
                                              const SizedBox(width: 6),
                                              Text('Frete',
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                      color: isFrete ? Colors.white : Colors.grey.shade600)),
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
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<int>(
                                          initialValue: categoriaFinanceiraIdDropdown,
                                          decoration: InputDecoration(
                                            labelText: 'Categoria financeira',
                                            prefixIcon: const Icon(Icons.category_outlined),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          items: _categoriasFinanceiras
                                              .where((c) => c.id != null)
                                              .map(
                                                (c) => DropdownMenuItem<int>(
                                                  value: c.id,
                                                  child: Text(c.nome),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (v) => setDialogState(() {
                                            categoriaFinanceiraId = v;
                                            _ultimaCategoriaFinanceiraIdSelecionada = v;
                                          }),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        height: 56,
                                        child: Tooltip(
                                          message: 'Gerenciar categorias financeiras',
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              final categoriaSelecionada = await _abrirGerenciarCategorias();
                                              if (!ctx2.mounted) return;
                                              setDialogState(() {
                                                if (categoriaSelecionada != null) {
                                                  categoriaFinanceiraId = categoriaSelecionada;
                                                  _ultimaCategoriaFinanceiraIdSelecionada = categoriaSelecionada;
                                                } else {
                                                  final categoriaAtualExiste = categoriaFinanceiraId != null &&
                                                      _categoriasFinanceiras.any((c) => c.id == categoriaFinanceiraId);
                                                  if (!categoriaAtualExiste) {
                                                    final ultimaCategoriaExiste = _ultimaCategoriaFinanceiraIdSelecionada != null &&
                                                        _categoriasFinanceiras.any((c) => c.id == _ultimaCategoriaFinanceiraIdSelecionada);
                                                    categoriaFinanceiraId =
                                                        ultimaCategoriaExiste ? _ultimaCategoriaFinanceiraIdSelecionada : null;
                                                  }
                                                }
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: dialogPrimary,
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
                                  const SizedBox(height: 12),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<int?>(
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
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        height: 56,
                                        child: Tooltip(
                                          message: 'Gerenciar fornecedores de serviço',
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              final fornecedorSelecionado = await _abrirCadastroRapidoFornecedorServico(ctx2);
                                              if (!ctx2.mounted) return;

                                              setDialogState(() {
                                                if (fornecedorSelecionado?.id != null) {
                                                  fornecedorId = fornecedorSelecionado!.id;
                                                } else if (fornecedorId != null &&
                                                    !_fornecedores.any((f) => f.servico && f.id == fornecedorId)) {
                                                  fornecedorId = null;
                                                }
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: dialogPrimary,
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
                                  const SizedBox(height: 10),
                                  CheckboxListTile(
                                    value: isAssinatura,
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    title: const Text('É assinatura?'),
                                    onChanged: (value) => setDialogState(() {
                                      final novoValor = value ?? false;
                                      if (novoValor) {
                                        final credito = tipoCredito();
                                        if (credito?.id == null) {
                                          _mostrarErro('Cadastre uma forma de pagamento de Cartão de Crédito antes de usar assinatura.');
                                          return;
                                        }
                                        tipoPagamentoId = credito!.id;
                                        assinaturaFrequencia ??= 'MENSAL';
                                        assinaturaDataInicio =
                                            assinaturaDataInicio.isBefore(hojeSemHora) ? hojeSemHora : assinaturaDataInicio;
                                        assinaturaDataFim = null;
                                        numeroParcelas = 1;
                                        parcelas = [];
                                        boletoDocCtrl.clear();
                                      }
                                      isAssinatura = novoValor;
                                    }),
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
                                const SizedBox(height: 14),
                                DropdownButtonFormField<int>(
                                  key: ValueKey('formaPagamento_${tipoPagamentoId}_$isAssinatura'),
                                  initialValue: tipoPagamentoId,
                                  decoration: InputDecoration(
                                    labelText: 'Forma de Pagamento *',
                                    prefixIcon: Icon(Icons.payment, color: isFrete ? Colors.orange.shade700 : _corPagar),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    filled: true,
                                    fillColor: isAssinatura ? Colors.grey.shade100 : null,
                                  ),
                                  items: tiposPagamentoOrdenados.map((tipo) {
                                    return DropdownMenuItem<int>(
                                      value: tipo.id,
                                      child: Row(
                                        children: [
                                          Icon(iconeTipoPagamento(tipo), size: 18, color: isFrete ? Colors.orange.shade700 : _corPagar),
                                          const SizedBox(width: 8),
                                          Text(tipo.nome),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: isAssinatura
                                      ? null
                                      : (v) => setDialogState(() {
                                            tipoPagamentoId = v;
                                            numeroParcelas = 1;
                                            boletoDocCtrl.clear();
                                            if (isBoletoParcelado()) {
                                              numeroParcelas = totalParcelasTipo();
                                            }
                                            recalcularParcelas();
                                          }),
                                  validator: (v) => v == null ? 'Selecione a forma de pagamento' : null,
                                ),
                                if (isAssinatura) ...[
                                  const SizedBox(height: 14),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey('assinaturaFrequencia_$assinaturaFrequencia'),
                                    initialValue: assinaturaFrequencia,
                                    decoration: const InputDecoration(
                                      labelText: 'Frequência *',
                                      prefixIcon: Icon(Icons.repeat),
                                      border: OutlineInputBorder(),
                                    ),
                                    items: opcoesFrequenciaAssinatura.entries
                                        .map((entry) => DropdownMenuItem<String>(
                                              value: entry.key,
                                              child: Text(entry.value),
                                            ))
                                        .toList(),
                                    onChanged: (value) => setDialogState(() => assinaturaFrequencia = value),
                                  ),
                                  const SizedBox(height: 12),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: ctx2,
                                        initialDate: assinaturaDataInicio,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2035),
                                        locale: const Locale('pt', 'BR'),
                                      );
                                      if (picked != null) {
                                        setDialogState(() {
                                          assinaturaDataInicio = picked;
                                          if (assinaturaDataFim != null && assinaturaDataFim!.isBefore(assinaturaDataInicio)) {
                                            assinaturaDataFim = null;
                                          }
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
                                          const Icon(Icons.play_circle_outline, color: Colors.grey),
                                          const SizedBox(width: 10),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Data de Início *', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                              Text(
                                                DateFormat('dd/MM/yyyy').format(assinaturaDataInicio),
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () async {
                                      final inicial = assinaturaDataFim ?? assinaturaDataInicio;
                                      final picked = await showDatePicker(
                                        context: ctx2,
                                        initialDate: inicial,
                                        firstDate: assinaturaDataInicio,
                                        lastDate: DateTime(2035),
                                        locale: const Locale('pt', 'BR'),
                                      );
                                      if (picked != null) {
                                        setDialogState(() => assinaturaDataFim = picked);
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
                                          const Icon(Icons.event_busy_outlined, color: Colors.grey),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Data de Fim (Opcional)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                                Text(
                                                  assinaturaDataFim != null
                                                      ? DateFormat('dd/MM/yyyy').format(assinaturaDataFim!)
                                                      : 'Selecionar data',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                    color: assinaturaDataFim != null ? Colors.black87 : Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (assinaturaDataFim != null)
                                            IconButton(
                                              icon: const Icon(Icons.close, size: 18),
                                              tooltip: 'Limpar data final',
                                              onPressed: () => setDialogState(() => assinaturaDataFim = null),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                if (!isAssinatura && isBoleto()) ...[
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () async {
                                      final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
                                      final picked = await showDatePicker(
                                        context: ctx2,
                                        initialDate: vencimento.isBefore(hojeSemHora) ? hojeSemHora : vencimento,
                                        firstDate: hojeSemHora,
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
                                ],
                                if (!isAssinatura && isBoleto()) ...[
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: boletoDocCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: const InputDecoration(
                                      labelText: 'Número do Doc. do Boleto *',
                                      prefixIcon: Icon(Icons.description_outlined),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (_) {
                                      final doc = boletoDocCtrl.text.trim();
                                      if (doc.isEmpty) return 'Informe o número do documento do boleto';
                                      return null;
                                    },
                                  ),
                                ],
                                if (!isAssinatura && usaTabelaParcelas()) ...[
                                  const SizedBox(height: 14),
                                  if (isCredito() || isFiado())
                                    DropdownButtonFormField<int>(
                                      initialValue: numeroParcelas,
                                      decoration: const InputDecoration(
                                        labelText: 'Número de Parcelas',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: List.generate(totalParcelasTipo() > 0 ? totalParcelasTipo() : 1, (i) => i + 1)
                                          .map((n) => DropdownMenuItem<int>(value: n, child: Text('$n parcelas')))
                                          .toList(),
                                      onChanged: (v) => setDialogState(() {
                                        numeroParcelas = v ?? 1;
                                        recalcularParcelas();
                                      }),
                                    )
                                  else
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Boleto em ${quantidadeParcelasTabela()} parcela${quantidadeParcelasTabela() > 1 ? 's' : ''}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
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
                                              DataCell(Text('${p.numero}/${quantidadeParcelasTabela()}')),
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx2),
                                child: const Text(
                                  'Cancelar',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: dialogPrimary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: Icon(isEditing ? Icons.save : Icons.check, size: 18),
                                label: Text(isEditing ? 'Editar' : 'Adicionar', style: const TextStyle(fontWeight: FontWeight.w700)),
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) return;
                                  if (!formularioValido()) {
                                    _mostrarErro('Confira forma de pagamento e parcelas.');
                                    return;
                                  }
                                  Navigator.pop(ctx2);

                                  final valor = double.parse(valorCtrl.text.replaceAll(',', '.'));
                                  final forma = idFormaPagamentoSelecionada();
                                  final backend = isAssinatura
                                      ? 'CREDITO'
                                      : forma == 2
                                          ? 'CREDITO'
                                          : forma == 3
                                              ? 'BOLETO'
                                              : forma == 4
                                                  ? 'FIADO'
                                                  : 'AVISTA';
                                  final baseOrigem =
                                      contaOrigem.isNotEmpty ? contaOrigem.split('_').first : (isFrete ? 'FRETE' : 'DESPESA');
                                  final diasTipo = tipoSelecionado()?.diasEntreParcelas ?? 30;
                                  final pagamentoData = <String, dynamic>{
                                    'formaPagamento': backend,
                                    'diasEntreParcelas': diasTipo >= 0 ? diasTipo : 30,
                                  };

                                  if (isAssinatura) {
                                    pagamentoData['isAssinatura'] = true;
                                    pagamentoData['assinaturaFrequencia'] = assinaturaFrequencia;
                                    pagamentoData['assinaturaDataInicio'] = assinaturaDataInicio.toIso8601String().substring(0, 10);
                                    if (assinaturaDataFim != null) {
                                      pagamentoData['assinaturaDataFim'] = assinaturaDataFim!.toIso8601String().substring(0, 10);
                                    }
                                  }

                                  if (!isAssinatura && (isCredito() || isFiado() || isBoletoParcelado())) {
                                    pagamentoData['parcelasDetalhadas'] = parcelas
                                        .map((p) => {
                                              'numero': p.numero,
                                              'valor': p.valor,
                                              'vencimento': p.vencimento.toIso8601String().substring(0, 10),
                                            })
                                        .toList();
                                    pagamentoData['numeroParcelas'] = parcelas.length;
                                  }
                                  if (!isAssinatura && isBoleto()) {
                                    pagamentoData['boletoVencimento'] = vencimento.toIso8601String().substring(0, 10);
                                    pagamentoData['boletoNumeroDocumento'] = boletoDocCtrl.text.trim();
                                  }

                                  if (isEditing && contaInicial != null) {
                                    final result = await ContaService.editarConta(
                                      contaInicial.id!,
                                      descricaoCtrl.text.trim(),
                                      valor,
                                      vencimento,
                                      categoriaFinanceiraId: isFrete ? null : categoriaFinanceiraId,
                                      fornecedorId: isFrete ? null : fornecedorId,
                                      origemTipo: contaInicial.isParcela
                                          ? null
                                          : (isAssinatura ? '${baseOrigem}_ASSINATURA' : '${baseOrigem}_$backend'),
                                      assinatura: isAssinatura,
                                      assinaturaFrequencia: isAssinatura ? assinaturaFrequencia : null,
                                      assinaturaDataInicio: isAssinatura ? assinaturaDataInicio : null,
                                      assinaturaDataFim: isAssinatura ? assinaturaDataFim : null,
                                      isParcela: contaInicial.isParcela,
                                    );

                                    if (result['sucesso'] == true) {
                                      _mostrarSucesso('Conta atualizada!');
                                      _carregarDados();
                                    } else {
                                      _mostrarErro(result['mensagem'] ?? 'Erro ao editar conta');
                                    }
                                  } else {
                                    final result = await ContaService.adicionarLancamentoAPagar(
                                      descricao: descricaoCtrl.text.trim(),
                                      valor: valor,
                                      origem: isFrete ? 'FRETE' : 'DESPESA',
                                      pagamento: pagamentoData,
                                      categoriaFinanceiraId: isFrete ? null : categoriaFinanceiraId,
                                      fornecedorId: isFrete ? null : fornecedorId,
                                    );

                                    if (result['sucesso'] == true) {
                                      if (!isFrete && categoriaFinanceiraId != null) {
                                        _ultimaCategoriaFinanceiraIdSelecionada = categoriaFinanceiraId;
                                      }
                                      _mostrarSucesso(isFrete ? 'Frete adicionado com sucesso!' : 'Despesa adicionada com sucesso!');
                                      _carregarDados();
                                    } else {
                                      _mostrarErro(result['mensagem'] ?? 'Erro ao adicionar lançamento');
                                    }
                                  }
                                },
                              ),
                            ],
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
                          'Este crediário próprio está com vencimento em atraso.',
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
                  _mostrarSucesso('Crediário Próprio quitado! Entradas futuras removidas automaticamente.');
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

    final isAssinatura = conta.assinatura || (conta.origemTipo ?? '').toUpperCase().contains('ASSINATURA');
    if (isAssinatura && conta.assinaturaDataFim != null && conta.id != null) {
      final acao = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Excluir Assinatura'),
          content: Text('O que deseja excluir em "${conta.descricao}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'somente'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange.shade700),
              child: const Text('Só esta cobrança'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'geral'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Excluir série inteira'),
            ),
          ],
        ),
      );

      if (acao == null) return;

      if (acao == 'somente') {
        final ok = await ContaService.deletarConta(conta.id!, isParcela: false);
        if (ok) {
          _mostrarSucesso('Cobrança removida.');
          _carregarDados();
        } else {
          _mostrarErro('Erro ao remover cobrança.');
        }
        return;
      }

      final resultado = await ContaService.deletarSerieAssinatura(conta.id!);
      if (resultado['sucesso'] == true) {
        _mostrarSucesso('Série da assinatura removida.');
        _carregarDados();
      } else {
        _mostrarErro(resultado['mensagem']?.toString() ?? 'Não foi possível remover a série da assinatura.');
      }
      return;
    }

    if (conta.isParcela && conta.id != null) {
      final acao = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Excluir Parcela'),
          content: Text('O que deseja excluir em "${conta.descricao}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'somente'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange.shade700),
              child: const Text('Só esta parcela'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'restantes'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Esta e restantes'),
            ),
          ],
        ),
      );

      if (acao == null) return;

      if (acao == 'somente') {
        final ok = await ContaService.deletarConta(conta.id!, isParcela: true);
        if (ok) {
          _mostrarSucesso('Parcela removida.');
          _carregarDados();
        } else {
          _mostrarErro('Erro ao remover parcela.');
        }
        return;
      }

      final resultado = await ContaService.deletarParcelaERestantes(conta.id!);
      if (resultado['sucesso'] == true) {
        _mostrarSucesso('Parcelas restantes removidas.');
        _carregarDados();
      } else {
        _mostrarErro(resultado['mensagem']?.toString() ?? 'Não foi possível remover as parcelas restantes.');
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja remover "${conta.descricao}"?\n'
            '${conta.isFiado ? 'Todas as entradas mensais deste crediário próprio serão removidas.' : ''}'),
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
      final ok = await ContaService.deletarConta(conta.id!, isParcela: conta.isParcela);
      if (ok) {
        _mostrarSucesso('Conta removida.');
        _carregarDados();
      } else {
        _mostrarErro('Erro ao remover conta.');
      }
    }
  }

  Widget _buildFabAcoes() {
    if (_isTelaCompacta()) {
      return FloatingActionButton(
        heroTag: 'fab_acoes_mobile',
        backgroundColor: _corPagar,
        foregroundColor: Colors.white,
        onPressed: _abrirDialogAdicionarConta,
        child: const Icon(Icons.add),
      );
    }

    return FloatingActionButton.extended(
      heroTag: 'fab_nova_conta',
      backgroundColor: _corPagar,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Nova Conta'),
      onPressed: _abrirDialogAdicionarConta,
    );
  }

  @override
  Widget build(BuildContext context) {
    final abaAtual = _indiceAbaAtual();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: abaAtual == 0 ? _buildFabAcoes() : null,
      body: Column(
        children: [
          _buildHeader(),
          if (abaAtual == 0 && _contasAtrasadas.any((c) => c.isAPagar))
            _buildAlertaAtrasadasTipo('A_PAGAR')
          else if (abaAtual == 1 && _contasAtrasadas.any((c) => c.isAReceber))
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
    final abaAtual = _indiceAbaAtual();
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: abaAtual == 0 ? _corPagar : _corReceber,
        unselectedLabelColor: Colors.grey,
        indicatorColor: abaAtual == 0 ? _corPagar : _corReceber,
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
        final ok = await ContaService.deletarConta(conta.id!, isParcela: conta.isParcela);
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
                              _descricaoLimpaParaCard(conta),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: conta.pago ? Colors.grey.shade500 : Colors.grey.shade900,
                                decoration: conta.pago ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (conta.assinatura || (conta.origemTipo ?? '').toUpperCase().contains('ASSINATURA')) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.45)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.autorenew, size: 11, color: Color(0xFF0F766E)),
                                SizedBox(width: 4),
                                Text(
                                  'ASSINATURA',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F766E),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                      if (_labelPagamentoConta(conta) != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Pagamento: ${_labelPagamentoConta(conta)!}',
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
                      if ((conta.isCredito || (conta.origemTipo ?? '').contains('FIADO')) &&
                          conta.parcelaNumero != null &&
                          conta.totalParcelas != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          (conta.origemTipo ?? '').contains('FIADO')
                              ? 'Mês ${conta.parcelaNumero}/${conta.totalParcelas}'
                              : 'Parcela ${conta.parcelaNumero}/${conta.totalParcelas}',
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
                              message: conta.isParcela && conta.isBoleto ? 'Parcelas de boleto não podem ser editadas' : 'Editar',
                              child: IconButton(
                                onPressed: conta.isParcela && conta.isBoleto ? null : () => _editarContaPagar(conta),
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
}
