import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { SESSION_COOKIE, decodeToken, isSessionValid } from '@/lib/session';
import { backendFetch } from '@/lib/backend';
import { formatThaiDate } from '@/lib/thaiDate';
import Sidebar from '@/components/Sidebar';
import LogoutButton from '@/components/LogoutButton';
import NewBookingPopup from '@/components/NewBookingPopup';
import NotificationBell from '@/components/NotificationBell';
import type { CurrentUser } from '@/lib/types';

export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const token = cookies().get(SESSION_COOKIE)?.value;
  const session = token ? decodeToken(token) : null;

  if (!isSessionValid(session)) {
    redirect('/login');
  }

  const res = await backendFetch('/api/users/me', token);
  const user: CurrentUser = await res.json();

  return (
    <div className="flex h-screen">
      <NewBookingPopup role={session.role} />
      <Sidebar role={session.role} fullName={user.fullName} />
      <div className="flex flex-1 flex-col overflow-y-auto bg-gray-50">
        <div className="flex items-center justify-end gap-3 px-6 pt-4 text-sm text-gray-500">
          <span>{formatThaiDate(new Date())}</span>
          <span className="text-gray-300">|</span>
          <NotificationBell role={session.role} />
          <LogoutButton />
        </div>
        <main className="flex-1 p-6 pt-2">{children}</main>
      </div>
    </div>
  );
}
