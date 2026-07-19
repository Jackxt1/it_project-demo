import { NextRequest, NextResponse } from 'next/server';
import { SESSION_COOKIE } from '@/lib/session';
import { BACKEND_URL } from '@/lib/backend';

async function proxy(request: NextRequest, params: { proxy: string[] }): Promise<NextResponse> {
  const token = request.cookies.get(SESSION_COOKIE)?.value;
  const path = params.proxy.join('/');
  const url = `${BACKEND_URL}/api/${path}${request.nextUrl.search}`;

  const headers = new Headers();
  const contentType = request.headers.get('content-type');
  if (contentType) {
    headers.set('content-type', contentType);
  }
  if (token) {
    headers.set('authorization', `Bearer ${token}`);
  }

  const hasBody = request.method !== 'GET' && request.method !== 'HEAD';
  const backendRes = await fetch(url, {
    method: request.method,
    headers,
    body: hasBody ? await request.arrayBuffer() : undefined,
  });

  const responseBody = await backendRes.arrayBuffer();
  const responseHeaders = new Headers();
  const resContentType = backendRes.headers.get('content-type');
  if (resContentType) {
    responseHeaders.set('content-type', resContentType);
  }

  return new NextResponse(responseBody, { status: backendRes.status, headers: responseHeaders });
}

export async function GET(request: NextRequest, { params }: { params: { proxy: string[] } }) {
  return proxy(request, params);
}
export async function POST(request: NextRequest, { params }: { params: { proxy: string[] } }) {
  return proxy(request, params);
}
export async function PUT(request: NextRequest, { params }: { params: { proxy: string[] } }) {
  return proxy(request, params);
}
export async function PATCH(request: NextRequest, { params }: { params: { proxy: string[] } }) {
  return proxy(request, params);
}
export async function DELETE(request: NextRequest, { params }: { params: { proxy: string[] } }) {
  return proxy(request, params);
}
