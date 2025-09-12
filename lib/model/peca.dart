import 'fabricante.dart';
import 'fornecedor.dart';

class Peca {
  int? id;
  String nome;
  String codigoFabricante;
  double precoUnitario;
  double precoFinal;
  int quantidadeEstoque;
  int estoqueSeguranca;
  Fabricante fabricante;
  Fornecedor? fornecedor;
  DateTime? createdAt;
  DateTime? updatedAt;

  Peca({
    this.id,
    required this.nome,
    required this.codigoFabricante,
    required this.precoUnitario,
    required this.precoFinal,
    required this.quantidadeEstoque,
    required this.estoqueSeguranca,
    required this.fabricante,
    this.fornecedor,
    this.createdAt,
    this.updatedAt,
  });

  factory Peca.fromJson(Map<String, dynamic> json) {
    return Peca(
      id: json['id'],
      nome: json['nome'],
      codigoFabricante: json['codigoFabricante'],
      precoUnitario: (json['precoUnitario'] as num).toDouble(),
      precoFinal: (json['precoFinal'] as num).toDouble(),
      quantidadeEstoque: json['quantidadeEstoque'],
      estoqueSeguranca: json['estoqueSeguranca'],
      fabricante: Fabricante.fromJson(json['fabricante']),
      fornecedor: json['fornecedor'] != null ? Fornecedor.fromJson(json['fornecedor']) : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'codigoFabricante': codigoFabricante,
      'precoUnitario': precoUnitario,
      'precoFinal': precoFinal,
      'quantidadeEstoque': quantidadeEstoque,
      'estoqueSeguranca': estoqueSeguranca,
      'fabricante': fabricante.toJson(),
      'fornecedor': fornecedor?.toJson(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
