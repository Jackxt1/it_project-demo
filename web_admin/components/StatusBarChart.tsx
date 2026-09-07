'use client';
import { useState } from 'react';
import type { BookingStatus } from '@/lib/types';

const STATUS_ORDER: BookingStatus[] = ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'];

const STATUS_LABELS: Record<BookingStatus, string> = {
  PENDING: 'รอดำเนินการ',
  CONFIRMED: 'ยืนยันแล้ว',
  IN_PROGRESS: 'กำลังดำเนินการ',
  COMPLETED: 'เสร็จสิ้น',
  CANCELLED: 'ยกเลิก',
};

// Same per-status hues as StatusBadge, so the chart and the queue list agree.
const STATUS_COLORS: Record<BookingStatus, string> = {
  PENDING: '#9CA3AF',
  CONFIRMED: '#3B82F6',
  IN_PROGRESS: '#EAB308',
  COMPLETED: '#22C55E',
  CANCELLED: '#EF4444',
};

const WIDTH = 480;
const HEIGHT = 200;
const BASELINE_Y = 160;
const BAR_WIDTH = 40;

export default function StatusBarChart({ statusCounts }: { statusCounts: Record<string, number> }) {
  const [hovered, setHovered] = useState<BookingStatus | null>(null);

  const counts = STATUS_ORDER.map((status) => statusCounts[status] ?? 0);
  const max = Math.max(1, ...counts);
  const bandWidth = WIDTH / STATUS_ORDER.length;

  return (
    <svg
      viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
      role="img"
      aria-label="กราฟจำนวนการจองตามสถานะ"
      className="w-full"
    >
      <line x1={0} y1={BASELINE_Y} x2={WIDTH} y2={BASELINE_Y} stroke="#E5E7EB" strokeWidth={1} />

      {STATUS_ORDER.map((status, i) => {
        const count = counts[i];
        const barHeight = (count / max) * (BASELINE_Y - 20);
        const bandCenter = bandWidth * i + bandWidth / 2;
        const x = bandCenter - BAR_WIDTH / 2;
        const y = BASELINE_Y - barHeight;
        const isHovered = hovered === status;

        return (
          <g
            key={status}
            onMouseEnter={() => setHovered(status)}
            onMouseLeave={() => setHovered(null)}
          >
            <text
              x={bandCenter}
              y={y - 6}
              textAnchor="middle"
              fontSize={12}
              fontWeight={600}
              fill="#374151"
            >
              {count}
            </text>
            <rect
              x={x}
              y={y}
              width={BAR_WIDTH}
              height={Math.max(barHeight, 1)}
              rx={4}
              fill={STATUS_COLORS[status]}
              opacity={isHovered ? 1 : 0.85}
            >
              <title>
                {STATUS_LABELS[status]}: {count}
              </title>
            </rect>
            <text
              x={bandCenter}
              y={BASELINE_Y + 18}
              textAnchor="middle"
              fontSize={11}
              fill="#6B7280"
            >
              {STATUS_LABELS[status]}
            </text>
          </g>
        );
      })}
    </svg>
  );
}
