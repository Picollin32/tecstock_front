import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import '../model/agendamento.dart';
import '../model/veiculo.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../services/agendamento_service.dart';
import '../services/veiculo_service.dart';

enum AgendamentoStep { calendario, horarios }

class AgendamentoPage extends StatefulWidget {
  const AgendamentoPage({super.key});

  @override
  _AgendamentoPageState createState() => _AgendamentoPageState();
}

class _AgendamentoPageState extends State<AgendamentoPage> with TickerProviderStateMixin {
  late final ValueNotifier<List<Agendamento>> _selectedEvents;

  AgendamentoStep _currentStep = AgendamentoStep.calendario;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<Agendamento>> _events = {};

  List<Veiculo> _veiculos = [];
  final _maskPlaca = MaskTextInputFormatter(
      mask: 'AAA-#X##',
      filter: {"#": RegExp(r'[0-9]'), "A": RegExp(r'[a-zA-Z]'), "X": RegExp(r'[a-zA-Z0-9]')},
      type: MaskAutoCompletionType.lazy);
  final _upperCaseFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  });

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const Color primaryColor = Color(0xFF0F172A);
  static const Color secondaryColor = Color(0xFF6366F1);
  static const Color errorColor = Color(0xFFDC2626);
  static const Color successColor = Color(0xFF16A34A);
  static const Color shadowColor = Color(0x1A000000);

  final Map<String, Map<String, dynamic>> _serviceTypes = {
    "Troca de Peça": {
      'color': const Color(0xFF16A34A),
      'icon': Icons.build_circle,
      'lightColor': const Color(0xFFDCFCE7),
    },
    "Diagnóstico": {
      'color': const Color(0xFFF59E0B),
      'icon': Icons.search,
      'lightColor': const Color(0xFFFEF3C7),
    },
    "Revisão": {
      'color': const Color(0xFFDC2626),
      'icon': Icons.checklist_rtl,
      'lightColor': const Color(0xFFFEE2E2),
    },
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _initializeAnimations();
    _loadEvents();
    _carregarVeiculos();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    _fadeController.forward();
  }

  Future<void> _carregarVeiculos() async {
    final lista = await VeiculoService.listarVeiculos();
    setState(() {
      _veiculos = lista.reversed.toList();
    });
  }

  @override
  void dispose() {
    _selectedEvents.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final agendamentos = await AgendamentoService.listarAgendamentos();
      setState(() {
        _events.clear();
        for (var agendamento in agendamentos) {
          final date = DateTime.utc(agendamento.data.year, agendamento.data.month, agendamento.data.day);
          _events.putIfAbsent(date, () => []).add(agendamento);
        }
        _selectedEvents.value = _getEventsForDay(_selectedDay!);
      });
    } catch (e) {
      _showErrorSnackBar('Erro ao carregar agendamentos');
    }
  }

  List<Agendamento> _getEventsForDay(DateTime day) {
    return _events[DateTime.utc(day.year, day.month, day.day)] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay) || _currentStep == AgendamentoStep.calendario) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _currentStep = AgendamentoStep.horarios;
      });
      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  Map<String, dynamic> _getServiceInfo(String service) {
    return _serviceTypes[service] ??
        {
          'color': Colors.grey,
          'icon': Icons.work,
          'lightColor': Colors.grey[100],
        };
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: errorColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _currentStep == AgendamentoStep.calendario ? 'Calendário de Agendamentos' : 'Horários do Dia',
          style: const TextStyle(
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
        child: Column(
          children: [
            if (_currentStep == AgendamentoStep.horarios) _buildBackButton(),
            Expanded(child: _buildCurrentStepView()),
            if (_currentStep == AgendamentoStep.calendario) _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.arrow_back),
          label: const Text("Voltar para o Calendário"),
          onPressed: () => setState(() => _currentStep = AgendamentoStep.calendario),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: primaryColor,
            elevation: 2,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case AgendamentoStep.calendario:
        return _buildCalendarView();
      case AgendamentoStep.horarios:
        return _buildHorariosView();
    }
  }

  Widget _buildCalendarView() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Selecione uma Data',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TableCalendar<Agendamento>(
              locale: 'pt_BR',
              startingDayOfWeek: StartingDayOfWeek.monday,
              availableCalendarFormats: const {
                CalendarFormat.month: 'Mês',
                CalendarFormat.twoWeeks: '2 semanas',
                CalendarFormat.week: 'Semana',
              },
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonTextStyle: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
                formatButtonDecoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: primaryColor),
                rightChevronIcon: Icon(Icons.chevron_right, color: primaryColor),
                titleTextStyle: TextStyle(
                  color: primaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                weekendTextStyle: const TextStyle(color: Colors.red),
                holidayTextStyle: const TextStyle(color: Colors.red),
                selectedDecoration: BoxDecoration(
                  color: secondaryColor,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: successColor,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                weekendStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
                dowTextFormatter: (date, locale) {
                  const labels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
                  return labels[date.weekday - 1];
                },
              ),
              firstDay: DateTime.utc(2020),
              lastDay: DateTime.utc(2030),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: _getEventsForDay,
              onDaySelected: _onDaySelected,
              onFormatChanged: (format) => setState(() => _calendarFormat = format),
              onPageChanged: (focusedDay) => _focusedDay = focusedDay,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorariosView() {
    final agendamentosDodia = _getEventsForDay(_selectedDay!);
    final agendamentosOrdenados = List<Agendamento>.from(agendamentosDodia);

    agendamentosOrdenados.sort((a, b) {
      final horaA = a.horaInicio ?? '00:00';
      final horaB = b.horaInicio ?? '00:00';
      return horaA.compareTo(horaB);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [secondaryColor, secondaryColor.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: secondaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
                  child: const Icon(Icons.today, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(_selectedDay!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.schedule, color: Colors.white.withOpacity(0.9), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${agendamentosDodia.length} agendamento${agendamentosDodia.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (agendamentosDodia.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${_calculateDuration(agendamentosOrdenados)}h',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (agendamentosOrdenados.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Cronograma do Dia',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildTimeline(agendamentosOrdenados),
          ] else
            _buildEnhancedEmptyState(),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [secondaryColor, secondaryColor.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: secondaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 24),
              label: const Text(
                'Novo Agendamento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: () => _showHorarioSelectionDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (agendamentosOrdenados.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildQuickStats(agendamentosOrdenados),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];

    return '${date.day} de ${months[date.month - 1]}';
  }

  String _calculateDuration(List<Agendamento> agendamentos) {
    if (agendamentos.isEmpty) return '0.0';

    double totalHours = 0;
    for (var agendamento in agendamentos) {
      if (agendamento.horaInicio != null &&
          agendamento.horaFim != null &&
          agendamento.horaInicio!.isNotEmpty &&
          agendamento.horaFim!.isNotEmpty) {
        final inicio = _parseTime(agendamento.horaInicio!);
        final fim = _parseTime(agendamento.horaFim!);
        if (inicio != null && fim != null) {
          final diffMinutes = fim.difference(inicio).inMinutes;
          if (diffMinutes > 0) {
            totalHours += diffMinutes / 60.0;
          } else {
            totalHours += 1.0;
          }
        } else {
          totalHours += 1.0;
        }
      } else {
        totalHours += 1.0;
      }
    }

    return totalHours.toStringAsFixed(1);
  }

  DateTime? _parseTime(String timeStr) {
    try {
      final cleanTime = timeStr.trim();
      if (cleanTime.isEmpty) return null;

      final parts = cleanTime.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);

        if (hour != null && minute != null && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
          return DateTime(2023, 1, 1, hour, minute);
        }
      }

      print('Erro ao fazer parse do horário: $timeStr');
      return null;
    } catch (e) {
      print('Erro ao fazer parse do horário $timeStr: $e');
      return null;
    }
  }

  String? _formatarHorario(String? horario) {
    if (horario == null || horario.trim().isEmpty) {
      return null;
    }

    try {
      final cleanTime = horario.trim();

      if (cleanTime.contains(':')) {
        final parts = cleanTime.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);

          if (hour != null && minute != null && hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
            return "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
          }
        }
      }

      print('Erro ao formatar horário: $horario');
      return null;
    } catch (e) {
      print('Erro ao formatar horário $horario: $e');
      return null;
    }
  }

  Widget _buildTimeline(List<Agendamento> agendamentos) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: agendamentos.length,
      itemBuilder: (context, index) {
        final agendamento = agendamentos[index];
        final isLast = index == agendamentos.length - 1;

        return _buildTimelineItem(agendamento, isLast);
      },
    );
  }

  Widget _buildTimelineItem(Agendamento agendamento, bool isLast) {
    final serviceInfo = _getServiceInfo(agendamento.cor);
    final horaDisplay = agendamento.horaInicio != null
        ? (agendamento.horaFim != null ? '${agendamento.horaInicio} - ${agendamento.horaFim}' : agendamento.horaInicio!)
        : '--:--';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: serviceInfo['color'],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: serviceInfo['color'].withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: serviceInfo['color'].withOpacity(0.2)),
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
                  onTap: () => _showAgendamentoDialog(horaDisplay, agendamento),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: serviceInfo['lightColor'],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                serviceInfo['icon'],
                                color: serviceInfo['color'],
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        horaDisplay,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: serviceInfo['lightColor'],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      agendamento.cor,
                                      style: TextStyle(
                                        color: serviceInfo['color'],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.grey[400],
                              size: 16,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailItem(
                                Icons.directions_car,
                                'Veículo',
                                agendamento.placaVeiculo,
                                Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDetailItem(
                                Icons.person,
                                'Mecânico',
                                agendamento.nomeMecanico,
                                Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: secondaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_available,
              size: 64,
              color: secondaryColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhum agendamento',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[800],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Este dia está livre para novos agendamentos',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: successColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Disponível',
                  style: TextStyle(
                    color: successColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(List<Agendamento> agendamentos) {
    final serviceStats = <String, int>{};
    for (var agendamento in agendamentos) {
      serviceStats[agendamento.cor] = (serviceStats[agendamento.cor] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Resumo do Dia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: serviceStats.entries.map((entry) {
              final serviceInfo = _getServiceInfo(entry.key);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: serviceInfo['lightColor'],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: serviceInfo['color'].withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(serviceInfo['icon'], color: serviceInfo['color'], size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${entry.value}x ${entry.key}',
                      style: TextStyle(
                        color: serviceInfo['color'],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tipos de Serviço',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: _serviceTypes.entries.map((entry) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(entry.value['icon'], color: entry.value['color'], size: 16),
                  const SizedBox(width: 6),
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showHorarioSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        TimeOfDay start = const TimeOfDay(hour: 8, minute: 0);
        TimeOfDay end = const TimeOfDay(hour: 9, minute: 0);

        return StatefulBuilder(builder: (context, setDialogState) {
          Future<void> pickStart() async {
            final picked = await showTimePicker(
              context: context,
              initialTime: start,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: secondaryColor,
                      onPrimary: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) setDialogState(() => start = picked);
          }

          Future<void> pickEnd() async {
            final picked = await showTimePicker(
              context: context,
              initialTime: end,
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: secondaryColor,
                      onPrimary: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) setDialogState(() => end = picked);
          }

          int toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

          return Theme(
            data: Theme.of(context).copyWith(
              dialogTheme: DialogTheme(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
              ),
            ),
            child: AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.access_time, color: secondaryColor),
                  const SizedBox(width: 12),
                  const Text('Selecione o horário'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.play_arrow, color: successColor),
                    title: const Text('Início'),
                    subtitle: Text(start.format(context)),
                    trailing: IconButton(
                      icon: Icon(Icons.access_time, color: secondaryColor),
                      onPressed: pickStart,
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.stop, color: errorColor),
                    title: const Text('Fim'),
                    subtitle: Text(end.format(context)),
                    trailing: IconButton(
                      icon: Icon(Icons.access_time, color: secondaryColor),
                      onPressed: pickEnd,
                    ),
                  ),
                  if (toMinutes(end) <= toMinutes(start))
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: errorColor, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Fim deve ser depois do início',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: toMinutes(end) > toMinutes(start)
                      ? () {
                          final horarioRange = '${start.format(context)} - ${end.format(context)}';
                          Navigator.pop(context);
                          _showAgendamentoDialog(horarioRange, null);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: secondaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Selecionar'),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showAgendamentoDialog(String horario, Agendamento? agendamentoExistente) {
    final placaController = TextEditingController(text: agendamentoExistente?.placaVeiculo);
    final mecanicoController = TextEditingController(text: agendamentoExistente?.nomeMecanico);
    String? selectedService = agendamentoExistente?.cor;

    String? inicioPref = agendamentoExistente?.horaInicio;
    String? fimPref = agendamentoExistente?.horaFim;

    if (horario.contains(' - ')) {
      final parts = horario.split(' - ');
      inicioPref = inicioPref ?? parts[0].trim();
      fimPref = fimPref ?? parts[1].trim();
    } else {
      inicioPref = inicioPref ?? horario;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Theme(
              data: Theme.of(context).copyWith(
                dialogTheme: DialogTheme(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
              ),
              child: AlertDialog(
                title: Row(
                  children: [
                    Icon(
                      agendamentoExistente != null ? Icons.edit : Icons.add_circle,
                      color: secondaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('${agendamentoExistente != null ? "Editar" : "Agendar"} às $horario'),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final query = _maskPlaca.unmaskText(textEditingValue.text).toUpperCase();
                          if (query.isEmpty) return const Iterable<String>.empty();
                          return _veiculos.map((v) => v.placa).where((placa) {
                            final placaSemMascara = placa.replaceAll('-', '');
                            return placaSemMascara.toUpperCase().contains(query);
                          });
                        },
                        displayStringForOption: (option) => option,
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          if (textEditingController.text.isEmpty && placaController.text.isNotEmpty) {
                            textEditingController.text = placaController.text;
                            textEditingController.selection = placaController.selection;
                          }
                          textEditingController.addListener(() {
                            if (placaController.text != textEditingController.text) {
                              placaController.text = textEditingController.text;
                              placaController.selection = textEditingController.selection;
                            }
                          });

                          return TextField(
                            controller: textEditingController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Placa do Carro',
                              prefixIcon: Icon(Icons.directions_car, color: secondaryColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            inputFormatters: [_maskPlaca, _upperCaseFormatter],
                            textCapitalization: TextCapitalization.characters,
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          final optList = options.toList();
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(8),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 220),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: optList.length,
                                  itemBuilder: (context, index) {
                                    final option = optList[index];
                                    return ListTile(
                                      dense: true,
                                      title: Text(option),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                        onSelected: (String selection) {
                          placaController.text = selection;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: mecanicoController,
                        decoration: InputDecoration(
                          labelText: 'Mecânico',
                          prefixIcon: Icon(Icons.person, color: secondaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: inicioPref,
                              decoration: InputDecoration(
                                labelText: 'Início (HH:mm)',
                                prefixIcon: Icon(Icons.play_arrow, color: successColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onChanged: (v) => inicioPref = v,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              initialValue: fimPref,
                              decoration: InputDecoration(
                                labelText: 'Fim (HH:mm)',
                                prefixIcon: Icon(Icons.stop, color: errorColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onChanged: (v) => fimPref = v,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedService,
                        hint: const Text("Selecione o tipo de serviço"),
                        onChanged: (value) => setDialogState(() => selectedService = value),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.build, color: secondaryColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: _serviceTypes.entries.map((entry) {
                          final serviceInfo = entry.value;
                          return DropdownMenuItem(
                            value: entry.key,
                            child: Row(
                              children: [
                                Icon(serviceInfo['icon'], color: serviceInfo['color'], size: 20),
                                const SizedBox(width: 8),
                                Text(entry.key),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                actionsAlignment: MainAxisAlignment.spaceBetween,
                actions: [
                  if (agendamentoExistente != null)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(agendamentoExistente.id!),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (placaController.text.isNotEmpty && mecanicoController.text.isNotEmpty && selectedService != null) {
                            String? horaInicioFormatada = _formatarHorario(inicioPref);
                            String? horaFimFormatada = _formatarHorario(fimPref);

                            horaInicioFormatada ??= "08:00";

                            if (horaFimFormatada == null) {
                              final inicio = _parseTime(horaInicioFormatada);
                              if (inicio != null) {
                                final fim = inicio.add(const Duration(hours: 1));
                                horaFimFormatada = "${fim.hour.toString().padLeft(2, '0')}:${fim.minute.toString().padLeft(2, '0')}";
                              } else {
                                horaFimFormatada = "09:00";
                              }
                            }

                            final agendamento = Agendamento(
                              id: agendamentoExistente?.id,
                              data: _selectedDay!,
                              horaInicio: horaInicioFormatada,
                              horaFim: horaFimFormatada,
                              placaVeiculo: placaController.text,
                              nomeMecanico: mecanicoController.text,
                              cor: selectedService!,
                            );

                            bool sucesso;
                            if (agendamentoExistente != null && agendamentoExistente.id != null) {
                              sucesso = await AgendamentoService.atualizarAgendamento(agendamentoExistente.id!, agendamento);
                              _showSuccessSnackBar(sucesso ? 'Agendamento atualizado com sucesso' : 'Erro ao atualizar agendamento');
                            } else {
                              sucesso = await AgendamentoService.salvarAgendamento(agendamento);
                              _showSuccessSnackBar(sucesso ? 'Agendamento salvo com sucesso' : 'Erro ao salvar agendamento');
                            }

                            if (sucesso) {
                              Navigator.pop(context);
                              _loadEvents();
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: secondaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Salvar'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(int id) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => Theme(
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
              const Text("Confirmar Exclusão"),
            ],
          ),
          content: const Text("Você tem certeza que deseja excluir este agendamento?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: errorColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                AgendamentoService.excluirAgendamento(id).then((_) {
                  Navigator.pop(context);
                  _loadEvents();
                  _showSuccessSnackBar("Agendamento excluído com sucesso!");
                }).catchError((e) {
                  _showErrorSnackBar("Erro ao excluir: $e");
                });
              },
              child: const Text("Excluir"),
            ),
          ],
        ),
      ),
    );
  }
}
