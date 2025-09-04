class Fabricante {
  int? id;
  String nome;

  Fabricante({this.id, required this.nome});

  factory Fabricante.fromJson(Map<String, dynamic> json) {
    return Fabricante(
      id: json['id'],
      nome: json['nome'],
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
