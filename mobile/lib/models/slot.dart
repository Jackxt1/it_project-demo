/// Slot availability for a given service/date, matching
/// `GET /api/services/{id}/slots?date=YYYY-MM-DD` → `{slots: [...]}`.
class Slot {
  Slot({
    required this.timeSlot,
    required this.capacity,
    required this.booked,
    required this.available,
  });

  final String timeSlot;
  final int capacity;
  final int booked;
  final bool available;

  factory Slot.fromJson(Map<String, dynamic> json) => Slot(
        timeSlot: json['timeSlot'] as String,
        capacity: (json['capacity'] as num).toInt(),
        booked: (json['booked'] as num).toInt(),
        available: json['available'] as bool,
      );
}

class SlotList {
  SlotList({required this.slots});

  final List<Slot> slots;

  factory SlotList.fromJson(Map<String, dynamic> json) => SlotList(
        slots: (json['slots'] as List<dynamic>)
            .map((e) => Slot.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
