'use client';
import { useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { apiGet, apiPut, apiPatch, ApiError } from '@/lib/api';
import type { Booking, BookingStatus, Technician } from '@/lib/types';
import StatusBadge, { STATUS_LABELS } from '@/components/StatusBadge';
import { createStompClient } from '@/lib/ws';
import { upsertBooking } from '@/lib/queueStore';
import type { Role } from '@/lib/session';

const STATUS_OPTIONS: BookingStatus[] = ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];

const priceFormat = new Intl.NumberFormat('th-TH');

export default function QueueBoard({ role, userId }: { role: Role; userId: number | null }) {
  const isTechnician = role === 'TECHNICIAN';
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [technicians, setTechnicians] = useState<Technician[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [quoteDrafts, setQuoteDrafts] = useState<Record<number, string>>({});
  const [submittingQuoteId, setSubmittingQuoteId] = useState<number | null>(null);
  const [dateFilter, setDateFilter] = useState('');
  const [statusFilter, setStatusFilter] = useState<BookingStatus | 'ALL'>('ALL');

  useEffect(() => {
    async function load() {
      try {
        const data = await apiGet<Booking[]>(isTechnician ? '/technician/bookings/me' : '/bookings');
        setBookings(data);
        if (!isTechnician) {
          const techs = await apiGet<Technician[]>('/admin/technicians?active=true');
          setTechnicians(techs);
        }
      } catch (err) {
        setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ');
      } finally {
        setLoading(false);
      }
    }
    load();
  }, [isTechnician]);

  useEffect(() => {
    if (!isTechnician || !userId) return;
    const client = createStompClient((connected) => {
      connected.subscribe(`/topic/technician/${userId}/queue`, (message) => {
        const updated = JSON.parse(message.body) as Booking;
        setBookings((prev) => upsertBooking(prev, updated));
      });
    });
    return () => {
      client.deactivate();
    };
  }, [isTechnician, userId]);

  useEffect(() => {
    if (isTechnician) return;
    const client = createStompClient((connected) => {
      connected.subscribe('/topic/admin/bookings', (message) => {
        const created = JSON.parse(message.body) as Booking;
        setBookings((prev) => upsertBooking(prev, created));
      });
    });
    return () => {
      client.deactivate();
    };
  }, [isTechnician]);

  const [highlightedId, setHighlightedId] = useState<number | null>(null);
  const searchParams = useSearchParams();

  useEffect(() => {
    // Reads via the reactive useSearchParams() (not window.location.search
    // in a []-deps effect) so this re-fires when a popup/notification click
    // pushes a new ?highlight= while already on /queue — that navigation
    // never remounts this component, so a one-shot effect would only ever
    // catch the *first* highlight and require a manual refresh afterwards.
    const raw = searchParams.get('highlight');
    if (!raw) return;
    const id = Number(raw);
    if (Number.isNaN(id)) return;
    setHighlightedId(id);
    const timer = setTimeout(() => setHighlightedId(null), 4000);
    return () => clearTimeout(timer);
  }, [searchParams]);

  useEffect(() => {
    if (highlightedId == null) return;
    document.getElementById(`booking-${highlightedId}`)?.scrollIntoView({
      behavior: 'smooth',
      block: 'center',
    });
  }, [highlightedId, bookings]);

  async function updateStatus(id: number, status: BookingStatus) {
    try {
      const path = isTechnician ? `/technician/bookings/${id}/status` : `/bookings/${id}/status`;
      const updated = await apiPut<Booking>(path, { status });
      setBookings((prev) => prev.map((b) => (b.id === id ? updated : b)));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'อัปเดตสถานะไม่สำเร็จ');
    }
  }

  async function assignTechnician(id: number, technicianId: number) {
    try {
      const updated = await apiPatch<Booking>(`/bookings/${id}/technician`, { technicianId });
      setBookings((prev) => prev.map((b) => (b.id === id ? updated : b)));
      // Assigning a technician while a job is still pending auto-confirms
      // it on the backend — jump the filter tab there so the admin sees
      // the result of what they just did instead of the card just
      // vanishing from "รอดำเนินการ".
      if (updated.status === 'CONFIRMED') {
        setStatusFilter('CONFIRMED');
      }
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'มอบหมายช่างไม่สำเร็จ');
    }
  }

  async function submitQuote(booking: Booking) {
    const raw = quoteDrafts[booking.id];
    const quotePrice = Number(raw);
    if (!raw || Number.isNaN(quotePrice) || quotePrice <= 0) {
      setError('กรอกราคาประเมินให้ถูกต้องก่อนส่ง');
      return;
    }
    setSubmittingQuoteId(booking.id);
    try {
      const updated = await apiPut<Booking>(`/bookings/${booking.id}/status`, {
        status: booking.status,
        quotePrice,
      });
      setBookings((prev) => prev.map((b) => (b.id === booking.id ? updated : b)));
      setQuoteDrafts((prev) => {
        const next = { ...prev };
        delete next[booking.id];
        return next;
      });
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'ส่งใบเสนอราคาไม่สำเร็จ');
    } finally {
      setSubmittingQuoteId(null);
    }
  }

  if (loading) return <p>กำลังโหลด...</p>;

  const dateFilteredBookings = dateFilter ? bookings.filter((b) => b.bookingDate === dateFilter) : bookings;
  const visibleBookings =
    statusFilter === 'ALL' ? dateFilteredBookings : dateFilteredBookings.filter((b) => b.status === statusFilter);

  const statusCounts = STATUS_OPTIONS.reduce((acc, status) => {
    acc[status] = dateFilteredBookings.filter((b) => b.status === status).length;
    return acc;
  }, {} as Record<BookingStatus, number>);

  return (
    <div className="space-y-3">
      {error && <p className="rounded bg-red-50 p-3 text-sm text-brand">{error}</p>}

      <div className="flex items-center gap-2">
        <label htmlFor="queue-date-filter" className="text-sm text-gray-500">
          กรองตามวันที่
        </label>
        <input
          id="queue-date-filter"
          type="date"
          value={dateFilter}
          onChange={(e) => setDateFilter(e.target.value)}
          className="rounded border border-gray-300 px-2 py-1 text-sm"
        />
        {dateFilter && (
          <button onClick={() => setDateFilter('')} className="text-sm text-brand underline">
            ล้างตัวกรอง
          </button>
        )}
      </div>

      <div className="flex flex-wrap gap-1 rounded-md bg-gray-100 p-1 text-sm">
        <button
          onClick={() => setStatusFilter('ALL')}
          className={`rounded px-3 py-1 ${
            statusFilter === 'ALL' ? 'bg-gradient-to-r from-[#be1a1a] to-[#580c0c] text-white shadow-sm' : 'text-gray-500'
          }`}
        >
          ทั้งหมด ({dateFilteredBookings.length})
        </button>
        {STATUS_OPTIONS.map((status) => (
          <button
            key={status}
            onClick={() => setStatusFilter(status)}
            className={`rounded px-3 py-1 ${
              statusFilter === status ? 'bg-gradient-to-r from-[#be1a1a] to-[#580c0c] text-white shadow-sm' : 'text-gray-500'
            }`}
          >
            {STATUS_LABELS[status]} ({statusCounts[status]})
          </button>
        ))}
      </div>

      {visibleBookings.length === 0 && (
        <p className="text-gray-500">{dateFilter ? 'ไม่มีงานในคิววันที่เลือก' : 'ไม่มีงานในคิว'}</p>
      )}
      {visibleBookings.map((booking) => (
        <div
          key={booking.id}
          id={`booking-${booking.id}`}
          className={`rounded-lg border bg-white p-4 shadow-sm transition-colors ${
            highlightedId === booking.id ? 'border-brand ring-2 ring-brand' : 'border-gray-200'
          }`}
        >
          <div className="flex items-center justify-between">
            <div>
              <p className="font-semibold">
                {booking.serviceName} — {booking.userFullName}
              </p>
              <p className="text-sm text-gray-500">
                {booking.bookingDate} {booking.timeSlot}
                {booking.orderCode ? ` · ${booking.orderCode}` : ''}
              </p>
              {!isTechnician && (
                <p className="text-sm text-gray-500">ช่าง: {booking.technicianName ?? 'ยังไม่มอบหมาย'}</p>
              )}
            </div>
            <StatusBadge status={booking.status} />
          </div>

          {(booking.imageUrl || booking.budget != null || booking.quotePrice != null) && (
            <div className="mt-3 flex items-start gap-3 rounded-md bg-gray-50 p-3">
              {booking.imageUrl && (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={booking.imageUrl}
                  alt="รูปที่ลูกค้าแนบ"
                  className="h-20 w-20 shrink-0 rounded object-cover"
                  onClick={() => window.open(booking.imageUrl!, '_blank')}
                  role="button"
                />
              )}
              <div className="text-sm">
                {booking.budget != null && (
                  <p>
                    งบลูกค้า: <span className="font-medium">{priceFormat.format(booking.budget)} บาท</span>
                  </p>
                )}
                {booking.quotePrice != null ? (
                  <p>
                    ราคาประเมินที่ส่งแล้ว:{' '}
                    <span className="font-medium">{priceFormat.format(booking.quotePrice)} บาท</span>
                  </p>
                ) : (
                  !isTechnician && (
                    <div className="mt-1 flex items-center gap-2">
                      <input
                        type="number"
                        min={0}
                        placeholder="ราคาประเมิน (บาท)"
                        value={quoteDrafts[booking.id] ?? ''}
                        onChange={(e) =>
                          setQuoteDrafts((prev) => ({ ...prev, [booking.id]: e.target.value }))
                        }
                        className="w-40 rounded border border-gray-300 px-2 py-1 text-sm"
                      />
                      <button
                        onClick={() => submitQuote(booking)}
                        disabled={submittingQuoteId === booking.id}
                        className="rounded bg-brand px-3 py-1 text-sm text-white disabled:opacity-40"
                      >
                        {submittingQuoteId === booking.id ? 'กำลังส่ง...' : 'ส่งใบเสนอราคา'}
                      </button>
                    </div>
                  )
                )}
              </div>
            </div>
          )}

          <div className="mt-3 flex flex-wrap items-center gap-2">
            {isTechnician ? (
              <>
                <button
                  onClick={() => updateStatus(booking.id, 'IN_PROGRESS')}
                  disabled={booking.status !== 'CONFIRMED'}
                  className="rounded bg-brand px-3 py-1 text-sm text-white disabled:opacity-40"
                >
                  เริ่มงาน
                </button>
                <button
                  onClick={() => updateStatus(booking.id, 'COMPLETED')}
                  disabled={booking.status !== 'IN_PROGRESS'}
                  className="rounded bg-green-600 px-3 py-1 text-sm text-white disabled:opacity-40"
                >
                  เสร็จสิ้น
                </button>
              </>
            ) : (
              <>
                <select
                  value={booking.status}
                  onChange={(e) => updateStatus(booking.id, e.target.value as BookingStatus)}
                  className="rounded border border-gray-300 px-2 py-1 text-sm"
                >
                  {STATUS_OPTIONS.map((status) => (
                    <option key={status} value={status}>
                      {STATUS_LABELS[status]}
                    </option>
                  ))}
                </select>
                <select
                  value={booking.technicianId ?? ''}
                  onChange={(e) => e.target.value && assignTechnician(booking.id, Number(e.target.value))}
                  className="rounded border border-gray-300 px-2 py-1 text-sm"
                >
                  <option value="">มอบหมายช่าง</option>
                  {technicians.map((tech) => (
                    <option key={tech.id} value={tech.id}>
                      {tech.fullName}
                    </option>
                  ))}
                </select>
              </>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}
