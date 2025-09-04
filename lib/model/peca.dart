import 'fabricante.dart';
import 'fornecedor.dart';

class Peca {
  int? id;
  String nome;
  String codigoFabricante;
  double precoUnitario;
  int quantidadeEstoque;
  Fabricante fabricante;
  Fornecedor? fornecedor;

  Peca({
    this.id,
    required this.nome,
    required this.codigoFabricante,
    required this.precoUnitario,
    required this.quantidadeEstoque,
    required this.fabricante,
    this.fornecedor,
  });

  factory Peca.fromJson(Map<String, dynamic> json) {
    return Peca(
      id: json['id'],
      nome: json['nome'],
      codigoFabricante: json['codigoFabricante'],
      precoUnitario: (json['precoUnitario'] as num).toDouble(),
      quantidadeEstoque: json['quantidadeEstoque'],
      fabricante: Fabricante.fromJson(json['fabricante']),
      fornecedor: json['fornecedor'] != null ? Fornecedor.fromJson(json['fornecedor']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'codigoFabricante': codigoFabricante,
      'precoUnitario': precoUnitario,
      'quantidadeEstoque': quantidadeEstoque,
      'fabricante': fabricante.toJson(),
      'fornecedor': fornecedor?.toJson(),
    };
  }
}
