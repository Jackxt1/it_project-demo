import { cookies } from 'next/headers';
import { decodeToken, SESSION_COOKIE } from '@/lib/session';
import { backendFetch } from '@/lib/backend';
import QueueBoard from './QueueBoard';
import type { CurrentUser } from '@/lib/types';

export default async function QueuePage() {
  const token = cookies().get(SESSION_COOKIE)?.value;
  const session = token ? decodeToken(token) : null;
  const role = session?.role ?? 'ADMIN';

  let userId: number | null = null;
  if (role === 'TECHNICIAN' && token) {
    const res = await backendFetch('/api/users/me', token);
    const user: CurrentUser = await res.json();
    userId = user.id;
  }

  return (
    <div>
      <h1 className="mb-4 text-xl font-bold text-brand-deep">คิวงาน</h1>
      <QueueBoard role={role} userId={userId} />
    </div>
  );
}
