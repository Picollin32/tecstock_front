import 'pessoa.dart';

class Funcionario extends Pessoa {
  int nivelAcesso;

  Funcionario({
    super.id,
    required super.nome,
    required super.telefone,
    required super.email,
    required super.cpf,
    required super.dataNascimento,
    required this.nivelAcesso,
    super.rua,
    super.numeroCasa,
    super.bairro,
    super.cidade,
    super.uf,
    super.createdAt,
    super.updatedAt,
  });

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
    final map = super.toJsonBase();
    map['nivelAcesso'] = nivelAcesso;
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
