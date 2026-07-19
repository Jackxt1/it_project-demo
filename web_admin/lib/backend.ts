export const BACKEND_URL = process.env.BACKEND_URL ?? 'http://localhost:8080';

export async function backendFetch(path: string, token?: string, init?: RequestInit): Promise<Response> {
  const headers = new Headers(init?.headers);
  if (token) {
    headers.set('authorization', `Bearer ${token}`);
  }
  return fetch(`${BACKEND_URL}${path}`, { ...init, headers, cache: 'no-store' });
}
