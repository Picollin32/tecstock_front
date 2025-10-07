class AuditoriaLog {
  final int? id;
  final String entidade;
  final int entidadeId;
  final String operacao; // CREATE, UPDATE, DELETE
  final String usuario;
  final DateTime dataHora;
  final String? valoresAntigos;
  final String? valoresNovos;
  final String descricao;

  AuditoriaLog({
    this.id,
    required this.entidade,
    required this.entidadeId,
    required this.operacao,
    required this.usuario,
    required this.dataHora,
    this.valoresAntigos,
    this.valoresNovos,
    required this.descricao,
  });

  factory AuditoriaLog.fromJson(Map<String, dynamic> json) {
    return AuditoriaLog(
      id: json['id'],
      entidade: json['entidade'],
      entidadeId: json['entidadeId'],
      operacao: json['operacao'],
      usuario: json['usuario'],
      dataHora: DateTime.parse(json['dataHora']),
      valoresAntigos: json['valoresAntigos'],
      valoresNovos: json['valoresNovos'],
      descricao: json['descricao'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entidade': entidade,
      'entidadeId': entidadeId,
      'operacao': operacao,
      'usuario': usuario,
      'dataHora': dataHora.toIso8601String(),
      'valoresAntigos': valoresAntigos,
      'valoresNovos': valoresNovos,
      'descricao': descricao,
    };
  }

  String get operacaoFormatada {
    switch (operacao) {
      case 'CREATE':
        return 'Criação';
      case 'UPDATE':
        return 'Atualização';
      case 'DELETE':
        return 'Exclusão';
      default:
        return operacao;
    }
  }

  String get dataHoraFormatada {
    return '${dataHora.day.toString().padLeft(2, '0')}/'
        '${dataHora.month.toString().padLeft(2, '0')}/'
        '${dataHora.year} '
        '${dataHora.hour.toString().padLeft(2, '0')}:'
        '${dataHora.minute.toString().padLeft(2, '0')}:'
        '${dataHora.second.toString().padLeft(2, '0')}';
  }
}
