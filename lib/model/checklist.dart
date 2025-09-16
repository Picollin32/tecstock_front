class Checklist {
  int? id;
  String numeroChecklist;

  String? data;
  String? hora;
  String? clienteNome;
  String? clienteCpf;
  String? clienteTelefone;
  String? clienteEmail;
  String? veiculoNome;
  String? veiculoMarca;
  String? veiculoAno;
  String? veiculoCor;
  String? veiculoPlaca;
  String? veiculoQuilometragem;
  String? veiculoCategoria;
  String? queixaPrincipal;
  int? nivelCombustivel;
  int? consultorId;
  String? consultorNome;
  String? parachoquesDianteiro;
  String? parachoquesTraseiro;
  String? capo;
  String? portaMalas;
  String? portaDiantEsq;
  String? portaTrasEsq;
  String? portaDiantDir;
  String? portaTrasDir;
  String? teto;
  String? paraBrisa;
  String? retrovisores;
  String? pneusRodas;
  String? estepe;
  String? parachoquesDianteiroObs;
  String? parachoquesTraseiroObs;
  String? capoObs;
  String? portaMalasObs;
  String? portaDiantEsqObs;
  String? portaTrasEsqObs;
  String? portaDiantDirObs;
  String? portaTrasDirObs;
  String? tetoObs;
  String? paraBrisaObs;
  String? retrovisoresObs;
  String? pneusRodasObs;
  String? estepeObs;
  String? buzina;
  String? farolBaixoAlto;
  String? setasPiscaAlerta;
  String? luzFreio;
  String? limpadorParaBrisa;
  String? arCondicionado;
  String? radioMultimidia;
  String? manualLivreto;
  String? crlv;
  String? chaveReserva;
  String? macaco;
  String? chaveRoda;
  String? triangulo;
  String? tapetes;
  String status;
  DateTime? createdAt;
  DateTime? updatedAt;

  Checklist({
    this.id,
    required this.numeroChecklist,
    this.data,
    this.hora,
    this.clienteNome,
    this.clienteCpf,
    this.clienteTelefone,
    this.clienteEmail,
    this.veiculoNome,
    this.veiculoMarca,
    this.veiculoAno,
    this.veiculoCor,
    this.veiculoPlaca,
    this.veiculoQuilometragem,
    this.veiculoCategoria,
    this.queixaPrincipal,
    this.nivelCombustivel,
    this.consultorId,
    this.consultorNome,
    this.parachoquesDianteiro,
    this.parachoquesTraseiro,
    this.capo,
    this.portaMalas,
    this.portaDiantEsq,
    this.portaTrasEsq,
    this.portaDiantDir,
    this.portaTrasDir,
    this.teto,
    this.paraBrisa,
    this.retrovisores,
    this.pneusRodas,
    this.estepe,
    this.parachoquesDianteiroObs,
    this.parachoquesTraseiroObs,
    this.capoObs,
    this.portaMalasObs,
    this.portaDiantEsqObs,
    this.portaTrasEsqObs,
    this.portaDiantDirObs,
    this.portaTrasDirObs,
    this.tetoObs,
    this.paraBrisaObs,
    this.retrovisoresObs,
    this.pneusRodasObs,
    this.estepeObs,
    this.buzina,
    this.farolBaixoAlto,
    this.setasPiscaAlerta,
    this.luzFreio,
    this.limpadorParaBrisa,
    this.arCondicionado,
    this.radioMultimidia,
    this.manualLivreto,
    this.crlv,
    this.chaveReserva,
    this.macaco,
    this.chaveRoda,
    this.triangulo,
    this.tapetes,
    this.status = 'ABERTO',
    this.createdAt,
    this.updatedAt,
  });

  factory Checklist.fromJson(Map<String, dynamic> json) {
    final nc = json['numeroChecklist'];
    return Checklist(
      id: json['id'],
      numeroChecklist: nc != null ? nc.toString() : '',
      data: json['data'],
      hora: json['hora'],
      clienteNome: json['clienteNome'],
      clienteCpf: json['clienteCpf'],
      clienteTelefone: json['clienteTelefone'],
      clienteEmail: json['clienteEmail'],
      veiculoNome: json['veiculoNome'],
      veiculoMarca: json['veiculoMarca'],
      veiculoAno: json['veiculoAno'],
      veiculoCor: json['veiculoCor'],
      veiculoPlaca: json['veiculoPlaca'],
      veiculoQuilometragem: json['veiculoQuilometragem'],
      veiculoCategoria: json['veiculoCategoria'],
      queixaPrincipal: json['queixaPrincipal'],
      nivelCombustivel: json['nivelCombustivel'],
      consultorId: json['consultor'] != null ? json['consultor']['id'] : null,
      consultorNome: json['consultor'] != null ? json['consultor']['nome'] : null,
      parachoquesDianteiro: json['parachoquesDianteiro'],
      parachoquesTraseiro: json['parachoquesTraseiro'],
      capo: json['capo'],
      portaMalas: json['portaMalas'],
      portaDiantEsq: json['portaDiantEsq'],
      portaTrasEsq: json['portaTrasEsq'],
      portaDiantDir: json['portaDiantDir'],
      portaTrasDir: json['portaTrasDir'],
      teto: json['teto'],
      paraBrisa: json['paraBrisa'],
      retrovisores: json['retrovisores'],
      pneusRodas: json['pneusRodas'],
      estepe: json['estepe'],
      parachoquesDianteiroObs: json['parachoquesDianteiroObs'],
      parachoquesTraseiroObs: json['parachoquesTraseiroObs'],
      capoObs: json['capoObs'],
      portaMalasObs: json['portaMalasObs'],
      portaDiantEsqObs: json['portaDiantEsqObs'],
      portaTrasEsqObs: json['portaTrasEsqObs'],
      portaDiantDirObs: json['portaDiantDirObs'],
      portaTrasDirObs: json['portaTrasDirObs'],
      tetoObs: json['tetoObs'],
      paraBrisaObs: json['paraBrisaObs'],
      retrovisoresObs: json['retrovisoresObs'],
      pneusRodasObs: json['pneusRodasObs'],
      estepeObs: json['estepeObs'],
      buzina: json['buzina'],
      farolBaixoAlto: json['farolBaixoAlto'],
      setasPiscaAlerta: json['setasPiscaAlerta'],
      luzFreio: json['luzFreio'],
      limpadorParaBrisa: json['limpadorParaBrisa'],
      arCondicionado: json['arCondicionado'],
      radioMultimidia: json['radioMultimidia'],
      manualLivreto: json['manualLivreto'],
      crlv: json['crlv'],
      chaveReserva: json['chaveReserva'],
      macaco: json['macaco'],
      chaveRoda: json['chaveRoda'],
      triangulo: json['triangulo'],
      tapetes: json['tapetes'],
      status: json['status'] ?? 'ABERTO',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (id != null) map['id'] = id;
    if (id != null || numeroChecklist.isNotEmpty) {
      final parsed = int.tryParse(numeroChecklist);
      map['numeroChecklist'] = parsed ?? numeroChecklist;
    }
    if (data != null) map['data'] = data;
    if (hora != null) map['hora'] = hora;
    if (clienteNome != null) map['clienteNome'] = clienteNome;
    if (clienteCpf != null) map['clienteCpf'] = clienteCpf;
    if (clienteTelefone != null) map['clienteTelefone'] = clienteTelefone;
    if (clienteEmail != null) map['clienteEmail'] = clienteEmail;
    if (veiculoNome != null) map['veiculoNome'] = veiculoNome;
    if (veiculoMarca != null) map['veiculoMarca'] = veiculoMarca;
    if (veiculoAno != null) map['veiculoAno'] = veiculoAno;
    if (veiculoCor != null) map['veiculoCor'] = veiculoCor;
    if (veiculoPlaca != null) map['veiculoPlaca'] = veiculoPlaca;
    if (veiculoQuilometragem != null) map['veiculoQuilometragem'] = veiculoQuilometragem;
    if (veiculoCategoria != null) map['veiculoCategoria'] = veiculoCategoria;
    if (queixaPrincipal != null) map['queixaPrincipal'] = queixaPrincipal;
    if (nivelCombustivel != null) map['nivelCombustivel'] = nivelCombustivel;
    if (consultorId != null) map['consultor'] = {'id': consultorId};
    if (parachoquesDianteiro != null) map['parachoquesDianteiro'] = parachoquesDianteiro;
    if (parachoquesTraseiro != null) map['parachoquesTraseiro'] = parachoquesTraseiro;
    if (capo != null) map['capo'] = capo;
    if (portaMalas != null) map['portaMalas'] = portaMalas;
    if (portaDiantEsq != null) map['portaDiantEsq'] = portaDiantEsq;
    if (portaTrasEsq != null) map['portaTrasEsq'] = portaTrasEsq;
    if (portaDiantDir != null) map['portaDiantDir'] = portaDiantDir;
    if (portaTrasDir != null) map['portaTrasDir'] = portaTrasDir;
    if (teto != null) map['teto'] = teto;
    if (paraBrisa != null) map['paraBrisa'] = paraBrisa;
    if (retrovisores != null) map['retrovisores'] = retrovisores;
    if (pneusRodas != null) map['pneusRodas'] = pneusRodas;
    if (estepe != null) map['estepe'] = estepe;
    if (parachoquesDianteiroObs != null) map['parachoquesDianteiroObs'] = parachoquesDianteiroObs;
    if (parachoquesTraseiroObs != null) map['parachoquesTraseiroObs'] = parachoquesTraseiroObs;
    if (capoObs != null) map['capoObs'] = capoObs;
    if (portaMalasObs != null) map['portaMalasObs'] = portaMalasObs;
    if (portaDiantEsqObs != null) map['portaDiantEsqObs'] = portaDiantEsqObs;
    if (portaTrasEsqObs != null) map['portaTrasEsqObs'] = portaTrasEsqObs;
    if (portaDiantDirObs != null) map['portaDiantDirObs'] = portaDiantDirObs;
    if (portaTrasDirObs != null) map['portaTrasDirObs'] = portaTrasDirObs;
    if (tetoObs != null) map['tetoObs'] = tetoObs;
    if (paraBrisaObs != null) map['paraBrisaObs'] = paraBrisaObs;
    if (retrovisoresObs != null) map['retrovisoresObs'] = retrovisoresObs;
    if (pneusRodasObs != null) map['pneusRodasObs'] = pneusRodasObs;
    if (estepeObs != null) map['estepeObs'] = estepeObs;
    if (buzina != null) map['buzina'] = buzina;
    if (farolBaixoAlto != null) map['farolBaixoAlto'] = farolBaixoAlto;
    if (setasPiscaAlerta != null) map['setasPiscaAlerta'] = setasPiscaAlerta;
    if (luzFreio != null) map['luzFreio'] = luzFreio;
    if (limpadorParaBrisa != null) map['limpadorParaBrisa'] = limpadorParaBrisa;
    if (arCondicionado != null) map['arCondicionado'] = arCondicionado;
    if (radioMultimidia != null) map['radioMultimidia'] = radioMultimidia;
    if (manualLivreto != null) map['manualLivreto'] = manualLivreto;
    if (crlv != null) map['crlv'] = crlv;
    if (chaveReserva != null) map['chaveReserva'] = chaveReserva;
    if (macaco != null) map['macaco'] = macaco;
    if (chaveRoda != null) map['chaveRoda'] = chaveRoda;
    if (triangulo != null) map['triangulo'] = triangulo;
    if (tapetes != null) map['tapetes'] = tapetes;
    map['status'] = status;
    if (createdAt != null) map['createdAt'] = createdAt!.toIso8601String();
    if (updatedAt != null) map['updatedAt'] = updatedAt!.toIso8601String();

    return map;
  }

  @override
  String toString() {
    return numeroChecklist;
  }
}
