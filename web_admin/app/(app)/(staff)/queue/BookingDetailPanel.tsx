'use client';
import { useState } from 'react';
import StatusBadge, { STATUS_LABELS } from '@/components/StatusBadge';
import { formatBaht, formatTimeSlot } from '@/lib/format';
import { formatThaiDateShort } from '@/lib/thaiDate';
import type { Booking, BookingStatus, Technician } from '@/lib/types';

const STATUS_OPTIONS: BookingStatus[] = ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-start justify-between gap-3 py-1.5 text-sm">
      <span className="shrink-0 text-gray-500">{label}</span>
      <span className="text-right font-medium text-gray-800">{value}</span>
    </div>
  );
}

/**
 * Everything an admin can do to one booking. The queue board itself stays a
 * read-at-a-glance board; the controls that used to crowd every card live
 * here, opened by clicking the card.
 */
export default function BookingDetailPanel({
  booking,
  technicians,
  isTechnician,
  onClose,
  onUpdateStatus,
  onAssignTechnician,
  onSubmitQuote,
}: {
  booking: Booking;
  technicians: Technician[];
  isTechnician: boolean;
  onClose: () => void;
  onUpdateStatus: (status: BookingStatus) => void;
  onAssignTechnician: (technicianId: number) => void;
  onSubmitQuote: (quotePrice: number) => Promise<void>;
}) {
  const [quoteDraft, setQuoteDraft] = useState('');
  const [submittingQuote, setSubmittingQuote] = useState(false);

  async function handleSubmitQuote() {
    const quotePrice = Number(quoteDraft);
    if (!quoteDraft || Number.isNaN(quotePrice) || quotePrice <= 0) return;
    setSubmittingQuote(true);
    try {
      await onSubmitQuote(quotePrice);
      setQuoteDraft('');
    } finally {
      setSubmittingQuote(false);
    }
  }

  return (
    <aside className="relative w-full shrink-0 rounded-2xl border border-gray-200 bg-white p-5 shadow-sm lg:w-80">
      <button
        type="button"
        onClick={onClose}
        aria-label="ปิด"
        className="absolute -right-2 -top-2 flex h-7 w-7 items-center justify-center rounded-full bg-brand text-white shadow"
      >
        <svg viewBox="0 0 20 20" fill="currentColor" className="h-4 w-4">
          <path d="M6.3 6.3a1 1 0 0 1 1.4 0L10 8.6l2.3-2.3a1 1 0 1 1 1.4 1.4L11.4 10l2.3 2.3a1 1 0 0 1-1.4 1.4L10 11.4l-2.3 2.3a1 1 0 0 1-1.4-1.4L8.6 10 6.3 7.7a1 1 0 0 1 0-1.4Z" />
        </svg>
      </button>

      <p className="text-lg font-bold text-brand-deep">{booking.userFullName || 'ไม่ระบุชื่อ'}</p>
      <p className="text-xs text-gray-400">{booking.orderCode ?? `งาน #${booking.id}`}</p>

      <div className="mt-3">
        <StatusBadge status={booking.status} />
      </div>

      <div className="mt-4 divide-y divide-gray-100 border-y border-gray-100">
        <Row label="บริการ" value={booking.serviceName} />
        {booking.productName && <Row label="สินค้า" value={booking.productName} />}
        <Row
          label="วันเวลา"
          value={`${formatThaiDateShort(booking.bookingDate)} · ${formatTimeSlot(booking.timeSlot)}`}
        />
        <Row label="รถ" value={booking.vehicleBrandModel ?? '-'} />
        <Row label="ทะเบียน" value={booking.vehicleLicensePlate ?? '-'} />
        {booking.installArea && <Row label="พื้นที่ติดตั้ง" value={booking.installArea} />}
        <Row label="ช่าง" value={booking.technicianName ?? 'ยังไม่มอบหมาย'} />
        {booking.budget != null && <Row label="งบลูกค้า" value={formatBaht(booking.budget)} />}
        {booking.quotePrice != null && <Row label="ราคาประเมิน" value={formatBaht(booking.quotePrice)} />}
        {booking.totalAmount != null && <Row label="ยอดรวม" value={formatBaht(booking.totalAmount)} />}
      </div>

      {booking.imageUrl && (
        /* eslint-disable-next-line @next/next/no-img-element */
        <img
          src={booking.imageUrl}
          alt="รูปที่ลูกค้าแนบ"
          onClick={() => window.open(booking.imageUrl!, '_blank')}
          role="button"
          className="mt-4 h-28 w-full cursor-zoom-in rounded-lg object-cover"
        />
      )}

      <div className="mt-5 space-y-3">
        {isTechnician ? (
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => onUpdateStatus('IN_PROGRESS')}
              disabled={booking.status !== 'CONFIRMED'}
              className="flex-1 rounded-lg bg-brand px-3 py-2 text-sm font-semibold text-white disabled:opacity-40"
            >
              เริ่มงาน
            </button>
            <button
              type="button"
              onClick={() => onUpdateStatus('COMPLETED')}
              disabled={booking.status !== 'IN_PROGRESS'}
              className="flex-1 rounded-lg bg-emerald-600 px-3 py-2 text-sm font-semibold text-white disabled:opacity-40"
            >
              เสร็จสิ้น
            </button>
          </div>
        ) : (
          <>
            <label className="block text-sm">
              <span className="mb-1 block font-semibold text-gray-700">สถานะ</span>
              <select
                value={booking.status}
                onChange={(e) => onUpdateStatus(e.target.value as BookingStatus)}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
              >
                {STATUS_OPTIONS.map((status) => (
                  <option key={status} value={status}>
                    {STATUS_LABELS[status]}
                  </option>
                ))}
              </select>
            </label>

            <label className="block text-sm">
              <span className="mb-1 block font-semibold text-gray-700">ช่างที่รับผิดชอบ</span>
              <select
                value={booking.technicianId ?? ''}
                onChange={(e) => e.target.value && onAssignTechnician(Number(e.target.value))}
                className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
              >
                <option value="">ยังไม่มอบหมาย</option>
                {technicians.map((tech) => (
                  <option key={tech.id} value={tech.id}>
                    {tech.fullName}
                  </option>
                ))}
              </select>
            </label>

            {booking.quotePrice == null && booking.productId == null && (
              <div className="text-sm">
                <span className="mb-1 block font-semibold text-gray-700">ใบเสนอราคา</span>
                <div className="flex gap-2">
                  <input
                    type="number"
                    min={0}
                    placeholder="ราคาประเมิน"
                    value={quoteDraft}
                    onChange={(e) => setQuoteDraft(e.target.value)}
                    className="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm"
                  />
                  <button
                    type="button"
                    onClick={handleSubmitQuote}
                    disabled={submittingQuote}
                    className="shrink-0 rounded-lg bg-brand px-3 py-2 text-sm font-semibold text-white disabled:opacity-40"
                  >
                    {submittingQuote ? 'กำลังส่ง…' : 'ส่ง'}
                  </button>
                </div>
              </div>
            )}
          </>
        )}
      </div>
    </aside>
  );
}
