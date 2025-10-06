import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../model/ordem_servico.dart';
import '../services/ordem_servico_service.dart';

class GerenciamentoFiadosPage extends StatefulWidget {
  const GerenciamentoFiadosPage({super.key});

  @override
  State<GerenciamentoFiadosPage> createState() => _GerenciamentoFiadosPageState();
}

class _GerenciamentoFiadosPageState extends State<GerenciamentoFiadosPage> {
  final OrdemServicoService _ordemServicoService = OrdemServicoService();
  List<OrdemServico> _fiadosEmAberto = [];
  bool _isLoading = false;
  String _filtro = 'todos';

  @override
  void initState() {
    super.initState();
    _carregarFiadosEmAberto();
  }

  Future<void> _carregarFiadosEmAberto() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fiados = await _ordemServicoService.getFiadosEmAberto();
      setState(() {
        _fiadosEmAberto = fiados;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar fiados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _marcarComoPago(OrdemServico fiado, bool pago) async {
    try {
      await _ordemServicoService.marcarFiadoComoPago(fiado.id!, pago);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pago ? 'Fiado marcado como PAGO' : 'Fiado marcado como NÃO PAGO'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _carregarFiadosEmAberto();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _calcularDiasRestantes(OrdemServico fiado) {
    final dataVencimento = fiado.dataHoraEncerramento!.add(Duration(days: fiado.prazoFiadoDias!));
    final hoje = DateTime.now();
    return dataVencimento.difference(hoje).inDays;
  }

  bool _estaVencido(OrdemServico fiado) {
    return _calcularDiasRestantes(fiado) < 0;
  }

  List<OrdemServico> _filtrarFiados() {
    switch (_filtro) {
      case 'no_prazo':
        return _fiadosEmAberto.where((f) => !_estaVencido(f)).toList();
      case 'vencidos':
        return _fiadosEmAberto.where((f) => _estaVencido(f)).toList();
      default:
        return _fiadosEmAberto;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fiadosFiltrados = _filtrarFiados();
    final fiadosNoPrazo = _fiadosEmAberto.where((f) => !_estaVencido(f)).length;
    final fiadosVencidos = _fiadosEmAberto.where((f) => _estaVencido(f)).length;
    final valorTotal = _fiadosEmAberto.fold<double>(0, (sum, f) => sum + f.precoTotal);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildResumo(fiadosNoPrazo, fiadosVencidos, valorTotal),
            _buildFiltros(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : fiadosFiltrados.isEmpty
                      ? _buildEmptyState()
                      : _buildListaFiados(fiadosFiltrados),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade700, Colors.orange.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.credit_card,
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gerenciamento de Fiados',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Controle de pagamentos em aberto',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _carregarFiadosEmAberto,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh,
                        color: Colors.orange.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Atualizar',
                        style: TextStyle(
                          color: Colors.orange.shade600,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildResumo(int noPrazo, int vencidos, double valorTotal) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildResumoCard(
              'No Prazo',
              noPrazo.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildResumoCard(
              'Vencidos',
              vencidos.toString(),
              Icons.warning,
              Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildResumoCard(
              'Valor Total',
              'R\$ ${valorTotal.toStringAsFixed(2)}',
              Icons.attach_money,
              Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoCard(String label, String valor, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildFiltroChip('Todos', 'todos', Icons.list),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFiltroChip('No Prazo', 'no_prazo', Icons.check_circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFiltroChip('Vencidos', 'vencidos', Icons.warning),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltroChip(String label, String valor, IconData icon) {
    final isSelected = _filtro == valor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            _filtro = valor;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.orange.shade600 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.orange.shade600 : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhum fiado encontrado',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filtro == 'todos'
                ? 'Não há fiados em aberto no momento'
                : _filtro == 'no_prazo'
                    ? 'Não há fiados no prazo'
                    : 'Não há fiados vencidos',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaFiados(List<OrdemServico> fiados) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: fiados.length,
      itemBuilder: (context, index) {
        final fiado = fiados[index];
        return _buildFiadoCard(fiado);
      },
    );
  }

  Widget _buildFiadoCard(OrdemServico fiado) {
    final diasRestantes = _calcularDiasRestantes(fiado);
    final estaVencido = diasRestantes < 0;
    final dataVencimento = fiado.dataHoraEncerramento!.add(Duration(days: fiado.prazoFiadoDias!));
    final fiadoPago = fiado.fiadoPago ?? false;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (fiadoPago) {
      statusColor = Colors.green;
      statusText = 'PAGO';
      statusIcon = Icons.check_circle;
    } else if (estaVencido) {
      statusColor = Colors.red;
      statusText = 'VENCIDO - ${diasRestantes.abs()} dia(s) atrasado';
      statusIcon = Icons.warning;
    } else {
      statusColor = Colors.orange;
      statusText = 'PENDENTE - $diasRestantes dia(s) restante(s)';
      statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OS #${fiado.numeroOS}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  'R\$ ${fiado.precoTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow(Icons.person, 'Cliente', fiado.clienteNome),
                if (fiado.clienteTelefone != null && fiado.clienteTelefone!.isNotEmpty)
                  _buildInfoRow(Icons.phone, 'Telefone', fiado.clienteTelefone!),
                _buildInfoRow(Icons.directions_car, 'Veículo', '${fiado.veiculoNome} - ${fiado.veiculoPlaca}'),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildDataInfo(
                        'Encerramento',
                        DateFormat('dd/MM/yyyy').format(fiado.dataHoraEncerramento!),
                        Icons.event,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[300],
                    ),
                    Expanded(
                      child: _buildDataInfo(
                        'Vencimento',
                        DateFormat('dd/MM/yyyy').format(dataVencimento),
                        Icons.calendar_today,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey[300],
                    ),
                    Expanded(
                      child: _buildDataInfo(
                        'Prazo',
                        '${fiado.prazoFiadoDias} dias',
                        Icons.timelapse,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: fiadoPago ? null : () => _marcarComoPago(fiado, true),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Marcar como PAGO'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[300],
                          disabledForegroundColor: Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: !fiadoPago ? null : () => _marcarComoPago(fiado, false),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Marcar como NÃO PAGO'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[300],
                          disabledForegroundColor: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataInfo(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
