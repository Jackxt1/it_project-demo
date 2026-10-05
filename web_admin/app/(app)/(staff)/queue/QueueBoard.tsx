'use client';
import { useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { apiGet, apiPut, apiPatch, ApiError } from '@/lib/api';
import type { Booking, BookingStatus, Service, Technician } from '@/lib/types';
import { createStompClient } from '@/lib/ws';
import { upsertBooking } from '@/lib/queueStore';
import { slotStartHour } from '@/lib/format';
import type { Role } from '@/lib/session';
import QueueCard from './QueueCard';
import BookingDetailPanel from './BookingDetailPanel';

type DateRange = 'TODAY' | 'WEEK' | 'ALL';

const RANGE_TABS: { key: DateRange; label: string }[] = [
  { key: 'TODAY', label: 'วันนี้' },
  { key: 'WEEK', label: 'สัปดาห์นี้' },
  { key: 'ALL', label: 'ทั้งหมด' },
];

/**
 * The board shows three columns, while bookings have five statuses.
 * "ยืนยันแล้ว" is still waiting for work to start, so it shares the first
 * column and is told apart by a label on the card. "ยกเลิก" has no column —
 * it sits in a collapsed list under the board so nothing disappears.
 */
const COLUMNS: { key: string; label: string; statuses: BookingStatus[]; countClass: string }[] = [
  { key: 'waiting', label: 'รอดำเนินการ', statuses: ['PENDING', 'CONFIRMED'], countClass: 'text-amber-500' },
  { key: 'active', label: 'กำลังดำเนินการ', statuses: ['IN_PROGRESS'], countClass: 'text-amber-500' },
  { key: 'done', label: 'เสร็จสิ้น', statuses: ['COMPLETED'], countClass: 'text-emerald-600' },
];

function toLocalDateString(date: Date): string {
  const month = `${date.getMonth() + 1}`.padStart(2, '0');
  const day = `${date.getDate()}`.padStart(2, '0');
  return `${date.getFullYear()}-${month}-${day}`;
}

/** Monday-to-Sunday window containing today, as inclusive ISO date strings. */
function currentWeek(): { from: string; to: string } {
  const now = new Date();
  const monday = new Date(now);
  monday.setDate(now.getDate() - ((now.getDay() + 6) % 7));
  const sunday = new Date(monday);
  sunday.setDate(monday.getDate() + 6);
  return { from: toLocalDateString(monday), to: toLocalDateString(sunday) };
}

export default function QueueBoard({ role, userId }: { role: Role; userId: number | null }) {
  const isTechnician = role === 'TECHNICIAN';
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [technicians, setTechnicians] = useState<Technician[]>([]);
  const [services, setServices] = useState<Service[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const [range, setRange] = useState<DateRange>('TODAY');
  const [search, setSearch] = useState('');
  const [serviceFilter, setServiceFilter] = useState<number | 'ALL'>('ALL');
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [showCancelled, setShowCancelled] = useState(false);

  useEffect(() => {
    async function load() {
      try {
        const data = await apiGet<Booking[]>(isTechnician ? '/technician/bookings/me' : '/bookings');
        setBookings(data);
        setServices(await apiGet<Service[]>('/services'));
        if (!isTechnician) {
          setTechnicians(await apiGet<Technician[]>('/admin/technicians?active=true'));
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
    // A highlighted booking can be any date, so widen the range or the card
    // the admin was sent to look at would not be on the board at all.
    setRange('ALL');
    setHighlightedId(id);
    setSelectedId(id);
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
      setError(null);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'อัปเดตสถานะไม่สำเร็จ');
    }
  }

  async function assignTechnician(id: number, technicianId: number) {
    try {
      const updated = await apiPatch<Booking>(`/bookings/${id}/technician`, { technicianId });
      setBookings((prev) => prev.map((b) => (b.id === id ? updated : b)));
      setError(null);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'มอบหมายช่างไม่สำเร็จ');
    }
  }

  async function submitQuote(booking: Booking, quotePrice: number) {
    try {
      const updated = await apiPut<Booking>(`/bookings/${booking.id}/status`, {
        status: booking.status,
        quotePrice,
      });
      setBookings((prev) => prev.map((b) => (b.id === booking.id ? updated : b)));
      setError(null);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'ส่งใบเสนอราคาไม่สำเร็จ');
    }
  }

  const inRange = useMemo(() => {
    if (range === 'ALL') return bookings;
    if (range === 'TODAY') {
      const today = toLocalDateString(new Date());
      return bookings.filter((b) => b.bookingDate === today);
    }
    const { from, to } = currentWeek();
    return bookings.filter((b) => b.bookingDate >= from && b.bookingDate <= to);
  }, [bookings, range]);

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase();
    return inRange.filter((b) => {
      if (serviceFilter !== 'ALL' && b.serviceId !== serviceFilter) return false;
      if (!term) return true;
      return [b.userFullName, b.vehicleBrandModel, b.vehicleLicensePlate, b.orderCode]
        .filter(Boolean)
        .some((field) => field!.toLowerCase().includes(term));
    });
  }, [inRange, search, serviceFilter]);

  const cancelled = filtered.filter((b) => b.status === 'CANCELLED');
  const selected = bookings.find((b) => b.id === selectedId) ?? null;

  if (loading) return <p className="text-gray-500">กำลังโหลด...</p>;

  return (
    <div className="space-y-4">
      {error && <p className="rounded-lg bg-red-50 p-3 text-sm text-brand">{error}</p>}

      <div className="flex flex-wrap gap-2">
        {RANGE_TABS.map((tab) => (
          <button
            key={tab.key}
            type="button"
            onClick={() => setRange(tab.key)}
            className={`rounded-full px-5 py-1.5 text-sm font-semibold transition ${
              range === tab.key
                ? 'bg-gradient-to-r from-[#be1a1a] to-[#580c0c] text-white shadow-sm'
                : 'bg-gray-100 text-gray-500 hover:bg-gray-200'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <div className="relative min-w-[220px] flex-1">
          <svg
            viewBox="0 0 20 20"
            fill="none"
            stroke="currentColor"
            strokeWidth={1.8}
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-brand"
          >
            <circle cx="9" cy="9" r="6" />
            <path d="m14 14 3 3" strokeLinecap="round" />
          </svg>
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="ค้นหาชื่อ ทะเบียนรถ"
            className="w-full rounded-full border border-gray-200 bg-white py-2 pl-9 pr-4 text-sm outline-none focus:border-brand"
          />
        </div>

        <label className="flex items-center gap-2 text-sm text-gray-500">
          เลือกบริการ
          <select
            value={serviceFilter}
            onChange={(e) => setServiceFilter(e.target.value === 'ALL' ? 'ALL' : Number(e.target.value))}
            className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm text-gray-800 outline-none focus:border-brand"
          >
            <option value="ALL">ทุกบริการ</option>
            {services.map((service) => (
              <option key={service.id} value={service.id}>
                {service.name}
              </option>
            ))}
          </select>
        </label>
      </div>

      <div className="flex flex-col gap-4 lg:flex-row lg:items-start">
        <div className="grid flex-1 gap-4 md:grid-cols-3">
          {COLUMNS.map((column) => {
            const items = filtered.filter((b) => column.statuses.includes(b.status));
            const morning = items.filter((b) => slotStartHour(b.timeSlot) < 12);
            const afternoon = items.filter((b) => slotStartHour(b.timeSlot) >= 12);

            return (
              <section key={column.key} className="rounded-2xl bg-gray-100/70 p-3">
                <header className="mb-3 flex items-baseline justify-between px-1">
                  <h2 className="text-sm font-bold text-gray-700">{column.label}</h2>
                  <span className={`text-sm font-bold ${column.countClass}`}>{items.length}</span>
                </header>

                {items.length === 0 && <p className="px-1 pb-2 text-xs text-gray-400">ไม่มีงาน</p>}

                {[
                  { label: 'ช่วงเช้า', list: morning },
                  { label: 'ช่วงบ่าย', list: afternoon },
                ].map((group) =>
                  group.list.length === 0 ? null : (
                    <div key={group.label} className="mb-3 last:mb-0">
                      <p className="mb-2 px-1 text-xs text-gray-400">{group.label}</p>
                      <div className="space-y-2">
                        {group.list.map((booking) => (
                          <QueueCard
                            key={booking.id}
                            booking={booking}
                            selected={selectedId === booking.id}
                            highlighted={highlightedId === booking.id}
                            onSelect={() => setSelectedId(booking.id)}
                          />
                        ))}
                      </div>
                    </div>
                  ),
                )}
              </section>
            );
          })}
        </div>

        {selected && (
          <BookingDetailPanel
            booking={selected}
            technicians={technicians}
            isTechnician={isTechnician}
            onClose={() => setSelectedId(null)}
            onUpdateStatus={(status) => updateStatus(selected.id, status)}
            onAssignTechnician={(technicianId) => assignTechnician(selected.id, technicianId)}
            onSubmitQuote={(quotePrice) => submitQuote(selected, quotePrice)}
          />
        )}
      </div>

      {cancelled.length > 0 && (
        <div className="rounded-2xl border border-gray-200 bg-white p-3">
          <button
            type="button"
            onClick={() => setShowCancelled((v) => !v)}
            className="flex w-full items-center justify-between text-sm font-semibold text-gray-500"
          >
            <span>งานที่ยกเลิก ({cancelled.length})</span>
            <span className="text-xs">{showCancelled ? 'ซ่อน' : 'แสดง'}</span>
          </button>
          {showCancelled && (
            <div className="mt-3 grid gap-2 md:grid-cols-3">
              {cancelled.map((booking) => (
                <div key={booking.id} className="opacity-60">
                  <QueueCard
                    booking={booking}
                    selected={selectedId === booking.id}
                    highlighted={highlightedId === booking.id}
                    onSelect={() => setSelectedId(booking.id)}
                  />
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
