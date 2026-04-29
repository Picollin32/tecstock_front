class GarantiaServicoResumo {
  final int id;
  final String nome;

  GarantiaServicoResumo({
    required this.id,
    required this.nome,
  });

  factory GarantiaServicoResumo.fromJson(Map<String, dynamic> json) {
    return GarantiaServicoResumo(
      id: json['id'] ?? 0,
      nome: json['nome'] ?? '',
    );
  }
}

class GarantiaResumo {
  final int id;
  final String numeroOS;
  final String clienteNome;
  final String veiculoNome;
  final String veiculoPlaca;
  final DateTime dataEncerramento;
  final DateTime dataInicioGarantia;
  final DateTime dataFimGarantia;
  final int garantiaMeses;
  final String statusOS;
  final String statusGarantia;
  final String? mecanicoNome;
  final String? consultorNome;
  final List<GarantiaServicoResumo> servicos;
  final int? retornoServicoId;
  final String? retornoServicoNome;
  final String? retornoMotivo;
  final int? retornoId;

  GarantiaResumo({
    required this.id,
    required this.numeroOS,
    required this.clienteNome,
    required this.veiculoNome,
    required this.veiculoPlaca,
    required this.dataEncerramento,
    required this.dataInicioGarantia,
    required this.dataFimGarantia,
    required this.garantiaMeses,
    required this.statusOS,
    required this.statusGarantia,
    this.mecanicoNome,
    this.consultorNome,
    required this.servicos,
    this.retornoServicoId,
    this.retornoServicoNome,
    this.retornoMotivo,
    this.retornoId,
  });

  factory GarantiaResumo.fromJson(Map<String, dynamic> json) {
    return GarantiaResumo(
      id: json['id'] ?? 0,
      numeroOS: json['numeroOS']?.toString() ?? '',
      clienteNome: json['clienteNome'] ?? '',
      veiculoNome: json['veiculoNome'] ?? '',
      veiculoPlaca: json['veiculoPlaca'] ?? '',
      dataEncerramento: DateTime.parse(json['dataEncerramento']),
      dataInicioGarantia: DateTime.parse(json['dataInicioGarantia']),
      dataFimGarantia: DateTime.parse(json['dataFimGarantia']),
      garantiaMeses: json['garantiaMeses'] ?? 0,
      statusOS: json['statusOS'] ?? '',
      statusGarantia: json['statusGarantia'] ?? '',
      mecanicoNome: json['mecanicoNome'],
      consultorNome: json['consultorNome'],
      servicos: (json['servicos'] as List?)?.map((s) => GarantiaServicoResumo.fromJson(s)).toList() ?? [],
      retornoServicoId: json['retornoServicoId'],
      retornoServicoNome: json['retornoServicoNome'],
      retornoMotivo: json['retornoMotivo'],
      retornoId: json['retornoId'],
    );
  }

  bool get isAtiva => statusGarantia.toLowerCase() == 'ativa';
  bool get isReclamada => statusGarantia.toLowerCase() == 'reclamada';
  bool get isExpirada => statusGarantia.toLowerCase() == 'expirada';
}

class GarantiaResumoTotal {
  final int total;
  final int ativas;
  final int reclamadas;
  final int expiradas;

  GarantiaResumoTotal({
    required this.total,
    required this.ativas,
    required this.reclamadas,
    required this.expiradas,
  });

  factory GarantiaResumoTotal.fromJson(Map<String, dynamic> json) {
    return GarantiaResumoTotal(
      total: json['total'] ?? 0,
      ativas: json['ativas'] ?? 0,
      reclamadas: json['reclamadas'] ?? 0,
      expiradas: json['expiradas'] ?? 0,
    );
  }
}
