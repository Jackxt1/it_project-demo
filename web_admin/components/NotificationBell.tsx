'use client';
import { useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import type { Booking } from '@/lib/types';
import { createStompClient } from '@/lib/ws';
import type { Role } from '@/lib/session';

/** Bell button next to "ออกจากระบบ" — keeps a running history of new-booking
 * notifications (unlike NewBookingPopup, which only shows the latest one as
 * a transient toast) so staff can check what came in even after dismissing
 * or missing the toast. Badge shows the unread count; opening the dropdown
 * marks everything read. */
export default function NotificationBell({ role }: { role: Role }) {
  const router = useRouter();
  const [items, setItems] = useState<Booking[]>([]);
  const [unread, setUnread] = useState(0);
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (role !== 'ADMIN' && role !== 'OWNER') return;
    const client = createStompClient((connected) => {
      connected.subscribe('/topic/admin/bookings', (message) => {
        const booking = JSON.parse(message.body) as Booking;
        setItems((prev) => [booking, ...prev].slice(0, 20));
        setUnread((prev) => prev + 1);
      });
    });
    return () => {
      client.deactivate();
    };
  }, [role]);

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (rootRef.current && !rootRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  function toggleOpen() {
    setOpen((prev) => !prev);
    setUnread(0);
  }

  function viewDetail(booking: Booking) {
    setOpen(false);
    router.push(`/queue?highlight=${booking.id}`);
  }

  if (role !== 'ADMIN' && role !== 'OWNER') return null;

  return (
    <div ref={rootRef} className="relative">
      <button
        onClick={toggleOpen}
        aria-label="การแจ้งเตือน"
        className="relative flex h-8 w-8 items-center justify-center rounded-full text-gray-500 hover:bg-gray-100"
      >
        <BellIcon />
        {unread > 0 && (
          <span className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-brand px-1 text-[10px] font-semibold text-white">
            {unread > 9 ? '9+' : unread}
          </span>
        )}
      </button>

      {open && (
        <div className="absolute right-0 top-10 z-50 w-80 rounded-lg border border-gray-200 bg-white shadow-lg">
          <div className="border-b border-gray-100 px-4 py-2 text-sm font-semibold text-brand-deep">
            การแจ้งเตือน
          </div>
          <div className="max-h-96 overflow-y-auto">
            {items.length === 0 ? (
              <p className="px-4 py-6 text-center text-sm text-gray-400">ยังไม่มีการแจ้งเตือน</p>
            ) : (
              items.map((booking, i) => (
                <button
                  key={`${booking.id}-${i}`}
                  onClick={() => viewDetail(booking)}
                  className="block w-full border-b border-gray-50 px-4 py-3 text-left last:border-b-0 hover:bg-gray-50"
                >
                  <p className="text-sm font-medium text-gray-800">
                    {booking.serviceName} — {booking.userFullName}
                  </p>
                  <p className="text-xs text-gray-500">
                    {booking.bookingDate} {booking.timeSlot}
                    {booking.orderCode ? ` · ${booking.orderCode}` : ''}
                  </p>
                </button>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function BellIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} className="h-5 w-5">
      <path
        d="M6 16v-5a6 6 0 0 1 12 0v5l1.5 2.5h-15L6 16Z"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path d="M10 20a2 2 0 0 0 4 0" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
