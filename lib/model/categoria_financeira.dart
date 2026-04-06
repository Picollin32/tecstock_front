class CategoriaFinanceira {
  final int? id;
  final String nome;
  final String? descricao;
  final bool ativo;

  CategoriaFinanceira({
    this.id,
    required this.nome,
    this.descricao,
    this.ativo = true,
  });

  factory CategoriaFinanceira.fromJson(Map<String, dynamic> json) {
    return CategoriaFinanceira(
      id: json['id'],
      nome: (json['nome'] ?? '').toString(),
      descricao: json['descricao']?.toString(),
      ativo: json['ativo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nome': nome,
      'descricao': descricao,
      'ativo': ativo,
    };
  }
}
