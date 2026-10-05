import { describe, expect, it } from 'vitest';
import { decodeToken, isSessionValid, resolveAccess } from './session';

function makeToken(payload: Record<string, unknown>): string {
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = btoa(JSON.stringify(payload));
  return `${header}.${body}.fakesignature`;
}

describe('decodeToken', () => {
  it('reads the email claim when the subject is a user id', () => {
    const token = makeToken({ sub: '12', email: 'owner@test.com', role: 'OWNER', exp: 9999999999 });
    const session = decodeToken(token);
    expect(session).toEqual({ email: 'owner@test.com', role: 'OWNER', exp: 9999999999 });
  });

  it('falls back to the subject for tokens issued before the email claim existed', () => {
    const token = makeToken({ sub: 'owner@test.com', role: 'OWNER', exp: 9999999999 });
    const session = decodeToken(token);
    expect(session).toEqual({ email: 'owner@test.com', role: 'OWNER', exp: 9999999999 });
  });

  it('returns null for a malformed token', () => {
    expect(decodeToken('not-a-jwt')).toBeNull();
  });

  it('returns null when required claims are missing', () => {
    const token = makeToken({ sub: 'owner@test.com' });
    expect(decodeToken(token)).toBeNull();
  });
});

describe('isSessionValid', () => {
  it('returns false for null session', () => {
    expect(isSessionValid(null)).toBe(false);
  });

  it('returns false for an expired session', () => {
    expect(isSessionValid({ email: 'a@test.com', role: 'ADMIN', exp: 1 })).toBe(false);
  });

  it('returns true for a session that has not expired', () => {
    const future = Math.floor(Date.now() / 1000) + 3600;
    expect(isSessionValid({ email: 'a@test.com', role: 'ADMIN', exp: future })).toBe(true);
  });
});

describe('resolveAccess', () => {
  it('allows only OWNER on /dashboard and /staff', () => {
    expect(resolveAccess('/dashboard', 'OWNER')).toBe(true);
    expect(resolveAccess('/dashboard', 'ADMIN')).toBe(false);
    expect(resolveAccess('/staff/accounts', 'OWNER')).toBe(true);
    expect(resolveAccess('/staff/accounts', 'ADMIN')).toBe(false);
  });

  it('allows ADMIN, OWNER, and TECHNICIAN on /queue', () => {
    expect(resolveAccess('/queue', 'ADMIN')).toBe(true);
    expect(resolveAccess('/queue', 'OWNER')).toBe(true);
    expect(resolveAccess('/queue', 'TECHNICIAN')).toBe(true);
    expect(resolveAccess('/queue', 'CUSTOMER')).toBe(false);
  });

  it('allows only ADMIN and OWNER on other staff routes', () => {
    expect(resolveAccess('/customers', 'ADMIN')).toBe(true);
    expect(resolveAccess('/customers', 'OWNER')).toBe(true);
    expect(resolveAccess('/customers', 'TECHNICIAN')).toBe(false);
  });
});
