class Marca {
  int? id;
  String marca;

  Marca({
    this.id,
    required this.marca,
  });

  factory Marca.fromJson(Map<String, dynamic> json) {
    return Marca(
      id: json['id'],
      marca: json['marca'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'marca': marca,
    };
  }

  @override
  String toString() {
    return marca;
  }
}
