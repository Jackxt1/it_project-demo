import type { Booking } from './types';

export function upsertBooking(bookings: Booking[], updated: Booking): Booking[] {
  const index = bookings.findIndex((b) => b.id === updated.id);
  const next = index === -1 ? [...bookings, updated] : bookings.map((b) => (b.id === updated.id ? updated : b));
  return next.sort(compareByDateSlot);
}

function compareByDateSlot(a: Booking, b: Booking): number {
  if (a.bookingDate !== b.bookingDate) {
    return a.bookingDate.localeCompare(b.bookingDate);
  }
  return a.timeSlot.localeCompare(b.timeSlot);
}
