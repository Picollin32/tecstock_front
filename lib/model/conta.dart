class Conta {
  final int? id;
  final String tipo;
  final String descricao;
  final double valor;
  final int mesReferencia;
  final int anoReferencia;
  final DateTime? dataVencimento;
  final bool pago;
  final DateTime? dataPagamento;
  final int? ordemServicoId;
  final String? ordemServicoNumero;
  final int? parcelaNumero;
  final int? totalParcelas;
  final String? origemTipo;
  final String? fiadoGrupoId;
  final double valorPagoParcial;
  final double? acrescimo;
  final double? desconto;
  final int? categoriaId;
  final String? categoriaNome;
  final int? fornecedorId;
  final String? fornecedorNome;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Conta({
    this.id,
    required this.tipo,
    required this.descricao,
    required this.valor,
    required this.mesReferencia,
    required this.anoReferencia,
    this.dataVencimento,
    this.pago = false,
    this.dataPagamento,
    this.ordemServicoId,
    this.ordemServicoNumero,
    this.parcelaNumero,
    this.totalParcelas,
    this.origemTipo,
    this.fiadoGrupoId,
    this.valorPagoParcial = 0.0,
    this.acrescimo,
    this.desconto,
    this.categoriaId,
    this.categoriaNome,
    this.fornecedorId,
    this.fornecedorNome,
    this.createdAt,
    this.updatedAt,
  });

  bool get isAPagar => tipo == 'A_PAGAR';
  bool get isAReceber => tipo == 'A_RECEBER';
  bool get isManual => origemTipo == 'MANUAL';
  bool get isFiado => origemTipo == 'OS_FIADO';
  bool get isCredito => (origemTipo ?? '').contains('CREDITO') || (origemTipo ?? '').contains('PARCELADO');
  bool get isAvista => origemTipo == 'OS_AVISTA';
  bool get isCompra => origemTipo?.startsWith('COMPRA') == true;
  bool get isParcela => isAPagar && parcelaNumero != null && totalParcelas != null;
  bool get isBoleto => origemTipo?.contains('BOLETO') == true;

  double get valorPendente => valor - valorPagoParcial;

  bool get temPagamentoParcial => !pago && valorPagoParcial > 0.001;

  bool get isAtrasada {
    if (pago) return false;
    if (dataVencimento == null) return false;
    final hoje = DateTime.now();
    final venc = dataVencimento!;
    return DateTime(venc.year, venc.month, venc.day).isBefore(DateTime(hoje.year, hoje.month, hoje.day));
  }

  factory Conta.fromJson(Map<String, dynamic> json) {
    return Conta(
      id: json['id'],
      tipo: json['tipo'] ?? 'A_RECEBER',
      descricao: json['descricao'] ?? '',
      valor: (json['valor'] ?? 0).toDouble(),
      mesReferencia: json['mesReferencia'] ?? DateTime.now().month,
      anoReferencia: json['anoReferencia'] ?? DateTime.now().year,
      dataVencimento: json['dataVencimento'] != null ? DateTime.tryParse(json['dataVencimento']) : null,
      pago: json['pago'] ?? false,
      dataPagamento: json['dataPagamento'] != null ? DateTime.tryParse(json['dataPagamento']) : null,
      ordemServicoId: json['ordemServicoId'],
      ordemServicoNumero: json['ordemServicoNumero'],
      parcelaNumero: json['parcelaNumero'],
      totalParcelas: json['totalParcelas'],
      origemTipo: json['origemTipo'],
      fiadoGrupoId: json['fiadoGrupoId'],
      valorPagoParcial: (json['valorPagoParcial'] ?? 0.0).toDouble(),
      acrescimo: json['acrescimo'] != null ? (json['acrescimo'] as num).toDouble() : null,
      desconto: json['desconto'] != null ? (json['desconto'] as num).toDouble() : null,
      categoriaId: json['categoriaId'],
      categoriaNome: json['categoriaNome'],
      fornecedorId: json['fornecedorId'],
      fornecedorNome: json['fornecedorNome'],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'tipo': tipo,
      'descricao': descricao,
      'valor': valor,
      'mesReferencia': mesReferencia,
      'anoReferencia': anoReferencia,
      if (dataVencimento != null) 'dataVencimento': dataVencimento!.toIso8601String().substring(0, 10),
      'pago': pago,
      if (dataPagamento != null) 'dataPagamento': dataPagamento!.toIso8601String(),
      if (ordemServicoId != null) 'ordemServicoId': ordemServicoId,
      if (ordemServicoNumero != null) 'ordemServicoNumero': ordemServicoNumero,
      if (parcelaNumero != null) 'parcelaNumero': parcelaNumero,
      if (totalParcelas != null) 'totalParcelas': totalParcelas,
      if (origemTipo != null) 'origemTipo': origemTipo,
      if (fiadoGrupoId != null) 'fiadoGrupoId': fiadoGrupoId,
      'valorPagoParcial': valorPagoParcial,
      if (acrescimo != null) 'acrescimo': acrescimo,
      if (desconto != null) 'desconto': desconto,
      if (categoriaId != null) 'categoriaId': categoriaId,
      if (categoriaNome != null) 'categoriaNome': categoriaNome,
      if (fornecedorId != null) 'fornecedorId': fornecedorId,
      if (fornecedorNome != null) 'fornecedorNome': fornecedorNome,
    };
  }

  Conta copyWith({
    int? id,
    String? tipo,
    String? descricao,
    double? valor,
    int? mesReferencia,
    int? anoReferencia,
    DateTime? dataVencimento,
    bool? pago,
    DateTime? dataPagamento,
    int? ordemServicoId,
    String? ordemServicoNumero,
    int? parcelaNumero,
    int? totalParcelas,
    String? origemTipo,
    String? fiadoGrupoId,
    double? valorPagoParcial,
    double? acrescimo,
    double? desconto,
    int? categoriaId,
    String? categoriaNome,
    int? fornecedorId,
    String? fornecedorNome,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Conta(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      descricao: descricao ?? this.descricao,
      valor: valor ?? this.valor,
      mesReferencia: mesReferencia ?? this.mesReferencia,
      anoReferencia: anoReferencia ?? this.anoReferencia,
      dataVencimento: dataVencimento ?? this.dataVencimento,
      pago: pago ?? this.pago,
      dataPagamento: dataPagamento ?? this.dataPagamento,
      ordemServicoId: ordemServicoId ?? this.ordemServicoId,
      ordemServicoNumero: ordemServicoNumero ?? this.ordemServicoNumero,
      parcelaNumero: parcelaNumero ?? this.parcelaNumero,
      totalParcelas: totalParcelas ?? this.totalParcelas,
      origemTipo: origemTipo ?? this.origemTipo,
      valorPagoParcial: valorPagoParcial ?? this.valorPagoParcial,
      fiadoGrupoId: fiadoGrupoId ?? this.fiadoGrupoId,
      acrescimo: acrescimo ?? this.acrescimo,
      desconto: desconto ?? this.desconto,
      categoriaId: categoriaId ?? this.categoriaId,
      categoriaNome: categoriaNome ?? this.categoriaNome,
      fornecedorId: fornecedorId ?? this.fornecedorId,
      fornecedorNome: fornecedorNome ?? this.fornecedorNome,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
