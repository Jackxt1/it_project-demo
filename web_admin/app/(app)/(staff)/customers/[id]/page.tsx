import { cookies } from 'next/headers';
import { notFound } from 'next/navigation';
import { SESSION_COOKIE } from '@/lib/session';
import { backendFetch } from '@/lib/backend';
import StatusBadge from '@/components/StatusBadge';
import type { CustomerDetail } from '@/lib/types';

export default async function CustomerDetailPage({ params }: { params: { id: string } }) {
  const token = cookies().get(SESSION_COOKIE)?.value;
  const res = await backendFetch(`/api/admin/customers/${params.id}`, token);
  if (res.status === 404) {
    notFound();
  }
  const customer: CustomerDetail = await res.json();

  return (
    <div>
      <h1 className="mb-1 text-xl font-bold text-brand-deep">{customer.fullName}</h1>
      <p className="mb-4 text-sm text-gray-500">
        {customer.email} · {customer.phone ?? '-'}
      </p>

      <h2 className="mb-2 font-semibold text-brand-deep">ประวัติการจอง</h2>
      <div className="space-y-2">
        {customer.bookings.length === 0 && <p className="text-gray-500">ยังไม่มีการจอง</p>}
        {customer.bookings.map((booking) => (
          <div key={booking.id} className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
            <div className="flex items-center justify-between">
              <div>
                <p className="font-medium">{booking.serviceName}</p>
                <p className="text-sm text-gray-500">
                  {booking.bookingDate} {booking.timeSlot}
                </p>
              </div>
              <StatusBadge status={booking.status} />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
