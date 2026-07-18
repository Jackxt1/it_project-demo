class Technician {
  final int id;
  final String fullName;
  final String? phone;
  final bool active;

  Technician({required this.id, required this.fullName, this.phone, required this.active});

  factory Technician.fromJson(Map<String, dynamic> json) => Technician(
        id: json['id'] as int,
        fullName: json['fullName'] as String,
        phone: json['phone'] as String?,
        active: json['active'] as bool? ?? true,
      );
}
