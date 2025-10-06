import 'package:TecStock/model/funcionario.dart';

class Usuario {
  int? id;
  String nomeUsuario;
  String? senha;
  Funcionario consultor;
  DateTime? createdAt;
  DateTime? updatedAt;

  Usuario({
    this.id,
    required this.nomeUsuario,
    this.senha,
    required this.consultor,
    this.createdAt,
    this.updatedAt,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'],
      nomeUsuario: json['nomeUsuario'],
      senha: json['senha'],
      consultor: Funcionario.fromJson(json['consultor']),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'nomeUsuario': nomeUsuario,
      'consultor': {'id': consultor.id},
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };

    if (senha != null && senha!.isNotEmpty) {
      data['senha'] = senha;
    }

    return data;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Usuario) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Usuario{id: $id, nomeUsuario: $nomeUsuario}';
  }
}
