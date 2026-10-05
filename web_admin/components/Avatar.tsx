/** Initials circle standing in for a customer photo, which the shop never collects. */
export default function Avatar({ name, size = 'md' }: { name: string; size?: 'md' | 'lg' }) {
  const initials = name.trim().slice(0, 2) || '?';
  const box = size === 'lg' ? 'h-14 w-14 text-lg' : 'h-11 w-11 text-sm';
  return (
    <span
      aria-hidden
      className={`flex shrink-0 items-center justify-center rounded-full bg-brand font-bold text-white ${box}`}
    >
      {initials}
    </span>
  );
}
