'use client';
import { useEffect, useState } from 'react';
import { apiGet, ApiError } from '@/lib/api';
import type { BookingsByStatus, DashboardSummary } from '@/lib/types';
import StatusBarChart from '@/components/StatusBarChart';
import BookingsTrendChart from '@/components/BookingsTrendChart';

const STATUS_LABELS: Record<string, string> = {
  PENDING: 'รอดำเนินการ',
  CONFIRMED: 'ยืนยันแล้ว',
  IN_PROGRESS: 'กำลังดำเนินการ',
  COMPLETED: 'เสร็จสิ้น',
  CANCELLED: 'ยกเลิก',
};

export default function DashboardView() {
  const [summary, setSummary] = useState<DashboardSummary | null>(null);
  const [byStatus, setByStatus] = useState<BookingsByStatus | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      try {
        const [summaryData, statusData] = await Promise.all([
          apiGet<DashboardSummary>('/admin/dashboard/summary'),
          apiGet<BookingsByStatus>('/admin/dashboard/bookings-by-status'),
        ]);
        setSummary(summaryData);
        setByStatus(statusData);
      } catch (err) {
        setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ');
      }
    }
    load();
  }, []);

  if (error) return <p className="rounded bg-red-50 p-3 text-sm text-brand">{error}</p>;
  if (!summary || !byStatus) return <p>กำลังโหลด...</p>;

  return (
    <div className="space-y-6">
      <div className="grid gap-4 sm:grid-cols-2">
        <div className="rounded-lg bg-white p-4 shadow-sm">
          <p className="text-sm text-gray-500">การจองวันนี้</p>
          <p className="text-2xl font-bold text-brand-deep">{summary.bookingsToday}</p>
        </div>
        <div className="rounded-lg bg-white p-4 shadow-sm">
          <p className="text-sm text-gray-500">การจองเดือนนี้</p>
          <p className="text-2xl font-bold text-brand-deep">{summary.bookingsThisMonth}</p>
        </div>
        <div className="rounded-lg bg-white p-4 shadow-sm">
          <p className="text-sm text-gray-500">รายได้วันนี้</p>
          <p className="text-2xl font-bold text-brand-deep">{summary.revenueToday.toLocaleString()} บาท</p>
        </div>
        <div className="rounded-lg bg-white p-4 shadow-sm">
          <p className="text-sm text-gray-500">รายได้เดือนนี้</p>
          <p className="text-2xl font-bold text-brand-deep">{summary.revenueThisMonth.toLocaleString()} บาท</p>
        </div>
      </div>

      <BookingsTrendChart />

      <div className="rounded-lg bg-white p-4 shadow-sm">
        <h2 className="mb-3 font-semibold text-brand-deep">จำนวนการจองตามสถานะ</h2>
        <StatusBarChart statusCounts={byStatus.statusCounts} />
        <div className="mt-3 space-y-1 border-t border-gray-100 pt-3">
          {Object.entries(byStatus.statusCounts).map(([status, count]) => (
            <div key={status} className="flex items-center justify-between text-sm text-gray-600">
              <span>{STATUS_LABELS[status] ?? status}</span>
              <span className="font-medium">{count}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
