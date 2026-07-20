export const SESSION_COOKIE = 'bkk_admin_token';

export type Role = 'CUSTOMER' | 'ADMIN' | 'OWNER' | 'TECHNICIAN';

export interface Session {
  email: string;
  role: Role;
  exp: number;
}

export function decodeToken(token: string): Session | null {
  const parts = token.split('.');
  if (parts.length !== 3) {
    return null;
  }
  try {
    const normalized = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const json = JSON.parse(atob(normalized));
    if (typeof json.sub !== 'string' || typeof json.role !== 'string' || typeof json.exp !== 'number') {
      return null;
    }
    return { email: json.sub, role: json.role as Role, exp: json.exp };
  } catch {
    return null;
  }
}

export function isSessionValid(session: Session | null): session is Session {
  return session !== null && session.exp * 1000 > Date.now();
}

export function canAccessQueue(role: Role): boolean {
  return role === 'ADMIN' || role === 'OWNER' || role === 'TECHNICIAN';
}

export function canAccessStaffArea(role: Role): boolean {
  return role === 'ADMIN' || role === 'OWNER';
}

export function isOwner(role: Role): boolean {
  return role === 'OWNER';
}

export function resolveAccess(pathname: string, role: Role): boolean {
  if (pathname.startsWith('/dashboard') || pathname.startsWith('/staff')) {
    return isOwner(role);
  }
  if (pathname.startsWith('/queue')) {
    return canAccessQueue(role);
  }
  return canAccessStaffArea(role);
}
