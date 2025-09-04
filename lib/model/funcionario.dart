class Funcionario {
  int? id;
  String nome;
  String telefone;
  String email;
  String cpf;
  DateTime dataNascimento;
  int nivelAcesso;

  Funcionario(
      {this.id,
      required this.nome,
      required this.telefone,
      required this.email,
      required this.cpf,
      required this.dataNascimento,
      required this.nivelAcesso});

  factory Funcionario.fromJson(Map<String, dynamic> json) {
    return Funcionario(
      id: json['id'],
      nome: json['nome'],
      telefone: json['telefone'],
      email: json['email'],
      cpf: json['cpf'],
      dataNascimento: DateTime.parse(json['dataNascimento']),
      nivelAcesso: json['nivelAcesso'],
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
    };
  }
}
