class RelatorioVendas {
  final DateTime dataInicio;
  final DateTime dataFim;
  final int totalOrcamentos;
  final int orcamentosAprovados;
  final int orcamentosRecusados;
  final int orcamentosPendentes;
  final double valorTotalOrcamentos;
  final double valorTotalAprovado;
  final double ticketMedio;
  final double taxaConversao;

  RelatorioVendas({
    required this.dataInicio,
    required this.dataFim,
    required this.totalOrcamentos,
    required this.orcamentosAprovados,
    required this.orcamentosRecusados,
    required this.orcamentosPendentes,
    required this.valorTotalOrcamentos,
    required this.valorTotalAprovado,
    required this.ticketMedio,
    required this.taxaConversao,
  });

  factory RelatorioVendas.fromJson(Map<String, dynamic> json) {
    return RelatorioVendas(
      dataInicio: DateTime.parse(json['dataInicio']),
      dataFim: DateTime.parse(json['dataFim']),
      totalOrcamentos: json['totalOrcamentos'] ?? 0,
      orcamentosAprovados: json['orcamentosAprovados'] ?? 0,
      orcamentosRecusados: json['orcamentosRecusados'] ?? 0,
      orcamentosPendentes: json['orcamentosPendentes'] ?? 0,
      valorTotalOrcamentos: (json['valorTotalOrcamentos'] ?? 0).toDouble(),
      valorTotalAprovado: (json['valorTotalAprovado'] ?? 0).toDouble(),
      ticketMedio: (json['ticketMedio'] ?? 0).toDouble(),
      taxaConversao: (json['taxaConversao'] ?? 0).toDouble(),
    );
  }
}

class ItemServico {
  final int idServico;
  final String nomeServico;
  final int quantidade;
  final double valorTotal;

  ItemServico({
    required this.idServico,
    required this.nomeServico,
    required this.quantidade,
    required this.valorTotal,
  });

  factory ItemServico.fromJson(Map<String, dynamic> json) {
    return ItemServico(
      idServico: json['idServico'] ?? 0,
      nomeServico: json['nomeServico'] ?? '',
      quantidade: json['quantidade'] ?? 0,
      valorTotal: (json['valorTotal'] ?? 0).toDouble(),
    );
  }
}

class RelatorioServicos {
  final DateTime dataInicio;
  final DateTime dataFim;

  // Seção: Serviços Realizados
  final double valorServicosRealizados; // valor - desconto em serviços
  final int totalServicosRealizados;
  final List<ItemServico> servicosMaisRealizados;

  // Seção: Ordem de Serviço
  final int totalOrdensServico;
  final int ordensFinalizadas;
  final int ordensEmAndamento;
  final int ordensCanceladas;

  // Campos adicionais
  final double descontoServicos;
  final double valorMedioPorOrdem;
  final double tempoMedioExecucao;

  RelatorioServicos({
    required this.dataInicio,
    required this.dataFim,
    required this.valorServicosRealizados,
    required this.totalServicosRealizados,
    required this.servicosMaisRealizados,
    required this.totalOrdensServico,
    required this.ordensFinalizadas,
    required this.ordensEmAndamento,
    required this.ordensCanceladas,
    required this.descontoServicos,
    required this.valorMedioPorOrdem,
    required this.tempoMedioExecucao,
  });

  factory RelatorioServicos.fromJson(Map<String, dynamic> json) {
    return RelatorioServicos(
      dataInicio: DateTime.parse(json['dataInicio']),
      dataFim: DateTime.parse(json['dataFim']),
      valorServicosRealizados: (json['valorServicosRealizados'] ?? 0).toDouble(),
      totalServicosRealizados: json['totalServicosRealizados'] ?? 0,
      servicosMaisRealizados: (json['servicosMaisRealizados'] as List?)?.map((item) => ItemServico.fromJson(item)).toList() ?? [],
      totalOrdensServico: json['totalOrdensServico'] ?? 0,
      ordensFinalizadas: json['ordensFinalizadas'] ?? 0,
      ordensEmAndamento: json['ordensEmAndamento'] ?? 0,
      ordensCanceladas: json['ordensCanceladas'] ?? 0,
      descontoServicos: (json['descontoServicos'] ?? 0).toDouble(),
      valorMedioPorOrdem: (json['valorMedioPorOrdem'] ?? 0).toDouble(),
      tempoMedioExecucao: (json['tempoMedioExecucao'] ?? 0).toDouble(),
    );
  }
}

