class Fabricante {
  int? id;
  String nome;
  DateTime? createdAt;
  DateTime? updatedAt;

  Fabricante({this.id, required this.nome, this.createdAt, this.updatedAt});

  factory Fabricante.fromJson(Map<String, dynamic> json) {
    return Fabricante(
      id: json['id'],
      nome: json['nome'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
    };
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Fabricante && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
