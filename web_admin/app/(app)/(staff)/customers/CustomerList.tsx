'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { apiGet, ApiError } from '@/lib/api';
import type { Customer, Page } from '@/lib/types';

export default function CustomerList() {
  const [search, setSearch] = useState('');
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      setLoading(true);
      try {
        const query = search ? `?search=${encodeURIComponent(search)}` : '';
        const data = await apiGet<Page<Customer>>(`/admin/customers${query}`);
        setCustomers(data.content);
      } catch (err) {
        setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ');
      } finally {
        setLoading(false);
      }
    }
    const timeout = setTimeout(load, 300);
    return () => clearTimeout(timeout);
  }, [search]);

  return (
    <div>
      <input
        type="text"
        placeholder="ค้นหาชื่อ, อีเมล, เบอร์โทร"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        className="mb-4 w-full max-w-sm rounded border border-gray-300 px-3 py-2"
      />
      {error && <p className="mb-3 rounded bg-red-50 p-3 text-sm text-brand">{error}</p>}
      {loading ? (
        <p>กำลังโหลด...</p>
      ) : (
        <table className="w-full rounded-lg bg-white shadow-sm">
          <thead>
            <tr className="border-b text-left text-sm text-gray-500">
              <th className="p-3">ชื่อ</th>
              <th className="p-3">อีเมล</th>
              <th className="p-3">เบอร์โทร</th>
              <th className="p-3"></th>
            </tr>
          </thead>
          <tbody>
            {customers.map((customer) => (
              <tr key={customer.id} className="border-b text-sm last:border-0">
                <td className="p-3">{customer.fullName}</td>
                <td className="p-3">{customer.email}</td>
                <td className="p-3">{customer.phone ?? '-'}</td>
                <td className="p-3">
                  <Link href={`/customers/${customer.id}`} className="text-brand hover:underline">
                    ดูรายละเอียด
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
