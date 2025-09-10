import 'servico.dart';
import 'tipo_pagamento.dart';
import 'peca_ordem_servico.dart';

class OrdemServico {
  int? id;
  String numeroOS;

  // Data e hora
  DateTime dataHora;

  // Dados do cliente (mecânicos e consultores também podem ser clientes)
  String clienteNome;
  String clienteCpf;
  String? clienteTelefone;
  String? clienteEmail;

  // Dados do veículo
  String veiculoNome;
  String veiculoMarca;
  String veiculoAno;
  String veiculoCor;
  String veiculoPlaca;
  String veiculoQuilometragem;
  String? veiculoCategoria;

  // Referência ao checklist
  int? checklistId;

  // Queixa automática do checklist
  String queixaPrincipal;

  // Serviços selecionados (objetos Servico completos)
  List<Servico> servicosRealizados;

  // Peças utilizadas (objetos PecaOrdemServico com quantidade)
  List<PecaOrdemServico> pecasUtilizadas;

  // Preço total calculado (serviços + peças)
  double precoTotal;

  // Garantia (em meses, padrão 3)
  int garantiaMeses;

  // Tipo de pagamento
  TipoPagamento? tipoPagamento;

  // Status da OS
  String status; // Pendente, Em Andamento, Concluída, Cancelada

  // Observações gerais
  String? observacoes;

  DateTime? createdAt;
  DateTime? updatedAt;

  OrdemServico({
    this.id,
    required this.numeroOS,
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
    this.checklistId,
    required this.queixaPrincipal,
    required this.servicosRealizados,
    this.pecasUtilizadas = const [],
    required this.precoTotal,
    this.garantiaMeses = 3, // Padrão de 3 meses por lei
    this.tipoPagamento,
    this.status = 'Pendente',
    this.observacoes,
    this.createdAt,
    this.updatedAt,
  });

  factory OrdemServico.fromJson(Map<String, dynamic> json) {
    return OrdemServico(
      id: json['id'],
      numeroOS: json['numeroOS']?.toString() ?? '',
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
      checklistId: json['checklistId'],
      queixaPrincipal: json['queixaPrincipal'] ?? '',
      servicosRealizados:
          json['servicosRealizados'] != null ? (json['servicosRealizados'] as List).map((s) => Servico.fromJson(s)).toList() : [],
      pecasUtilizadas:
          json['pecasUtilizadas'] != null ? (json['pecasUtilizadas'] as List).map((p) => PecaOrdemServico.fromJson(p)).toList() : [],
      precoTotal: json['precoTotal']?.toDouble() ?? 0.0,
      garantiaMeses: json['garantiaMeses'] ?? 3,
      tipoPagamento: json['tipoPagamento'] != null ? TipoPagamento.fromJson(json['tipoPagamento']) : null,
      status: json['status'] ?? 'Pendente',
      observacoes: json['observacoes'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    if (id != null) map['id'] = id;
    map['numeroOS'] = numeroOS;
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
    if (checklistId != null) map['checklistId'] = checklistId;
    map['queixaPrincipal'] = queixaPrincipal;
    map['servicosRealizados'] = servicosRealizados.map((s) => s.toJson()).toList();
    map['pecasUtilizadas'] = pecasUtilizadas.map((p) => p.toJson()).toList();
    map['precoTotal'] = precoTotal;
    map['garantiaMeses'] = garantiaMeses;
    if (tipoPagamento != null) map['tipoPagamento'] = tipoPagamento!.toJson();
    map['status'] = status;
    if (observacoes != null) map['observacoes'] = observacoes;
    if (createdAt != null) map['createdAt'] = createdAt!.toIso8601String();
    if (updatedAt != null) map['updatedAt'] = updatedAt!.toIso8601String();

    return map;
  }

  @override
  String toString() {
    return 'OS $numeroOS';
  }
}
