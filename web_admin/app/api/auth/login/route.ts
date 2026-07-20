import { NextRequest, NextResponse } from 'next/server';
import { SESSION_COOKIE } from '@/lib/session';
import { backendFetch } from '@/lib/backend';

export async function POST(request: NextRequest) {
  const body = await request.json();

  const backendRes = await backendFetch('/api/auth/login', undefined, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  const data = await backendRes.json();

  if (!backendRes.ok) {
    return NextResponse.json(data, { status: backendRes.status });
  }

  if (data.role !== 'ADMIN' && data.role !== 'OWNER' && data.role !== 'TECHNICIAN') {
    return NextResponse.json({ message: 'บัญชีนี้ไม่มีสิทธิ์เข้าใช้งานระบบนี้' }, { status: 403 });
  }

  const response = NextResponse.json({ fullName: data.fullName, email: data.email, role: data.role });
  response.cookies.set(SESSION_COOKIE, data.token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: 60 * 60 * 24,
  });
  return response;
}
