import 'package:TecStock/model/marca.dart';
import 'package:TecStock/model/veiculo.dart';
import 'package:TecStock/services/marca_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../services/veiculo_service.dart';
import '../utils/error_utils.dart';

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
  List<Marca> _marcas = [];
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

  final TextEditingController _searchController = TextEditingController();
  List<Veiculo> _veiculos = [];
  List<Veiculo> _veiculosFiltrados = [];
  Veiculo? _veiculoEmEdicao;

  bool _isLoading = false;
  bool _isLoadingVeiculos = true;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF03DAC6);
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
    _searchController.addListener(_filtrarVeiculos);
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
    _searchController.removeListener(_filtrarVeiculos);
    _searchController.dispose();
    _nome.dispose();
    _placa.dispose();
    _ano.dispose();
    _modelo.dispose();
    _cor.dispose();
    _quilometragem.dispose();
    super.dispose();
  }

  void _filtrarVeiculos() {
    final unmaskedQuery = _maskPlaca.unmaskText(_searchController.text).toUpperCase();

    setState(() {
      if (unmaskedQuery.isEmpty) {
        _veiculosFiltrados = _veiculos.take(6).toList();
      } else {
        _veiculosFiltrados = _veiculos.where((veiculo) {
          final placaSemMascara = veiculo.placa.replaceAll('-', '');
          return placaSemMascara.toUpperCase().contains(unmaskedQuery);
        }).toList();
      }
    });
  }

  Future<void> _carregarVeiculos() async {
    setState(() => _isLoadingVeiculos = true);
    try {
      final lista = await VeiculoService.listarVeiculos();
      setState(() {
        _veiculos = lista.reversed.toList();
        _filtrarVeiculos();
      });
    } catch (e) {
      ErrorUtils.showVisibleError(context, 'Erro ao carregar veículos');
    } finally {
      setState(() => _isLoadingVeiculos = false);
    }
  }

  Future<void> _carregarMarcas() async {
    try {
      final lista = await MarcaService.listarMarcas();
      setState(() {
        _marcas = lista;
      });
    } catch (e) {
      ErrorUtils.showVisibleError(context, 'Erro ao carregar marcas');
    }
  }

  void _salvarVeiculo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

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
        _showSuccessSnackBar(resultado['message']);
        _limparFormulario();
        await _carregarVeiculos();
        Navigator.of(context).pop();
      } else {
        ErrorUtils.showVisibleError(context, resultado['message']);
      }
    } catch (e) {
      String errorMessage = "Erro inesperado ao salvar veículo";
      if (e.toString().contains('Placa já cadastrada')) {
        errorMessage = "Placa já cadastrada";
      } else if (e.toString().contains('já cadastrada')) {
        errorMessage = "Veículo já cadastrado";
      }
      ErrorUtils.showVisibleError(context, errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _editarVeiculo(Veiculo veiculo) {
    setState(() {
      _nome.text = veiculo.nome;
      _placa.text = veiculo.placa;
      _ano.text = veiculo.ano.toString();
      _modelo.text = veiculo.modelo;
      _marcaSelecionadaId = veiculo.marca?.id;
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
    setState(() => _isLoading = true);
    try {
      final sucesso = await VeiculoService.excluirVeiculo(veiculo.id!);
      if (sucesso) {
        await _carregarVeiculos();
        _showSuccessSnackBar('Veículo excluído com sucesso');
      } else {
        ErrorUtils.showVisibleError(context, 'Erro ao excluir veículo');
      }
    } catch (e) {
      ErrorUtils.showVisibleError(context, 'Erro inesperado ao excluir veículo');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    _nome.clear();
    _placa.clear();
    _ano.clear();
    _modelo.clear();
    _marcaSelecionadaId = null;
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
        inputFormatters: [_maskPlaca, _upperCaseFormatter],
        decoration: InputDecoration(
          hintText: 'Pesquisar por placa...',
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

  Widget _buildVehicleGrid() {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 1;
        if (constraints.maxWidth > 900) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 2;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        veiculo.categoria == 'Passeio' ? Icons.directions_car : Icons.local_shipping,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        veiculo.nome,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                const SizedBox(height: 12),
                _buildInfoRow(Icons.pin_drop, veiculo.placa),
                _buildInfoRow(Icons.build, '${veiculo.modelo} - ${veiculo.ano}'),
                _buildInfoRow(Icons.business, veiculo.marca?.marca ?? "Não informada"),
                _buildInfoRow(Icons.palette, veiculo.cor),
                _buildInfoRow(Icons.speed, '${veiculo.quilometragem.toStringAsFixed(0)} km'),
                const Spacer(),
                if (veiculo.createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(
                          'Cadastrado em ${DateFormat('dd/MM/yyyy').format(veiculo.createdAt!)}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: secondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    veiculo.categoria,
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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

  Widget _buildFormulario() {
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
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _ano,
                  label: 'Ano',
                  icon: Icons.calendar_today,
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Informe o ano' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _modelo,
                  label: 'Modelo',
                  icon: Icons.build,
                  validator: (v) => v!.isEmpty ? 'Informe o modelo' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            value: _marcaSelecionadaId,
            label: 'Marca',
            icon: Icons.business,
            items: _marcas
                .map((marca) => DropdownMenuItem<int>(
                      value: marca.id,
                      child: Text(marca.marca),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _marcaSelecionadaId = value),
          ),
          const SizedBox(height: 16),
          _buildDropdownField(
            value: _categoriaSelecionada,
            label: 'Categoria',
            icon: Icons.category,
            items: _categorias
                .map((categoria) => DropdownMenuItem<String>(
                      value: categoria,
                      child: Text(categoria),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _categoriaSelecionada = value),
            validator: (value) => value == null ? 'Selecione uma categoria' : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _cor,
                  label: 'Cor',
                  icon: Icons.palette,
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
                  validator: (v) => v!.isEmpty ? 'Informe a quilometragem' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _salvarVeiculo,
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
                  'Resultados da Busca (${_veiculosFiltrados.length})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              const SizedBox(height: 16),
              _buildVehicleGrid(),
            ],
          ),
        ),
      ),
    );
  }
}
