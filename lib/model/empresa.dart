class Empresa {
  final int? id;
  final String cnpj;
  final String razaoSocial;
  final String nomeFantasia;
  final String? inscricaoEstadual;
  final String? inscricaoMunicipal;
  final String? telefone;
  final String? email;
  final String? site;
  final String cep;
  final String logradouro;
  final String numero;
  final String? complemento;
  final String bairro;
  final String cidade;
  final String uf;
  final String? codigoMunicipio;
  final String? regimeTributario;
  final String? cnae;
  final bool ativa;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Empresa({
    this.id,
    required this.cnpj,
    required this.razaoSocial,
    required this.nomeFantasia,
    this.inscricaoEstadual,
    this.inscricaoMunicipal,
    this.telefone,
    this.email,
    this.site,
    required this.cep,
    required this.logradouro,
    required this.numero,
    this.complemento,
    required this.bairro,
    required this.cidade,
    required this.uf,
    this.codigoMunicipio,
    this.regimeTributario,
    this.cnae,
    this.ativa = true,
    this.createdAt,
    this.updatedAt,
  });

  factory Empresa.fromJson(Map<String, dynamic> json) {
    return Empresa(
      id: json['id'],
      cnpj: json['cnpj'] ?? '',
      razaoSocial: json['razaoSocial'] ?? '',
      nomeFantasia: json['nomeFantasia'] ?? '',
      inscricaoEstadual: json['inscricaoEstadual'],
      inscricaoMunicipal: json['inscricaoMunicipal'],
      telefone: json['telefone'],
      email: json['email'],
      site: json['site'],
      cep: json['cep'] ?? '',
      logradouro: json['logradouro'] ?? '',
      numero: json['numero'] ?? '',
      complemento: json['complemento'],
      bairro: json['bairro'] ?? '',
      cidade: json['cidade'] ?? '',
      uf: json['uf'] ?? '',
      codigoMunicipio: json['codigoMunicipio'],
      regimeTributario: json['regimeTributario'],
      cnae: json['cnae'],
      ativa: json['ativa'] ?? true,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cnpj': cnpj,
      'razaoSocial': razaoSocial,
      'nomeFantasia': nomeFantasia,
      'inscricaoEstadual': inscricaoEstadual,
      'inscricaoMunicipal': inscricaoMunicipal,
      'telefone': telefone,
      'email': email,
      'site': site,
      'cep': cep,
      'logradouro': logradouro,
      'numero': numero,
      'complemento': complemento,
      'bairro': bairro,
      'cidade': cidade,
      'uf': uf,
      'codigoMunicipio': codigoMunicipio,
      'regimeTributario': regimeTributario,
      'cnae': cnae,
      'ativa': ativa,
    };
  }
}
