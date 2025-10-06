class Funcionario {
  int? id;
  String nome;
  String telefone;
  String email;
  String cpf;
  DateTime dataNascimento;
  int nivelAcesso;
  String? rua;
  String? numeroCasa;
  String? bairro;
  String? cidade;
  String? uf;
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
      this.rua,
      this.numeroCasa,
      this.bairro,
      this.cidade,
      this.uf,
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
      rua: json['rua'],
      numeroCasa: json['numeroCasa'],
      bairro: json['bairro'],
      cidade: json['cidade'],
      uf: json['uf'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
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

    if (rua != null) map['rua'] = rua;
    if (numeroCasa != null) map['numeroCasa'] = numeroCasa;
    if (bairro != null) map['bairro'] = bairro;
    if (cidade != null) map['cidade'] = cidade;
    if (uf != null) map['uf'] = uf;

    return map;
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
