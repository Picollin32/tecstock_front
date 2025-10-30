class Marca {
  int? id;
  String marca;
  DateTime? createdAt;
  DateTime? updatedAt;

  Marca({
    this.id,
    required this.marca,
    this.createdAt,
    this.updatedAt,
  });

  factory Marca.fromJson(Map<String, dynamic> json) {
    return Marca(
      id: json['id'],
      marca: json['marca'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
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