class ItemEstoque {
  final int idPeca;
  final String nomePeca;
  final int quantidade;
  final double valor;

  ItemEstoque({
    required this.idPeca,
    required this.nomePeca,
    required this.quantidade,
    required this.valor,
  });

  factory ItemEstoque.fromJson(Map<String, dynamic> json) {
    return ItemEstoque(
      idPeca: json['idPeca'] ?? 0,
      nomePeca: json['nomePeca'] ?? '',
      quantidade: json['quantidade'] ?? 0,
      valor: (json['valor'] ?? 0).toDouble(),
    );
  }
}

class RelatorioEstoque {
  final DateTime dataInicio;
  final DateTime dataFim;
  final int totalMovimentacoes;
  final int totalEntradas;
  final int totalSaidas;
  final double valorTotalEstoque;
  final double valorEntradas;
  final double valorSaidas;
  final List<ItemEstoque> pecasMaisMovimentadas;
  final List<ItemEstoque> pecasEstoqueBaixo;

  RelatorioEstoque({
    required this.dataInicio,
    required this.dataFim,
    required this.totalMovimentacoes,
    required this.totalEntradas,
    required this.totalSaidas,
    required this.valorTotalEstoque,
    required this.valorEntradas,
    required this.valorSaidas,
    required this.pecasMaisMovimentadas,
    required this.pecasEstoqueBaixo,
  });

  factory RelatorioEstoque.fromJson(Map<String, dynamic> json) {
    return RelatorioEstoque(
      dataInicio: DateTime.parse(json['dataInicio']),
      dataFim: DateTime.parse(json['dataFim']),
      totalMovimentacoes: json['totalMovimentacoes'] ?? 0,
      totalEntradas: json['totalEntradas'] ?? 0,
      totalSaidas: json['totalSaidas'] ?? 0,
      valorTotalEstoque: (json['valorTotalEstoque'] ?? 0).toDouble(),
      valorEntradas: (json['valorEntradas'] ?? 0).toDouble(),
      valorSaidas: (json['valorSaidas'] ?? 0).toDouble(),
      pecasMaisMovimentadas: (json['pecasMaisMovimentadas'] as List?)?.map((item) => ItemEstoque.fromJson(item)).toList() ?? [],
      pecasEstoqueBaixo: (json['pecasEstoqueBaixo'] as List?)?.map((item) => ItemEstoque.fromJson(item)).toList() ?? [],
    );
  }
}

class RelatorioFinanceiro {
  final DateTime dataInicio;
  final DateTime dataFim;
  final double receitaTotal;
  final double receitaServicos;
  final double receitaPecas;
  final double despesasEstoque;
  final double descontosPecas;
  final double descontosServicos;
  final double descontosTotal;
  final double lucroEstimado;
  final Map<String, double> receitaPorTipoPagamento;
  final Map<String, int> quantidadePorTipoPagamento;
  final double ticketMedio;

  RelatorioFinanceiro({
    required this.dataInicio,
    required this.dataFim,
    required this.receitaTotal,
    required this.receitaServicos,
    required this.receitaPecas,
    required this.despesasEstoque,
    required this.descontosPecas,
    required this.descontosServicos,
    required this.descontosTotal,
    required this.lucroEstimado,
    required this.receitaPorTipoPagamento,
    required this.quantidadePorTipoPagamento,
    required this.ticketMedio,
  });

