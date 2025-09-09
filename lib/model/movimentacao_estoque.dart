import 'fornecedor.dart';

class MovimentacaoEstoque {
  int? id;
  String codigoPeca;
  Fornecedor fornecedor;
  int quantidade;
  String numeroNotaFiscal;
  TipoMovimentacao tipoMovimentacao;
  DateTime dataMovimentacao;
  String? observacoes;

  MovimentacaoEstoque({
    this.id,
    required this.codigoPeca,
    required this.fornecedor,
    required this.quantidade,
    required this.numeroNotaFiscal,
    required this.tipoMovimentacao,
    required this.dataMovimentacao,
    this.observacoes,
  });

  factory MovimentacaoEstoque.fromJson(Map<String, dynamic> json) {
    return MovimentacaoEstoque(
      id: json['id'],
      codigoPeca: json['codigoPeca'],
      fornecedor: Fornecedor.fromJson(json['fornecedor']),
      quantidade: json['quantidade'],
      numeroNotaFiscal: json['numeroNotaFiscal'],
      tipoMovimentacao: TipoMovimentacao.values.firstWhere(
        (e) => e.toString().split('.').last == json['tipoMovimentacao'],
      ),
      dataMovimentacao: DateTime.parse(json['dataMovimentacao']),
      observacoes: json['observacoes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigoPeca': codigoPeca,
      'fornecedor': fornecedor.toJson(),
      'quantidade': quantidade,
      'numeroNotaFiscal': numeroNotaFiscal,
      'tipoMovimentacao': tipoMovimentacao.toString().split('.').last,
      'dataMovimentacao': dataMovimentacao.toIso8601String(),
      'observacoes': observacoes,
    };
  }
}

enum TipoMovimentacao {
  ENTRADA,
  SAIDA,
}
