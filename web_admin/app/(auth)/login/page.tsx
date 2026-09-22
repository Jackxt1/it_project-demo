'use client';
import { useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import Image from 'next/image';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.message ?? 'เข้าสู่ระบบไม่สำเร็จ');
      }
      router.push(data.role === 'OWNER' ? '/dashboard' : '/queue');
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'เข้าสู่ระบบไม่สำเร็จ');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div
      className="flex min-h-screen items-center justify-center bg-brand-light bg-cover bg-center"
      style={{ backgroundImage: "url('/bg_web.png')" }}
    >
      <form onSubmit={handleSubmit} className="w-full max-w-sm rounded-xl bg-white p-8 shadow-lg">
        <Image
          src="/logo-red-mark.png"
          alt="BKK Car Glass and Service"
          width={1522}
          height={426}
          className="mx-auto mb-6 h-auto w-full max-w-xs"
          priority
        />
        <h1 className="mb-6 text-center text-2xl font-bold text-gray-900">เข้าสู่ระบบ</h1>
        {error && <p className="mb-4 rounded bg-red-50 p-2 text-sm text-brand">{error}</p>}
        <label className="mb-1 block text-sm font-medium text-brand-deep">อีเมล</label>
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="mb-4 w-full rounded-lg border-0 bg-gray-100 px-4 py-3 focus:outline-none focus:ring-2 focus:ring-brand"
        />
        <label className="mb-1 block text-sm font-medium text-brand-deep">รหัสผ่าน</label>
        <input
          type="password"
          required
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="mb-6 w-full rounded-lg border-0 bg-gray-100 px-4 py-3 focus:outline-none focus:ring-2 focus:ring-brand"
        />
        <button
          type="submit"
          disabled={loading}
          className="w-full rounded-full bg-gradient-to-r from-[#be1a1a] to-[#580c0c] py-3 font-semibold text-white shadow-sm transition hover:brightness-110 disabled:opacity-50"
        >
          {loading ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ'}
        </button>
      </form>
    </div>
  );
}
