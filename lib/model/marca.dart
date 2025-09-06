class Marca {
  int? id;
  String marca;
  DateTime? createdAt;

  Marca({
    this.id,
    required this.marca,
    this.createdAt,
  });

  factory Marca.fromJson(Map<String, dynamic> json) {
    return Marca(
      id: json['id'],
      marca: json['marca'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'marca': marca,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return marca;
  }
}
