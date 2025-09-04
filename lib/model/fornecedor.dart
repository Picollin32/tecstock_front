import 'fornecedor_peca.dart';

class Fornecedor {
  int? id;
  String nome;
  String cnpj;
  String telefone;
  String email;
  double? margemLucro;
  List<FornecedorPeca>? pecasComDesconto;

  Fornecedor({
    this.id,
    required this.nome,
    required this.cnpj,
    required this.telefone,
    required this.email,
    this.margemLucro,
    this.pecasComDesconto,
  });

  factory Fornecedor.fromJson(Map<String, dynamic> json) {
    return Fornecedor(
      id: json['id'],
      nome: json['nome'],
      cnpj: json['cnpj'],
      telefone: json['telefone'],
      email: json['email'],
      margemLucro: (json['margemLucro'] as num?)?.toDouble(),
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
    };
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is Fornecedor && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
