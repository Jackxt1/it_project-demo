import { cookies } from 'next/headers';
import { decodeToken, SESSION_COOKIE } from '@/lib/session';
import QueueBoard from './QueueBoard';

export default function QueuePage() {
  const token = cookies().get(SESSION_COOKIE)?.value;
  const session = token ? decodeToken(token) : null;
  const role = session?.role ?? 'ADMIN';

  return (
    <div>
      <h1 className="mb-4 text-xl font-bold text-brand-deep">คิวงาน</h1>
      <QueueBoard role={role} />
    </div>
  );
}
