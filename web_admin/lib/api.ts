export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`/api${path}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(init?.headers ?? {}) },
  });

  if (res.status === 204) {
    return undefined as T;
  }

  const data = await res.json().catch(() => null);
  if (!res.ok) {
    const message = data && typeof data.message === 'string' ? data.message : `Request failed (${res.status})`;
    throw new ApiError(res.status, message);
  }
  return data as T;
}

export const apiGet = <T>(path: string) => request<T>(path);
export const apiPost = <T>(path: string, body: unknown) =>
  request<T>(path, { method: 'POST', body: JSON.stringify(body) });
export const apiPut = <T>(path: string, body: unknown) =>
  request<T>(path, { method: 'PUT', body: JSON.stringify(body) });
export const apiPatch = <T>(path: string, body: unknown) =>
  request<T>(path, { method: 'PATCH', body: JSON.stringify(body) });
export const apiDelete = <T>(path: string) => request<T>(path, { method: 'DELETE' });