  factory RelatorioFinanceiro.fromJson(Map<String, dynamic> json) {
    Map<String, double> receitaPorTipo = {};
    if (json['receitaPorTipoPagamento'] != null) {
      (json['receitaPorTipoPagamento'] as Map<String, dynamic>).forEach((key, value) {
        receitaPorTipo[key] = (value ?? 0).toDouble();
      });
    }

    Map<String, int> quantidadePorTipo = {};
    if (json['quantidadePorTipoPagamento'] != null) {
      (json['quantidadePorTipoPagamento'] as Map<String, dynamic>).forEach((key, value) {
        quantidadePorTipo[key] = value ?? 0;
      });
    }

    return RelatorioFinanceiro(
      dataInicio: DateTime.parse(json['dataInicio']),
      dataFim: DateTime.parse(json['dataFim']),
      receitaTotal: (json['receitaTotal'] ?? 0).toDouble(),
      receitaServicos: (json['receitaServicos'] ?? 0).toDouble(),
      receitaPecas: (json['receitaPecas'] ?? 0).toDouble(),
      despesasEstoque: (json['despesasEstoque'] ?? 0).toDouble(),
      descontosPecas: (json['descontosPecas'] ?? 0).toDouble(),
      descontosServicos: (json['descontosServicos'] ?? 0).toDouble(),
      descontosTotal: (json['descontosTotal'] ?? 0).toDouble(),
      lucroEstimado: (json['lucroEstimado'] ?? 0).toDouble(),
      receitaPorTipoPagamento: receitaPorTipo,
      quantidadePorTipoPagamento: quantidadePorTipo,
      ticketMedio: (json['ticketMedio'] ?? 0).toDouble(),
    );
  }
}

class ServicoRealizado {
  final int idServico;
  final String nomeServico;
  final double valor;
  final double valorDesconto;
  final DateTime? dataRealizacao;

  ServicoRealizado({
    required this.idServico,
    required this.nomeServico,
    required this.valor,
    this.valorDesconto = 0.0,
    this.dataRealizacao,
  });

  factory ServicoRealizado.fromJson(Map<String, dynamic> json) {
    return ServicoRealizado(
      idServico: json['idServico'] ?? 0,
      nomeServico: json['nomeServico'] ?? '',
      valor: (json['valor'] ?? 0).toDouble(),
      valorDesconto: (json['valorDesconto'] ?? 0).toDouble(),
      dataRealizacao: json['dataRealizacao'] != null ? DateTime.parse(json['dataRealizacao']) : null,
    );
  }
}

class OrdemServicoComissao {
  final int id;
  final String numeroOS;
  final DateTime dataHora;
  final DateTime? dataHoraEncerramento;
  final String clienteNome;
  final String veiculoNome;
  final String veiculoPlaca;
  final double valorServicos;
  final double descontoServicos;
  final double valorFinal;
  final List<ServicoRealizado> servicosRealizados;

  OrdemServicoComissao({
    required this.id,
    required this.numeroOS,
    required this.dataHora,
    this.dataHoraEncerramento,
    required this.clienteNome,
    required this.veiculoNome,
    required this.veiculoPlaca,
    required this.valorServicos,
    required this.descontoServicos,
    required this.valorFinal,
    required this.servicosRealizados,
  });

  factory OrdemServicoComissao.fromJson(Map<String, dynamic> json) {
    return OrdemServicoComissao(
      id: json['id'] ?? 0,
      numeroOS: json['numeroOS'] ?? '',
      dataHora: DateTime.parse(json['dataHora']),
      dataHoraEncerramento: json['dataHoraEncerramento'] != null ? DateTime.parse(json['dataHoraEncerramento']) : null,
      clienteNome: json['clienteNome'] ?? '',
      veiculoNome: json['veiculoNome'] ?? '',
      veiculoPlaca: json['veiculoPlaca'] ?? '',
      valorServicos: (json['valorServicos'] ?? 0).toDouble(),
      descontoServicos: (json['descontoServicos'] ?? 0).toDouble(),
      valorFinal: (json['valorFinal'] ?? 0).toDouble(),
      servicosRealizados: (json['servicosRealizados'] as List?)?.map((item) => ServicoRealizado.fromJson(item)).toList() ?? [],
    );
  }
}

class RelatorioComissao {
  final DateTime dataInicio;
  final DateTime dataFim;
  final int mecanicoId;
  final String mecanicoNome;
  final double valorTotalServicos;
  final double descontoServicos;
  final double valorComissao;
  final int totalOrdensServico;
  final int totalServicosRealizados;
  final List<OrdemServicoComissao> ordensServico;

