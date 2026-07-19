'use client';
import { useEffect, useState } from 'react';
import { apiGet, apiPut, apiPatch, ApiError } from '@/lib/api';
import type { Booking, BookingStatus, Technician } from '@/lib/types';
import StatusBadge from '@/components/StatusBadge';
import { createStompClient } from '@/lib/ws';
import { upsertBooking } from '@/lib/queueStore';
import type { Role } from '@/lib/session';

const STATUS_OPTIONS: BookingStatus[] = ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];

export default function QueueBoard({ role, userId }: { role: Role; userId: number | null }) {
  const isTechnician = role === 'TECHNICIAN';
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [technicians, setTechnicians] = useState<Technician[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

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
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'มอบหมายช่างไม่สำเร็จ');
    }
  }

  if (loading) return <p>กำลังโหลด...</p>;

  return (
    <div className="space-y-3">
      {error && <p className="rounded bg-red-50 p-3 text-sm text-brand">{error}</p>}
      {bookings.length === 0 && <p className="text-gray-500">ไม่มีงานในคิว</p>}
      {bookings.map((booking) => (
        <div key={booking.id} className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
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
                      {status}
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
