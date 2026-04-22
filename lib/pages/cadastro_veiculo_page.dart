import 'dart:async';
import 'package:tecstock/model/marca.dart';
import 'package:tecstock/model/veiculo.dart';
import 'package:tecstock/services/marca_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../services/veiculo_service.dart';
import '../utils/error_utils.dart';
import '../widgets/pagination_controls.dart';

class CadastroVeiculoPage extends StatefulWidget {
  const CadastroVeiculoPage({super.key});

  @override
  State<CadastroVeiculoPage> createState() => _CadastroVeiculoPageState();
}

class _CadastroVeiculoPageState extends State<CadastroVeiculoPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nome = TextEditingController();
  final TextEditingController _placa = TextEditingController();
  final TextEditingController _ano = TextEditingController();
  final TextEditingController _modelo = TextEditingController();
  int? _marcaSelecionadaId;
  String? _marcaSelecionadaNome;
  List<Marca> _marcas = [];
  int? _marcaFiltroId;
  final Set<int> _marcaIdsComVeiculos = {};
  List<Marca> _marcasFiltroDisponiveis = [];
  final TextEditingController _cor = TextEditingController();
  final TextEditingController _quilometragem = TextEditingController();

  final List<String> _categorias = ['Passeio', 'Caminhonete'];
  String? _categoriaSelecionada;
  final _maskPlaca = MaskTextInputFormatter(
      mask: 'AAA-#X##',
      filter: {"#": RegExp(r'[0-9]'), "A": RegExp(r'[a-zA-Z]'), "X": RegExp(r'[a-zA-Z0-9]')},
      type: MaskAutoCompletionType.lazy);

  final _upperCaseFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  });

  final _numbersOnlyFormatter = FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));
  final _lettersOnlyFormatter = FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZÀ-ÿ\s]'));
  final _maxLength4Formatter = LengthLimitingTextInputFormatter(4);

  final TextEditingController _searchController = TextEditingController();
  String _searchMode = 'placa';
  List<Veiculo> _veiculosFiltrados = [];
  Veiculo? _veiculoEmEdicao;

  bool _isLoadingVeiculos = true;
  bool _isSaving = false;
  StateSetter? _formModalSetState;

  Timer? _debounceTimer;
  int _currentPage = 0;
  int _totalPages = 0;
  int _totalElements = 0;
  String _lastSearchQuery = '';
  int _pageSize = 30;
  final List<int> _pageSizeOptions = [30, 50, 100];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const Color primaryColor = Color(0xFF2196F3);
  static const Color errorColor = Color(0xFFE53E3E);
  static const Color successColor = Color(0xFF38A169);
  static const Color shadowColor = Color(0x1A000000);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _limparFormulario();
    _carregarMarcas();
    _carregarVeiculos();
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
    _formModalSetState = null;
    _fadeController.dispose();
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _nome.dispose();
    _placa.dispose();
    _ano.dispose();
    _modelo.dispose();
    _cor.dispose();
    _quilometragem.dispose();
    super.dispose();
  }

  void _rebuildFormModal() {
    final setter = _formModalSetState;
    if (setter != null) {
      setter(() {});
    }
  }

  void _onSearchChanged({bool force = false}) {
    final query = _searchController.text.trim();
    final composite = '$_searchMode|$query';
    if (!force && composite == _lastSearchQuery) return;
    _lastSearchQuery = composite;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _currentPage = 0;
      });
      _filtrarVeiculos();
    });
  }

  bool _matchesVeiculoQuery(Veiculo veiculo, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    if (_searchMode == 'nome') {
      final nome = veiculo.nome.toLowerCase();
      return nome.startsWith(normalizedQuery);
    }
    final placa = veiculo.placa.replaceAll('-', '').toUpperCase();
    return placa.startsWith(normalizedQuery);
  }

  Future<void> _filtrarVeiculos() async {
    final rawQuery = _searchController.text.trim();
    final apiQuery = _searchMode == 'placa' ? rawQuery.toUpperCase() : rawQuery.toLowerCase();
    final normalizedQuery = _searchMode == 'placa' ? rawQuery.replaceAll('-', '').toUpperCase() : rawQuery.toLowerCase();

    setState(() => _isLoadingVeiculos = true);

    try {
      final resultado = await VeiculoService.buscarPaginado(
        apiQuery,
        _currentPage,
        size: _pageSize,
        marcaId: _marcaFiltroId,
        searchMode: _searchMode,
      );

      if (resultado['success']) {
        final veiculos = resultado['content'] as List<Veiculo>;
        final marcasEncontradas = veiculos.map((v) => v.marca?.id).whereType<int>().toSet();
        final filtrados = veiculos.where((v) {
          final matchesMarca = _marcaFiltroId == null || v.marca?.id == _marcaFiltroId;
          final matchesQuery = _matchesVeiculoQuery(v, normalizedQuery);
          return matchesMarca && matchesQuery;
        }).toList();
        setState(() {
          _veiculosFiltrados = filtrados;
          _totalPages = resultado['totalPages'] as int;
          _totalElements = resultado['totalElements'] as int;
          _marcaIdsComVeiculos
            ..clear()
            ..addAll(marcasEncontradas);
          if (_marcaFiltroId != null && !_marcaIdsComVeiculos.contains(_marcaFiltroId)) {
            _marcaFiltroId = null;
          }
          _marcasFiltroDisponiveis = _marcas.where((m) => _marcaIdsComVeiculos.contains(m.id)).toList();
        });
      } else {
        if (!mounted) return;
        ErrorUtils.showVisibleError(context, 'Erro ao buscar veículos');
      }
    } catch (e) {
      if (!mounted) return;
      ErrorUtils.showVisibleError(context, 'Erro ao buscar veículos');
    } finally {
      setState(() => _isLoadingVeiculos = false);
    }
  }

  void _irParaPagina(int page) {
    if (page < 0 || page >= _totalPages) return;
    setState(() => _currentPage = page);
    _filtrarVeiculos();
  }

  void _alterarPageSize(int size) {
    setState(() {
      _pageSize = size;
      _currentPage = 0;
    });
    _filtrarVeiculos();
  }

  Future<void> _carregarVeiculos() async {
    setState(() => _isLoadingVeiculos = true);
    try {
      final resultado = await VeiculoService.buscarPaginado('', 0, size: _pageSize, marcaId: _marcaFiltroId);

      if (resultado['success']) {
        final veiculos = resultado['content'] as List<Veiculo>;
        final marcasEncontradas = veiculos.map((v) => v.marca?.id).whereType<int>().toSet();
        final filtrados = veiculos.where((v) {
          final matchesMarca = _marcaFiltroId == null || v.marca?.id == _marcaFiltroId;
          return matchesMarca;
        }).toList();
        setState(() {
          _veiculosFiltrados = filtrados;
          _totalPages = resultado['totalPages'] as int;
          _totalElements = resultado['totalElements'] as int;
          _currentPage = 0;
          _marcaIdsComVeiculos
            ..clear()
            ..addAll(marcasEncontradas);
          if (_marcaFiltroId != null && !_marcaIdsComVeiculos.contains(_marcaFiltroId)) {
            _marcaFiltroId = null;
          }
          _marcasFiltroDisponiveis = _marcas.where((m) => _marcaIdsComVeiculos.contains(m.id)).toList();
        });
      } else {
        if (!mounted) return;
        ErrorUtils.showVisibleError(context, 'Erro ao carregar veículos');
      }
    } catch (e) {
      if (!mounted) return;
      ErrorUtils.showVisibleError(context, 'Erro ao carregar veículos');
    } finally {
      setState(() => _isLoadingVeiculos = false);
    }
  }

  Future<void> _carregarMarcas() async {
    try {
      final lista = await MarcaService.listarMarcas();
      lista.sort((a, b) => a.marca.toLowerCase().compareTo(b.marca.toLowerCase()));
      setState(() {
        _marcas = lista;
        _marcasFiltroDisponiveis = _marcas.where((m) => _marcaIdsComVeiculos.contains(m.id)).toList();
        if (_marcaSelecionadaId != null) {
          final selecionada = _marcas.where((m) => m.id == _marcaSelecionadaId).cast<Marca?>().firstOrNull;
          _marcaSelecionadaNome = selecionada?.marca;
        } else if ((_marcaSelecionadaNome ?? '').trim().isNotEmpty) {
          final nomeSelecionado = _marcaSelecionadaNome!.trim().toLowerCase();
          final reconciliada = _marcas.where((m) => m.marca.trim().toLowerCase() == nomeSelecionado).cast<Marca?>().firstOrNull;
          if (reconciliada != null) {
            _marcaSelecionadaId = reconciliada.id;
            _marcaSelecionadaNome = reconciliada.marca;
          }
        }
      });
      _rebuildFormModal();
    } catch (e) {
      if (!mounted) return;
      ErrorUtils.showVisibleError(context, 'Erro ao carregar marcas');
    }
  }

  void _salvarVeiculo() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      Marca? marcaSelecionada;
      if (_marcaSelecionadaId != null) {
        marcaSelecionada = _marcas.firstWhere(
          (marca) => marca.id == _marcaSelecionadaId,
          orElse: () => _marcas.first,
        );
      }
      final kmString = _quilometragem.text.replaceAll(',', '.');

      final veiculo = Veiculo(
        id: _veiculoEmEdicao?.id,
        nome: _nome.text,
        placa: _placa.text.toUpperCase(),
        ano: int.tryParse(_ano.text) ?? 0,
        modelo: _modelo.text,
        marca: marcaSelecionada,
        cor: _cor.text,
        quilometragem: double.tryParse(kmString) ?? 0.0,
        categoria: _categoriaSelecionada!,
      );

      final resultado = _veiculoEmEdicao != null
          ? await VeiculoService.atualizarVeiculo(veiculo.id!, veiculo)
          : await VeiculoService.salvarVeiculo(veiculo);

      if (resultado['success']) {
        if (!mounted) return;
        _showSuccessSnackBar(resultado['message']);
        _limparFormulario();
        await _carregarVeiculos();
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        if (!mounted) return;
        ErrorUtils.showVisibleError(context, resultado['message']);
      }
    } catch (e) {
      String errorMessage = "Erro inesperado ao salvar veículo";
      if (e.toString().contains('Placa já cadastrada')) {
        errorMessage = "Placa já cadastrada";
      } else if (e.toString().contains('já cadastrada')) {
        errorMessage = "Veículo já cadastrado";
      } else if (e.toString().contains('marca') && e.toString().contains('obrigatória')) {
        errorMessage = "A marca do veículo é obrigatória";
      }
      if (!mounted) return;
      ErrorUtils.showVisibleError(context, errorMessage);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _editarVeiculo(Veiculo veiculo) {
    setState(() {
      _nome.text = veiculo.nome;
      _placa.text = veiculo.placa;
      _ano.text = veiculo.ano.toString();
      _modelo.text = veiculo.modelo;
      _marcaSelecionadaId = veiculo.marca?.id;
      _marcaSelecionadaNome = veiculo.marca?.marca;
      _cor.text = veiculo.cor;
      _quilometragem.text = veiculo.quilometragem.toString().replaceAll('.', ',');
      _categoriaSelecionada = veiculo.categoria;
      _veiculoEmEdicao = veiculo;
    });
    _showFormModal();
  }

  void _confirmarExclusao(Veiculo veiculo) {
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
          content: Text('Deseja excluir o veículo ${veiculo.nome}?'),
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
                await _excluirVeiculo(veiculo);
              },
              child: const Text('Excluir'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _excluirVeiculo(Veiculo veiculo) async {
    try {
      final resultado = await VeiculoService.excluirVeiculo(veiculo.id!);
      if (!mounted) return;

      if (resultado['success']) {
        await _carregarVeiculos();
        _showSuccessSnackBar('Veículo excluído com sucesso');
      } else {
        ErrorUtils.showVisibleError(context, resultado['message']);
      }
    } catch (e) {
      if (!mounted) return;
      String errorMessage = "Erro inesperado ao excluir veículo";
      if (e.toString().contains('Veículo não pode ser excluído')) {
        errorMessage = "Veículo em uso";
      } else if (e.toString().contains('vinculado')) {
        errorMessage = "Veículo em uso";
      }
      ErrorUtils.showVisibleError(context, errorMessage);
    }
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    _nome.clear();
    _placa.clear();
    _ano.clear();
    _modelo.clear();
    _marcaSelecionadaId = null;
    _marcaSelecionadaNome = null;
    _cor.clear();
    _quilometragem.clear();
    _categoriaSelecionada = 'Passeio';
    _veiculoEmEdicao = null;
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

  Future<Marca?> _abrirGerenciarMarcas() async {
    Marca? marcaSelecionadaNoGerenciador;
    bool carregouNoDialog = false;

    await _carregarMarcas();
    if (!mounted) return null;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setDialogState) {
            Future<void> recarregarMarcas() async {
              await _carregarMarcas();
              if (!mounted) return;

              if (_marcaSelecionadaId != null && !_marcas.any((m) => m.id == _marcaSelecionadaId)) {
                setState(() {
                  _marcaSelecionadaId = null;
                  _marcaSelecionadaNome = null;
                });
              }

              if (_marcaFiltroId != null && !_marcas.any((m) => m.id == _marcaFiltroId)) {
                setState(() {
                  _marcaFiltroId = null;
                });
              }

              setDialogState(() {});
              _rebuildFormModal();
            }

            Future<void> abrirFormulario({Marca? marca}) async {
              final nomeCtrl = TextEditingController(text: marca?.marca ?? '');
              final formKey = GlobalKey<FormState>();
              final isEdicao = marca != null;
              const corMarca = primaryColor;

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
                                    color: corMarca,
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
                                          isEdicao ? 'Editar Marca' : 'Nova Marca',
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
                                            if (value.isEmpty) return 'Informe o nome da marca';
                                            if (value.length < 2) return 'Nome muito curto';
                                            return null;
                                          },
                                          autovalidateMode: AutovalidateMode.onUserInteraction,
                                          decoration: InputDecoration(
                                            labelText: 'Nome da Marca',
                                            prefixIcon: const Icon(Icons.branding_watermark, color: corMarca),
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
                                              borderSide: const BorderSide(color: corMarca, width: 2),
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
                                              backgroundColor: corMarca,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: () async {
                                              if (!formKey.currentState!.validate()) return;

                                              Map<String, dynamic> result;
                                              if (!isEdicao) {
                                                result = await MarcaService.salvarMarca(Marca(marca: nomeCtrl.text.trim()));
                                              } else {
                                                result = await MarcaService.atualizarMarca(
                                                  marca.id!,
                                                  Marca(id: marca.id, marca: nomeCtrl.text.trim()),
                                                );
                                              }

                                              if (result['success'] == true) {
                                                if (!mounted) return;
                                                if (!sheetCtx.mounted) return;
                                                Navigator.pop(sheetCtx);
                                                _showSuccessSnackBar(
                                                    !isEdicao ? 'Marca cadastrada com sucesso' : 'Marca atualizada com sucesso');
                                                await recarregarMarcas();

                                                if (!isEdicao) {
                                                  final selecionada = _marcas
                                                      .where((m) => m.marca.trim().toLowerCase() == nomeCtrl.text.trim().toLowerCase())
                                                      .firstOrNull;
                                                  if (selecionada != null) {
                                                    marcaSelecionadaNoGerenciador = selecionada;
                                                  }
                                                } else {
                                                  final atualizada = _marcas.where((m) => m.id == marca.id).firstOrNull;
                                                  if (atualizada != null) {
                                                    marcaSelecionadaNoGerenciador = atualizada;
                                                  }
                                                }
                                              } else {
                                                if (!mounted) return;
                                                ErrorUtils.showVisibleError(context, result['message'] ?? 'Erro ao salvar marca');
                                              }
                                            },
                                            child: Text(
                                              isEdicao ? 'Atualizar Marca' : 'Cadastrar Marca',
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

            Future<void> excluirMarca(Marca marca) async {
              final confirmar = await showDialog<bool>(
                context: ctx2,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Excluir marca'),
                  content: Text('Deseja excluir a marca "${marca.marca}"?'),
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

              final result = await MarcaService.excluirMarca(marca.id!);
              if (result['success'] == true) {
                _showSuccessSnackBar('Marca removida com sucesso');
                await recarregarMarcas();
              } else {
                if (!mounted) return;
                ErrorUtils.showVisibleError(context, result['message'] ?? 'Erro ao excluir marca');
              }
            }

            final marcasOrdenadas = List<Marca>.from(_marcas)..sort((a, b) => a.marca.toLowerCase().compareTo(b.marca.toLowerCase()));

            if (!carregouNoDialog) {
              carregouNoDialog = true;
              Future.microtask(recarregarMarcas);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              title: const Row(
                children: [
                  Icon(Icons.branding_watermark_outlined, color: primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Marcas de Veiculos',
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
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => abrirFormulario(),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Nova Marca'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: marcasOrdenadas.isEmpty
                          ? const Center(child: Text('Nenhuma marca cadastrada.'))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: marcasOrdenadas.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final marca = marcasOrdenadas[i];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(marca.marca, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Editar',
                                        onPressed: () => abrirFormulario(marca: marca),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Excluir',
                                        onPressed: () => excluirMarca(marca),
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

    return marcaSelecionadaNoGerenciador;
  }

  Future<void> _showFormModal() async {
    await _carregarMarcas();
    if (!mounted) return;

    await showModalBottomSheet<void>(
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
                          _veiculoEmEdicao != null ? Icons.edit : Icons.add,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _veiculoEmEdicao != null ? 'Editar Veículo' : 'Novo Veículo',
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
    final marcasDropdown = List<Marca>.from(_marcasFiltroDisponiveis);
    if (_marcaFiltroId != null && marcasDropdown.every((m) => m.id != _marcaFiltroId)) {
      final selected = _marcas.firstWhere((m) => m.id == _marcaFiltroId, orElse: () => Marca(id: _marcaFiltroId!, marca: ''));
      marcasDropdown.insert(0, selected);
    }

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
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: _searchController,
              inputFormatters: _searchMode == 'placa' ? [_upperCaseFormatter, _maskPlaca] : [],
              keyboardType: _searchMode == 'placa' ? TextInputType.text : TextInputType.name,
              decoration: InputDecoration(
                hintText: _searchMode == 'placa' ? 'Pesquisar por placa...' : 'Pesquisar por nome...',
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
            ),
          ),
          const SizedBox(width: 12),
          ToggleButtons(
            isSelected: [_searchMode == 'placa', _searchMode == 'nome'],
            onPressed: (index) {
              final mode = index == 0 ? 'placa' : 'nome';
              if (_searchMode == mode) return;
              setState(() {
                _searchMode = mode;
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
                child: Text('Placa'),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text('Nome'),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<int?>(
              initialValue: _marcaFiltroId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Filtrar por marca',
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
                  child: Text('Todas as marcas'),
                ),
                ...marcasDropdown.map(
                  (marca) => DropdownMenuItem<int?>(
                    value: marca.id,
                    child: Text(marca.marca),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _marcaFiltroId = value;
                  _currentPage = 0;
                });
                _onSearchChanged(force: true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleGrid({bool isMobile = false}) {
    if (_isLoadingVeiculos) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_veiculosFiltrados.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                _searchController.text.isEmpty ? Icons.directions_car_outlined : Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isEmpty ? 'Nenhum veículo cadastrado' : 'Nenhum resultado encontrado',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_searchController.text.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Comece adicionando seu primeiro veículo',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (isMobile) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _veiculosFiltrados.length,
        itemBuilder: (context, index) => _buildMobileVehicleCard(_veiculosFiltrados[index]),
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

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisExtent: 240,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _veiculosFiltrados.length,
          itemBuilder: (context, index) => _buildVehicleCard(_veiculosFiltrados[index]),
        );
      },
    );
  }

  Widget _buildVehicleCard(Veiculo veiculo) {
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
          onTap: () => _editarVeiculo(veiculo),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
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
                        veiculo.categoria == 'Passeio' ? Icons.directions_car : Icons.local_shipping,
                        color: primaryColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            veiculo.nome,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              veiculo.categoria,
                              style: TextStyle(
                                color: primaryColor,
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
                          _editarVeiculo(veiculo);
                        } else if (value == 'delete') {
                          _confirmarExclusao(veiculo);
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
                const SizedBox(height: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.pin_drop, veiculo.placa),
                      _buildInfoRow(Icons.build, '${veiculo.modelo} - ${veiculo.ano}'),
                      _buildInfoRow(Icons.business, veiculo.marca?.marca ?? "Não informada"),
                      _buildInfoRow(Icons.palette, veiculo.cor),
                      _buildInfoRow(Icons.speed, '${veiculo.quilometragem.toStringAsFixed(0)} km'),
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
                      if (veiculo.createdAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(
                                'Cadastrado: ${DateFormat('dd/MM/yyyy').format(veiculo.createdAt!)}',
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

  Widget _buildMobileVehicleCard(Veiculo veiculo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
          onTap: () => _editarVeiculo(veiculo),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                        veiculo.categoria == 'Passeio' ? Icons.directions_car : Icons.local_shipping,
                        color: primaryColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            veiculo.nome,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              veiculo.categoria,
                              style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editarVeiculo(veiculo);
                        } else if (value == 'delete') {
                          _confirmarExclusao(veiculo);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Editar')]),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Excluir', style: TextStyle(color: Colors.red))
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.pin_drop, veiculo.placa),
                _buildInfoRow(Icons.build, '${veiculo.modelo} - ${veiculo.ano}'),
                _buildInfoRow(Icons.business, veiculo.marca?.marca ?? 'Não informada'),
                _buildInfoRow(Icons.palette, veiculo.cor),
                _buildInfoRow(Icons.speed, '${veiculo.quilometragem.toStringAsFixed(0)} km'),
                if (veiculo.createdAt != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'Cadastrado: ${DateFormat('dd/MM/yyyy').format(veiculo.createdAt!)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 10, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
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

  Widget _buildFormulario() {
    final marcasOrdenadas = List<Marca>.from(_marcas)..sort((a, b) => a.marca.toLowerCase().compareTo(b.marca.toLowerCase()));
    final marcaSelecionadaAtual = marcasOrdenadas.any((m) => m.id == _marcaSelecionadaId) ? _marcaSelecionadaId : null;

    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildTextField(
            controller: _nome,
            label: 'Nome do Veículo',
            icon: Icons.directions_car,
            validator: (v) => v!.isEmpty ? 'Informe o nome' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _placa,
            label: 'Placa',
            icon: Icons.pin_drop,
            inputFormatters: [_maskPlaca, _upperCaseFormatter],
            textCapitalization: TextCapitalization.characters,
            validator: (v) => v!.isEmpty ? 'Informe a placa' : null,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              if (isNarrow) {
                return Column(
                  children: [
                    _buildTextField(
                      controller: _ano,
                      label: 'Ano',
                      icon: Icons.calendar_today,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_numbersOnlyFormatter, _maxLength4Formatter],
                      validator: (v) => v!.isEmpty ? 'Informe o ano' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _modelo,
                      label: 'Modelo',
                      icon: Icons.build,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_numbersOnlyFormatter, _maxLength4Formatter],
                      validator: (v) => v!.isEmpty ? 'Informe o modelo' : null,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _ano,
                      label: 'Ano',
                      icon: Icons.calendar_today,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_numbersOnlyFormatter, _maxLength4Formatter],
                      validator: (v) => v!.isEmpty ? 'Informe o ano' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _modelo,
                      label: 'Modelo',
                      icon: Icons.build,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_numbersOnlyFormatter, _maxLength4Formatter],
                      validator: (v) => v!.isEmpty ? 'Informe o modelo' : null,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  key: ValueKey('marca-${_marcaSelecionadaId ?? 'none'}-${marcasOrdenadas.length}'),
                  initialValue: marcaSelecionadaAtual,
                  isExpanded: true,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: 'Marca',
                    prefixIcon: Icon(Icons.business, color: primaryColor),
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
                  items: marcasOrdenadas
                      .map(
                        (marca) => DropdownMenuItem<int?>(
                          value: marca.id,
                          child: Text(marca.marca),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    final selecionada = marcasOrdenadas.where((m) => m.id == value).cast<Marca?>().firstOrNull;
                    setState(() {
                      _marcaSelecionadaId = value;
                      _marcaSelecionadaNome = selecionada?.marca;
                    });
                  },
                  validator: (value) => value == null ? 'Selecione uma marca' : null,
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 56,
                child: Tooltip(
                  message: 'Gerenciar marcas',
                  child: ElevatedButton(
                    onPressed: () async {
                      final selecionada = await _abrirGerenciarMarcas();
                      if (!mounted) return;

                      setState(() {
                        if (selecionada?.id != null) {
                          _marcaSelecionadaId = selecionada!.id;
                          _marcaSelecionadaNome = selecionada.marca;
                        } else if (_marcaSelecionadaId != null && !_marcas.any((m) => m.id == _marcaSelecionadaId)) {
                          _marcaSelecionadaId = null;
                          _marcaSelecionadaNome = null;
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
          _buildDropdownField(
            value: _categoriaSelecionada,
            label: 'Categoria',
            icon: Icons.category,
            items: (() {
              final lista = List<String>.from(_categorias);
              lista.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              return lista
                  .map<DropdownMenuItem<String>>((categoria) => DropdownMenuItem<String>(
                        value: categoria,
                        child: Text(categoria),
                      ))
                  .toList();
            })(),
            onChanged: (value) => setState(() => _categoriaSelecionada = value),
            validator: (value) => value == null ? 'Selecione uma categoria' : null,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              if (isNarrow) {
                return Column(
                  children: [
                    _buildTextField(
                      controller: _cor,
                      label: 'Cor',
                      icon: Icons.palette,
                      inputFormatters: [_lettersOnlyFormatter],
                      validator: (v) => v!.isEmpty ? 'Informe a cor' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _quilometragem,
                      label: 'Quilometragem',
                      icon: Icons.speed,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [_numbersOnlyFormatter],
                      validator: (v) => v!.isEmpty ? 'Informe a quilometragem' : null,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _cor,
                      label: 'Cor',
                      icon: Icons.palette,
                      inputFormatters: [_lettersOnlyFormatter],
                      validator: (v) => v!.isEmpty ? 'Informe a cor' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _quilometragem,
                      label: 'Quilometragem',
                      icon: Icons.speed,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [_numbersOnlyFormatter],
                      validator: (v) => v!.isEmpty ? 'Informe a quilometragem' : null,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _salvarVeiculo,
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
                      _veiculoEmEdicao != null ? 'Atualizar Veículo' : 'Cadastrar Veículo',
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
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
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

  Widget _buildDropdownField<T>({
    Key? fieldKey,
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    VoidCallback? onTap,
    String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      key: fieldKey,
      initialValue: value,
      onChanged: onChanged,
      onTap: onTap,
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

  Widget _buildMobileLayout() {
    final marcasDropdown = List<Marca>.from(_marcasFiltroDisponiveis);
    if (_marcaFiltroId != null && marcasDropdown.every((m) => m.id != _marcaFiltroId)) {
      final selected = _marcas.firstWhere((m) => m.id == _marcaFiltroId, orElse: () => Marca(id: _marcaFiltroId!, marca: ''));
      marcasDropdown.insert(0, selected);
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        inputFormatters: _searchMode == 'placa' ? [_upperCaseFormatter, _maskPlaca] : [],
                        decoration: InputDecoration(
                          hintText: _searchMode == 'placa' ? 'Pesquisar por placa...' : 'Pesquisar por nome...',
                          prefixIcon: Icon(Icons.search, color: primaryColor),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged(force: true);
                                  })
                              : null,
                          border:
                              OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                          enabledBorder:
                              OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
                          filled: true,
                          fillColor: Colors.grey[50],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ToggleButtons(
                      isSelected: [_searchMode == 'placa', _searchMode == 'nome'],
                      onPressed: (index) {
                        final mode = index == 0 ? 'placa' : 'nome';
                        if (_searchMode == mode) return;
                        setState(() {
                          _searchMode = mode;
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
                      constraints: const BoxConstraints(minHeight: 48, minWidth: 56),
                      children: const [
                        Text('Placa', style: TextStyle(fontSize: 13)),
                        Text('Nome', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _marcaFiltroId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Filtrar por marca',
                    prefixIcon: Icon(Icons.filter_list, color: primaryColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                    enabledBorder:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                    focusedBorder:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Todas as marcas')),
                    ...marcasDropdown
                        .map((m) => DropdownMenuItem<int?>(value: m.id, child: Text(m.marca, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _marcaFiltroId = value;
                      _currentPage = 0;
                    });
                    _onSearchChanged(force: true);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_searchController.text.isEmpty && !_isLoadingVeiculos && _veiculosFiltrados.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('Últimos Veículos Cadastrados',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                    ),
                  if (_searchController.text.isNotEmpty && !_isLoadingVeiculos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('Resultados ($_totalElements)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                    ),
                  if (_searchController.text.isNotEmpty && _totalElements > _pageSize)
                    ...([
                      _buildPaginationControls(compact: true),
                      const SizedBox(height: 10),
                    ]),
                  _buildVehicleGrid(isMobile: true),
                  if (_searchController.text.isNotEmpty && _totalElements > _pageSize)
                    ...([
                      const SizedBox(height: 16),
                      _buildPaginationControls(),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Gestão de Veículos',
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
      floatingActionButton: isMobile
          ? FloatingActionButton(
              onPressed: () {
                _limparFormulario();
                _showFormModal();
              },
              backgroundColor: primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: isMobile
          ? _buildMobileLayout()
          : FadeTransition(
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
                    if (_searchController.text.isEmpty && !_isLoadingVeiculos && _veiculosFiltrados.isNotEmpty)
                      Text(
                        'Últimos Veículos Cadastrados',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    if (_searchController.text.isNotEmpty && !_isLoadingVeiculos)
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
                    _buildVehicleGrid(),
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
}
