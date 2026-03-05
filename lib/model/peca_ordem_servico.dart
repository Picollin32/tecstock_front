import 'peca.dart';

class PecaOrdemServico {
  int? id;
  final Peca peca;
  int quantidade;

  final int originalQuantidade;
  double? valorUnitario;
  double? valorTotal;

  double get valorTotalCalculado => valorTotal ?? (peca.precoFinal * quantidade);

  PecaOrdemServico({
    this.id,
    required this.peca,
    required this.quantidade,
    this.originalQuantidade = 0,
    this.valorUnitario,
    this.valorTotal,
  }) {
    valorUnitario ??= peca.precoFinal;
    valorTotal ??= valorUnitario! * quantidade;
  }

  factory PecaOrdemServico.fromJson(Map<String, dynamic> json) {
    return PecaOrdemServico(
      id: json['id'],
      peca: Peca.fromJson(json['peca']),
      quantidade: json['quantidade'] ?? 1,
      valorUnitario: json['valorUnitario']?.toDouble(),
      valorTotal: json['valorTotal']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'peca': peca.toJson(),
      'quantidade': quantidade,
      'valorUnitario': valorUnitario,
      'valorTotal': valorTotal,
    };
  }

  @override
  String toString() {
    return '${peca.nome} (${peca.codigoFabricante}) - Qtd: $quantidade - Total: R\$ ${valorTotalCalculado.toStringAsFixed(2)}';
  }
}
