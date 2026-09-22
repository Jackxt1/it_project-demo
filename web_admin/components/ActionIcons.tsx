const iconProps = {
  viewBox: '0 0 24 24',
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.8,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const,
  className: 'h-4 w-4 shrink-0',
};

export const PencilIcon = () => (
  <svg {...iconProps}>
    <g transform="rotate(45 12 12)">
      <rect x="10" y="3" width="4" height="13" rx="1" />
      <polygon points="10,16 14,16 12,20" fill="currentColor" stroke="none" />
    </g>
  </svg>
);

export const TrashIcon = () => (
  <svg {...iconProps}>
    <line x1="5" y1="7" x2="19" y2="7" />
    <path d="M9 4h6a1 1 0 0 1 1 1v2H8V5a1 1 0 0 1 1-1Z" />
    <rect x="6" y="7" width="12" height="13" rx="1" />
    <line x1="10" y1="11" x2="10" y2="16" />
    <line x1="14" y1="11" x2="14" y2="16" />
  </svg>
);

/** Standard "power off" glyph — used for the "ปิดใช้งาน" (deactivate) action. */
export const PowerOffIcon = () => (
  <svg {...iconProps}>
    <line x1="12" y1="4" x2="12" y2="11" />
    <path d="M7.5 7A7 7 0 1 0 16.5 7" />
  </svg>
);
