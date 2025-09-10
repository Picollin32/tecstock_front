class Servico {
  int? id;
  String nome;
  double? precoPasseio;
  double? precoCaminhonete;
  DateTime? createdAt;
  DateTime? updatedAt;

  Servico({
    this.id,
    required this.nome,
    this.precoPasseio,
    this.precoCaminhonete,
    this.createdAt,
    this.updatedAt,
  });

  factory Servico.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(',', '.'));
    }

    return Servico(
      id: json['id'],
      nome: json['nome'] ?? '',
      precoPasseio: parseDouble(json['precoPasseio']),
      precoCaminhonete: parseDouble(json['precoCaminhonete']),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'precoPasseio': precoPasseio,
      'precoCaminhonete': precoCaminhonete,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Servico && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
