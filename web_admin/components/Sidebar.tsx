'use client';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import LogoutButton from './LogoutButton';
import type { Role } from '@/lib/session';

interface NavItem {
  href: string;
  label: string;
}

const STAFF_ITEMS: NavItem[] = [
  { href: '/queue', label: 'คิวงาน' },
  { href: '/customers', label: 'ลูกค้า' },
  { href: '/catalog', label: 'บริการ/สินค้า' },
  { href: '/technicians', label: 'ช่าง' },
  { href: '/chat', label: 'แชท' },
];

const OWNER_ITEMS: NavItem[] = [{ href: '/dashboard', label: 'ภาพรวม' }];

export default function Sidebar({ role, fullName }: { role: Role; fullName: string }) {
  const pathname = usePathname();
  const items = role === 'TECHNICIAN' ? [{ href: '/queue', label: 'คิวงานของฉัน' }] : STAFF_ITEMS;
  const ownerItems = role === 'OWNER' ? OWNER_ITEMS : [];

  return (
    <aside className="flex h-screen w-56 flex-col bg-brand-deep text-white">
      <div className="p-4 text-lg font-bold">BKK Car Glass</div>
      <div className="px-4 pb-4 text-sm text-brand-light">{fullName}</div>
      <nav className="flex-1 space-y-1 px-2">
        {[...items, ...ownerItems].map((item) => (
          <Link
            key={item.href}
            href={item.href}
            className={`block rounded px-3 py-2 text-sm ${
              pathname.startsWith(item.href) ? 'bg-brand text-white' : 'text-brand-light hover:bg-brand-darker'
            }`}
          >
            {item.label}
          </Link>
        ))}
      </nav>
      <div className="p-4">
        <LogoutButton />
      </div>
    </aside>
  );
}
