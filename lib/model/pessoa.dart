abstract class Pessoa {
  int? id;
  String nome;
  String telefone;
  String email;
  String cpf;
  DateTime dataNascimento;
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

  Pessoa({
    this.id,
    required this.nome,
    required this.telefone,
    required this.email,
    required this.cpf,
    required this.dataNascimento,
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

  Map<String, dynamic> toJsonBase() {
    final map = {
      'id': id,
      'nome': nome,
      'telefone': telefone,
      'email': email,
      'cpf': cpf,
      'dataNascimento': dataNascimento.toIso8601String(),
    };

    if (cep != null) map['cep'] = cep;
    if (rua != null) map['rua'] = rua;
    if (numeroCasa != null) map['numeroCasa'] = numeroCasa;
    if (complemento != null) map['complemento'] = complemento;
    if (bairro != null) map['bairro'] = bairro;
    if (cidade != null) map['cidade'] = cidade;
    if (uf != null) map['uf'] = uf;
    if (codigoMunicipio != null) map['codigoMunicipio'] = codigoMunicipio;

    return map;
  }
}
