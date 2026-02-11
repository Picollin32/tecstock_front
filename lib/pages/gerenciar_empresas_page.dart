import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:cpf_cnpj_validator/cnpj_validator.dart';
import '../utils/adaptive_phone_formatter.dart';
import 'package:tecstock/model/empresa.dart';
import 'package:tecstock/model/usuario.dart';
import '../services/empresa_service.dart';
import '../services/usuario_service.dart';
import '../services/auth_service.dart';
import '../utils/error_utils.dart';

class GerenciarEmpresasPage extends StatefulWidget {
  const GerenciarEmpresasPage({super.key});

  @override
  State<GerenciarEmpresasPage> createState() => _GerenciarEmpresasPageState();
}

class _GerenciarEmpresasPageState extends State<GerenciarEmpresasPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _cnpjController = TextEditingController();
  final TextEditingController _razaoSocialController = TextEditingController();
  final TextEditingController _nomeFantasiaController = TextEditingController();
  final TextEditingController _inscricaoEstadualController = TextEditingController();
  final TextEditingController _inscricaoMunicipalController = TextEditingController();
  final TextEditingController _telefoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _siteController = TextEditingController();
  final TextEditingController _cepController = TextEditingController();
  final TextEditingController _logradouroController = TextEditingController();
  final TextEditingController _numeroController = TextEditingController();
  final TextEditingController _complementoController = TextEditingController();
  final TextEditingController _bairroController = TextEditingController();
  final TextEditingController _cidadeController = TextEditingController();
  final TextEditingController _codigoMunicipioController = TextEditingController();
  final TextEditingController _cnaeController = TextEditingController();

  final TextEditingController _searchController = TextEditingController();

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
  final _maskInscricaoEstadual = MaskTextInputFormatter(
    mask: '###.###.###',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
  final AdaptivePhoneFormatter _maskTelefone = AdaptivePhoneFormatter();

  List<Empresa> _empresasCompleta = [];
  List<Empresa> _empresas = [];
  List<Empresa> _empresasFiltradas = [];
  Empresa? _empresaEmEdicao;
  String _ufSelecionada = 'GO';
  String _regimeTributarioSelecionado = '1';

  bool _isLoading = false;
  bool _isLoadingEmpresas = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  static const Color primaryColor = Color(0xFF0EA5E9);
  static const Color errorColor = Color(0xFFDC2626);
  static const Color successColor = Color(0xFF16A34A);

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

  final List<Map<String, String>> _regimesTributarios = [
    {'value': '1', 'label': 'Simples Nacional'},
    {'value': '2', 'label': 'Simples Nacional - Excesso'},
    {'value': '3', 'label': 'Regime Normal'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _carregarDados();
    _searchController.addListener(_filtrarEmpresas);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.removeListener(_filtrarEmpresas);
    _searchController.dispose();
    _cnpjController.dispose();
    _razaoSocialController.dispose();
    _nomeFantasiaController.dispose();
    _inscricaoEstadualController.dispose();
    _inscricaoMunicipalController.dispose();
    _telefoneController.dispose();
    _emailController.dispose();
    _siteController.dispose();
    _cepController.dispose();
    _logradouroController.dispose();
    _numeroController.dispose();
    _complementoController.dispose();
    _bairroController.dispose();
    _cidadeController.dispose();
    _codigoMunicipioController.dispose();
    _cnaeController.dispose();
    super.dispose();
  }

  void _filtrarEmpresas() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _empresasFiltradas = _empresas;
      } else {
        _empresasFiltradas = _empresasCompleta.where((empresa) {
          final cnpjMatch = empresa.cnpj.contains(query);
          final razaoSocialMatch = empresa.razaoSocial.toLowerCase().contains(query);
          final nomeFantasiaMatch = empresa.nomeFantasia.toLowerCase().contains(query);
          return cnpjMatch || razaoSocialMatch || nomeFantasiaMatch;
        }).toList();
      }
    });
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoadingEmpresas = true);
    try {
      final lista = await EmpresaService.listarEmpresas();
      lista.sort((a, b) {
        final aId = a.id ?? 0;
        final bId = b.id ?? 0;
        return bId.compareTo(aId);
      });
      final recent = lista.take(5).toList();
      setState(() {
        _empresasCompleta = lista;
        _empresas = recent;
        _filtrarEmpresas();
      });
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Erro ao carregar dados';
        if (e.toString().contains('403') || e.toString().contains('Proibido')) {
          errorMessage = 'Acesso negado. Faça login novamente.';

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          });
        }
        ErrorUtils.showVisibleError(context, errorMessage);
      }
    } finally {
      setState(() => _isLoadingEmpresas = false);
    }
  }

  void _salvarEmpresa() async {
    if (!_formKey.currentState!.validate()) return;

    final cnpjLimpo = _cnpjController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cnpjLimpo.length != 14) {
      ErrorUtils.showVisibleError(context, 'CNPJ deve conter 14 dígitos');
      return;
    }

    final cnpjJaExiste = _empresas.any((e) => e.cnpj.replaceAll(RegExp(r'[^0-9]'), '') == cnpjLimpo && e.id != _empresaEmEdicao?.id);

    if (cnpjJaExiste) {
      ErrorUtils.showVisibleError(context, 'Já existe uma empresa com este CNPJ');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final empresa = Empresa(
        id: _empresaEmEdicao?.id,
        cnpj: cnpjLimpo,
        razaoSocial: _razaoSocialController.text.trim(),
        nomeFantasia: _nomeFantasiaController.text.trim(),
        inscricaoEstadual:
            _inscricaoEstadualController.text.trim().isEmpty ? null : _inscricaoEstadualController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        inscricaoMunicipal: _inscricaoMunicipalController.text.trim().isEmpty ? null : _inscricaoMunicipalController.text.trim(),
        telefone: _telefoneController.text.trim().isEmpty ? null : _telefoneController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        site: _siteController.text.trim().isEmpty ? null : _siteController.text.trim(),
        cep: _cepController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        logradouro: _logradouroController.text.trim(),
        numero: _numeroController.text.trim(),
        complemento: _complementoController.text.trim().isEmpty ? null : _complementoController.text.trim(),
        bairro: _bairroController.text.trim(),
        cidade: _cidadeController.text.trim(),
        uf: _ufSelecionada,
        codigoMunicipio: _codigoMunicipioController.text.trim().isEmpty ? null : _codigoMunicipioController.text.trim(),
        regimeTributario: _regimeTributarioSelecionado,
        cnae: _cnaeController.text.trim().isEmpty ? null : _cnaeController.text.trim(),
      );

      Map<String, dynamic> result;
      if (_empresaEmEdicao == null) {
        result = await EmpresaService.salvarEmpresa(empresa);
      } else {
        result = await EmpresaService.atualizarEmpresa(_empresaEmEdicao!.id!, empresa);
      }

      if (result['success'] == true) {
        _limparFormulario();
        if (!mounted) return;
        Navigator.pop(context);
        await _carregarDados();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Operação realizada com sucesso'),
              backgroundColor: successColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ErrorUtils.showVisibleError(context, result['message'] ?? 'Erro ao salvar empresa');
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showVisibleError(context, 'Erro ao salvar empresa: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    setState(() {
      _cnpjController.clear();
      _razaoSocialController.clear();
      _nomeFantasiaController.clear();
      _inscricaoEstadualController.clear();
      _inscricaoMunicipalController.clear();
      _telefoneController.clear();
      _emailController.clear();
      _siteController.clear();
      _cepController.clear();
      _logradouroController.clear();
      _numeroController.clear();
      _complementoController.clear();
      _bairroController.clear();
      _cidadeController.clear();
      _codigoMunicipioController.clear();
      _cnaeController.clear();
      _empresaEmEdicao = null;
      _ufSelecionada = 'GO';
      _regimeTributarioSelecionado = '1';
    });
  }

  void _editarEmpresa(Empresa empresa) {
    setState(() {
      _empresaEmEdicao = empresa;
      _cnpjController.text = _formatarCNPJ(empresa.cnpj);
      _razaoSocialController.text = empresa.razaoSocial;
      _nomeFantasiaController.text = empresa.nomeFantasia;
      _inscricaoEstadualController.text = empresa.inscricaoEstadual ?? '';
      _inscricaoMunicipalController.text = empresa.inscricaoMunicipal ?? '';
      _telefoneController.text = empresa.telefone ?? '';
      _emailController.text = empresa.email ?? '';
      _siteController.text = empresa.site ?? '';
      _cepController.text = _formatarCEP(empresa.cep);
      _logradouroController.text = empresa.logradouro;
      _numeroController.text = empresa.numero;
      _complementoController.text = empresa.complemento ?? '';
      _bairroController.text = empresa.bairro;
      _cidadeController.text = empresa.cidade;
      _codigoMunicipioController.text = empresa.codigoMunicipio ?? '';
      _ufSelecionada = empresa.uf;
      _regimeTributarioSelecionado = empresa.regimeTributario ?? '1';
      _cnaeController.text = empresa.cnae ?? '';
    });
    _showFormModal();
  }

  void _gerenciarAdmins(Empresa empresa) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AdminManagementDialog(empresa: empresa),
    );
    _carregarDados();
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
                      _empresaEmEdicao != null ? Icons.edit : Icons.add_business,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _empresaEmEdicao != null ? 'Editar Empresa' : 'Nova Empresa',
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

  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Dados da Empresa'),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _cnpjController,
            label: 'CNPJ',
            icon: Icons.badge,
            inputFormatters: [_maskCnpj],
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'CNPJ é obrigatório';
              }
              if (!CNPJValidator.isValid(value)) {
                return 'CNPJ inválido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _razaoSocialController,
            label: 'Razão Social',
            icon: Icons.business,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Razão Social é obrigatória';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _nomeFantasiaController,
            label: 'Nome Fantasia',
            icon: Icons.store,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nome Fantasia é obrigatório';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _inscricaoEstadualController,
                  label: 'Inscrição Estadual',
                  icon: Icons.receipt_long,
                  inputFormatters: [_maskInscricaoEstadual],
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final ie = value.replaceAll(RegExp(r'[^0-9]'), '');
                      if (ie.length != 9) {
                        return 'IE deve conter 9 dígitos';
                      }
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _inscricaoMunicipalController,
                  label: 'Inscrição Municipal *',
                  icon: Icons.receipt,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Inscrição Municipal é obrigatória';
                    }
                    if (value.trim().isNotEmpty) {
                      if (value.length < 5) {
                        return 'IM inválida (mín. 5 dígitos)';
                      }
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Dados de Contato'),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _telefoneController,
            label: 'Telefone',
            icon: Icons.phone,
            inputFormatters: [_maskTelefone],
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            label: 'E-mail',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null && value.trim().isNotEmpty) {
                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(value)) {
                  return 'E-mail inválido';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _siteController,
            label: 'Site',
            icon: Icons.language,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Endereço'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: _cepController,
                  label: 'CEP',
                  icon: Icons.location_on,
                  inputFormatters: [_maskCep],
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'CEP é obrigatório';
                    }
                    final cep = value.replaceAll(RegExp(r'[^0-9]'), '');
                    if (cep.length != 8) {
                      return 'CEP inválido';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildTextField(
                  controller: _logradouroController,
                  label: 'Logradouro',
                  icon: Icons.place,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Logradouro é obrigatório';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _buildTextField(
                  controller: _numeroController,
                  label: 'Número',
                  icon: Icons.pin,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Número é obrigatório';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _complementoController,
            label: 'Complemento',
            icon: Icons.add_location,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _bairroController,
            label: 'Bairro',
            icon: Icons.home_work,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Bairro é obrigatório';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildTextField(
                  controller: _cidadeController,
                  label: 'Cidade',
                  icon: Icons.location_city,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Cidade é obrigatória';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _buildDropdown(
                  value: _ufSelecionada,
                  items: _ufs,
                  label: 'UF',
                  icon: Icons.map,
                  onChanged: (value) => setState(() => _ufSelecionada = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _codigoMunicipioController,
            label: 'Código do Município (IBGE) *',
            icon: Icons.numbers,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(7),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Código do Município é obrigatório';
              }
              if (value.length != 7) {
                return 'Código IBGE deve ter 7 dígitos';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Dados Fiscais'),
          const SizedBox(height: 16),
          _buildDropdown(
            value: _regimeTributarioSelecionado,
            items: _regimesTributarios.map((e) => e['value']!).toList(),
            itemLabels: _regimesTributarios.map((e) => e['label']!).toList(),
            label: 'Regime Tributário',
            icon: Icons.account_balance,
            onChanged: (value) => setState(() => _regimeTributarioSelecionado = value!),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _cnaeController,
            label: 'CNAE (Ex: 4520-0/01) *',
            icon: Icons.category,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'CNAE é obrigatório para emissão de NF';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _salvarEmpresa,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _empresaEmEdicao != null ? 'Atualizar Empresa' : 'Cadastrar Empresa',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarExclusao(Empresa empresa) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: errorColor, size: 28),
            const SizedBox(width: 12),
            const Text('Confirmar Exclusão'),
          ],
        ),
        content: Text('Deseja excluir a empresa "${empresa.nomeFantasia}"?'),
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
              await _excluirEmpresa(empresa);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _excluirEmpresa(Empresa empresa) async {
    setState(() => _isLoading = true);
    try {
      final result = await EmpresaService.deletarEmpresa(empresa.id!);
      if (result['success'] == true) {
        await _carregarDados();
        if (!mounted) return;
        _showSuccessSnackBar('Empresa excluída com sucesso');
      } else {
        if (!mounted) return;
        ErrorUtils.showVisibleError(context, result['message'] ?? 'Erro ao excluir empresa');
      }
    } catch (e) {
      if (!mounted) return;
      ErrorUtils.showVisibleError(context, 'Erro inesperado ao excluir empresa');
    } finally {
      setState(() => _isLoading = false);
    }
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

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Logout'),
        content: const Text('Deseja realmente sair do sistema?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  String _formatarCNPJ(String cnpj) {
    final numeros = cnpj.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeros.length != 14) return cnpj;
    return '${numeros.substring(0, 2)}.${numeros.substring(2, 5)}.${numeros.substring(5, 8)}/${numeros.substring(8, 12)}-${numeros.substring(12, 14)}';
  }

  String _formatarCEP(String cep) {
    final numeros = cep.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeros.length != 8) return cep;
    return '${numeros.substring(0, 5)}-${numeros.substring(5, 8)}';
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: primaryColor,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
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
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    List<String>? itemLabels,
    required String label,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
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
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: items.asMap().entries.map((entry) {
        return DropdownMenuItem(
          value: entry.value,
          child: Text(itemLabels != null ? itemLabels[entry.key] : entry.value),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade50,
              Colors.cyan.shade50,
              Colors.indigo.shade50,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModernHeader(colorScheme),
                  const SizedBox(height: 32),
                  if (_isLoadingEmpresas)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: CircularProgressIndicator(color: primaryColor),
                      ),
                    )
                  else ...[
                    _buildSearchSection(colorScheme),
                    const SizedBox(height: 24),
                    _buildRecentList(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, Colors.cyan.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.business_center,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gerenciar Empresas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Controle total das empresas cadastradas',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _carregarDados,
                  icon: Icon(Icons.refresh, color: primaryColor),
                  tooltip: 'Atualizar',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _logout,
                  icon: Icon(Icons.logout, color: errorColor),
                  tooltip: 'Sair',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Pesquisar por CNPJ, Razão Social ou Nome Fantasia...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search, color: primaryColor),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[600]),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
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
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                _limparFormulario();
                _showFormModal();
              },
              icon: const Icon(Icons.add_business),
              label: const Text(
                'Nova Empresa',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentList() {
    if (_empresasFiltradas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.business_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty ? 'Nenhuma empresa cadastrada' : 'Nenhum resultado encontrado',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isEmpty ? 'Clique em "Nova Empresa" para começar' : 'Tente ajustar os termos da busca',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.business, color: primaryColor),
              const SizedBox(width: 12),
              Text(
                _searchController.text.isEmpty ? 'Últimas Empresas' : 'Resultados da Busca',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_empresasFiltradas.length} item${_empresasFiltradas.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _empresasFiltradas.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey[200],
              indent: 20,
              endIndent: 20,
            ),
            itemBuilder: (context, index) {
              final empresa = _empresasFiltradas[index];
              return _buildEmpresaCard(empresa);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmpresaCard(Empresa empresa) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: empresa.ativa ? Colors.grey.shade200 : Colors.red.shade200,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: empresa.ativa ? [primaryColor, Colors.cyan.shade400] : [Colors.grey.shade400, Colors.grey.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.business,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                empresa.nomeFantasia,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            if (!empresa.ativa)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'INATIVA',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.badge, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'CNPJ: ${_formatarCNPJ(empresa.cnpj)}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.business, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    empresa.razaoSocial,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  '${empresa.cidade} - ${empresa.uf}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
            if (empresa.email != null && empresa.email!.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.email, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      empresa.email!,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            if (empresa.telefone != null && empresa.telefone!.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    empresa.telefone!,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.admin_panel_settings,
                  color: Colors.green.shade600,
                  size: 20,
                ),
                onPressed: () => _gerenciarAdmins(empresa),
                tooltip: 'Gerenciar Admins',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
                onPressed: () => _editarEmpresa(empresa),
                tooltip: 'Editar Empresa',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade600,
                  size: 20,
                ),
                onPressed: () => _confirmarExclusao(empresa),
                tooltip: 'Excluir Empresa',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminManagementDialog extends StatefulWidget {
  final Empresa empresa;

  const _AdminManagementDialog({required this.empresa});

  @override
  State<_AdminManagementDialog> createState() => _AdminManagementDialogState();
}

class _AdminManagementDialogState extends State<_AdminManagementDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  final TextEditingController _confirmarSenhaController = TextEditingController();

  List<Usuario> _admins = [];
  Usuario? _adminEmEdicao;
  bool _isLoading = false;
  bool _senhaVisivel = false;
  bool _confirmarSenhaVisivel = false;

  @override
  void initState() {
    super.initState();
    _carregarAdmins();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _carregarAdmins() async {
    setState(() => _isLoading = true);
    try {
      final todosUsuarios = await UsuarioService.listarUsuarios();
      setState(() {
        _admins = todosUsuarios.where((u) => u.nivelAcesso == 1 && u.empresa?.id == widget.empresa.id).toList();
      });
    } catch (e) {
      if (mounted) {
        ErrorUtils.showVisibleError(context, 'Erro ao carregar administradores');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _salvarAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    final senhaPreenchida = _senhaController.text.isNotEmpty;
    if (senhaPreenchida && _senhaController.text != _confirmarSenhaController.text) {
      ErrorUtils.showVisibleError(context, 'As senhas não coincidem');
      return;
    }

    if (_adminEmEdicao == null && !senhaPreenchida) {
      ErrorUtils.showVisibleError(context, 'Senha é obrigatória para novo administrador');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final usuario = Usuario(
        id: _adminEmEdicao?.id,
        nomeUsuario: _nomeController.text.trim(),
        senha: _senhaController.text.isNotEmpty ? _senhaController.text : null,
        nivelAcesso: 1,
        consultor: null,
        empresa: widget.empresa,
      );

      Map<String, dynamic> result;
      if (_adminEmEdicao == null) {
        result = await UsuarioService.salvarUsuario(usuario);
      } else {
        result = await UsuarioService.atualizarUsuario(_adminEmEdicao!.id!, usuario);
      }

      if (result['success'] == true) {
        _limparFormulario();
        await _carregarAdmins();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Operação realizada com sucesso'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ErrorUtils.showVisibleError(context, result['message'] ?? 'Erro ao salvar administrador');
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorUtils.showVisibleError(context, 'Erro ao salvar administrador: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    setState(() {
      _nomeController.clear();
      _senhaController.clear();
      _confirmarSenhaController.clear();
      _adminEmEdicao = null;
      _senhaVisivel = false;
      _confirmarSenhaVisivel = false;
    });
  }

  void _editarAdmin(Usuario admin) {
    setState(() {
      _adminEmEdicao = admin;
      _nomeController.text = admin.nomeUsuario;
      _senhaController.clear();
      _confirmarSenhaController.clear();
    });
  }

  Future<void> _excluirAdmin(Usuario admin) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja excluir o administrador "${admin.nomeUsuario}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _isLoading = true);
      try {
        final resultado = await UsuarioService.excluirUsuario(admin.id!);
        if (resultado['success']) {
          await _carregarAdmins();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(resultado['message'] ?? 'Administrador excluído com sucesso'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          if (mounted) {
            ErrorUtils.showVisibleError(context, resultado['message'] ?? 'Erro ao excluir administrador');
          }
        }
      } catch (e) {
        if (mounted) {
          ErrorUtils.showVisibleError(context, 'Erro inesperado ao excluir administrador: $e');
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gerenciar Administradores',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.empresa.nomeFantasia,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nomeController,
                                  decoration: InputDecoration(
                                    labelText: 'Nome do Administrador',
                                    prefixIcon: const Icon(Icons.person),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Nome é obrigatório';
                                    }
                                    if (value.trim().length < 3) {
                                      return 'Nome deve ter pelo menos 3 caracteres';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _senhaController,
                                  obscureText: !_senhaVisivel,
                                  decoration: InputDecoration(
                                    labelText: _adminEmEdicao != null ? 'Nova Senha (deixe vazio para manter)' : 'Senha',
                                    prefixIcon: const Icon(Icons.lock),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _senhaVisivel ? Icons.visibility_off : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() => _senhaVisivel = !_senhaVisivel);
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (_adminEmEdicao != null && (value == null || value.isEmpty)) {
                                      return null;
                                    }
                                    if (value == null || value.isEmpty) {
                                      return 'Senha é obrigatória';
                                    }
                                    if (value.length < 4) {
                                      return 'Senha deve ter pelo menos 4 caracteres';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _confirmarSenhaController,
                                  obscureText: !_confirmarSenhaVisivel,
                                  decoration: InputDecoration(
                                    labelText: 'Confirmar Senha',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _confirmarSenhaVisivel ? Icons.visibility_off : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() => _confirmarSenhaVisivel = !_confirmarSenhaVisivel);
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (_senhaController.text.isNotEmpty && value != _senhaController.text) {
                                      return 'As senhas não coincidem';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    if (_adminEmEdicao != null)
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _limparFormulario,
                                          child: const Text('Cancelar'),
                                        ),
                                      ),
                                    if (_adminEmEdicao != null) const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _salvarAdmin,
                                        icon: Icon(_adminEmEdicao == null ? Icons.add : Icons.save),
                                        label: Text(
                                          _adminEmEdicao == null ? 'Adicionar Admin' : 'Atualizar Admin',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green.shade600,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text(
                            'Administradores Cadastrados (${_admins.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_admins.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Nenhum administrador cadastrado',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ),
                            )
                          else
                            ...(_admins.map((admin) => Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.green.shade100,
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                    title: Text(
                                      admin.nomeUsuario,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: const Text('Administrador - Nível 1'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, color: Colors.blue),
                                          onPressed: () => _editarAdmin(admin),
                                          tooltip: 'Editar',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _excluirAdmin(admin),
                                          tooltip: 'Excluir',
                                        ),
                                      ],
                                    ),
                                  ),
                                ))),
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
