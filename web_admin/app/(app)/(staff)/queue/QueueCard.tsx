'use client';
import ServiceBadge from '@/components/ServiceBadge';
import { formatTimeSlot } from '@/lib/format';
import type { Booking } from '@/lib/types';

/** "Nissan GTR-R34 ทะเบียน ขอ 8888", or the order code when no vehicle is attached. */
function vehicleLine(booking: Booking): string {
  const parts: string[] = [];
  if (booking.vehicleBrandModel) parts.push(booking.vehicleBrandModel);
  if (booking.vehicleLicensePlate) parts.push(`ทะเบียน ${booking.vehicleLicensePlate}`);
  if (parts.length > 0) return parts.join(' ');
  return booking.orderCode ?? 'ไม่ได้ระบุรถ';
}

export default function QueueCard({
  booking,
  selected,
  highlighted,
  onSelect,
}: {
  booking: Booking;
  selected: boolean;
  highlighted: boolean;
  onSelect: () => void;
}) {
  const border = highlighted
    ? 'border-brand ring-2 ring-brand/40'
    : selected
      ? 'border-brand'
      : 'border-gray-200 hover:border-brand/40';

  return (
    <button
      type="button"
      id={`booking-${booking.id}`}
      onClick={onSelect}
      className={`w-full rounded-xl border bg-white p-3 text-left shadow-sm transition hover:shadow ${border}`}
    >
      {/* Badge first in a float so the name wraps around it instead of being
          truncated away when a column gets narrow. */}
      <div className="float-right ml-2">
        <ServiceBadge serviceName={booking.serviceName} />
      </div>
      <p className="text-sm font-bold text-brand-deep">{booking.userFullName || 'ไม่ระบุชื่อ'}</p>
      <p className="text-xs text-gray-600">{vehicleLine(booking)}</p>
      <p className="mt-1 clear-both text-xs text-gray-400">{formatTimeSlot(booking.timeSlot)}</p>

      {booking.status === 'COMPLETED' && (
        <p className="mt-2 flex items-center gap-1 text-xs font-medium text-emerald-600">
          <svg viewBox="0 0 20 20" fill="currentColor" className="h-4 w-4">
            <path
              fillRule="evenodd"
              d="M10 18a8 8 0 1 0 0-16 8 8 0 0 0 0 16Zm3.7-9.3a1 1 0 0 0-1.4-1.4L9 10.6 7.7 9.3a1 1 0 0 0-1.4 1.4l2 2a1 1 0 0 0 1.4 0l4-4Z"
              clipRule="evenodd"
            />
          </svg>
          เสร็จสิ้นแล้ว
        </p>
      )}

      {booking.status === 'CONFIRMED' && (
        <p className="mt-2 text-xs font-medium text-blue-600">ยืนยันแล้ว</p>
      )}
    </button>
  );
}