  RelatorioComissao({
    required this.dataInicio,
    required this.dataFim,
    required this.mecanicoId,
    required this.mecanicoNome,
    required this.valorTotalServicos,
    required this.descontoServicos,
    required this.valorComissao,
    required this.totalOrdensServico,
    required this.totalServicosRealizados,
    required this.ordensServico,
  });

  factory RelatorioComissao.fromJson(Map<String, dynamic> json) {
    return RelatorioComissao(
      dataInicio: DateTime.parse(json['dataInicio']),
      dataFim: DateTime.parse(json['dataFim']),
      mecanicoId: json['mecanicoId'] ?? 0,
      mecanicoNome: json['mecanicoNome'] ?? '',
      valorTotalServicos: (json['valorTotalServicos'] ?? 0).toDouble(),
      descontoServicos: (json['descontoServicos'] ?? 0).toDouble(),
      valorComissao: (json['valorComissao'] ?? 0).toDouble(),
      totalOrdensServico: json['totalOrdensServico'] ?? 0,
      totalServicosRealizados: json['totalServicosRealizados'] ?? 0,
      ordensServico: (json['ordensServico'] as List?)?.map((item) => OrdemServicoComissao.fromJson(item)).toList() ?? [],
    );
  }
}

class GarantiaItem {
  final int id;
  final String numeroOS;
  final DateTime dataEncerramento;
  final DateTime dataInicioGarantia;
  final DateTime dataFimGarantia;
  final int garantiaMeses;
  final String clienteNome;
  final String clienteCpf;
  final String? clienteTelefone;
  final String veiculoNome;
  final String veiculoPlaca;
  final String? veiculoMarca;
  final double valorTotal;
  final String? mecanicoNome;
  final String? consultorNome;
  final bool emAberto;
  final String statusDescricao;

  GarantiaItem({
    required this.id,
    required this.numeroOS,
    required this.dataEncerramento,
    required this.dataInicioGarantia,
    required this.dataFimGarantia,
    required this.garantiaMeses,
    required this.clienteNome,
    required this.clienteCpf,
    this.clienteTelefone,
    required this.veiculoNome,
    required this.veiculoPlaca,
    this.veiculoMarca,
    required this.valorTotal,
    this.mecanicoNome,
    this.consultorNome,
    required this.emAberto,
    required this.statusDescricao,
  });

  factory GarantiaItem.fromJson(Map<String, dynamic> json) {
    return GarantiaItem(
      id: json['id'] ?? 0,
      numeroOS: json['numeroOS'] ?? '',
      dataEncerramento: DateTime.parse(json['dataEncerramento']),
      dataInicioGarantia: DateTime.parse(json['dataInicioGarantia']),
      dataFimGarantia: DateTime.parse(json['dataFimGarantia']),
      garantiaMeses: json['garantiaMeses'] ?? 0,
      clienteNome: json['clienteNome'] ?? '',
      clienteCpf: json['clienteCpf'] ?? '',
      clienteTelefone: json['clienteTelefone'],
      veiculoNome: json['veiculoNome'] ?? '',
      veiculoPlaca: json['veiculoPlaca'] ?? '',
      veiculoMarca: json['veiculoMarca'],
      valorTotal: (json['valorTotal'] ?? 0).toDouble(),
      mecanicoNome: json['mecanicoNome'],
      consultorNome: json['consultorNome'],
      emAberto: json['emAberto'] ?? false,
      statusDescricao: json['statusDescricao'] ?? '',
    );
  }
}

class RelatorioGarantias {
  final DateTime dataInicio;
  final DateTime dataFim;
  final int totalGarantias;
  final int garantiasEmAberto;
  final int garantiasEncerradas;
  final List<GarantiaItem> garantias;

  RelatorioGarantias({
    required this.dataInicio,
    required this.dataFim,
    required this.totalGarantias,
    required this.garantiasEmAberto,
    required this.garantiasEncerradas,
    required this.garantias,
  });

  factory RelatorioGarantias.fromJson(Map<String, dynamic> json) {
    return RelatorioGarantias(
      dataInicio: DateTime.parse(json['dataInicio']),
      dataFim: DateTime.parse(json['dataFim']),
      totalGarantias: json['totalGarantias'] ?? 0,
      garantiasEmAberto: json['garantiasEmAberto'] ?? 0,
      garantiasEncerradas: json['garantiasEncerradas'] ?? 0,
      garantias: (json['garantias'] as List?)?.map((item) => GarantiaItem.fromJson(item)).toList() ?? [],
    );
  }
}

