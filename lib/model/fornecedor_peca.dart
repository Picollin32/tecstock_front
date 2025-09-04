import 'fornecedor.dart';
import 'peca.dart';

class FornecedorPeca {
  final double desconto;
  final Fornecedor fornecedor;
  final Peca peca;

  FornecedorPeca({
    required this.desconto,
    required this.fornecedor,
    required this.peca,
  });

  factory FornecedorPeca.fromJson(Map<String, dynamic> json) {
    return FornecedorPeca(
      desconto: (json['desconto'] as num).toDouble(),
      fornecedor: Fornecedor.fromJson(json['fornecedor']),
      peca: Peca.fromJson(json['peca']),
    );
  }
}
