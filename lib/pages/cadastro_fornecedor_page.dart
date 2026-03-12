import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../utils/adaptive_phone_formatter.dart';
import 'package:cpf_cnpj_validator/cnpj_validator.dart';
import '../services/cep_service.dart';
import '../services/cnpj_service.dart';
import '../model/fornecedor.dart';
import '../services/fornecedor_service.dart';
import '../utils/error_utils.dart';
import '../widgets/pagination_controls.dart';

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
  final _cepController = TextEditingController();
  final _complementoController = TextEditingController();
  final _codigoMunicipioController = TextEditingController();
  final _searchController = TextEditingController();
  String _ufSelecionada = 'GO';
  final ValueNotifier<String> _ufNotifier = ValueNotifier('GO');

  final _maskCnpj = MaskTextInputFormatter(
    mask: '##.###.###/####-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  final _maskCep = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  final AdaptivePhoneFormatter _maskTelefone = AdaptivePhoneFormatter();

  final _decimalFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
    final filteredText = newValue.text.replaceAll(RegExp(r'[^0-9,]'), '');
    final parts = filteredText.split(',');
    String formattedText = parts[0];
    if (parts.length > 1) {
      formattedText += ',${parts[1]}';
    }

    if (parts.length > 1 && parts[1].length > 2) {
      formattedText = '${parts[0]},${parts[1].substring(0, 2)}';
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

  final ValueNotifier<bool> _isLoadingCep = ValueNotifier(false);
  final ValueNotifier<bool> _cepAutoPreenchido = ValueNotifier(false);
  String _lastSearchedCep = '';

  final ValueNotifier<bool> _isLoadingCnpj = ValueNotifier(false);
  final ValueNotifier<bool> _cnpjAutoPreenchido = ValueNotifier(false);
  String _lastSearchedCnpj = '';

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
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color shadowColor = Color(0x1A000000);

  final List<String> _ufs = [
    'AC',
    'AL',
    'AP',
    'AM',
    'BA',
    'CE',
    'DF',
    'ES',
    'GO',
    'MA',
    'MT',
    'MS',
    'MG',
    'PA',
    'PB',
    'PR',
    'PE',
    'PI',
    'RJ',
    'RN',
    'RS',
    'RO',
    'RR',
    'SC',
    'SP',
    'SE',
    'TO'
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _limparFormulario();
    _carregarFornecedores();
    _searchController.addListener(_onSearchChanged);
    _cepController.addListener(_onCepChanged);
    _cnpjController.addListener(_onCnpjChanged);
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
    _cnpjController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _margemLucroController.dispose();
    _ruaController.dispose();
    _numeroCasaController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _cepController.removeListener(_onCepChanged);
    _cepController.dispose();
    _cnpjController.removeListener(_onCnpjChanged);
    _complementoController.dispose();
    _codigoMunicipioController.dispose();
    _isLoadingCep.dispose();
    _cepAutoPreenchido.dispose();
    _isLoadingCnpj.dispose();
    _cnpjAutoPreenchido.dispose();
    _ufNotifier.dispose();
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
      _filtrarFornecedores();
    });
  }

  void _onCnpjChanged() {
    final digits = _cnpjController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _lastSearchedCnpj = '';
      return;
    }
    if (digits.length == 14 && digits != _lastSearchedCnpj) _buscarCnpj(digits);
  }

  Future<void> _buscarCnpj(String digits) async {
    if (!mounted) return;
    _lastSearchedCnpj = digits;
    _isLoadingCnpj.value = true;
    try {
      final result = await CnpjService.buscar(digits);
      if (!mounted) return;
      setState(() {
        final nome = result.nomeFantasia.isNotEmpty ? result.nomeFantasia : result.razaoSocial;
        if (nome.isNotEmpty) _nomeController.text = nome;
        if (result.telefone.isNotEmpty) _telefoneController.text = _maskTelefone.maskText(result.telefone);
        if (result.email.isNotEmpty) _emailController.text = result.email;
        if (result.cep.isNotEmpty) {
          _cepController.text = '${result.cep.substring(0, 5)}-${result.cep.substring(5)}';
          _lastSearchedCep = result.cep;
        }
        if (result.logradouro.isNotEmpty) _ruaController.text = result.logradouro;
        if (result.numero.isNotEmpty) _numeroCasaController.text = result.numero;
        if (result.complemento.isNotEmpty) _complementoController.text = result.complemento;
        if (result.bairro.isNotEmpty) _bairroController.text = result.bairro;
        if (result.cidade.isNotEmpty) _cidadeController.text = result.cidade;
        if (result.codigoMunicipio.isNotEmpty) _codigoMunicipioController.text = result.codigoMunicipio;
        if (_ufs.contains(result.uf)) {
          _ufSelecionada = result.uf;
          _ufNotifier.value = result.uf;
        }
      });
      _cnpjAutoPreenchido.value = true;
      _cepAutoPreenchido.value = result.cep.isNotEmpty;
    } catch (e) {
      if (mounted) {
        ErrorUtils.showVisibleError(
          context,
          e.toString().contains('não encontrado')
              ? 'CNPJ não encontrado na Receita Federal.'
              : 'Não foi possível consultar o CNPJ. Preencha manualmente.',
        );
      }
    } finally {
      if (mounted) _isLoadingCnpj.value = false;
    }
  }

  void _limparDadosCnpjAutomatico() {
    setState(() {
      _cnpjController.clear();
      _nomeController.clear();
      _telefoneController.clear();
      _emailController.clear();
      _cepController.clear();
      _ruaController.clear();
      _numeroCasaController.clear();
      _complementoController.clear();
      _bairroController.clear();
      _cidadeController.clear();
      _codigoMunicipioController.clear();
      _ufSelecionada = 'GO';
      _ufNotifier.value = 'GO';
    });
    _cnpjAutoPreenchido.value = false;
    _cepAutoPreenchido.value = false;
    _lastSearchedCnpj = '';
    _lastSearchedCep = '';
  }

  void _onCepChanged() {
    final digits = _cepController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _lastSearchedCep = '';
      return;
    }
    if (digits.length == 8 && digits != _lastSearchedCep) _buscarCep(digits);
  }

  Future<void> _buscarCep(String digits) async {
    if (!mounted) return;
    _lastSearchedCep = digits;
    _isLoadingCep.value = true;
    try {
      final result = await CepService.buscar(digits);
      if (!mounted) return;
      setState(() {
        _ruaController.text = result.logradouro;
        _complementoController.text = result.complemento;
        _bairroController.text = result.bairro;
        _cidadeController.text = result.cidade;
        if (_ufs.contains(result.uf.toUpperCase())) {
          _ufSelecionada = result.uf.toUpperCase();
          _ufNotifier.value = _ufSelecionada;
        }
        if (result.codigoIBGE.isNotEmpty) {
          _codigoMunicipioController.text = result.codigoIBGE;
        }
      });
      _cepAutoPreenchido.value = true;
    } catch (e) {
      if (mounted) {
        ErrorUtils.showVisibleError(
          context,
          e.toString().contains('não encontrado')
              ? 'CEP não encontrado. Preencha o endereço manualmente.'
              : 'Não foi possível consultar o CEP. Preencha manualmente.',
        );
      }
    } finally {
      _isLoadingCep.value = false;
    }
  }

  void _limparEnderecoAutomatico() {
    setState(() {
      _cepController.clear();
      _ruaController.clear();
      _complementoController.clear();
      _bairroController.clear();
      _cidadeController.clear();
      _codigoMunicipioController.clear();
      _ufSelecionada = 'GO';
      _ufNotifier.value = 'GO';
    });
    _cepAutoPreenchido.value = false;
    _lastSearchedCep = '';
  }

  String _formatarCEP(String? cep) {
    if (cep == null || cep.isEmpty) return '';
    final digits = cep.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 8) return '${digits.substring(0, 5)}-${digits.substring(5)}';
    return cep;
  }

  Future<void> _filtrarFornecedores() async {
    final query = _searchController.text.trim();
    final cnpjSemMascara = query.replaceAll(RegExp(r'[^0-9]'), '');
    final queryParaBusca = cnpjSemMascara.isNotEmpty ? cnpjSemMascara : query;

    setState(() => _isLoadingFornecedores = true);

    try {
      final resultado = await FornecedorService.buscarPaginado(queryParaBusca, _currentPage, size: _pageSize);

      if (resultado['success']) {
        setState(() {
          _fornecedoresFiltrados = resultado['content'] as List<Fornecedor>;
          _totalPages = resultado['totalPages'] as int;
          _totalElements = resultado['totalElements'] as int;
        });
      } else {
        if (!mounted) return;
        ErrorUtils.showVisibleError(context, 'Erro ao buscar fornecedores');
      }
    } catch (e) {
      if (!mounted) return;
      ErrorUtils.showVisibleError(context, 'Erro ao buscar fornecedores');
    } finally {
      setState(() => _isLoadingFornecedores = false);
    }
  }

  void _irParaPagina(int page) {
    if (page < 0 || page >= _totalPages) return;
    setState(() => _currentPage = page);
    _filtrarFornecedores();
  }

  void _alterarPageSize(int size) {
    setState(() {
      _pageSize = size;
      _currentPage = 0;
    });
    _filtrarFornecedores();
  }

  Future<void> _carregarFornecedores() async {
    setState(() => _isLoadingFornecedores = true);
    try {
      final resultado = await FornecedorService.buscarPaginado('', 0, size: _pageSize);

      if (resultado['success']) {
        setState(() {
          _fornecedores = resultado['content'] as List<Fornecedor>;
          _fornecedoresFiltrados = _fornecedores;
          _totalPages = resultado['totalPages'] as int;
          _totalElements = resultado['totalElements'] as int;
          _currentPage = 0;
        });
      } else {
        if (!mounted) return;
        ErrorUtils.showVisibleError(context, 'Erro ao carregar fornecedores');
      }
    } catch (e) {
      if (!mounted) return;
      ErrorUtils.showVisibleError(context, 'Erro ao carregar fornecedores');
    } finally {
      setState(() => _isLoadingFornecedores = false);
    }
  }

  void _salvarFornecedor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final cnpjLimpo = _cnpjController.text.replaceAll(RegExp(r'[^\d]'), '');

      if (_fornecedorEmEdicao == null || _fornecedorEmEdicao!.cnpj.replaceAll(RegExp(r'[^\d]'), '') != cnpjLimpo) {
        final todosFornecedores = await FornecedorService.listarFornecedores();

        final fornecedorExistente = todosFornecedores.firstWhere(
          (f) {
            final cnpjFornecedor = f.cnpj.replaceAll(RegExp(r'[^\d]'), '');
            return cnpjFornecedor == cnpjLimpo && f.id != _fornecedorEmEdicao?.id;
          },
          orElse: () => Fornecedor(
            nome: '',
            cnpj: '',
            telefone: '',
            email: '',
            margemLucro: 0,
          ),
        );

        if (fornecedorExistente.cnpj.isNotEmpty) {
          if (!mounted) return;
          ErrorUtils.showVisibleError(context, 'Este CNPJ já está cadastrado para outro fornecedor');
          setState(() => _isLoading = false);
          return;
        }
      }

      final margemText = _margemLucroController.text.replaceAll(',', '.');
      final margemValue = double.tryParse(margemText) ?? 0;

      final fornecedor = Fornecedor(
        id: _fornecedorEmEdicao?.id,
        nome: _nomeController.text,
        cnpj: cnpjLimpo,
        telefone: _telefoneController.text.replaceAll(RegExp(r'[^\d]'), ''),
        email: _emailController.text,
        margemLucro: margemValue / 100,
        rua: _ruaController.text,
        numeroCasa: _numeroCasaController.text,
        bairro: _bairroController.text,
        cidade: _cidadeController.text,
        cep:
            _cepController.text.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty ? _cepController.text.replaceAll(RegExp(r'[^0-9]'), '') : null,
        uf: _ufSelecionada,
        complemento: _complementoController.text.isNotEmpty ? _complementoController.text : null,
        codigoMunicipio: _codigoMunicipioController.text.isNotEmpty ? _codigoMunicipioController.text : null,
      );

      final resultado = _fornecedorEmEdicao != null
          ? await FornecedorService.atualizarFornecedor(_fornecedorEmEdicao!.id!, fornecedor)
          : await FornecedorService.salvarFornecedor(fornecedor);

      if (resultado['success']) {
        if (!mounted) return;
        _showSuccessSnackBar(resultado['message']);
        _limparFormulario();
        await _carregarFornecedores();
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        if (!mounted) return;
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
      if (!mounted) return;
      ErrorUtils.showVisibleError(context, errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _editarFornecedor(Fornecedor fornecedor) {
    setState(() {
      _lastSearchedCnpj = fornecedor.cnpj.replaceAll(RegExp(r'[^0-9]'), '');
      _nomeController.text = fornecedor.nome;
      _emailController.text = fornecedor.email;

      final margemPercentual = (fornecedor.margemLucro ?? 0) * 100;
      _margemLucroController.text = margemPercentual.toStringAsFixed(2).replaceAll('.', ',');

      _ruaController.text = fornecedor.rua ?? '';
      _numeroCasaController.text = fornecedor.numeroCasa ?? '';
      _bairroController.text = fornecedor.bairro ?? '';
      _cidadeController.text = fornecedor.cidade ?? '';
      _lastSearchedCep = fornecedor.cep?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      _cepController.text = _formatarCEP(fornecedor.cep);
      _complementoController.text = fornecedor.complemento ?? '';
      _codigoMunicipioController.text = fornecedor.codigoMunicipio ?? '';
      _ufSelecionada = fornecedor.uf ?? 'GO';
      _ufNotifier.value = _ufSelecionada;

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
      if (!mounted) return;

      if (resultado['success']) {
        await _carregarFornecedores();
        _showSuccessSnackBar('Fornecedor excluído com sucesso');
      } else {
        ErrorUtils.showVisibleError(context, resultado['message']);
      }
    } catch (e) {
      if (!mounted) return;
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
    _cepController.clear();
    _complementoController.clear();
    _codigoMunicipioController.clear();
    _cepAutoPreenchido.value = false;
    _lastSearchedCep = '';
    _cnpjAutoPreenchido.value = false;
    _lastSearchedCnpj = '';
    _ufSelecionada = 'GO';
    _ufNotifier.value = 'GO';
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
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 16 : 24),
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

  Widget _buildSupplierGrid({bool isMobile = false}) {
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

    if (isMobile) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _fornecedoresFiltrados.length,
        itemBuilder: (context, index) => _buildMobileFornecedorCard(_fornecedoresFiltrados[index]),
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

        if (crossAxisCount == 1) {
          return Column(
            children: _fornecedoresFiltrados
                .map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildSupplierCard(f),
                    ))
                .toList(),
          );
        }

        final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 12) / crossAxisCount;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _fornecedoresFiltrados.map((f) => SizedBox(width: itemWidth, child: _buildSupplierCard(f))).toList(),
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
            padding: const EdgeInsets.all(10),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.store,
                        color: primaryColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fornecedor.nome,
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
                              color: margemColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Margem: ${margem.toStringAsFixed(2).replaceAll('.', ',')}%',
                              style: TextStyle(
                                color: margemColor,
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
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInfoRow(Icons.badge, _maskCnpj.maskText(fornecedor.cnpj)),
                    _buildInfoRow(Icons.phone, _maskTelefone.maskText(fornecedor.telefone)),
                    _buildInfoRow(Icons.email, fornecedor.email),
                    if (fornecedor.cep != null && fornecedor.cep!.isNotEmpty) _buildInfoRow(Icons.pin_drop, _formatarCEP(fornecedor.cep!)),
                    if (fornecedor.rua != null && fornecedor.rua!.isNotEmpty)
                      _buildInfoRow(
                        Icons.location_on,
                        '${fornecedor.rua}${fornecedor.numeroCasa != null && fornecedor.numeroCasa!.isNotEmpty ? ', ${fornecedor.numeroCasa}' : ''}',
                      ),
                    if (fornecedor.bairro != null && fornecedor.bairro!.isNotEmpty) _buildInfoRow(Icons.map, fornecedor.bairro!),
                    if (fornecedor.cidade != null && fornecedor.cidade!.isNotEmpty)
                      _buildInfoRow(
                        Icons.location_city,
                        '${fornecedor.cidade}${fornecedor.uf != null && fornecedor.uf!.isNotEmpty ? ' - ${fornecedor.uf}' : ''}',
                      ),
                  ],
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

  Widget _buildMobileFornecedorCard(Fornecedor fornecedor) {
    final margem = (fornecedor.margemLucro ?? 0) * 100;
    Color margemColor = successColor;
    if (margem < 10) {
      margemColor = errorColor;
    } else if (margem < 15) {
      margemColor = warningColor;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _editarFornecedor(fornecedor),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.store, color: primaryColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fornecedor.nome,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: margemColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Margem: ${margem.toStringAsFixed(2).replaceAll('.', ',')}%',
                              style: TextStyle(color: margemColor, fontSize: 11, fontWeight: FontWeight.w600),
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
                _buildInfoRow(Icons.badge, _maskCnpj.maskText(fornecedor.cnpj)),
                _buildInfoRow(Icons.phone, _maskTelefone.maskText(fornecedor.telefone)),
                _buildInfoRow(Icons.email, fornecedor.email),
                if (fornecedor.cidade != null && fornecedor.cidade!.isNotEmpty)
                  _buildInfoRow(
                    Icons.location_city,
                    '${fornecedor.cidade}${fornecedor.uf != null && fornecedor.uf!.isNotEmpty ? ' - ${fornecedor.uf}' : ''}',
                  ),
                if (fornecedor.createdAt != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'Cadastrado: ${DateFormat('dd/MM/yyyy').format(fornecedor.createdAt!)}',
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
    return Form(
      key: _formKey,
      child: Column(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: _isLoadingCnpj,
            builder: (context, isLoading, _) => ValueListenableBuilder<bool>(
              valueListenable: _cnpjAutoPreenchido,
              builder: (context, autoPreenchido, _) => TextFormField(
                controller: _cnpjController,
                keyboardType: TextInputType.number,
                inputFormatters: [_maskCnpj],
                readOnly: _fornecedorEmEdicao != null,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  labelText: 'CNPJ',
                  prefixIcon: Icon(Icons.badge, color: primaryColor),
                  suffixIcon: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                          ),
                        )
                      : autoPreenchido
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              tooltip: 'Limpar dados preenchidos automaticamente',
                              onPressed: _limparDadosCnpjAutomatico,
                            )
                          : IconButton(
                              icon: const Icon(Icons.search, color: primaryColor, size: 20),
                              tooltip: 'Buscar CNPJ',
                              onPressed: () {
                                _lastSearchedCnpj = '';
                                _onCnpjChanged();
                              },
                            ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                  focusedBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: errorColor)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Informe o CNPJ';
                  if (!CNPJValidator.isValid(v)) return 'CNPJ inválido';
                  return null;
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _nomeController,
            label: 'Nome do Fornecedor',
            icon: Icons.store,
            validator: (v) => v!.isEmpty ? 'Informe o nome' : null,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              final telefoneField = _buildTextField(
                controller: _telefoneController,
                label: 'Telefone',
                icon: Icons.phone,
                keyboardType: TextInputType.number,
                inputFormatters: [_maskTelefone],
                validator: (v) => v!.isEmpty ? 'Informe o telefone' : null,
              );
              final margemField = _buildTextField(
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
              );
              if (isNarrow) {
                return Column(
                  children: [
                    telefoneField,
                    const SizedBox(height: 16),
                    margemField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: telefoneField),
                  const SizedBox(width: 16),
                  Expanded(child: margemField),
                ],
              );
            },
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
          ValueListenableBuilder<bool>(
            valueListenable: _isLoadingCep,
            builder: (context, isLoading, _) => ValueListenableBuilder<bool>(
              valueListenable: _cepAutoPreenchido,
              builder: (context, autoPreenchido, _) => TextFormField(
                controller: _cepController,
                keyboardType: TextInputType.number,
                inputFormatters: [_maskCep],
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  labelText: 'CEP',
                  prefixIcon: Icon(Icons.location_on, color: primaryColor),
                  suffixIcon: isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                          ),
                        )
                      : autoPreenchido
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              tooltip: 'Limpar endere\u00e7o preenchido automaticamente',
                              onPressed: _limparEnderecoAutomatico,
                            )
                          : IconButton(
                              icon: const Icon(Icons.search, color: primaryColor, size: 20),
                              tooltip: 'Buscar CEP',
                              onPressed: () {
                                _lastSearchedCep = '';
                                _onCepChanged();
                              },
                            ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                  enabledBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                  focusedBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: errorColor)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    final cep = value.replaceAll(RegExp(r'[^0-9]'), '');
                    if (cep.length != 8) return 'CEP inv\u00e1lido';
                  }
                  return null;
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _complementoController,
            label: 'Complemento',
            icon: Icons.add_location_alt,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _ruaController,
            label: 'Rua',
            icon: Icons.location_on,
            validator: (v) => v!.isEmpty ? 'Informe a rua' : null,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              final bairroField = _buildTextField(
                controller: _bairroController,
                label: 'Bairro',
                icon: Icons.location_city,
                validator: (v) => v!.isEmpty ? 'Informe o bairro' : null,
              );
              final numeroField = _buildTextField(
                controller: _numeroCasaController,
                label: 'Número',
                icon: Icons.home,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => v!.isEmpty ? 'Informe o número' : null,
              );
              if (isNarrow) {
                return Column(
                  children: [
                    bairroField,
                    const SizedBox(height: 16),
                    numeroField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 2, child: bairroField),
                  const SizedBox(width: 16),
                  Expanded(flex: 1, child: numeroField),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              final cidadeField = _buildTextField(
                controller: _cidadeController,
                label: 'Cidade',
                icon: Icons.location_city,
                validator: (v) => v!.isEmpty ? 'Informe a cidade' : null,
              );
              final ufField = ValueListenableBuilder<String>(
                valueListenable: _ufNotifier,
                builder: (context, ufAtual, _) => DropdownButtonFormField<String>(
                  initialValue: ufAtual,
                  decoration: InputDecoration(
                    labelText: 'UF',
                    prefixIcon: Icon(Icons.map, color: primaryColor),
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
                  items: _ufs
                      .map((uf) => DropdownMenuItem(
                            value: uf,
                            child: Text(uf),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _ufSelecionada = value!;
                    _ufNotifier.value = value;
                  }),
                ),
              );
              if (isNarrow) {
                return Column(
                  children: [
                    cidadeField,
                    const SizedBox(height: 16),
                    ufField,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(flex: 2, child: cidadeField),
                  const SizedBox(width: 16),
                  Expanded(flex: 1, child: ufField),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _codigoMunicipioController,
            label: 'Código IBGE do Município',
            icon: Icons.code,
            keyboardType: TextInputType.number,
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

  Widget _buildMobileLayout() {
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
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Pesquisar por nome ou CNPJ...',
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
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_searchController.text.isEmpty && !_isLoadingFornecedores && _fornecedoresFiltrados.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('Últimos Fornecedores Cadastrados',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                    ),
                  if (_searchController.text.isNotEmpty && !_isLoadingFornecedores)
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
                  _buildSupplierGrid(isMobile: true),
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
                    _buildSupplierGrid(),
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
