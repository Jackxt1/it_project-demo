/// Customer vehicle, matching VehicleResponse / VehicleRequest contracts:
/// `{id, vehicleType(SEDAN|PICKUP|SUV|OTHER), brandModel, year?, licensePlate}`
class Vehicle {
  Vehicle({
    this.id,
    required this.vehicleType,
    required this.brandModel,
    this.year,
    required this.licensePlate,
  });

  final int? id;
  final String vehicleType;
  final String brandModel;
  final int? year;
  final String licensePlate;

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as int?,
        vehicleType: json['vehicleType'] as String,
        brandModel: json['brandModel'] as String,
        year: json['year'] as int?,
        licensePlate: json['licensePlate'] as String,
      );

  /// Request body for `POST /api/vehicles` / `PUT /api/vehicles/{id}`.
  /// `id` is server-assigned, so it is only included when already known.
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'vehicleType': vehicleType,
        'brandModel': brandModel,
        'year': year,
        'licensePlate': licensePlate,
      };
}
