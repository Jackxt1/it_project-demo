'use client';
import { useEffect, useState, type FormEvent } from 'react';
import { apiGet, apiPost, apiPut, ApiError } from '@/lib/api';
import type { ChatMessage } from '@/lib/types';
import { createStompClient } from '@/lib/ws';

export default function ChatThread({
  bookingId,
  onMessagesRead,
}: {
  bookingId: number;
  onMessagesRead: () => void;
}) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [draft, setDraft] = useState('');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;

    async function load() {
      try {
        const history = await apiGet<ChatMessage[]>(`/chat/bookings/${bookingId}/messages`);
        if (active) setMessages(history);
        await apiPut(`/chat/bookings/${bookingId}/read`, {});
        onMessagesRead();
      } catch (err) {
        setError(err instanceof ApiError ? err.message : 'โหลดข้อความไม่สำเร็จ');
      }
    }
    load();

    const client = createStompClient((connected) => {
      connected.subscribe(`/topic/chat/${bookingId}`, (message) => {
        const incoming = JSON.parse(message.body) as ChatMessage;
        setMessages((prev) => [...prev, incoming]);
      });
    });

    return () => {
      active = false;
      client.deactivate();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [bookingId]);

  async function handleSend(e: FormEvent) {
    e.preventDefault();
    if (!draft.trim()) return;
    try {
      await apiPost(`/chat/bookings/${bookingId}/messages`, { message: draft });
      setDraft('');
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'ส่งข้อความไม่สำเร็จ');
    }
  }

  return (
    <div className="flex h-[32rem] flex-col">
      <div className="flex-1 space-y-2 overflow-y-auto p-4">
        {error && <p className="text-sm text-brand">{error}</p>}
        {messages.map((message) => (
          <div
            key={message.id}
            className={`max-w-[75%] rounded-lg p-2 text-sm ${
              message.senderType === 'ADMIN' ? 'ml-auto bg-brand-light text-brand-deep' : 'bg-gray-100'
            }`}
          >
            <p>{message.message}</p>
          </div>
        ))}
      </div>
      <form onSubmit={handleSend} className="flex gap-2 border-t p-3">
        <input
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder="พิมพ์ข้อความ..."
          className="flex-1 rounded border border-gray-300 px-3 py-2"
        />
        <button type="submit" className="rounded bg-brand px-4 py-2 text-sm text-white hover:bg-brand-dark">
          ส่ง
        </button>
      </form>
    </div>
  );
}
