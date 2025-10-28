import 'pessoa.dart';

class Cliente extends Pessoa {
  Cliente({
    super.id,
    required super.nome,
    required super.telefone,
    required super.email,
    required super.cpf,
    required super.dataNascimento,
    super.rua,
    super.numeroCasa,
    super.bairro,
    super.cidade,
    super.uf,
    super.createdAt,
    super.updatedAt,
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
    return super.toJsonBase();
  }
}
