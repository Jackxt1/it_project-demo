'use client';
import { useEffect, useState } from 'react';
import { apiGet, ApiError } from '@/lib/api';
import type { ChatInboxItem } from '@/lib/types';
import ChatThread from './ChatThread';

export default function ChatInbox() {
  const [items, setItems] = useState<ChatInboxItem[]>([]);
  const [selected, setSelected] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    try {
      setItems(await apiGet<ChatInboxItem[]>('/chat/inbox'));
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ');
    }
  }

  useEffect(() => {
    load();
  }, []);

  return (
    <div className="grid gap-4 md:grid-cols-[1fr_2fr]">
      <div className="rounded-lg bg-white shadow-sm">
        {error && <p className="p-3 text-sm text-brand">{error}</p>}
        {items.map((item) => (
          <button
            key={item.bookingId}
            onClick={() => setSelected(item.bookingId)}
            className={`block w-full border-b p-3 text-left last:border-0 ${
              selected === item.bookingId ? 'bg-brand-light' : 'hover:bg-gray-50'
            }`}
          >
            <div className="flex items-center justify-between">
              <span className="font-medium">{item.customerName}</span>
              {item.unreadCount > 0 && (
                <span className="rounded-full bg-brand px-2 text-xs text-white">{item.unreadCount}</span>
              )}
            </div>
            <p className="text-xs text-gray-500">{item.serviceName}</p>
            <p className="truncate text-sm text-gray-600">{item.lastMessage}</p>
          </button>
        ))}
        {items.length === 0 && <p className="p-3 text-sm text-gray-500">ยังไม่มีข้อความ</p>}
      </div>
      <div className="rounded-lg bg-white shadow-sm">
        {selected ? (
          <ChatThread bookingId={selected} onMessagesRead={load} />
        ) : (
          <p className="p-6 text-center text-gray-400">เลือกการสนทนาทางซ้าย</p>
        )}
      </div>
    </div>
  );
}
