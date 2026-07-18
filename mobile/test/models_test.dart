import 'package:flutter_test/flutter_test.dart';

import 'package:bkk_customer/models/booking.dart';
import 'package:bkk_customer/models/vehicle.dart';
import 'package:bkk_customer/models/slot.dart';

void main() {
  group('Booking.fromJson', () {
    final json = {
      'id': 1,
      'orderCode': 'BKDL-000001-0001',
      'userId': 10,
      'userFullName': 'สมชาย ใจดี',
      'serviceId': 2,
      'serviceName': 'ติดตั้งฟิล์มกรองแสง',
      'productId': 5,
      'productName': 'ฟิล์ม 3M รุ่น Crystalline',
      'technicianId': 7,
      'technicianName': 'ช่างเอ',
      'vehicleId': 3,
      'vehicleBrandModel': 'Toyota Camry',
      'vehicleLicensePlate': 'กข 1234',
      'installArea': 'FULL',
      'paymentType': 'DEPOSIT',
      'paidAmount': 600.00,
      'bookingDate': '2026-08-01',
      'timeSlot': '10:00-11:00',
      'status': 'CONFIRMED',
      'budget': 5000.00,
      'imageUrl': 'https://example.com/car.jpg',
      'quotePrice': 4800.00,
      'notes': 'โปรดโทรก่อนถึง',
      'statusHistory': [
        {
          'id': 1,
          'status': 'PENDING',
          'note': 'สร้างคำสั่งจอง',
          'changedByName': 'ระบบ',
          'changedAt': '2026-07-18T09:00:00',
        },
        {
          'id': 2,
          'status': 'CONFIRMED',
          'note': 'ยืนยันคิว',
          'changedByName': 'แอดมิน',
          'changedAt': '2026-07-18T10:00:00',
        },
      ],
    };

    test('parses every field from the BookingResponse contract', () {
      final booking = Booking.fromJson(json);

      expect(booking.id, 1);
      expect(booking.orderCode, 'BKDL-000001-0001');
      expect(booking.userId, 10);
      expect(booking.userFullName, 'สมชาย ใจดี');
      expect(booking.serviceId, 2);
      expect(booking.serviceName, 'ติดตั้งฟิล์มกรองแสง');
      expect(booking.productId, 5);
      expect(booking.productName, 'ฟิล์ม 3M รุ่น Crystalline');
      expect(booking.technicianId, 7);
      expect(booking.technicianName, 'ช่างเอ');
      expect(booking.vehicleId, 3);
      expect(booking.vehicleBrandModel, 'Toyota Camry');
      expect(booking.vehicleLicensePlate, 'กข 1234');
      expect(booking.installArea, 'FULL');
      expect(booking.paymentType, 'DEPOSIT');
      expect(booking.paidAmount, 600.00);
      expect(booking.bookingDate, DateTime.parse('2026-08-01'));
      expect(booking.timeSlot, '10:00-11:00');
      expect(booking.status, 'CONFIRMED');
      expect(booking.budget, 5000.00);
      expect(booking.imageUrl, 'https://example.com/car.jpg');
      expect(booking.quotePrice, 4800.00);
      expect(booking.notes, 'โปรดโทรก่อนถึง');

      expect(booking.statusHistory, hasLength(2));
      expect(booking.statusHistory[0].id, 1);
      expect(booking.statusHistory[0].status, 'PENDING');
      expect(booking.statusHistory[0].note, 'สร้างคำสั่งจอง');
      expect(booking.statusHistory[0].changedByName, 'ระบบ');
      expect(booking.statusHistory[0].changedAt,
          DateTime.parse('2026-07-18T09:00:00'));
      expect(booking.statusHistory[1].status, 'CONFIRMED');
      expect(booking.statusHistory[1].changedByName, 'แอดมิน');
    });

    test('statusLabel translates every known status', () {
      expect(Booking.fromJson({...json, 'status': 'PENDING'}).statusLabel,
          'รอดำเนินการ');
      expect(Booking.fromJson({...json, 'status': 'CONFIRMED'}).statusLabel,
          'ยืนยันแล้ว');
      expect(Booking.fromJson({...json, 'status': 'IN_PROGRESS'}).statusLabel,
          'กำลังดำเนินการ');
      expect(Booking.fromJson({...json, 'status': 'COMPLETED'}).statusLabel,
          'เสร็จสิ้น');
      expect(Booking.fromJson({...json, 'status': 'CANCELLED'}).statusLabel,
          'ยกเลิก');
    });

    test('handles nullable optional fields gracefully', () {
      final minimal = {
        'id': 2,
        'orderCode': 'BKDL-000002-0001',
        'userId': 11,
        'userFullName': 'สมหญิง ใจดี',
        'serviceId': 4,
        'serviceName': 'ซ่อมกระจก',
        'paidAmount': 0,
        'bookingDate': '2026-08-02',
        'timeSlot': '09:00-10:00',
        'status': 'PENDING',
        'statusHistory': <Map<String, dynamic>>[],
      };

      final booking = Booking.fromJson(minimal);
      expect(booking.productId, isNull);
      expect(booking.productName, isNull);
      expect(booking.vehicleId, isNull);
      expect(booking.installArea, isNull);
      expect(booking.paymentType, isNull);
      expect(booking.budget, isNull);
      expect(booking.quotePrice, isNull);
      expect(booking.notes, isNull);
      expect(booking.statusHistory, isEmpty);
    });
  });

  group('Vehicle.fromJson / toJson round trip', () {
    test('round trips every field', () {
      final json = {
        'id': 1,
        'vehicleType': 'SUV',
        'brandModel': 'Honda CR-V',
        'year': 2022,
        'licensePlate': 'กท 9999',
      };

      final vehicle = Vehicle.fromJson(json);
      expect(vehicle.id, 1);
      expect(vehicle.vehicleType, 'SUV');
      expect(vehicle.brandModel, 'Honda CR-V');
      expect(vehicle.year, 2022);
      expect(vehicle.licensePlate, 'กท 9999');

      final roundTripped = Vehicle.fromJson(vehicle.toJson());
      expect(roundTripped.id, vehicle.id);
      expect(roundTripped.vehicleType, vehicle.vehicleType);
      expect(roundTripped.brandModel, vehicle.brandModel);
      expect(roundTripped.year, vehicle.year);
      expect(roundTripped.licensePlate, vehicle.licensePlate);
    });

    test('toJson omits id for request bodies when null (new vehicle)', () {
      final vehicle = Vehicle(
        vehicleType: 'SEDAN',
        brandModel: 'Toyota Vios',
        year: null,
        licensePlate: 'กก 1111',
      );
      final json = vehicle.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json['vehicleType'], 'SEDAN');
      expect(json['brandModel'], 'Toyota Vios');
      expect(json['year'], isNull);
      expect(json['licensePlate'], 'กก 1111');
    });
  });

  group('SlotList.fromJson', () {
    test('parses slots list from {slots: [...]}', () {
      final json = {
        'slots': [
          {'timeSlot': '09:00-10:00', 'capacity': 3, 'booked': 1, 'available': true},
          {'timeSlot': '10:00-11:00', 'capacity': 2, 'booked': 2, 'available': false},
        ],
      };

      final slotList = SlotList.fromJson(json);
      expect(slotList.slots, hasLength(2));
      expect(slotList.slots[0].timeSlot, '09:00-10:00');
      expect(slotList.slots[0].capacity, 3);
      expect(slotList.slots[0].booked, 1);
      expect(slotList.slots[0].available, isTrue);
      expect(slotList.slots[1].available, isFalse);
    });
  });
}
