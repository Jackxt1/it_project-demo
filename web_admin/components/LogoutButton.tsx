'use client';
import { useRouter } from 'next/navigation';

export default function LogoutButton() {
  const router = useRouter();

  async function handleLogout() {
    await fetch('/api/auth/logout', { method: 'POST' });
    router.push('/login');
    router.refresh();
  }

  return (
    <button
      onClick={handleLogout}
      className="rounded-md bg-gradient-to-r from-[#be1a1a] to-[#580c0c] px-3 py-1.5 text-sm font-medium text-white shadow-sm transition hover:brightness-110"
    >
      ออกจากระบบ
    </button>
  );
}
