class DiagnosticoItem {
  int? id;
  String descricao;
  double valor;

  DiagnosticoItem({
    this.id,
    required this.descricao,
    required this.valor,
  });

  factory DiagnosticoItem.fromJson(Map<String, dynamic> json) {
    return DiagnosticoItem(
      id: json['id'],
      descricao: json['descricao'] ?? '',
      valor: (json['valor'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'descricao': descricao,
      'valor': valor,
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }
}
