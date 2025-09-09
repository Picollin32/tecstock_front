class TipoPagamento {
  int? id;
  String nome;
  int? codigo;
  DateTime? createdAt;
  DateTime? updatedAt;

  TipoPagamento({
    this.id,
    required this.nome,
    this.codigo,
    this.createdAt,
    this.updatedAt,
  });

  factory TipoPagamento.fromJson(Map<String, dynamic> json) {
    return TipoPagamento(
      id: json['id'],
      nome: json['nome'],
      codigo: json['codigo'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'codigo': codigo,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'TipoPagamento{id: $id, nome: $nome, codigo: $codigo}';
  }
}
