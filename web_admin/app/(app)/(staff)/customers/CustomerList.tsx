'use client';
import { useEffect, useState } from 'react';
import Avatar from '@/components/Avatar';
import { apiGet, ApiError } from '@/lib/api';
import type { Customer, Page } from '@/lib/types';
import CustomerDetailPanel from './CustomerDetailPanel';

/** How many rows to show before the "ดูทั้งหมด" button reveals the rest. */
const PREVIEW_COUNT = 6;

function vehicleLine(customer: Customer): string {
  const parts: string[] = [];
  if (customer.vehicleBrandModel) parts.push(customer.vehicleBrandModel);
  if (customer.vehicleLicensePlate) parts.push(`ทะเบียน ${customer.vehicleLicensePlate}`);
  return parts.length > 0 ? parts.join(' ') : 'ยังไม่ได้บันทึกรถ';
}

export default function CustomerList() {
  const [search, setSearch] = useState('');
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [total, setTotal] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [expanded, setExpanded] = useState(false);

  useEffect(() => {
    async function load() {
      setLoading(true);
      try {
        const query = search ? `?search=${encodeURIComponent(search)}` : '';
        const data = await apiGet<Page<Customer>>(`/admin/customers${query}`);
        setCustomers(data.content);
        setTotal(data.totalElements);
        setError(null);
      } catch (err) {
        setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ');
      } finally {
        setLoading(false);
      }
    }
    const timeout = setTimeout(load, 300);
    return () => clearTimeout(timeout);
  }, [search]);

  const visible = expanded ? customers : customers.slice(0, PREVIEW_COUNT);

  return (
    <div>
      <div className="mb-4 flex items-baseline gap-3">
        <h1 className="text-2xl font-bold text-brand-deep">ข้อมูลลูกค้า</h1>
        <span className="text-sm text-gray-400">ทั้งหมด {total} คน</span>
      </div>

      <div className="flex flex-col gap-4 lg:flex-row lg:items-start">
        <div className="flex-1">
          <div className="relative mb-3">
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
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="ค้นหาชื่อ เบอร์โทรศัพท์ หรือทะเบียนรถ"
              className="w-full rounded-full border border-gray-200 bg-white py-2 pl-9 pr-4 text-sm outline-none focus:border-brand"
            />
          </div>

          {error && <p className="mb-3 rounded-lg bg-red-50 p-3 text-sm text-brand">{error}</p>}
          {loading && <p className="text-sm text-gray-500">กำลังโหลด...</p>}
          {!loading && customers.length === 0 && (
            <p className="text-sm text-gray-400">ไม่พบลูกค้าที่ค้นหา</p>
          )}

          <ul className="space-y-2">
            {visible.map((customer) => (
              <li key={customer.id}>
                <button
                  type="button"
                  onClick={() => setSelectedId(customer.id)}
                  className={`flex w-full items-center gap-3 rounded-2xl border bg-white p-3 text-left shadow-sm transition hover:shadow ${
                    selectedId === customer.id
                      ? 'border-brand ring-1 ring-brand/30'
                      : 'border-gray-200 hover:border-brand/40'
                  }`}
                >
                  <Avatar name={customer.fullName || '?'} />
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-bold text-brand-deep">
                      {customer.fullName || 'ไม่ระบุชื่อ'}
                    </span>
                    <span className="block truncate text-xs text-gray-600">{vehicleLine(customer)}</span>
                    <span className="block truncate text-xs text-gray-400">
                      เบอร์โทรศัพท์ {customer.phone ?? '-'}
                    </span>
                  </span>
                </button>
              </li>
            ))}
          </ul>

          {!expanded && customers.length > PREVIEW_COUNT && (
            <button
              type="button"
              onClick={() => setExpanded(true)}
              className="mt-3 w-full rounded-xl bg-brand-dark py-2.5 text-sm font-bold text-white hover:bg-brand"
            >
              ดูทั้งหมด
            </button>
          )}
        </div>

        {selectedId != null && (
          <CustomerDetailPanel customerId={selectedId} onClose={() => setSelectedId(null)} />
        )}
      </div>
    </div>
  );
}
