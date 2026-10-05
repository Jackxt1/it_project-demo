/**
 * Short, colour-coded label for a service, so a card can be read at a glance
 * on the queue board. Services are matched by name because the board shows
 * whatever services the shop has configured, not a fixed list.
 */
const TONES: { match: RegExp; label: string; className: string }[] = [
  { match: /ฟิล์ม/, label: 'ติดฟิล์ม', className: 'bg-amber-100 text-amber-800' },
  { match: /ล้าง/, label: 'ล้างรถ', className: 'bg-emerald-100 text-emerald-700' },
  { match: /กระจก|ร้าว/, label: 'ซ่อมกระจก', className: 'bg-rose-100 text-rose-700' },
];

const FALLBACK = 'bg-slate-100 text-slate-700';

export function serviceTone(serviceName: string) {
  return TONES.find((tone) => tone.match.test(serviceName));
}

export default function ServiceBadge({ serviceName }: { serviceName: string }) {
  const tone = serviceTone(serviceName);
  return (
    <span
      className={`shrink-0 rounded-full px-2.5 py-1 text-[11px] font-semibold ${tone?.className ?? FALLBACK}`}
    >
      {tone?.label ?? serviceName}
    </span>
  );
}
