'use client';
import { useEffect, useState } from 'react';
import { apiGet, apiPut, ApiError } from '@/lib/api';
import type { Booking } from '@/lib/types';

export default function PaymentSlipReview() {
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [rejectingId, setRejectingId] = useState<number | null>(null);
  const [rejectNote, setRejectNote] = useState('');
  const [submittingId, setSubmittingId] = useState<number | null>(null);

  async function load() {
    setLoading(true);
    try {
      setBookings(await apiGet<Booking[]>('/bookings/payment-slips/pending'));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  async function review(id: number, approved: boolean, note?: string) {
    setSubmittingId(id);
    setError(null);
    try {
      await apiPut(`/bookings/${id}/payment-slip/review`, { approved, note: note ?? null });
      setRejectingId(null);
      setRejectNote('');
      await load();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'บันทึกผลตรวจสอบไม่สำเร็จ');
    } finally {
      setSubmittingId(null);
    }
  }

  if (loading) return <p>กำลังโหลด...</p>;

  return (
    <div>
      {error && <p className="mb-3 rounded bg-red-50 p-3 text-sm text-brand">{error}</p>}
      {bookings.length === 0 ? (
        <p className="text-sm text-gray-500">ไม่มีสลิปที่รอตรวจสอบ</p>
      ) : (
        <div className="grid gap-4 md:grid-cols-2">
          {bookings.map((booking) => (
            <div key={booking.id} className="rounded-lg bg-white p-4 shadow-sm">
              <div className="mb-2 flex items-start justify-between">
                <div>
                  <div className="font-semibold">{booking.userFullName}</div>
                  <div className="text-xs text-gray-500">{booking.orderCode}</div>
                </div>
                <div className="text-right font-semibold text-brand">
                  {(booking.paidAmount ?? 0).toLocaleString()} บาท
                </div>
              </div>
              {booking.slipImageUrl && (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={booking.slipImageUrl}
                  alt="สลิปการโอนเงิน"
                  className="mb-3 max-h-80 w-full rounded border border-gray-200 object-contain"
                />
              )}
              {booking.slipSubmittedAt && (
                <div className="mb-3 text-xs text-gray-500">
                  ส่งเมื่อ {new Date(booking.slipSubmittedAt).toLocaleString('th-TH')}
                </div>
              )}
              {/* เหตุผลที่ตัวตรวจอัตโนมัติไม่ยืนยันสลิปใบนี้ เช่น "สลิปซ้ำ" หรือ
                  "บัญชีผู้รับไม่ใช่ของร้าน" — ต้องเห็นก่อนกด ไม่ใช่เพ่งรูปเอง */}
              {booking.slipReviewNote && (
                <div className="mb-3 flex gap-2 rounded-lg bg-amber-50 p-3 text-xs text-amber-900">
                  <svg
                    viewBox="0 0 20 20"
                    fill="currentColor"
                    aria-hidden="true"
                    className="mt-0.5 h-4 w-4 shrink-0 text-amber-500"
                  >
                    <path d="M10 2a8 8 0 1 0 0 16 8 8 0 0 0 0-16Zm0 3.5a.9.9 0 0 1 .9.9v4.2a.9.9 0 0 1-1.8 0V6.4a.9.9 0 0 1 .9-.9Zm0 7.3a1 1 0 1 1 0 2 1 1 0 0 1 0-2Z" />
                  </svg>
                  <span>{booking.slipReviewNote}</span>
                </div>
              )}
              {rejectingId === booking.id ? (
                <div className="space-y-2">
                  <textarea
                    value={rejectNote}
                    onChange={(e) => setRejectNote(e.target.value)}
                    placeholder="เหตุผลที่ปฏิเสธ (จะแจ้งให้ลูกค้าเห็น)"
                    className="w-full rounded border border-gray-300 px-3 py-2 text-sm"
                    rows={2}
                  />
                  <div className="flex gap-2">
                    <button
                      onClick={() => review(booking.id, false, rejectNote)}
                      disabled={submittingId === booking.id}
                      className="rounded bg-red-600 px-3 py-1.5 text-sm text-white hover:bg-red-700 disabled:opacity-50"
                    >
                      ยืนยันปฏิเสธ
                    </button>
                    <button
                      onClick={() => {
                        setRejectingId(null);
                        setRejectNote('');
                      }}
                      className="rounded border border-gray-300 px-3 py-1.5 text-sm"
                    >
                      ยกเลิก
                    </button>
                  </div>
                </div>
              ) : (
                <div className="flex gap-2">
                  <button
                    onClick={() => review(booking.id, true)}
                    disabled={submittingId === booking.id}
                    className="rounded bg-brand px-3 py-1.5 text-sm text-white hover:bg-brand-dark disabled:opacity-50"
                  >
                    อนุมัติ
                  </button>
                  <button
                    onClick={() => {
                      setRejectingId(booking.id);
                      // เหตุผลที่ระบบตรวจได้ใช้เป็นร่างให้เลย แอดมินแก้ทับได้
                      setRejectNote(booking.slipReviewNote ?? '');
                    }}
                    disabled={submittingId === booking.id}
                    className="rounded border border-red-300 px-3 py-1.5 text-sm text-red-600 hover:bg-red-50 disabled:opacity-50"
                  >
                    ปฏิเสธ
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
