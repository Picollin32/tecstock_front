class Checklist {
  int? id;
  String numeroChecklist;

  Checklist({
    this.id,
    required this.numeroChecklist,
  });

  factory Checklist.fromJson(Map<String, dynamic> json) {
    return Checklist(
      id: json['id'],
      numeroChecklist: json['numeroChecklist'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numeroChecklist': numeroChecklist,
    };
  }

  @override
  String toString() {
    return numeroChecklist;
  }
}
