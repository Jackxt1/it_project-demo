import { describe, expect, it } from 'vitest';
import { upsertBooking } from './queueStore';
import type { Booking } from './types';

function makeBooking(overrides: Partial<Booking>): Booking {
  return {
    id: 1,
    userId: 1,
    userFullName: 'ลูกค้าทดสอบ',
    serviceId: 1,
    serviceName: 'ล้างรถ',
    productId: null,
    productName: null,
    technicianId: 7,
    technicianName: 'ช่างเอ',
    bookingDate: '2026-07-21',
    timeSlot: '09:00',
    status: 'CONFIRMED',
    budget: null,
    imageUrl: null,
    quotePrice: null,
    notes: null,
    orderCode: null,
    vehicleId: null,
    vehicleBrandModel: null,
    vehicleLicensePlate: null,
    installArea: null,
    paymentType: null,
    paidAmount: null,
    createdAt: '2026-07-20T00:00:00',
    updatedAt: '2026-07-20T00:00:00',
    statusHistory: [],
    ...overrides,
  };
}

describe('upsertBooking', () => {
  it('adds a new booking not already in the list', () => {
    const existing = [makeBooking({ id: 1 })];
    const incoming = makeBooking({ id: 2, bookingDate: '2026-07-22' });

    const result = upsertBooking(existing, incoming);

    expect(result).toHaveLength(2);
    expect(result.map((b) => b.id)).toContain(2);
  });

  it('replaces an existing booking with the same id', () => {
    const existing = [makeBooking({ id: 1, status: 'CONFIRMED' })];
    const incoming = makeBooking({ id: 1, status: 'IN_PROGRESS' });

    const result = upsertBooking(existing, incoming);

    expect(result).toHaveLength(1);
    expect(result[0].status).toBe('IN_PROGRESS');
  });

  it('keeps the list sorted by date then time slot', () => {
    const existing = [
      makeBooking({ id: 1, bookingDate: '2026-07-22', timeSlot: '09:00' }),
      makeBooking({ id: 2, bookingDate: '2026-07-21', timeSlot: '15:00' }),
    ];
    const incoming = makeBooking({ id: 3, bookingDate: '2026-07-21', timeSlot: '09:00' });

    const result = upsertBooking(existing, incoming);

    expect(result.map((b) => b.id)).toEqual([3, 2, 1]);
  });
});
