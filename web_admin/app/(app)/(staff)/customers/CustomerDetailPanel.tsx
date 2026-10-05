'use client';
import { useEffect, useState } from 'react';
import Avatar from '@/components/Avatar';
import { apiGet, ApiError } from '@/lib/api';
import { formatBaht } from '@/lib/format';
import { formatThaiDateShort } from '@/lib/thaiDate';
import type { Booking, CustomerDetail } from '@/lib/types';

/** What a booking was actually worth to the shop, best figure available. */
function bookingAmount(booking: Booking): number {
  return booking.totalAmount ?? booking.quotePrice ?? 0;
}

function Fact({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div className="flex items-center gap-3 py-2">
      <span className="text-gray-400">{icon}</span>
      <span className="flex-1 text-sm text-gray-500">{label}</span>
      <span className="text-sm font-semibold text-gray-800">{value}</span>
    </div>
  );
}

const iconProps = {
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.7,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
  className: 'h-4 w-4',
};

export default function CustomerDetailPanel({
  customerId,
  onClose,
}: {
  customerId: number;
  onClose: () => void;
}) {
  const [detail, setDetail] = useState<CustomerDetail | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setDetail(null);
    setError(null);
    apiGet<CustomerDetail>(`/admin/customers/${customerId}`)
      .then((data) => {
        if (!cancelled) setDetail(data);
      })
      .catch((err) => {
        if (!cancelled) setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ');
      });
    return () => {
      cancelled = true;
    };
  }, [customerId]);

  // Cancelled jobs are neither a visit nor revenue.
  const served = detail?.bookings.filter((b) => b.status !== 'CANCELLED') ?? [];
  const totalSpend = served
    .filter((b) => b.status === 'COMPLETED')
    .reduce((sum, b) => sum + bookingAmount(b), 0);
  const history = [...served].sort((a, b) => b.bookingDate.localeCompare(a.bookingDate));

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

      {error && <p className="rounded bg-red-50 p-3 text-sm text-brand">{error}</p>}
      {!detail && !error && <p className="text-sm text-gray-500">กำลังโหลด...</p>}

      {detail && (
        <>
          <div className="flex items-center gap-3">
            <Avatar name={detail.fullName || '?'} size="lg" />
            <div className="min-w-0">
              <p className="truncate text-base font-bold text-brand-deep">
                {detail.fullName || 'ไม่ระบุชื่อ'}
              </p>
              <p className="text-xs text-gray-400">
                ใช้บริการตั้งแต่ {formatThaiDateShort(detail.createdAt)}
              </p>
            </div>
          </div>

          <div className="mt-4 divide-y divide-gray-100 border-y border-gray-100">
            <Fact
              icon={
                <svg {...iconProps}>
                  <path d="M4 5a2 2 0 0 1 2-2h1.6a1 1 0 0 1 1 .7l1 3a1 1 0 0 1-.3 1L8 9a12 12 0 0 0 5 5l1.3-1.3a1 1 0 0 1 1-.3l3 1a1 1 0 0 1 .7 1V18a2 2 0 0 1-2 2A14 14 0 0 1 4 6Z" />
                </svg>
              }
              label="เบอร์ติดต่อ"
              value={detail.phone ?? '-'}
            />
            <Fact
              icon={
                <svg {...iconProps}>
                  <path d="M5 13 6.5 8A2 2 0 0 1 8.4 6.5h7.2A2 2 0 0 1 17.5 8L19 13" />
                  <rect x="3" y="13" width="18" height="5" rx="1.5" />
                  <circle cx="7.5" cy="15.5" r="1" />
                  <circle cx="16.5" cy="15.5" r="1" />
                </svg>
              }
              label="รถยนต์ลูกค้า"
              value={detail.vehicleBrandModel ?? '-'}
            />
            <Fact
              icon={
                <svg {...iconProps}>
                  <rect x="3" y="6" width="18" height="12" rx="2" />
                  <path d="M7 12h10" />
                </svg>
              }
              label="ป้ายทะเบียน"
              value={detail.vehicleLicensePlate ?? '-'}
            />
            <Fact
              icon={
                <svg {...iconProps}>
                  <rect x="3" y="5" width="18" height="16" rx="2" />
                  <path d="M8 3v4M16 3v4M3 10h18" />
                </svg>
              }
              label="ใช้บริการทั้งหมด"
              value={`${served.length} ครั้ง`}
            />
            <Fact
              icon={
                <svg {...iconProps}>
                  <circle cx="12" cy="12" r="8" />
                  <path d="M12 8v8M9.5 10.5h5M9.5 13.5h5" />
                </svg>
              }
              label="ยอดใช้จ่ายรวม"
              value={formatBaht(totalSpend)}
            />
          </div>

          <h3 className="mt-5 text-sm font-bold text-gray-700">ประวัติการใช้บริการ</h3>
          {history.length === 0 ? (
            <p className="mt-2 text-sm text-gray-400">ยังไม่เคยใช้บริการ</p>
          ) : (
            <ul className="mt-2 space-y-3">
              {history.map((booking) => (
                <li key={booking.id} className="flex gap-2">
                  <span className="mt-1.5 h-2 w-2 shrink-0 rounded-full bg-brand" />
                  <div className="min-w-0">
                    <p className="truncate text-sm font-medium text-gray-800">
                      {booking.productName ?? booking.serviceName}
                    </p>
                    <p className="text-xs text-gray-400">
                      {formatThaiDateShort(booking.bookingDate)}
                      {bookingAmount(booking) > 0 ? ` · ${formatBaht(bookingAmount(booking))}` : ''}
                    </p>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </>
      )}
    </aside>
  );
}
