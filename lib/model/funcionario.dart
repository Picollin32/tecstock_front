class Funcionario {
  int? id;
  String nome;
  String telefone;
  String email;
  String cpf;
  DateTime dataNascimento;
  int nivelAcesso;
  DateTime? createdAt;
  DateTime? updatedAt;

  Funcionario(
      {this.id,
      required this.nome,
      required this.telefone,
      required this.email,
      required this.cpf,
      required this.dataNascimento,
      required this.nivelAcesso,
      this.createdAt,
      this.updatedAt});

  factory Funcionario.fromJson(Map<String, dynamic> json) {
    return Funcionario(
      id: json['id'],
      nome: json['nome'],
      telefone: json['telefone'],
      email: json['email'],
      cpf: json['cpf'],
      dataNascimento: DateTime.parse(json['dataNascimento']),
      nivelAcesso: json['nivelAcesso'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'telefone': telefone,
      'email': email,
      'cpf': cpf,
      'dataNascimento': dataNascimento.toIso8601String(),
      'nivelAcesso': nivelAcesso,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Funcionario) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Funcionario{id: $id, nome: $nome}';
  }
}
