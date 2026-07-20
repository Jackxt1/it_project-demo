import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { SESSION_COOKIE, decodeToken, isSessionValid } from '@/lib/session';
import { backendFetch } from '@/lib/backend';
import Sidebar from '@/components/Sidebar';
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
    <div className="flex min-h-screen">
      <Sidebar role={session.role} fullName={user.fullName} />
      <main className="flex-1 overflow-y-auto bg-gray-50 p-6">{children}</main>
    </div>
  );
}
