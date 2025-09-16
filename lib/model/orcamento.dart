import 'servico.dart';
import 'tipo_pagamento.dart';
import 'peca_ordem_servico.dart';
import 'funcionario.dart';

class Orcamento {
  int? id;
  String numeroOrcamento;

  DateTime dataHora;

  String clienteNome;
  String clienteCpf;
  String? clienteTelefone;
  String? clienteEmail;
  String veiculoNome;
  String veiculoMarca;
  String veiculoAno;
  String veiculoCor;
  String veiculoPlaca;
  String veiculoQuilometragem;
  String? veiculoCategoria;
  String queixaPrincipal;
  List<Servico> servicosOrcados;
  List<PecaOrdemServico> pecasOrcadas;
  double precoTotal;
  double? precoTotalServicos;
  double? precoTotalPecas;
  double? descontoServicos;
  double? descontoPecas;
  int garantiaMeses;
  TipoPagamento? tipoPagamento;
  int? numeroParcelas;
  Funcionario? mecanico;
  Funcionario? consultor;
  String? observacoes;
  DateTime? createdAt;
  DateTime? updatedAt;

  Orcamento({
    this.id,
    required this.numeroOrcamento,
    required this.dataHora,
    required this.clienteNome,
    required this.clienteCpf,
    this.clienteTelefone,
    this.clienteEmail,
    required this.veiculoNome,
    required this.veiculoMarca,
    required this.veiculoAno,
    required this.veiculoCor,
    required this.veiculoPlaca,
    required this.veiculoQuilometragem,
    this.veiculoCategoria,
    required this.queixaPrincipal,
    required this.servicosOrcados,
    this.pecasOrcadas = const [],
    required this.precoTotal,
    this.precoTotalServicos,
    this.precoTotalPecas,
    this.descontoServicos,
    this.descontoPecas,
    this.garantiaMeses = 3,
    this.tipoPagamento,
    this.numeroParcelas,
    this.mecanico,
    this.consultor,
    this.observacoes,
    this.createdAt,
    this.updatedAt,
  });

  factory Orcamento.fromJson(Map<String, dynamic> json) {
    return Orcamento(
      id: json['id'],
      numeroOrcamento: json['numeroOrcamento']?.toString() ?? '',
      dataHora: json['dataHora'] != null ? DateTime.parse(json['dataHora']) : DateTime.now(),
      clienteNome: json['clienteNome'] ?? '',
      clienteCpf: json['clienteCpf'] ?? '',
      clienteTelefone: json['clienteTelefone'],
      clienteEmail: json['clienteEmail'],
      veiculoNome: json['veiculoNome'] ?? '',
      veiculoMarca: json['veiculoMarca'] ?? '',
      veiculoAno: json['veiculoAno'] ?? '',
      veiculoCor: json['veiculoCor'] ?? '',
      veiculoPlaca: json['veiculoPlaca'] ?? '',
      veiculoQuilometragem: json['veiculoQuilometragem'] ?? '',
      veiculoCategoria: json['veiculoCategoria'],
      queixaPrincipal: json['queixaPrincipal'] ?? '',
      servicosOrcados: json['servicosOrcados'] != null ? (json['servicosOrcados'] as List).map((s) => Servico.fromJson(s)).toList() : [],
      pecasOrcadas: json['pecasOrcadas'] != null ? (json['pecasOrcadas'] as List).map((p) => PecaOrdemServico.fromJson(p)).toList() : [],
      precoTotal: json['precoTotal']?.toDouble() ?? 0.0,
      precoTotalServicos: json['precoTotalServicos']?.toDouble(),
      precoTotalPecas: json['precoTotalPecas']?.toDouble(),
      descontoServicos: json['descontoServicos']?.toDouble(),
      descontoPecas: json['descontoPecas']?.toDouble(),
      garantiaMeses: json['garantiaMeses'] ?? 3,
      tipoPagamento: json['tipoPagamento'] != null ? TipoPagamento.fromJson(json['tipoPagamento']) : null,
      numeroParcelas: json['numeroParcelas'],
      mecanico: json['mecanico'] != null ? Funcionario.fromJson(json['mecanico']) : null,
      consultor: json['consultor'] != null ? Funcionario.fromJson(json['consultor']) : null,
      observacoes: json['observacoes'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    if (id != null) map['id'] = id;
    map['numeroOrcamento'] = numeroOrcamento;
    map['dataHora'] = dataHora.toIso8601String();
    map['clienteNome'] = clienteNome;
    map['clienteCpf'] = clienteCpf;
    if (clienteTelefone != null) map['clienteTelefone'] = clienteTelefone;
    if (clienteEmail != null) map['clienteEmail'] = clienteEmail;
    map['veiculoNome'] = veiculoNome;
    map['veiculoMarca'] = veiculoMarca;
    map['veiculoAno'] = veiculoAno;
    map['veiculoCor'] = veiculoCor;
    map['veiculoPlaca'] = veiculoPlaca;
    map['veiculoQuilometragem'] = veiculoQuilometragem;
    if (veiculoCategoria != null) map['veiculoCategoria'] = veiculoCategoria;
    map['queixaPrincipal'] = queixaPrincipal;
    map['servicosOrcados'] = servicosOrcados.map((s) => s.toJson()).toList();
    map['pecasOrcadas'] = pecasOrcadas.map((p) => p.toJson()).toList();
    map['precoTotal'] = precoTotal;
    if (precoTotalServicos != null) map['precoTotalServicos'] = precoTotalServicos;
    if (precoTotalPecas != null) map['precoTotalPecas'] = precoTotalPecas;
    if (descontoServicos != null) map['descontoServicos'] = descontoServicos;
    if (descontoPecas != null) map['descontoPecas'] = descontoPecas;
    map['garantiaMeses'] = garantiaMeses;
    if (tipoPagamento != null) map['tipoPagamento'] = tipoPagamento!.toJson();
    if (numeroParcelas != null) map['numeroParcelas'] = numeroParcelas;
    if (mecanico != null) map['mecanico'] = mecanico!.toJson();
    if (consultor != null) map['consultor'] = consultor!.toJson();
    if (observacoes != null) map['observacoes'] = observacoes;
    if (createdAt != null) map['createdAt'] = createdAt!.toIso8601String();
    if (updatedAt != null) map['updatedAt'] = updatedAt!.toIso8601String();

    return map;
  }

  @override
  String toString() {
    return 'Orçamento $numeroOrcamento';
  }
}
