import 'fornecedor.dart';

class MovimentacaoEstoque {
  int? id;
  String codigoPeca;
  Fornecedor fornecedor;
  int quantidade;
  double? precoUnitario;
  String numeroNotaFiscal;
  TipoMovimentacao tipoMovimentacao;
  DateTime? dataEntrada;
  DateTime? dataSaida;
  String? observacoes;

  MovimentacaoEstoque({
    this.id,
    required this.codigoPeca,
    required this.fornecedor,
    required this.quantidade,
    this.precoUnitario,
    required this.numeroNotaFiscal,
    required this.tipoMovimentacao,
    this.dataEntrada,
    this.dataSaida,
    this.observacoes,
  });

  factory MovimentacaoEstoque.fromJson(Map<String, dynamic> json) {
    return MovimentacaoEstoque(
      id: json['id'],
      codigoPeca: json['codigoPeca'],
      fornecedor: Fornecedor.fromJson(json['fornecedor']),
      quantidade: json['quantidade'],
      precoUnitario: json['precoUnitario'] != null ? (json['precoUnitario'] as num).toDouble() : null,
      numeroNotaFiscal: json['numeroNotaFiscal'],
      tipoMovimentacao: TipoMovimentacao.values.firstWhere(
        (e) => e.toString().split('.').last == json['tipoMovimentacao'],
      ),
      dataEntrada: json['dataEntrada'] != null ? DateTime.parse(json['dataEntrada']) : null,
      dataSaida: json['dataSaida'] != null ? DateTime.parse(json['dataSaida']) : null,
      observacoes: json['observacoes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigoPeca': codigoPeca,
      'fornecedor': fornecedor.toJson(),
      'quantidade': quantidade,
      'precoUnitario': precoUnitario,
      'numeroNotaFiscal': numeroNotaFiscal,
      'tipoMovimentacao': tipoMovimentacao.toString().split('.').last,
      'dataEntrada': dataEntrada?.toIso8601String(),
      'dataSaida': dataSaida?.toIso8601String(),
      'observacoes': observacoes,
    };
  }

  DateTime? get dataMovimentacao {
    if (tipoMovimentacao == TipoMovimentacao.ENTRADA) {
      return dataEntrada;
    } else if (tipoMovimentacao == TipoMovimentacao.SAIDA) {
      return dataSaida;
    }
    return dataEntrada ?? dataSaida;
  }
}

enum TipoMovimentacao {
  ENTRADA,
  SAIDA,
}
