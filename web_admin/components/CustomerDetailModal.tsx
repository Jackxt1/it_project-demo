'use client';
import { useEffect, useState } from 'react';
import { apiGet, ApiError } from '@/lib/api';
import { formatThaiDateShort } from '@/lib/thaiDate';
import type { CustomerDetail } from '@/lib/types';

const priceFormat = new Intl.NumberFormat('th-TH');

const rowIconProps = {
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.6,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
  className: 'h-5 w-5 shrink-0 text-gray-700',
};

const PhoneIcon = () => (
  <svg {...rowIconProps}>
    <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 22 16.92Z" />
  </svg>
);

const CarIcon = () => (
  <svg {...rowIconProps}>
    <path d="M5 15 L6.5 10.5 Q7.5 8 10.5 8 L15.5 8 Q18.5 8 19.5 10.5 L21 15" />
    <rect x="3" y="14" width="18" height="5" rx="2" />
    <circle cx="8" cy="19" r="2" />
    <circle cx="17" cy="19" r="2" />
  </svg>
);

const KeyIcon = () => (
  <svg {...rowIconProps}>
    <circle cx="8" cy="8" r="4" />
    <line x1="11" y1="11" x2="20" y2="20" />
    <line x1="16" y1="16" x2="17.5" y2="14.5" />
    <line x1="18" y1="18" x2="19.5" y2="16.5" />
  </svg>
);

const CountIcon = () => (
  <svg {...rowIconProps}>
    <rect x="4" y="7" width="14" height="12" rx="2" />
    <path d="M8 7v-1a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2h-1" />
  </svg>
);

const WalletIcon = () => (
  <svg {...rowIconProps}>
    <rect x="3" y="6" width="18" height="13" rx="2" />
    <path d="M3 10h18" />
    <circle cx="16.5" cy="14" r="1.2" fill="currentColor" stroke="none" />
  </svg>
);

function initials(fullName: string): string {
  const firstWord = fullName.trim().split(/\s+/)[0] ?? '';
  return firstWord.slice(0, 2);
}

export default function CustomerDetailModal({
  customerId,
  onClose,
}: {
  customerId: number | null;
  onClose: () => void;
}) {
  const [customer, setCustomer] = useState<CustomerDetail | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (customerId === null) return;
    setCustomer(null);
    setError(null);
    apiGet<CustomerDetail>(`/admin/customers/${customerId}`)
      .then(setCustomer)
      .catch((err) => setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ'));
  }, [customerId]);

  if (customerId === null) return null;

  const latestVehicleBooking = customer?.bookings.find((b) => b.vehicleBrandModel);
  const totalSpent = (customer?.bookings ?? []).reduce(
    (sum, b) => sum + (b.totalAmount ?? b.quotePrice ?? 0),
    0,
  );

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4" onClick={onClose}>
      <div
        className="relative w-full max-w-md rounded-2xl bg-white p-6 shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <button
          onClick={onClose}
          aria-label="ปิด"
          className="absolute right-4 top-4 flex h-8 w-8 items-center justify-center rounded-full bg-brand text-white hover:bg-brand-dark"
        >
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" className="h-4 w-4">
            <line x1="6" y1="6" x2="18" y2="18" />
            <line x1="18" y1="6" x2="6" y2="18" />
          </svg>
        </button>

        {error && <p className="rounded bg-red-50 p-3 text-sm text-brand">{error}</p>}
        {!error && !customer && <p className="text-sm text-gray-500">กำลังโหลด...</p>}

        {customer && (
          <>
            <div className="flex items-center gap-4">
              <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-[#be1a1a] to-[#580c0c] text-xl font-bold text-white">
                {initials(customer.fullName)}
              </div>
              <div>
                <div className="text-lg font-bold text-gray-900">{customer.fullName}</div>
                <div className="text-sm text-gray-500">
                  ใช้บริการตั้งแต่ {formatThaiDateShort(customer.createdAt)}
                </div>
              </div>
            </div>

            <hr className="my-4 border-gray-200" />

            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <span className="flex items-center gap-2 text-sm text-gray-500">
                  <PhoneIcon /> เบอร์ติดต่อ
                </span>
                <span className="font-medium text-gray-900">{customer.phone ?? '-'}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="flex items-center gap-2 text-sm text-gray-500">
                  <CarIcon /> รถของลูกค้า
                </span>
                <span className="font-medium text-gray-900">
                  {latestVehicleBooking?.vehicleBrandModel ?? '-'}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="flex items-center gap-2 text-sm text-gray-500">
                  <KeyIcon /> ป้ายทะเบียน
                </span>
                <span className="font-medium text-gray-900">
                  {latestVehicleBooking?.vehicleLicensePlate ?? '-'}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="flex items-center gap-2 text-sm text-gray-500">
                  <CountIcon /> ใช้บริการทั้งหมด
                </span>
                <span className="font-medium text-gray-900">{customer.bookings.length} ครั้ง</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="flex items-center gap-2 text-sm text-gray-500">
                  <WalletIcon /> ยอดใช้จ่ายรวม
                </span>
                <span className="font-medium text-gray-900">{priceFormat.format(totalSpent)} บาท</span>
              </div>
            </div>

            <hr className="my-4 border-gray-200" />

            <h3 className="mb-3 font-semibold text-gray-900">ประวัติการใช้บริการ</h3>
            <div className="max-h-64 space-y-4 overflow-y-auto pr-1">
              {customer.bookings.length === 0 && <p className="text-sm text-gray-500">ยังไม่มีการใช้บริการ</p>}
              {customer.bookings.map((booking) => (
                <div key={booking.id} className="flex gap-3">
                  <span className="mt-1.5 h-2.5 w-2.5 shrink-0 rounded-full bg-brand" />
                  <div>
                    <p className="text-sm font-medium text-gray-900">
                      {booking.productName ?? booking.serviceName}
                    </p>
                    <p className="text-sm text-gray-500">
                      {formatThaiDateShort(booking.bookingDate)} -{' '}
                      {priceFormat.format(booking.totalAmount ?? booking.quotePrice ?? 0)} บาท
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
