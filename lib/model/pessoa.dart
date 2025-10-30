abstract class Pessoa {
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

  Pessoa({
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

  Map<String, dynamic> toJsonBase() {
    final map = {
      'id': id,
      'nome': nome,
      'telefone': telefone,
      'email': email,
      'cpf': cpf,
      'dataNascimento': dataNascimento.toIso8601String(),
    };

    if (rua != null) map['rua'] = rua;
    if (numeroCasa != null) map['numeroCasa'] = numeroCasa;
    if (bairro != null) map['bairro'] = bairro;
    if (cidade != null) map['cidade'] = cidade;
    if (uf != null) map['uf'] = uf;

    return map;
  }
}
