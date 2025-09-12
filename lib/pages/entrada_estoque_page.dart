import 'package:flutter/material.dart';
import '../model/fornecedor.dart';
import '../model/peca.dart';
import '../services/fornecedor_service.dart';
import '../services/peca_service.dart';
import '../services/movimentacao_estoque_service.dart';

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
                        'Entrada de Estoque',
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
  final _codigoPecaController = TextEditingController();
  final _quantidadeController = TextEditingController();
  final _precoUnitarioController = TextEditingController();
  final _numeroNotaFiscalController = TextEditingController();
  final _observacoesController = TextEditingController();

  Fornecedor? _fornecedorSelecionado;
  List<Fornecedor> _fornecedores = [];
  Peca? _pecaEncontrada;

  bool _isLoading = false;
  bool _isLoadingPeca = false;
  bool _canSubmit = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const Color primaryColor = Color(0xFF6366F1);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color successColor = Color(0xFF059669);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _carregarFornecedores();
    _codigoPecaController.addListener(_buscarPecaPorCodigo);
    _numeroNotaFiscalController.addListener(_updateSubmitState);
    _quantidadeController.addListener(_updateSubmitState);
    _precoUnitarioController.addListener(_updateSubmitState);
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
    _codigoPecaController.removeListener(_buscarPecaPorCodigo);
    _numeroNotaFiscalController.removeListener(_updateSubmitState);
    _quantidadeController.removeListener(_updateSubmitState);
    _precoUnitarioController.removeListener(_updateSubmitState);
    _codigoPecaController.dispose();
    _quantidadeController.dispose();
    _precoUnitarioController.dispose();
    _numeroNotaFiscalController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _carregarFornecedores() async {
    try {
      final listaFornecedores = await FornecedorService.listarFornecedores();
      setState(() {
        _fornecedores = listaFornecedores;
      });
    } catch (e) {
      _showError('Erro ao carregar fornecedores');
    }
  }

  void _buscarPecaPorCodigo() async {
    final codigo = _codigoPecaController.text.trim();

    if (codigo.length < 3) {
      setState(() {
        _pecaEncontrada = null;
      });
      _updateSubmitState();
      return;
    }

    if (_fornecedorSelecionado == null) {
      _updateSubmitState();
      return;
    }

    setState(() => _isLoadingPeca = true);

    try {
      final pecas = await PecaService.listarPecas();
      final peca = pecas
          .where((p) => p.codigoFabricante.toLowerCase() == codigo.toLowerCase() && p.fornecedor?.id == _fornecedorSelecionado!.id)
          .firstOrNull;

      setState(() {
        _pecaEncontrada = peca;
        if (peca != null) {
          _precoUnitarioController.text = peca.precoUnitario.toStringAsFixed(2).replaceAll('.', ',');
        } else {
          _precoUnitarioController.clear();
        }
      });
    } catch (e) {
      print('Erro ao buscar peça: $e');
    } finally {
      setState(() => _isLoadingPeca = false);
      _updateSubmitState();
    }
  }

  void _updateSubmitState() {
    final canSubmit = _pecaEncontrada != null &&
        _numeroNotaFiscalController.text.trim().isNotEmpty &&
        _quantidadeController.text.trim().isNotEmpty &&
        _precoUnitarioController.text.trim().isNotEmpty &&
        (int.tryParse(_quantidadeController.text) ?? 0) > 0 &&
        (double.tryParse(_precoUnitarioController.text.replaceAll(',', '.')) ?? 0) > 0 &&
        !_isLoading;

    if (_canSubmit != canSubmit) {
      setState(() {
        _canSubmit = canSubmit;
      });
    }
  }

  void _registrarEntrada() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pecaEncontrada == null) {
      _showError('Peça não encontrada com o código informado');
      return;
    }

    setState(() {
      _isLoading = true;
      _canSubmit = false;
    });

    try {
      final resultado = await MovimentacaoEstoqueService.registrarEntrada(
        codigoPeca: _codigoPecaController.text.trim(),
        fornecedorId: _fornecedorSelecionado!.id!,
        quantidade: int.parse(_quantidadeController.text),
        precoUnitario: double.parse(_precoUnitarioController.text.replaceAll(',', '.')),
        numeroNotaFiscal: _numeroNotaFiscalController.text.trim(),
        observacoes: _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(),
      );

      if (resultado['sucesso']) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(resultado['mensagem'])),
              ],
            ),
            backgroundColor: successColor,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        _limparFormulario();
      } else {
        _showVisibleError(resultado['mensagem']);
      }
    } catch (e) {
      _showVisibleError("Erro inesperado ao registrar entrada: $e");
    } finally {
      setState(() => _isLoading = false);
      _updateSubmitState();
    }
  }

  void _limparFormulario() {
    _formKey.currentState?.reset();
    _codigoPecaController.clear();
    _quantidadeController.clear();
    _precoUnitarioController.clear();
    _numeroNotaFiscalController.clear();
    _observacoesController.clear();
    setState(() {
      _fornecedorSelecionado = null;
      _pecaEncontrada = null;
      _canSubmit = false;
    });
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
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool enabled = true,
    TextStyle? style,
    int? maxLines,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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

  Widget _buildPecaInfo() {
    if (_isLoadingPeca) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Buscando peça...'),
          ],
        ),
      );
    }

    if (_pecaEncontrada != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: successColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: successColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: successColor, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Peça Encontrada',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Nome: ${_pecaEncontrada!.nome}'),
            Text('Fabricante: ${_pecaEncontrada!.fabricante.nome}'),
            Text('Estoque Atual: ${_pecaEncontrada!.quantidadeEstoque} unidades'),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preço Atual: R\$ ${_pecaEncontrada!.precoUnitario.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Informe o novo preço abaixo. Se for diferente do atual, será atualizado automaticamente.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_codigoPecaController.text.trim().length >= 3 && _fornecedorSelecionado != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: errorColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: errorColor),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: errorColor, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Peça não encontrada com este código para o fornecedor selecionado',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
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
                      'Selecione primeiro o fornecedor, depois digite o código da peça para buscar automaticamente.',
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
              items: _fornecedores
                  .map((fornecedor) => DropdownMenuItem<Fornecedor>(
                        value: fornecedor,
                        child: Text(fornecedor.nome),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _fornecedorSelecionado = value;
                  _pecaEncontrada = null;
                });
                _buscarPecaPorCodigo();
                _updateSubmitState();
              },
              validator: (value) => value == null ? 'Selecione um fornecedor' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _codigoPecaController,
              label: 'Código da Peça',
              icon: Icons.qr_code,
              validator: (v) => v!.isEmpty ? 'Informe o código da peça' : null,
            ),
            const SizedBox(height: 16),
            _buildPecaInfo(),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _precoUnitarioController,
              label: 'Preço Unitário (Custo)',
              icon: Icons.attach_money,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Informe o preço unitário';
                }
                if (!RegExp(r'^\d*[,.]?\d*$').hasMatch(value)) {
                  return 'Digite apenas números e vírgula/ponto';
                }
                final preco = double.tryParse(value.replaceAll(',', '.'));
                if (preco == null || preco <= 0) {
                  return 'Preço deve ser maior que zero';
                }
                return null;
              },
              onChanged: (value) {
                String newValue = value.replaceAll(RegExp(r'[^\d,.]'), '');
                if (newValue.indexOf(',') != newValue.lastIndexOf(',')) {
                  newValue = newValue.replaceFirst(RegExp(',.*'), ',');
                }
                if (newValue.indexOf('.') != newValue.lastIndexOf('.')) {
                  newValue = newValue.replaceFirst(RegExp('..*'), '.');
                }
                if (newValue != value) {
                  _precoUnitarioController.value = TextEditingValue(
                    text: newValue,
                    selection: TextSelection.collapsed(offset: newValue.length),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _numeroNotaFiscalController,
              label: 'Número da Nota Fiscal',
              icon: Icons.receipt,
              validator: (v) => v!.isEmpty ? 'Informe o número da nota fiscal' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _quantidadeController,
              label: 'Quantidade de Entrada',
              icon: Icons.add_box,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Informe a quantidade';
                }
                final quantidade = int.tryParse(value);
                if (quantidade == null || quantidade <= 0) {
                  return 'Quantidade deve ser maior que zero';
                }
                return null;
              },
            ),
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
                onPressed: _canSubmit ? _registrarEntrada : null,
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
                    : const Text(
                        'Registrar Entrada',
                        style: TextStyle(
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
}
