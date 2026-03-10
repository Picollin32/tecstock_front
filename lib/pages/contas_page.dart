import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/conta.dart';
import '../services/conta_service.dart';

class ContasPage extends StatefulWidget {
  const ContasPage({super.key});

  @override
  State<ContasPage> createState() => _ContasPageState();
}

class _ContasPageState extends State<ContasPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  DateTime _mesAtual = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isLoading = false;

  List<Conta> _contasAPagar = [];
  List<Conta> _contasAReceber = [];
  List<Conta> _contasAtrasadas = [];
  Map<String, double> _resumo = {};

  static const Color _corPagar = Color(0xFFDC2626);
  static const Color _corReceber = Color(0xFF16A34A);
  static const Color _corAtrasada = Color(0xFFB45309);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
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
      ]);
      setState(() {
        _contasAPagar = results[0] as List<Conta>;
        _contasAReceber = results[1] as List<Conta>;
        _resumo = results[2] as Map<String, double>;
        _contasAtrasadas = results[3] as List<Conta>;
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

    final result = conta.pago ? await ContaService.desmarcarPagamento(conta.id!) : await ContaService.marcarComoPago(conta.id!);

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
    String? fretePagamento;
    int freteNumeroParcelas = 2;
    DateTime? freteBoleto30Venc;

    final freteFormas = [
      (key: 'dinheiro', label: 'Dinheiro', backend: 'AVISTA', icon: Icons.payments_outlined),
      (key: 'pix', label: 'Pix', backend: 'AVISTA', icon: Icons.pix),
      (key: 'debito', label: 'Débito', backend: 'AVISTA', icon: Icons.credit_card),
      (key: 'credito', label: 'Crédito', backend: 'CREDITO', icon: Icons.credit_score),
      (key: 'boleto30', label: 'Boleto 30 dias', backend: 'BOLETO30', icon: Icons.receipt_long),
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          bool freteValido() {
            if (!isFrete) return true;
            final v = double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0;
            if (v <= 0 || fretePagamento == null || descricaoCtrl.text.trim().isEmpty) return false;
            if (fretePagamento == 'boleto30' && freteBoleto30Venc == null) return false;
            return true;
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
                            onTap: () => setDialogState(() => isFrete = false),
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
                            onTap: () => setDialogState(() => isFrete = true),
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: valorCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setDialogState(() {}),
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
                    if (!isFrete)
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
                            setDialogState(() => vencimento = picked);
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
                                  const Text('Vencimento', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                    if (isFrete) ...[
                      DropdownButtonFormField<String>(
                        initialValue: fretePagamento,
                        decoration: InputDecoration(
                          labelText: 'Forma de Pagamento *',
                          prefixIcon: Icon(Icons.payment, color: Colors.orange.shade700),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.orange.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.orange.shade50,
                        ),
                        items: freteFormas.map((f) {
                          return DropdownMenuItem<String>(
                            value: f.key,
                            child: Row(
                              children: [
                                Icon(f.icon, size: 18, color: Colors.orange.shade700),
                                const SizedBox(width: 8),
                                Text(f.label),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) => setDialogState(() {
                          fretePagamento = v;
                          freteBoleto30Venc = null;
                          freteNumeroParcelas = 2;
                        }),
                        validator: (v) => isFrete && v == null ? 'Selecione a forma de pagamento' : null,
                      ),
                      if (fretePagamento == 'credito') ...[
                        const SizedBox(height: 12),
                        Builder(builder: (ctx3) {
                          final val = double.tryParse(valorCtrl.text.replaceAll(',', '.')) ?? 0;
                          return DropdownButtonFormField<int>(
                            initialValue: freteNumeroParcelas,
                            decoration: InputDecoration(
                              labelText: 'Número de Parcelas',
                              prefixIcon: Icon(Icons.format_list_numbered, color: Colors.orange.shade700),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.orange.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.orange.shade50,
                            ),
                            items: List.generate(12, (i) => i + 2).map((n) {
                              final vp = val > 0 ? val / n : 0.0;
                              return DropdownMenuItem<int>(
                                value: n,
                                child: Text('${n}x  (parcela ~R\$ ${vp.toStringAsFixed(2)})'),
                              );
                            }).toList(),
                            onChanged: (v) => setDialogState(() => freteNumeroParcelas = v ?? 2),
                          );
                        }),
                      ],
                      if (fretePagamento == 'boleto30') ...[
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx2,
                              initialDate: DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              locale: const Locale('pt', 'BR'),
                            );
                            if (picked != null) setDialogState(() => freteBoleto30Venc = picked);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: freteBoleto30Venc != null ? Colors.orange.shade400 : Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.orange.shade50,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event, color: Colors.orange.shade700),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Vencimento', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    Text(
                                      freteBoleto30Venc != null ? DateFormat('dd/MM/yyyy').format(freteBoleto30Venc!) : 'Selecionar data',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: freteBoleto30Venc != null ? Colors.black87 : Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (freteBoleto30Venc == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, left: 4),
                            child: Text('Selecione a data de vencimento', style: TextStyle(fontSize: 11, color: Colors.red.shade400)),
                          ),
                      ],
                      if (fretePagamento != null && fretePagamento != 'credito' && fretePagamento != 'boleto30') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 14, color: Colors.green.shade700),
                              const SizedBox(width: 6),
                              Text('Registrado como já pago',
                                  style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
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
                  if (!freteValido()) return;
                  Navigator.pop(ctx);

                  if (!isFrete) {
                    final valor = double.parse(valorCtrl.text.replaceAll(',', '.'));
                    final nova = Conta(
                      tipo: 'A_PAGAR',
                      descricao: descricaoCtrl.text.trim(),
                      valor: valor,
                      mesReferencia: vencimento.month,
                      anoReferencia: vencimento.year,
                      dataVencimento: vencimento,
                    );
                    final result = await ContaService.adicionarContaPagar(nova);
                    if (result['sucesso'] == true) {
                      _mostrarSucesso('Conta adicionada com sucesso!');
                      _carregarDados();
                    } else {
                      _mostrarErro(result['mensagem'] ?? 'Erro ao adicionar conta');
                    }
                  } else {
                    final valor = double.parse(valorCtrl.text.replaceAll(',', '.'));
                    final backend = freteFormas.firstWhere((f) => f.key == fretePagamento).backend;
                    final pagamentoData = <String, dynamic>{'formaPagamento': backend};
                    if (fretePagamento == 'credito') {
                      pagamentoData['numeroParcelas'] = freteNumeroParcelas;
                    } else if (fretePagamento == 'boleto30') {
                      pagamentoData['boleto30Vencimento'] = freteBoleto30Venc!.toIso8601String().substring(0, 10);
                    }
                    final result = await ContaService.adicionarFrete(
                      descricao: descricaoCtrl.text.trim(),
                      valor: valor,
                      pagamento: pagamentoData,
                    );
                    if (result['sucesso'] == true) {
                      _mostrarSucesso('Frete adicionado com sucesso!');
                      _carregarDados();
                    } else {
                      _mostrarErro(result['mensagem'] ?? 'Erro ao adicionar frete');
                    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: _corPagar,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nova Conta'),
              onPressed: _abrirDialogAdicionarConta,
            )
          : null,
      body: Column(
        children: [
          _buildHeader(),
          if (_contasAtrasadas.isNotEmpty) _buildAlertaAtrasadas(),
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

  Widget _buildAlertaAtrasadas() {
    final aPagar = _contasAtrasadas.where((c) => c.isAPagar).toList();
    final aReceber = _contasAtrasadas.where((c) => c.isAReceber).toList();

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
                  '${_contasAtrasadas.length} conta${_contasAtrasadas.length != 1 ? "s" : ""} com vencimento passado',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
          if (aPagar.isNotEmpty || aReceber.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(color: Color(0xFFB45309), height: 1),
            const SizedBox(height: 8),
          ],
          if (aPagar.isNotEmpty)
            _buildAlertaLinha('A Pagar (${aPagar.length})', aPagar.fold<double>(0, (s, c) => s + c.valor), const Color(0xFFDC2626),
                Icons.arrow_circle_up_outlined),
          if (aPagar.isNotEmpty && aReceber.isNotEmpty) const SizedBox(height: 6),
          if (aReceber.isNotEmpty)
            _buildAlertaLinha('A Receber (${aReceber.length})', aReceber.fold<double>(0, (s, c) => s + c.valorPendente),
                const Color(0xFF059669), Icons.arrow_circle_down_outlined),
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
        labelColor: _tabController.index == 0 ? _corPagar : _corReceber,
        unselectedLabelColor: Colors.grey,
        indicatorColor: _tabController.index == 0 ? _corPagar : _corReceber,
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
        onTap: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildListaContas(List<Conta> contas, String tipo) {
    final cor = tipo == 'A_PAGAR' ? _corPagar : _corReceber;

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

    final atrasadas = contas.where((c) => c.isAtrasada).toList();
    final pendentes = contas.where((c) => !c.pago && !c.isAtrasada).toList();
    final pagas = contas.where((c) => c.pago).toList();

    return RefreshIndicator(
      onRefresh: _carregarDados,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          _buildAbaResumo(contas, tipo),
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
      ),
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
      direction: conta.isManual ? DismissDirection.endToStart : DismissDirection.none,
      confirmDismiss: (_) async {
        if (!conta.isManual) return false;
        await _confirmarExclusao(conta);
        return false;
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
