class Agendamento {
  final int? id;
  final DateTime data;
  final String? horaInicio;
  final String? horaFim;
  final String placaVeiculo;
  final String nomeMecanico;
  final String cor;
  final DateTime? createdAt;

  Agendamento({
    this.id,
    required this.data,
    this.horaInicio,
    this.horaFim,
    required this.placaVeiculo,
    required this.nomeMecanico,
    required this.cor,
    this.createdAt,
  });

  factory Agendamento.fromJson(Map<String, dynamic> json) {
    String? horaInicio;
    String? horaFim;
    if (json.containsKey('horaInicio')) {
      horaInicio = json['horaInicio'];
      horaFim = json['horaFim'];
    } else if (json.containsKey('hora')) {
      horaInicio = json['hora'];
      horaFim = null;
    }

    return Agendamento(
      id: json['id'],
      data: DateTime.parse(json['data']),
      horaInicio: horaInicio,
      horaFim: horaFim,
      placaVeiculo: json['placaVeiculo'],
      nomeMecanico: json['nomeMecanico'],
      cor: json['cor'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'id': id,
      'data': data.toIso8601String(),
      'placaVeiculo': placaVeiculo,
      'nomeMecanico': nomeMecanico,
      'cor': cor,
      'createdAt': createdAt?.toIso8601String(),
    };
    if (horaInicio != null) map['horaInicio'] = horaInicio;
    if (horaFim != null) map['horaFim'] = horaFim;
    return map;
  }
}