class FiadoItem {
  final int id;
  final String numeroOS;
  final DateTime dataEncerramento;
  final DateTime dataInicioFiado;
  final DateTime dataVencimentoFiado;
  final int prazoFiadoDias;
  final String clienteNome;
  final String clienteCpf;
  final String? clienteTelefone;
  final String veiculoNome;
  final String veiculoPlaca;
  final String? veiculoMarca;
  final double valorTotal;
  final String? mecanicoNome;
  final String? consultorNome;
  final String? tipoPagamentoNome;
  final bool noPrazo;
  final String statusDescricao;

  FiadoItem({
    required this.id,
    required this.numeroOS,
    required this.dataEncerramento,
    required this.dataInicioFiado,
    required this.dataVencimentoFiado,
    required this.prazoFiadoDias,
    required this.clienteNome,
    required this.clienteCpf,
    this.clienteTelefone,
    required this.veiculoNome,
    required this.veiculoPlaca,
    this.veiculoMarca,
    required this.valorTotal,
    this.mecanicoNome,
    this.consultorNome,
    this.tipoPagamentoNome,
    required this.noPrazo,
    required this.statusDescricao,
  });

  factory FiadoItem.fromJson(Map<String, dynamic> json) {
    return FiadoItem(
      id: json['id'] ?? 0,
      numeroOS: json['numeroOS'] ?? '',
      dataEncerramento: DateTime.parse(json['dataEncerramento']),
      dataInicioFiado: DateTime.parse(json['dataInicioFiado']),
      dataVencimentoFiado: DateTime.parse(json['dataVencimentoFiado']),
      prazoFiadoDias: json['prazoFiadoDias'] ?? 0,
      clienteNome: json['clienteNome'] ?? '',
      clienteCpf: json['clienteCpf'] ?? '',
      clienteTelefone: json['clienteTelefone'],
      veiculoNome: json['veiculoNome'] ?? '',
      veiculoPlaca: json['veiculoPlaca'] ?? '',
      veiculoMarca: json['veiculoMarca'],
      valorTotal: (json['valorTotal'] ?? 0).toDouble(),
      mecanicoNome: json['mecanicoNome'],
      consultorNome: json['consultorNome'],
      tipoPagamentoNome: json['tipoPagamentoNome'],
      noPrazo: json['noPrazo'] ?? false,
      statusDescricao: json['statusDescricao'] ?? '',
    );
  }
}

class RelatorioFiado {
  final DateTime dataInicio;
  final DateTime dataFim;
  final int totalFiados;
  final int fiadosNoPrazo;
  final int fiadosVencidos;
  final double valorTotalFiado;
  final double valorNoPrazo;
  final double valorVencido;
  final List<FiadoItem> fiados;

  RelatorioFiado({
    required this.dataInicio,
    required this.dataFim,
    required this.totalFiados,
    required this.fiadosNoPrazo,
    required this.fiadosVencidos,
    required this.valorTotalFiado,
    required this.valorNoPrazo,
    required this.valorVencido,
    required this.fiados,
  });

  factory RelatorioFiado.fromJson(Map<String, dynamic> json) {
    return RelatorioFiado(
      dataInicio: DateTime.parse(json['dataInicio']),
      dataFim: DateTime.parse(json['dataFim']),
      totalFiados: json['totalFiados'] ?? 0,
      fiadosNoPrazo: json['fiadosNoPrazo'] ?? 0,
      fiadosVencidos: json['fiadosVencidos'] ?? 0,
      valorTotalFiado: (json['valorTotalFiado'] ?? 0).toDouble(),
      valorNoPrazo: (json['valorNoPrazo'] ?? 0).toDouble(),
      valorVencido: (json['valorVencido'] ?? 0).toDouble(),
      fiados: (json['fiados'] as List?)?.map((item) => FiadoItem.fromJson(item)).toList() ?? [],
    );
  }
}
