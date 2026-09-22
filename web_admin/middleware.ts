import { NextRequest, NextResponse } from 'next/server';
import { SESSION_COOKIE, decodeToken, isSessionValid, resolveAccess } from '@/lib/session';

export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  const token = request.cookies.get(SESSION_COOKIE)?.value;
  const session = token ? decodeToken(token) : null;

  if (!isSessionValid(session)) {
    const response = NextResponse.redirect(new URL('/login', request.url));
    response.cookies.delete(SESSION_COOKIE);
    return response;
  }

  if (!resolveAccess(pathname, session.role)) {
    return NextResponse.redirect(new URL('/login?error=forbidden', request.url));
  }

  return NextResponse.next();
}

export const config = {
  // Also skips public static assets (bg_web.png, logo-mark.png, etc.) — anything
  // with a file extension — so unauthenticated pages like /login can load them
  // without the middleware bouncing the asset request itself to /login.
  matcher: ['/((?!_next/static|_next/image|favicon.ico|api|login|.*\\.\\w+$).*)'],
};
