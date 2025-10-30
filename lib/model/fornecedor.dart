class Fornecedor {
  int? id;
  String nome;
  String cnpj;
  String telefone;
  String email;
  double? margemLucro;
  String? rua;
  String? numeroCasa;
  String? bairro;
  String? cidade;
  String? uf;
  DateTime? createdAt;
  DateTime? updatedAt;

  Fornecedor({
    this.id,
    required this.nome,
    required this.cnpj,
    required this.telefone,
    required this.email,
    this.margemLucro,
    this.rua,
    this.numeroCasa,
    this.bairro,
    this.cidade,
    this.uf,
    this.createdAt,
    this.updatedAt,
  });

  factory Fornecedor.fromJson(Map<String, dynamic> json) {
    return Fornecedor(
      id: json['id'],
      nome: json['nome'],
      cnpj: json['cnpj'],
      telefone: json['telefone'],
      email: json['email'],
      margemLucro: (json['margemLucro'] as num?)?.toDouble(),
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
    return {
      'id': id,
      'nome': nome,
      'cnpj': cnpj,
      'telefone': telefone,
      'email': email,
      'margemLucro': margemLucro,
      'rua': rua,
      'numeroCasa': numeroCasa,
      'bairro': bairro,
      'cidade': cidade,
      'uf': uf,
    };
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Fornecedor && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
