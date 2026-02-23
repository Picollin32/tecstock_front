class BrazilianValidators {
  static String? validarInscricaoEstadual(String ie, String uf) {
    final valor = ie.trim();
    if (valor.isEmpty) return null;

    if (valor.toUpperCase() == 'ISENTO') return null;

    final digits = valor.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return 'IE inválida';

    switch (uf.toUpperCase()) {
      case 'AC':
        return _validarTamanho(digits, 13, 'AC') ?? _validarModulo11Padrao(digits, 13);
      case 'AL':
        return _validarTamanho(digits, 9, 'AL') ?? _validarModulo11Padrao(digits, 9);
      case 'AP':
        return _validarTamanho(digits, 9, 'AP') ?? _validarModulo11Padrao(digits, 9);
      case 'AM':
        return _validarTamanho(digits, 9, 'AM') ?? _validarModulo11Padrao(digits, 9);
      case 'BA':
        if (digits.length != 8 && digits.length != 9) {
          return 'IE para BA deve ter 8 ou 9 dígitos';
        }
        return _validarIEBA(digits);
      case 'CE':
        return _validarTamanho(digits, 9, 'CE') ?? _validarIECE(digits);
      case 'DF':
        return _validarTamanho(digits, 13, 'DF') ?? _validarModulo11Padrao(digits, 13);
      case 'ES':
        return _validarTamanho(digits, 9, 'ES') ?? _validarModulo11Padrao(digits, 9);
      case 'GO':
        return _validarTamanho(digits, 9, 'GO') ?? _validarIEGO(digits);
      case 'MA':
        return _validarTamanho(digits, 9, 'MA') ?? _validarModulo11Padrao(digits, 9);
      case 'MG':
        return _validarTamanho(digits, 13, 'MG') ?? _validarIEMG(digits);
      case 'MT':
        return _validarTamanho(digits, 11, 'MT') ?? _validarModulo11Padrao(digits, 11);
      case 'MS':
        if (digits.length != 14) return 'IE para MS deve ter 14 dígitos';
        if (!digits.startsWith('28')) return 'IE/MS deve começar com 28';
        return null;
      case 'PA':
        return _validarTamanho(digits, 9, 'PA') ?? _validarModulo11Padrao(digits, 9);
      case 'PB':
        return _validarTamanho(digits, 9, 'PB') ?? _validarModulo11Padrao(digits, 9);
      case 'PE':
        if (digits.length != 9 && digits.length != 14) {
          return 'IE para PE deve ter 9 ou 14 dígitos';
        }
        if (digits.length == 9) return _validarIEPE(digits);
        return null;
      case 'PI':
        return _validarTamanho(digits, 9, 'PI') ?? _validarModulo11Padrao(digits, 9);
      case 'PR':
        return _validarTamanho(digits, 10, 'PR') ?? _validarIEPR(digits);
      case 'RJ':
        return _validarTamanho(digits, 8, 'RJ') ?? _validarIERJ(digits);
      case 'RN':
        if (digits.length != 9 && digits.length != 10) {
          return 'IE para RN deve ter 9 ou 10 dígitos';
        }
        return _validarIERN(digits);
      case 'RO':
        return _validarTamanho(digits, 14, 'RO');
      case 'RR':
        return _validarTamanho(digits, 9, 'RR') ?? _validarModulo11Padrao(digits, 9);
      case 'RS':
        return _validarTamanho(digits, 10, 'RS') ?? _validarIERS(digits);
      case 'SC':
        return _validarTamanho(digits, 9, 'SC') ?? _validarIESC(digits);
      case 'SE':
        return _validarTamanho(digits, 9, 'SE') ?? _validarModulo11Padrao(digits, 9);
      case 'SP':
        return _validarTamanho(digits, 12, 'SP') ?? _validarIESP(digits);
      case 'TO':
        return _validarTamanho(digits, 11, 'TO') ?? _validarModulo11Padrao(digits, 11);
      default:
        return null;
    }
  }

  static int maxDigitosIE(String uf) {
    switch (uf.toUpperCase()) {
      case 'AC':
      case 'DF':
      case 'MG':
        return 13;
      case 'MS':
      case 'PE':
      case 'RO':
        return 14;
      case 'MT':
      case 'TO':
        return 11;
      case 'SP':
        return 12;
      case 'PR':
      case 'RS':
        return 10;
      case 'RJ':
      case 'BA':
        return 9;
      case 'RN':
        return 10;
      default:
        return 9;
    }
  }

  static String? _validarTamanho(String digits, int esperado, String uf) {
    if (digits.length != esperado) {
      return 'IE para $uf deve ter $esperado dígitos';
    }
    return null;
  }

  static String? _validarModulo11Padrao(String digits, int tamanho) {
    int sum = 0;
    int peso = 2;
    for (int i = tamanho - 2; i >= 0; i--) {
      sum += int.parse(digits[i]) * peso;
      peso = peso == 9 ? 2 : peso + 1;
    }
    final remainder = sum % 11;
    final check = remainder < 2 ? 0 : 11 - remainder;
    if (check != int.parse(digits[tamanho - 1])) {
      return 'IE inválida (dígito verificador incorreto)';
    }
    return null;
  }

  static String? _validarIEBA(String digits) {
    final tamanho = digits.length;
    final baseLen = tamanho - 2;
    final primeiroDigito = int.parse(digits[0]);
    final usaMod10 = {0, 1, 2, 3, 4, 5, 8}.contains(primeiroDigito);

    int calcDV(List<int> bases) {
      int sum = 0;

      for (int i = 0; i < bases.length; i++) {
        sum += bases[i] * (bases.length + 1 - i);
      }
      if (usaMod10) {
        final r = sum % 10;
        return r == 0 ? 0 : 10 - r;
      } else {
        final r = sum % 11;
        return r < 2 ? 0 : 11 - r;
      }
    }

    final base = List.generate(baseLen, (i) => int.parse(digits[i]));
    final d1Esperado = calcDV(base);
    final d1Real = int.parse(digits[baseLen]);
    if (d1Esperado != d1Real) {
      return 'IE/BA inválida (1º dígito verificador incorreto)';
    }

    final baseComD1 = [...base, d1Real];
    final d2Esperado = calcDV(baseComD1);
    final d2Real = int.parse(digits[baseLen + 1]);
    if (d2Esperado != d2Real) {
      return 'IE/BA inválida (2º dígito verificador incorreto)';
    }

    return null;
  }

  static String? _validarIEGO(String digits) {
    final prefix = int.tryParse(digits.substring(0, 2));
    if (prefix != 10 && prefix != 11 && prefix != 15) {
      return 'IE/GO deve começar com 10, 11 ou 15';
    }
    const weights = [9, 8, 7, 6, 5, 4, 3, 2];
    int sum = 0;
    for (int i = 0; i < 8; i++) {
      sum += int.parse(digits[i]) * weights[i];
    }
    final remainder = sum % 11;
    int check;
    if (remainder == 0) {
      check = 0;
    } else if (remainder == 1) {
      final base = int.parse(digits.substring(0, 8));
      check = (base >= 10103105 && base <= 10119997) ? 1 : 0;
    } else {
      check = 11 - remainder;
    }
    if (check != int.parse(digits[8])) {
      return 'IE/GO inválida (dígito verificador incorreto)';
    }
    return null;
  }

  static String? _validarIESP(String digits) {
    const w1 = [1, 3, 4, 5, 6, 7, 8, 10];
    int sum1 = 0;
    for (int i = 0; i < 8; i++) {
      sum1 += int.parse(digits[i]) * w1[i];
    }
    final check1 = (sum1 % 11) % 10;
    if (check1 != int.parse(digits[8])) {
      return 'IE/SP inválida (1º dígito verificador incorreto)';
    }

    const w2 = [3, 2, 10, 9, 8, 7, 6, 5, 4, 3, 2];
    int sum2 = 0;
    for (int i = 0; i < 11; i++) {
      sum2 += int.parse(digits[i]) * w2[i];
    }
    final check2 = (sum2 % 11) % 10;
    if (check2 != int.parse(digits[11])) {
      return 'IE/SP inválida (2º dígito verificador incorreto)';
    }
    return null;
  }

  static String? _validarIEPR(String digits) {
    const w1 = [3, 2, 7, 6, 5, 4, 3, 2];
    int sum1 = 0;
    for (int i = 0; i < 8; i++) {
      sum1 += int.parse(digits[i]) * w1[i];
    }
    final r1 = sum1 % 11;
    final check1 = r1 < 2 ? 0 : 11 - r1;
    if (check1 != int.parse(digits[8])) {
      return 'IE/PR inválida (1º dígito verificador incorreto)';
    }

    const w2 = [4, 3, 2, 7, 6, 5, 4, 3, 2];
    int sum2 = 0;
    for (int i = 0; i < 9; i++) {
      sum2 += int.parse(digits[i]) * w2[i];
    }
    final r2 = sum2 % 11;
    final check2 = r2 < 2 ? 0 : 11 - r2;
    if (check2 != int.parse(digits[9])) {
      return 'IE/PR inválida (2º dígito verificador incorreto)';
    }
    return null;
  }

  static String? _validarIERJ(String digits) {
    const weights = [2, 7, 6, 5, 4, 3, 2];
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      sum += int.parse(digits[i]) * weights[i];
    }
    final remainder = sum % 11;
    final check = remainder < 2 ? 0 : 11 - remainder;
    if (check != int.parse(digits[7])) {
      return 'IE/RJ inválida (dígito verificador incorreto)';
    }
    return null;
  }

  static String? _validarIERS(String digits) {
    const weights = [2, 9, 8, 7, 6, 5, 4, 3, 2];
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      sum += int.parse(digits[i]) * weights[i];
    }
    final remainder = sum % 11;
    final check = remainder < 2 ? 0 : 11 - remainder;
    if (check != int.parse(digits[9])) {
      return 'IE/RS inválida (dígito verificador incorreto)';
    }
    return null;
  }

  static String? _validarIESC(String digits) {
    const weights = [9, 8, 7, 6, 5, 4, 3, 2];
    int sum = 0;
    for (int i = 0; i < 8; i++) {
      sum += int.parse(digits[i]) * weights[i];
    }
    final remainder = sum % 11;
    final check = remainder < 2 ? 0 : 11 - remainder;
    if (check != int.parse(digits[8])) {
      return 'IE/SC inválida (dígito verificador incorreto)';
    }
    return null;
  }

  static String? _validarIECE(String digits) {
    const weights = [9, 8, 7, 6, 5, 4, 3, 2];
    int sum = 0;
    for (int i = 0; i < 8; i++) {
      sum += int.parse(digits[i]) * weights[i];
    }
    final remainder = sum % 11;
    final check = (remainder == 0 || remainder == 1) ? 0 : 11 - remainder;
    if (check != int.parse(digits[8])) {
      return 'IE/CE inválida (dígito verificador incorreto)';
    }
    return null;
  }

  static String? _validarIEPE(String digits) {
    const w1 = [8, 7, 6, 5, 4, 3, 2];
    int sum1 = 0;
    for (int i = 0; i < 7; i++) {
      sum1 += int.parse(digits[i]) * w1[i];
    }
    final r1 = sum1 % 11;
    final check1 = r1 < 2 ? 0 : 11 - r1;
    if (check1 != int.parse(digits[7])) {
      return 'IE/PE inválida (1º dígito verificador incorreto)';
    }

    const w2 = [9, 8, 7, 6, 5, 4, 3, 2];
    int sum2 = 0;
    for (int i = 0; i < 8; i++) {
      sum2 += int.parse(digits[i]) * w2[i];
    }
    final r2 = sum2 % 11;
    final check2 = r2 < 2 ? 0 : 11 - r2;
    if (check2 != int.parse(digits[8])) {
      return 'IE/PE inválida (2º dígito verificador incorreto)';
    }
    return null;
  }

  static String? _validarIERN(String digits) {
    if (digits.length == 9) {
      const weights = [9, 8, 7, 6, 5, 4, 3, 2];
      int sum = 0;
      for (int i = 0; i < 8; i++) {
        sum += int.parse(digits[i]) * weights[i];
      }
      final r = sum % 11;
      final check = r < 2 ? 0 : 11 - r;
      if (check != int.parse(digits[8])) {
        return 'IE/RN inválida (dígito verificador incorreto)';
      }
    } else {
      const weights = [10, 9, 8, 7, 6, 5, 4, 3, 2];
      int sum = 0;
      for (int i = 0; i < 9; i++) {
        sum += int.parse(digits[i]) * weights[i];
      }
      final r = sum % 11;
      final check = r < 2 ? 0 : 11 - r;
      if (check != int.parse(digits[9])) {
        return 'IE/RN inválida (dígito verificador incorreto)';
      }
    }
    return null;
  }

  static String? _validarIEMG(String digits) {
    final expandido = '${digits.substring(0, 3)}0${digits.substring(3, 11)}';
    const weights1 = [1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2];
    int sum1 = 0;
    for (int i = 0; i < 12; i++) {
      final p = int.parse(expandido[i]) * weights1[i];
      sum1 += p >= 10 ? (p ~/ 10 + p % 10) : p;
    }
    final prox10 = (((sum1 ~/ 10) + 1) * 10);
    final check1 = prox10 - sum1;
    final digV1 = check1 >= 10 ? 0 : check1;
    if (digV1 != int.parse(digits[11])) {
      return 'IE/MG inválida (1º dígito verificador incorreto)';
    }
    const weights2 = [3, 2, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2];
    int sum2 = 0;
    for (int i = 0; i < 12; i++) {
      sum2 += int.parse(digits[i]) * weights2[i];
    }
    final r2 = sum2 % 11;
    final check2 = r2 < 2 ? 0 : 11 - r2;
    if (check2 != int.parse(digits[12])) {
      return 'IE/MG inválida (2º dígito verificador incorreto)';
    }
    return null;
  }

  static const Set<int> _ufCodesValidos = {
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    31,
    32,
    33,
    35,
    41,
    42,
    43,
    50,
    51,
    52,
    53,
  };

  static String? validarCodigoIBGE(String codigo) {
    if (codigo.trim().isEmpty) return 'Código do Município é obrigatório';

    final digits = codigo.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 7) return 'Código IBGE deve ter 7 dígitos';

    final ufCode = int.parse(digits.substring(0, 2));
    if (!_ufCodesValidos.contains(ufCode)) {
      return 'Código IBGE inválido (prefixo de UF inexistente)';
    }

    int sum = 0;
    for (int i = 0; i < 6; i++) {
      int produto = int.parse(digits[i]) * (i.isEven ? 1 : 2);
      if (produto >= 10) produto = produto ~/ 10 + produto % 10;
      sum += produto;
    }
    final remainder = sum % 10;
    final check = remainder == 0 ? 0 : 10 - remainder;

    if (check != int.parse(digits[6])) {
      return 'Código IBGE inválido (dígito verificador incorreto)';
    }
    return null;
  }

  static const Set<String> _divisioesCNAEValidas = {
    '01',
    '02',
    '03',
    '05',
    '06',
    '07',
    '08',
    '09',
    '10',
    '11',
    '12',
    '13',
    '14',
    '15',
    '16',
    '17',
    '18',
    '19',
    '20',
    '21',
    '22',
    '23',
    '24',
    '25',
    '26',
    '27',
    '28',
    '29',
    '30',
    '31',
    '32',
    '33',
    '35',
    '36',
    '37',
    '38',
    '39',
    '41',
    '42',
    '43',
    '45',
    '46',
    '47',
    '49',
    '50',
    '51',
    '52',
    '53',
    '55',
    '56',
    '58',
    '59',
    '60',
    '61',
    '62',
    '63',
    '64',
    '65',
    '66',
    '68',
    '69',
    '70',
    '71',
    '72',
    '73',
    '74',
    '75',
    '77',
    '78',
    '79',
    '80',
    '81',
    '82',
    '84',
    '85',
    '86',
    '87',
    '88',
    '90',
    '91',
    '92',
    '93',
    '94',
    '95',
    '96',
    '97',
    '99',
  };

  static String? validarCNAE(String cnae) {
    if (cnae.trim().isEmpty) return 'CNAE é obrigatório para emissão de NF';

    final digits = cnae.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 7) {
      return 'CNAE deve ter 7 dígitos (Ex: 4520-0/01)';
    }

    final divisao = digits.substring(0, 2);
    if (!_divisioesCNAEValidas.contains(divisao)) {
      return 'CNAE inválido (divisão $divisao não existe na tabela CNAE-IBGE)';
    }

    if (cnae.contains('-') || cnae.contains('/')) {
      final regex = RegExp(r'^\d{4}-\d/\d{2}$');
      if (!regex.hasMatch(cnae.trim())) {
        return 'Formato inválido. Use: NNNN-N/NN (Ex: 4520-0/01)';
      }
    }

    return null;
  }

  static String formatarCNAE(String digits) {
    final d = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length < 4) return d;
    if (d.length == 4) return '${d.substring(0, 4)}-';
    if (d.length == 5) return '${d.substring(0, 4)}-${d.substring(4, 5)}/';
    if (d.length == 6) return '${d.substring(0, 4)}-${d.substring(4, 5)}/${d.substring(5, 6)}';
    return '${d.substring(0, 4)}-${d.substring(4, 5)}/${d.substring(5, 7)}';
  }

  static String? validarInscricaoMunicipal(String im) {
    if (im.trim().isEmpty) return 'Inscrição Municipal é obrigatória';
    final digits = im.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 4) return 'IM inválida (mínimo 4 dígitos)';
    if (digits.length > 15) return 'IM inválida (máximo 15 dígitos)';
    return null;
  }
}
