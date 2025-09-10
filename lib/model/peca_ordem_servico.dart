import 'peca.dart';

class PecaOrdemServico {
  final Peca peca;
  int quantidade;
  double get valorTotal => peca.precoFinal * quantidade;

  PecaOrdemServico({
    required this.peca,
    required this.quantidade,
  });

  factory PecaOrdemServico.fromJson(Map<String, dynamic> json) {
    return PecaOrdemServico(
      peca: Peca.fromJson(json['peca']),
      quantidade: json['quantidade'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'peca': peca.toJson(),
      'quantidade': quantidade,
    };
  }

  @override
  String toString() {
    return '${peca.nome} (${peca.codigoFabricante}) - Qtd: $quantidade - Total: R\$ ${valorTotal.toStringAsFixed(2)}';
  }
}
