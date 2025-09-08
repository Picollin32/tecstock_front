class Agendamento {
  final int? id;
  final DateTime data;
  final String? horaInicio;
  final String? horaFim;
  final String placaVeiculo;
  final String nomeMecanico;
  final String? nomeConsultor;
  final String cor;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Agendamento({
    this.id,
    required this.data,
    this.horaInicio,
    this.horaFim,
    required this.placaVeiculo,
    required this.nomeMecanico,
    this.nomeConsultor,
    required this.cor,
    this.createdAt,
    this.updatedAt,
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
      nomeConsultor: json['nomeConsultor'],
      cor: json['cor'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'id': id,
      'data': data.toIso8601String(),
      'placaVeiculo': placaVeiculo,
      'nomeMecanico': nomeMecanico,
      'nomeConsultor': nomeConsultor,
      'cor': cor,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
    if (horaInicio != null) map['horaInicio'] = horaInicio;
    if (horaFim != null) map['horaFim'] = horaFim;
    return map;
  }
}
