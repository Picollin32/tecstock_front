import 'package:tecstock/model/marca.dart';

class Veiculo {
  int? id;
  String nome;
  String placa;
  int ano;
  String modelo;
  Marca? marca;
  String categoria;
  String cor;
  double quilometragem;
  DateTime? createdAt;
  DateTime? updatedAt;

  Veiculo({
    this.id,
    required this.nome,
    required this.placa,
    required this.ano,
    required this.modelo,
    this.marca,
    required this.categoria,
    required this.cor,
    required this.quilometragem,
    this.createdAt,
    this.updatedAt,
  });

  factory Veiculo.fromJson(Map<String, dynamic> json) {
    return Veiculo(
      id: json['id'],
      nome: json['nome'],
      placa: json['placa'],
      ano: json['ano'],
      modelo: json['modelo'],
      marca: json['marca'] != null ? Marca.fromJson(json['marca']) : null,
      categoria: json['categoria'] ?? 'Passeio',
      cor: json['cor'],
      quilometragem: json['quilometragem'] as double,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'placa': placa,
      'ano': ano,
      'modelo': modelo,
      'marca': {
        'id': marca!.id,
        'marca': marca!.marca,
      },
      'categoria': categoria,
      'cor': cor,
      'quilometragem': quilometragem,
    };
  }
}
