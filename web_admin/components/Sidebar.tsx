'use client';
import Image from 'next/image';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import type { Role } from '@/lib/session';

interface NavItem {
  href: string;
  label: string;
  icon: React.ReactNode;
}

const iconProps = {
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.6,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
  className: 'h-5 w-5 shrink-0',
};

const QueueIcon = () => (
  <svg {...iconProps}>
    <rect x="5" y="4" width="14" height="17" rx="2" />
    <rect x="9" y="2" width="6" height="4" rx="1" fill="currentColor" stroke="none" />
    <line x1="8" y1="10" x2="16" y2="10" />
    <line x1="8" y1="14" x2="16" y2="14" />
    <line x1="8" y1="18" x2="13" y2="18" />
  </svg>
);

const CustomersIcon = () => (
  <svg {...iconProps}>
    <circle cx="9" cy="7" r="3" />
    <rect x="4" y="13" width="10" height="7" rx="3" />
    <circle cx="18" cy="8" r="2.2" />
    <path d="M15 20v-1a3 3 0 0 1 3-3h0a3 3 0 0 1 3 3v1" />
  </svg>
);

const CatalogIcon = () => (
  <svg {...iconProps}>
    <g transform="rotate(45 12 12)">
      <rect x="7" y="7" width="10" height="10" rx="2" />
    </g>
    <circle cx="8.5" cy="8.5" r="1" fill="currentColor" stroke="none" />
  </svg>
);

const TechniciansIcon = () => (
  <svg {...iconProps}>
    <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76Z" />
  </svg>
);

const ChatIcon = () => (
  <svg {...iconProps}>
    <rect x="3" y="4" width="18" height="12" rx="3" />
    <polygon points="8,16 8,20 12,16" fill="currentColor" stroke="none" />
  </svg>
);

const PaymentsIcon = () => (
  <svg {...iconProps}>
    <rect x="5" y="3" width="14" height="18" rx="2" />
    <polyline points="8,12 11,15 16,9" />
  </svg>
);

const DashboardIcon = () => (
  <svg {...iconProps}>
    <rect x="4" y="12" width="4" height="8" />
    <rect x="10" y="7" width="4" height="13" />
    <rect x="16" y="3" width="4" height="17" />
  </svg>
);

const STAFF_ITEMS: NavItem[] = [
  { href: '/queue', label: 'คิวงาน', icon: <QueueIcon /> },
  { href: '/customers', label: 'ลูกค้า', icon: <CustomersIcon /> },
  { href: '/catalog', label: 'บริการ/สินค้า', icon: <CatalogIcon /> },
  { href: '/technicians', label: 'ช่าง', icon: <TechniciansIcon /> },
  { href: '/chat', label: 'แชท', icon: <ChatIcon /> },
  { href: '/payments', label: 'ตรวจสอบสลิป', icon: <PaymentsIcon /> },
];

const OWNER_ITEMS: NavItem[] = [{ href: '/dashboard', label: 'ภาพรวม', icon: <DashboardIcon /> }];

export default function Sidebar({ role, fullName }: { role: Role; fullName: string }) {
  const pathname = usePathname();
  const items =
    role === 'TECHNICIAN' ? [{ href: '/queue', label: 'คิวงานของฉัน', icon: <QueueIcon /> }] : STAFF_ITEMS;
  const ownerItems = role === 'OWNER' ? OWNER_ITEMS : [];

  return (
    <aside className="flex h-screen w-72 flex-col bg-[#373737] text-white">
      <div className="flex items-center gap-3 p-4">
        <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl bg-gradient-to-br from-[#be1a1a] to-[#580c0c] p-2 shadow-md">
          <Image src="/logo-mark.png" alt="BKK" width={688} height={198} className="h-auto w-full" priority />
        </div>
        <div>
          <div className="whitespace-nowrap text-xs font-extrabold uppercase leading-tight tracking-tight">
            BKK Car Glass &amp; Film
          </div>
          <div className="text-sm text-brand-light">Admin Menu</div>
        </div>
      </div>
      <hr className="mx-4 border-t border-white/10" />
      <nav className="flex-1 space-y-1 px-2 pt-2">
        {[...items, ...ownerItems].map((item) => (
          <Link
            key={item.href}
            href={item.href}
            className={`flex items-center gap-3 rounded px-3 py-2 text-sm ${
              pathname.startsWith(item.href)
                ? 'bg-gradient-to-r from-[#be1a1a] to-[#580c0c] text-white'
                : 'text-brand-light hover:bg-brand-darker'
            }`}
          >
            {item.icon}
            {item.label}
          </Link>
        ))}
      </nav>
    </aside>
  );
}
