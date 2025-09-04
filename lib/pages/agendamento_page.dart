import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../model/agendamento.dart';
import '../model/veiculo.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../services/agendamento_service.dart';
import '../services/veiculo_service.dart';

enum AgendamentoStep { calendario, horarios }

class AgendamentoPage extends StatefulWidget {
  const AgendamentoPage({super.key});

  @override
  _AgendamentoPageState createState() => _AgendamentoPageState();
}

class _AgendamentoPageState extends State<AgendamentoPage> {
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

  final Map<String, Color> _serviceColors = {
    "Troca de Peça": Colors.green,
    "Diagnóstico": Colors.yellow,
    "Revisão": Colors.red,
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _loadEvents();
    _carregarVeiculos();
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
    super.dispose();
  }

  Future<void> _loadEvents() async {
    final agendamentos = await AgendamentoService.listarAgendamentos();
    setState(() {
      _events.clear();
      for (var agendamento in agendamentos) {
        final date = DateTime.utc(agendamento.data.year, agendamento.data.month, agendamento.data.day);
        _events.putIfAbsent(date, () => []).add(agendamento);
      }
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    });
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

  Color _stringToColor(String service) {
    return _serviceColors[service] ?? Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_currentStep == AgendamentoStep.horarios)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text("Voltar para o Calendário"),
                onPressed: () => setState(() => _currentStep = AgendamentoStep.calendario),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
            ),
          Expanded(child: _buildCurrentStepView()),
          _buildLegend(),
        ],
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
    return TableCalendar<Agendamento>(
      locale: 'pt_BR',
      startingDayOfWeek: StartingDayOfWeek.monday,
      availableCalendarFormats: const {
        CalendarFormat.month: 'Mês',
        CalendarFormat.twoWeeks: '2 semanas',
        CalendarFormat.week: 'Semana',
      },
      headerStyle: const HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: const TextStyle(fontWeight: FontWeight.bold),
        weekendStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
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
    );
  }

  Widget _buildHorariosView() {
    final agendamentosDodia = _getEventsForDay(_selectedDay!);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Agendamentos para ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              if (agendamentosDodia.isNotEmpty)
                ...agendamentosDodia.map((agendamento) {
                  final horaDisplay = agendamento.horaInicio != null
                      ? (agendamento.horaFim != null ? '${agendamento.horaInicio} - ${agendamento.horaFim}' : agendamento.horaInicio)
                      : '';

                  return ListTile(
                    leading: Icon(Icons.calendar_today, color: _stringToColor(agendamento.cor)),
                    title: Text('$horaDisplay - ${agendamento.placaVeiculo}'),
                    subtitle: Text('Mecânico: ${agendamento.nomeMecanico}\nServiço: ${agendamento.cor}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showAgendamentoDialog(horaDisplay ?? '', agendamento),
                    ),
                  );
                })
              else
                const ListTile(
                  leading: Icon(Icons.info),
                  title: Text('Nenhum agendamento para este dia'),
                ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Novo Agendamento'),
                  onPressed: () => _showHorarioSelectionDialog(),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
            final picked = await showTimePicker(context: context, initialTime: start);
            if (picked != null) setDialogState(() => start = picked);
          }

          Future<void> pickEnd() async {
            final picked = await showTimePicker(context: context, initialTime: end);
            if (picked != null) setDialogState(() => end = picked);
          }

          int toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

          return AlertDialog(
            title: const Text('Selecione o horário de cobertura'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Início'),
                  subtitle: Text(start.format(context)),
                  trailing: IconButton(icon: const Icon(Icons.access_time), onPressed: pickStart),
                ),
                ListTile(
                  title: const Text('Fim'),
                  subtitle: Text(end.format(context)),
                  trailing: IconButton(icon: const Icon(Icons.access_time), onPressed: pickEnd),
                ),
                const SizedBox(height: 8),
                if (toMinutes(end) <= toMinutes(start)) const Text('Fim deve ser depois do início', style: TextStyle(color: Colors.red)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              TextButton(
                onPressed: toMinutes(end) > toMinutes(start)
                    ? () {
                        final horarioRange = '${start.format(context)} - ${end.format(context)}';
                        Navigator.pop(context);
                        _showAgendamentoDialog(horarioRange, null);
                      }
                    : null,
                child: const Text('Selecionar'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _serviceColors.entries.map((entry) {
          return Row(
            children: [
              Icon(Icons.circle, color: entry.value, size: 16),
              const SizedBox(width: 4),
              Text(entry.key),
            ],
          );
        }).toList(),
      ),
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
            return AlertDialog(
              title: Text('${agendamentoExistente != null ? "Editar" : "Agendar"} às $horario'),
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
                          decoration: const InputDecoration(labelText: 'Placa do Carro'),
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
                    TextField(controller: mecanicoController, decoration: const InputDecoration(labelText: 'Mecânico')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: inicioPref,
                            decoration: const InputDecoration(labelText: 'Início (HH:mm)'),
                            onChanged: (v) => inicioPref = v,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: fimPref,
                            decoration: const InputDecoration(labelText: 'Fim (HH:mm)'),
                            onChanged: (v) => fimPref = v,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedService,
                      hint: const Text("Selecione a modalidade"),
                      onChanged: (value) => setDialogState(() => selectedService = value),
                      items: _serviceColors.keys.map((service) {
                        return DropdownMenuItem(value: service, child: Text(service));
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
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                    TextButton(
                      onPressed: () async {
                        if (placaController.text.isNotEmpty && mecanicoController.text.isNotEmpty && selectedService != null) {
                          final agendamento = Agendamento(
                            id: agendamentoExistente?.id,
                            data: _selectedDay!,
                            horaInicio: inicioPref,
                            horaFim: fimPref,
                            placaVeiculo: placaController.text,
                            nomeMecanico: mecanicoController.text,
                            cor: selectedService!,
                          );

                          bool sucesso;
                          if (agendamentoExistente != null && agendamentoExistente.id != null) {
                            sucesso = await AgendamentoService.atualizarAgendamento(agendamentoExistente.id!, agendamento);
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(sucesso ? 'Agendamento atualizado com sucesso' : 'Erro ao atualizar agendamento')));
                          } else {
                            sucesso = await AgendamentoService.salvarAgendamento(agendamento);
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(sucesso ? 'Agendamento salvo com sucesso' : 'Erro ao salvar agendamento')));
                          }

                          if (sucesso) {
                            Navigator.pop(context);
                            _loadEvents();
                          }
                        }
                      },
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
              ],
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
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Exclusão"),
        content: const Text("Você tem certeza que deseja excluir este agendamento?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Não")),
          TextButton(
            onPressed: () {
              AgendamentoService.excluirAgendamento(id).then((_) {
                Navigator.pop(context);
                _loadEvents();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Agendamento excluído com sucesso!")),
                );
              }).catchError((e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Erro ao excluir: $e")),
                );
              });
            },
            child: const Text("Sim, Excluir"),
          ),
        ],
      ),
    );
  }
}
