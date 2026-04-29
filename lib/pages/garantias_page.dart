import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tecstock/model/garantia.dart';
import 'package:tecstock/services/garantia_service.dart';
import 'package:tecstock/widgets/pagination_controls.dart';

class GarantiasPage extends StatefulWidget {
  const GarantiasPage({super.key});

  @override
  State<GarantiasPage> createState() => _GarantiasPageState();
}

class _GarantiasPageState extends State<GarantiasPage>
    with TickerProviderStateMixin {
  static const Color primaryColor = Color(0xFF1565C0);
  static const Color emeraldColor = Color(0xFF16A34A);
  static const Color amberColor = Color(0xFFF59E0B);
  static const Color expiradaColor = Color(0xFF64748B);
  static const Color errorColor = Color(0xFFDC2626);

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<GarantiaResumo> _garantias = [];
  GarantiaResumoTotal _resumo =
      GarantiaResumoTotal(total: 0, ativas: 0, reclamadas: 0, expiradas: 0);

  bool _isLoading = true;
  String _statusFiltro = 'TODOS';
  String _searchField = 'TODOS';

  int _currentPage = 0;
  int _totalPages = 0;
  int _pageSize = 10;
  final List<int> _pageSizeOptions = [10, 20, 30];

  final Map<int, int> _servicoIndexByOS = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _carregarGarantias();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() => _currentPage = 0);
      _carregarGarantias();
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: errorColor,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: emeraldColor,
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: amberColor,
      ),
    );
  }

  Future<void> _carregarGarantias() async {
    setState(() => _isLoading = true);

    final result = await GarantiaService.buscarPaginado(
      query: _searchController.text.trim(),
      field: _searchField,
      status: _statusFiltro,
      page: _currentPage,
      size: _pageSize,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _garantias = result['content'] as List<GarantiaResumo>;
        _totalPages = result['totalPages'] as int;
        _resumo = result['resumo'] as GarantiaResumoTotal;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              result['message']?.toString() ?? 'Erro ao carregar garantias'),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  void _irParaPagina(int page) {
    if (page < 0 || page >= _totalPages) return;
    setState(() => _currentPage = page);
    _carregarGarantias();
  }

  void _alterarPageSize(int size) {
    setState(() {
      _pageSize = size;
      _currentPage = 0;
    });
    _carregarGarantias();
  }

  void _alterarStatus(String status) {
    setState(() {
      _statusFiltro = status;
      _currentPage = 0;
    });
    _carregarGarantias();
  }

  void _alterarCampoBusca(String field) {
    setState(() {
      _searchField = field;
      _currentPage = 0;
    });
    _carregarGarantias();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        automaticallyImplyLeading: false,
        title: const Text(
          'Gestão de Garantias',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            _buildStatsCards(isMobile: isMobile),
            const SizedBox(height: 16),
            _buildFilters(),
            const SizedBox(height: 16),
            _buildTabelaGarantias(isMobile: isMobile),
            if (_totalPages > 1) ...[
              const SizedBox(height: 16),
              PaginationControls(
                currentPage: _currentPage,
                totalPages: _totalPages,
                pageSize: _pageSize,
                pageSizeOptions: _pageSizeOptions,
                onPageChange: _irParaPagina,
                onPageSizeChange: _alterarPageSize,
                primaryColor: primaryColor,
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards({required bool isMobile}) {
    final cards = [
      _StatCard(
        title: 'OS GARANTIA ATIVA',
        value: _resumo.ativas.toString(),
        color: emeraldColor,
        icon: Icons.check_circle_outline,
      ),
      _StatCard(
        title: 'OS EM RETORNO',
        value: _resumo.reclamadas.toString(),
        color: amberColor,
        icon: Icons.replay,
      ),
      _StatCard(
        title: 'OS EXPIRADAS',
        value: _resumo.expiradas.toString(),
        color: expiradaColor,
        icon: Icons.timer_off_outlined,
      ),
      _StatCard(
        title: 'TOTAL DE OS',
        value: _resumo.total.toString(),
        color: primaryColor,
        icon: Icons.trending_up,
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: 12),
          ]
        ],
      );
    }

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i < cards.length - 1) const SizedBox(width: 12),
        ]
      ],
    );
  }

  static const List<Map<String, String>> _searchFieldOptions = [
    {'value': 'TODOS', 'label': 'Todos os campos'},
    {'value': 'OS', 'label': 'Nº da OS'},
    {'value': 'CLIENTE', 'label': 'Cliente'},
    {'value': 'VEICULO', 'label': 'Veículo'},
    {'value': 'PLACA', 'label': 'Placa'},
    {'value': 'SERVICO', 'label': 'Serviço'},
    {'value': 'MECANICO', 'label': 'Mecânico'},
    {'value': 'CONSULTOR', 'label': 'Consultor'},
    {'value': 'MOTIVO', 'label': 'Motivo do retorno'},
  ];

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 1120;

          final searchControls = isCompact
              ? Column(
                  children: [
                    _buildCampoBuscaDropdown(),
                    const SizedBox(height: 10),
                    _buildBuscaTextField(),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(width: 230, child: _buildCampoBuscaDropdown()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildBuscaTextField()),
                  ],
                );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                searchControls,
                const SizedBox(height: 12),
                _buildStatusGroup(),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: searchControls),
              const SizedBox(width: 16),
              SizedBox(
                width: 430,
                child: _buildStatusGroup(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCampoBuscaDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _searchField,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Buscar em',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
      items: _searchFieldOptions
          .map(
            (item) => DropdownMenuItem<String>(
              value: item['value'],
              child: Text(item['label']!),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null || value == _searchField) return;
        _alterarCampoBusca(value);
      },
    );
  }

  Widget _buildBuscaTextField() {
    final String hint = _hintCampoBusca();

    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                tooltip: 'Limpar busca',
                onPressed: () {
                  _searchController.clear();
                  _debounceTimer?.cancel();
                  setState(() => _currentPage = 0);
                  _carregarGarantias();
                },
                icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF5F7FA),
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }

  String _hintCampoBusca() {
    return switch (_searchField) {
      'OS' => 'Ex.: 1024',
      'CLIENTE' => 'Ex.: João da Silva',
      'VEICULO' => 'Ex.: Corolla',
      'PLACA' => 'Ex.: ABC-1234',
      'SERVICO' => 'Ex.: Troca de amortecedor',
      'MECANICO' => 'Ex.: Ronaldo',
      'CONSULTOR' => 'Ex.: Felipe',
      'MOTIVO' => 'Ex.: barulho ao frear',
      _ => 'Buscar por OS, cliente, veículo, placa ou serviço...',
    };
  }

  Widget _buildStatusGroup() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          _buildStatusBtn('TODOS', 'TODOS'),
          _buildStatusBtn('ATIVA', 'ATIVA'),
          _buildStatusBtn('RECLAMADA', 'RECLAMADA'),
          _buildStatusBtn('EXPIRADA', 'EXPIRADA'),
        ],
      ),
    );
  }

  Widget _buildStatusBtn(String value, String label) {
    final isActive = _statusFiltro == value;
    return GestureDetector(
      onTap: () => _alterarStatus(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E293B) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
            fontSize: 12,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTabelaGarantias({required bool isMobile}) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_garantias.isEmpty) {
      return _buildEmptyState();
    }

    if (isMobile) {
      return Column(
        children: _garantias.map(_buildGarantiaCardMobile).toList(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          ..._garantias.map(_buildGarantiaRow),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          _buildHeaderCell(
            flex: 2,
            label: 'OS / VEÍCULO',
          ),
          const SizedBox(width: 8),
          _buildHeaderCell(
            flex: 3,
            label: 'SERVIÇOS EXECUTADOS',
          ),
          const SizedBox(width: 8),
          _buildHeaderCell(
            flex: 2,
            label: 'PRAZO GLOBAL',
          ),
          const SizedBox(width: 8),
          _buildHeaderCell(
            flex: 2,
            label: 'SITUAÇÃO DA OS',
          ),
          const SizedBox(width: 8),
          _buildHeaderCell(
            flex: 1,
            label: 'AÇÕES',
            center: true,
          ),
        ],
      ),
    );
  }

  Widget _buildGarantiaRow(GarantiaResumo garantia) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRowCell(flex: 2, child: _buildOsVeiculo(garantia)),
          const SizedBox(width: 8),
          _buildRowCell(flex: 3, child: _buildServicoCarousel(garantia)),
          const SizedBox(width: 8),
          _buildRowCell(flex: 2, child: _buildPrazo(garantia)),
          const SizedBox(width: 8),
          _buildRowCell(flex: 2, child: _buildSituacao(garantia)),
          const SizedBox(width: 8),
          _buildRowCell(
            flex: 1,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _buildAcoes(garantia),
              ),
            ),
            center: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell({
    required int flex,
    required String label,
    bool center = false,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          label,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.6,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildRowCell({
    required int flex,
    required Widget child,
    bool center = false,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Align(
          alignment: center ? Alignment.topCenter : Alignment.topLeft,
          child: child,
        ),
      ),
    );
  }

  Widget _buildGarantiaCardMobile(GarantiaResumo garantia) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildOsVeiculo(garantia)),
              _buildAcoes(garantia),
            ],
          ),
          const SizedBox(height: 12),
          _buildServicoCarousel(garantia, compact: true),
          const SizedBox(height: 12),
          _buildPrazo(garantia, compact: true),
          const SizedBox(height: 12),
          _buildSituacao(garantia),
        ],
      ),
    );
  }

  Widget _buildOsVeiculo(GarantiaResumo garantia) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '#OS-${garantia.numeroOS}',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: primaryColor,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          garantia.clienteNome,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            const Icon(Icons.directions_car_outlined,
                size: 13, color: Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${garantia.veiculoNome} - ${garantia.veiculoPlaca}',
                style: const TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServicoCarousel(GarantiaResumo garantia,
      {bool compact = false}) {
    final servicos = garantia.servicos;
    if (servicos.isEmpty) {
      return const Text(
        'Sem serviços',
        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      );
    }

    final int currentIndex = _servicoIndexByOS[garantia.id] ?? 0;
    final GarantiaServicoResumo servico =
        servicos[currentIndex.clamp(0, servicos.length - 1)];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (servicos.length > 1)
              SizedBox(
                width: 22,
                height: 22,
                child: IconButton(
                  onPressed: () =>
                      _moverServico(garantia.id, -1, servicos.length),
                  icon: const Icon(Icons.chevron_left,
                      size: 16, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          servico.nome,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (garantia.isReclamada &&
                          garantia.retornoServicoId != null &&
                          garantia.retornoServicoId == servico.id) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.info_outline,
                            size: 14, color: Color(0xFFF59E0B)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 13, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          garantia.mecanicoNome ?? 'Mecânico não informado',
                          style: const TextStyle(
                              color: Color(0xFF94A3B8), fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (servicos.length > 1)
              SizedBox(
                width: 22,
                height: 22,
                child: IconButton(
                  onPressed: () =>
                      _moverServico(garantia.id, 1, servicos.length),
                  icon: const Icon(Icons.chevron_right,
                      size: 16, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        if (servicos.length > 1)
          Padding(
            padding: const EdgeInsets.only(left: 30, top: 4),
            child: Row(
              children: List.generate(
                servicos.length,
                (index) => Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: index == currentIndex
                        ? primaryColor
                        : const Color(0xFFCBD5E1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _moverServico(int osId, int delta, int total) {
    setState(() {
      final atual = _servicoIndexByOS[osId] ?? 0;
      int novo = atual + delta;
      if (novo < 0) novo = total - 1;
      if (novo >= total) novo = 0;
      _servicoIndexByOS[osId] = novo;
    });
  }

  Widget _buildPrazo(GarantiaResumo garantia, {bool compact = false}) {
    final now = DateTime.now();
    final int totalDays = garantia.garantiaMeses > 0
        ? garantia.garantiaMeses * 30
        : garantia.dataFimGarantia
            .difference(garantia.dataInicioGarantia)
            .inDays;
    final elapsedDays =
        now.difference(garantia.dataInicioGarantia).inDays;
    final int safeTotalDays = totalDays <= 0 ? 1 : totalDays;
    final int safeElapsed = elapsedDays.clamp(0, safeTotalDays);
    final double progress = safeElapsed / safeTotalDays;

    final bool expirada = garantia.isExpirada;
    final int diasRestantes = safeTotalDays - safeElapsed;

    String diasText;
    if (expirada) {
      diasText = '0 DIAS';
    } else {
      diasText = '$diasRestantes DIAS';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              diasText,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.3,
                color: expirada
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd/MM/yyyy').format(garantia.dataFimGarantia),
              style: const TextStyle(
                  color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(
              expirada ? errorColor : primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSituacao(GarantiaResumo garantia) {
    final Color badgeColor;
    final Color bgColor;

    if (garantia.isReclamada) {
      badgeColor = amberColor;
      bgColor = const Color(0xFFFEF3C7);
    } else if (garantia.isExpirada) {
      badgeColor = expiradaColor;
      bgColor = const Color(0xFFF1F5F9);
    } else {
      badgeColor = emeraldColor;
      bgColor = const Color(0xFFDCFCE7);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            garantia.statusGarantia,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        if (garantia.isReclamada &&
            (garantia.retornoMotivo ?? '').isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            '"Motivo: ${garantia.retornoMotivo}"',
            style: const TextStyle(
              color: Color(0xFFF59E0B),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildAcoes(GarantiaResumo garantia) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
      tooltip: 'Ações',
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'detalhes':
            _mostrarDetalhesOS(garantia);
            break;
          case 'retorno':
            _mostrarModalRetorno(garantia);
            break;
          case 'editar_retorno':
            _mostrarModalEditarRetorno(garantia);
            break;
          case 'excluir_retorno':
            _confirmarExcluirRetorno(garantia);
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'detalhes',
          child: Row(
            children: [
              Icon(Icons.visibility_outlined,
                  size: 18, color: Color(0xFF475569)),
              SizedBox(width: 10),
              Text('Ver Detalhes da OS', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
        if (!garantia.isReclamada)
          const PopupMenuItem(
            value: 'retorno',
            child: Row(
              children: [
                Icon(Icons.replay, size: 18, color: Color(0xFFF59E0B)),
                SizedBox(width: 10),
                Text('Registrar Retorno',
                    style: TextStyle(
                        fontSize: 14, color: Color(0xFFF59E0B))),
              ],
            ),
          ),
        if (garantia.isReclamada && garantia.retornoId != null) ...[
          const PopupMenuItem(
            value: 'editar_retorno',
            child: Row(
              children: [
                Icon(Icons.edit_outlined,
                    size: 18, color: Color(0xFF1565C0)),
                SizedBox(width: 10),
                Text('Editar Retorno',
                    style: TextStyle(
                        fontSize: 14, color: Color(0xFF1565C0))),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'excluir_retorno',
            child: Row(
              children: [
                Icon(Icons.delete_outline,
                    size: 18, color: Color(0xFFDC2626)),
                SizedBox(width: 10),
                Text('Excluir Retorno',
                    style: TextStyle(
                        fontSize: 14, color: Color(0xFFDC2626))),
              ],
            ),
          ),
        ],
      ],
    );
  }


  void _mostrarDetalhesOS(GarantiaResumo garantia) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.assignment_outlined,
                          color: primaryColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'OS #${garantia.numeroOS}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(dialogCtx).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close,
                            size: 20, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildSituacaoBadge(garantia),
                const Divider(
                    height: 24, thickness: 1, color: Color(0xFFE2E8F0)),
                _buildDetailRow('Cliente', garantia.clienteNome),
                _buildDetailRow(
                  'Veículo',
                  '${garantia.veiculoNome} - ${garantia.veiculoPlaca}',
                ),
                _buildDetailRow(
                  'Encerramento',
                  DateFormat('dd/MM/yyyy').format(garantia.dataEncerramento),
                ),
                _buildDetailRow(
                  'Fim Garantia',
                  DateFormat('dd/MM/yyyy').format(garantia.dataFimGarantia),
                ),
                _buildDetailRow(
                    'Mecânico', garantia.mecanicoNome ?? 'Não informado'),
                if (garantia.consultorNome != null)
                  _buildDetailRow('Consultor', garantia.consultorNome!),
                const SizedBox(height: 12),
                const Text(
                  'Serviços',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...garantia.servicos.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                            child: Text(s.nome,
                                style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                  ),
                ),
                if (garantia.isReclamada &&
                    (garantia.retornoMotivo ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Motivo do Retorno',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFF59E0B)
                              .withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      garantia.retornoMotivo!,
                      style: const TextStyle(
                          fontSize: 14, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 11),
                    ),
                    child: const Text('Fechar',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildSituacaoBadge(GarantiaResumo garantia) {
    final Color badgeColor = garantia.isReclamada
        ? amberColor
        : garantia.isExpirada
            ? expiradaColor
            : emeraldColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        garantia.statusGarantia,
        style: TextStyle(
            color: badgeColor,
            fontWeight: FontWeight.w700,
            fontSize: 11),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _mostrarModalRetorno(GarantiaResumo garantia) {
    if (garantia.servicos.isEmpty) {
      _showWarningSnackBar('Não há serviços cadastrados nesta OS.');
      return;
    }

    int selectedServicoId = garantia.servicos.first.id;
    final motivoController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: amberColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.replay,
                                color: amberColor, size: 18),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Registrar Retorno',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18),
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.of(dialogCtx).pop(),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close,
                                  size: 20, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                      const Divider(
                          height: 28,
                          thickness: 1,
                          color: Color(0xFFE2E8F0)),
                      const Text(
                        'Serviço da OS',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: selectedServicoId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: primaryColor, width: 1.5)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                        items: garantia.servicos
                            .map(
                              (s) => DropdownMenuItem<int>(
                                value: s.id,
                                child: Text(s.nome),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setStateDialog(() => selectedServicoId = value);
                        },
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Descrição do retorno',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: motivoController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Ex: parafuso solto',
                          hintStyle:
                              const TextStyle(color: Color(0xFFCBD5E1)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: primaryColor, width: 1.5)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogCtx).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                            child: const Text('Cancelar',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final motivo =
                                  motivoController.text.trim();
                              if (motivo.isEmpty) {
                                _showWarningSnackBar('Descreva o motivo do retorno.');
                                return;
                              }
                              final nav = Navigator.of(dialogCtx);
                              final response =
                                  await GarantiaService.registrarRetorno(
                                ordemServicoId: garantia.id,
                                servicoId: selectedServicoId,
                                motivo: motivo,
                              );
                              if (!mounted) return;
                              if (response['success'] == true) {
                                nav.pop();
                                await _carregarGarantias();
                                if (!mounted) return;
                                _showSuccessSnackBar('Retorno registrado com sucesso.');
                              } else {
                                _showErrorSnackBar(
                                  response['message']?.toString() ?? 'Erro ao registrar retorno',
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 11),
                            ),
                            child: const Text('Confirmar',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) => motivoController.dispose());
  }

  void _mostrarModalEditarRetorno(GarantiaResumo garantia) {
    final retornoId = garantia.retornoId;
    if (retornoId == null) return;

    final motivoController =
        TextEditingController(text: garantia.retornoMotivo ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_outlined,
                            color: primaryColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Editar Retorno',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 18),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(dialogCtx).pop(),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close,
                              size: 20, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const Divider(
                      height: 28,
                      thickness: 1,
                      color: Color(0xFFE2E8F0)),
                  const Text(
                    'Descrição do retorno',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: motivoController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: primaryColor, width: 1.5)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        child: const Text('Cancelar',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final motivo = motivoController.text.trim();
                          if (motivo.isEmpty) {
                            _showWarningSnackBar('Descreva o motivo do retorno.');
                            return;
                          }
                          final nav = Navigator.of(dialogCtx);
                          final response =
                              await GarantiaService.editarRetorno(
                            retornoId: retornoId,
                            motivo: motivo,
                          );
                          if (!mounted) return;
                          if (response['success'] == true) {
                            nav.pop();
                            await _carregarGarantias();
                            if (!mounted) return;
                            _showSuccessSnackBar('Retorno atualizado com sucesso.');
                          } else {
                            _showErrorSnackBar(
                              response['message']?.toString() ?? 'Erro ao editar retorno',
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 11),
                        ),
                        child: const Text('Salvar',
                            style:
                                TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) => motivoController.dispose());
  }

  Future<void> _confirmarExcluirRetorno(GarantiaResumo garantia) async {
    final retornoId = garantia.retornoId;
    if (retornoId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Excluir Retorno',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Deseja excluir este registro de retorno? A OS voltará ao status anterior.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: errorColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final response =
        await GarantiaService.deletarRetorno(retornoId: retornoId);

    if (!mounted) return;

    if (response['success'] == true) {
      await _carregarGarantias();
      if (!mounted) return;
      _showSuccessSnackBar('Retorno excluído com sucesso.');
    } else {
      _showErrorSnackBar(
        response['message']?.toString() ?? 'Erro ao excluir retorno',
      );
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Nenhuma garantia encontrada',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
