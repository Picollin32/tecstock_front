class Cliente {
  int? id;
  String nome;
  String telefone;
  String email;
  String cpf;
  DateTime dataNascimento;
  String? rua;
  String? numeroCasa;
  String? bairro;
  String? cidade;
  String? uf;
  DateTime? createdAt;
  DateTime? updatedAt;

  Cliente({
    this.id,
    required this.nome,
    required this.telefone,
    required this.email,
    required this.cpf,
    required this.dataNascimento,
    this.rua,
    this.numeroCasa,
    this.bairro,
    this.cidade,
    this.uf,
    this.createdAt,
    this.updatedAt,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id'],
      nome: json['nome'],
      telefone: json['telefone'],
      email: json['email'],
      cpf: json['cpf'],
      dataNascimento: DateTime.parse(json['dataNascimento']),
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
}
