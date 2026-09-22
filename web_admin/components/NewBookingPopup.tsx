'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import type { Booking } from '@/lib/types';
import { createStompClient } from '@/lib/ws';
import type { Role } from '@/lib/session';

const AUTO_DISMISS_MS = 10000;

/** Pops up in the corner whenever a customer creates a new booking, for
 * ADMIN/OWNER staff — regardless of which page they're currently on
 * (mounted once at the app layout level, not just the queue page). Clicking
 * it jumps to the queue and highlights that booking's card. */
export default function NewBookingPopup({ role }: { role: Role }) {
  const router = useRouter();
  const [queue, setQueue] = useState<Booking[]>([]);

  useEffect(() => {
    if (role !== 'ADMIN' && role !== 'OWNER') return;
    const client = createStompClient((connected) => {
      connected.subscribe('/topic/admin/bookings', (message) => {
        const booking = JSON.parse(message.body) as Booking;
        setQueue((prev) => [...prev, booking]);
      });
    });
    return () => {
      client.deactivate();
    };
  }, [role]);

  if (queue.length === 0) return null;

  const current = queue[0];

  function dismiss() {
    setQueue((prev) => prev.slice(1));
  }

  function viewDetail() {
    router.push(`/queue?highlight=${current.id}`);
    dismiss();
  }

  return (
    <div className="fixed right-4 top-4 z-50 w-80 rounded-lg border border-gray-200 bg-white p-4 shadow-lg">
      <div className="flex items-start justify-between gap-2">
        <div className="flex items-center gap-2">
          <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-r from-[#be1a1a] to-[#580c0c] text-white">
            <BellIcon />
          </span>
          <p className="font-semibold text-brand-deep">งานใหม่เข้ามาแล้ว!</p>
        </div>
        <button onClick={dismiss} className="text-gray-400 hover:text-gray-600" aria-label="ปิด">
          ✕
        </button>
      </div>
      <p className="mt-2 text-sm text-gray-700">
        {current.serviceName} — {current.userFullName}
      </p>
      <p className="text-sm text-gray-500">
        {current.bookingDate} {current.timeSlot}
        {current.orderCode ? ` · ${current.orderCode}` : ''}
      </p>
      <div className="mt-3 flex justify-end gap-2">
        <button onClick={dismiss} className="rounded px-3 py-1 text-sm text-gray-500 hover:bg-gray-100">
          ปิด
        </button>
        <button
          onClick={viewDetail}
          className="rounded bg-gradient-to-r from-[#be1a1a] to-[#580c0c] px-3 py-1 text-sm text-white"
        >
          ดูรายละเอียด
        </button>
      </div>
      <AutoDismiss onDone={dismiss} />
    </div>
  );
}

function BellIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} className="h-4 w-4">
      <path
        d="M6 16v-5a6 6 0 0 1 12 0v5l1.5 2.5h-15L6 16Z"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path d="M10 20a2 2 0 0 0 4 0" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function AutoDismiss({ onDone }: { onDone: () => void }) {
  useEffect(() => {
    const timer = setTimeout(onDone, AUTO_DISMISS_MS);
    return () => clearTimeout(timer);
  }, [onDone]);
  return null;
}
