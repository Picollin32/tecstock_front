class Fabricante {
  int? id;
  String nome;
  DateTime? createdAt;

  Fabricante({this.id, required this.nome, this.createdAt});

  factory Fabricante.fromJson(Map<String, dynamic> json) {
    return Fabricante(
      id: json['id'],
      nome: json['nome'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Fabricante && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
