class Fornecedor {
  int? id;
  String nome;
  String cnpj;
  String telefone;
  String email;
  double? margemLucro;
  String? cep;
  String? rua;
  String? numeroCasa;
  String? complemento;
  String? bairro;
  String? cidade;
  String? uf;
  String? codigoMunicipio;
  DateTime? createdAt;
  DateTime? updatedAt;

  Fornecedor({
    this.id,
    required this.nome,
    required this.cnpj,
    required this.telefone,
    required this.email,
    this.margemLucro,
    this.cep,
    this.rua,
    this.numeroCasa,
    this.complemento,
    this.bairro,
    this.cidade,
    this.uf,
    this.codigoMunicipio,
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
      cep: json['cep'],
      rua: json['rua'],
      numeroCasa: json['numeroCasa'],
      complemento: json['complemento'],
      bairro: json['bairro'],
      cidade: json['cidade'],
      uf: json['uf'],
      codigoMunicipio: json['codigoMunicipio'],
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
      'cep': cep,
      'rua': rua,
      'numeroCasa': numeroCasa,
      'complemento': complemento,
      'bairro': bairro,
      'cidade': cidade,
      'uf': uf,
      'codigoMunicipio': codigoMunicipio,
    };
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Fornecedor && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
