'use client';
import { useEffect, useState } from 'react';
import { apiGet, ApiError } from '@/lib/api';
import type { BookingsTrend } from '@/lib/types';

const WIDTH = 640;
const HEIGHT = 220;
const PADDING_LEFT = 28;
const PADDING_RIGHT = 12;
const BASELINE_Y = 170;
const TOP_Y = 20;

type Granularity = 'day' | 'month';

export default function BookingsTrendChart() {
  const [granularity, setGranularity] = useState<Granularity>('day');
  const [trend, setTrend] = useState<BookingsTrend | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setError(null);
    apiGet<BookingsTrend>(`/admin/dashboard/bookings-trend?granularity=${granularity}`)
      .then((data) => {
        if (!cancelled) setTrend(data);
      })
      .catch((err) => {
        if (!cancelled) setError(err instanceof ApiError ? err.message : 'โหลดข้อมูลไม่สำเร็จ');
      });
    return () => {
      cancelled = true;
    };
  }, [granularity]);

  return (
    <div className="rounded-lg bg-white p-4 shadow-sm">
      <div className="mb-3 flex items-center justify-between">
        <h2 className="font-semibold text-brand-deep">ยอดจอง</h2>
        <div className="flex gap-1 rounded-md bg-gray-100 p-1 text-sm">
          <button
            onClick={() => setGranularity('day')}
            className={`rounded px-3 py-1 ${
              granularity === 'day'
                ? 'bg-gradient-to-r from-[#be1a1a] to-[#580c0c] text-white shadow-sm'
                : 'text-gray-500'
            }`}
          >
            รายวัน
          </button>
          <button
            onClick={() => setGranularity('month')}
            className={`rounded px-3 py-1 ${
              granularity === 'month'
                ? 'bg-gradient-to-r from-[#be1a1a] to-[#580c0c] text-white shadow-sm'
                : 'text-gray-500'
            }`}
          >
            รายเดือน
          </button>
        </div>
      </div>

      {error && <p className="rounded bg-red-50 p-2 text-sm text-brand">{error}</p>}
      {!error && !trend && <p className="text-sm text-gray-500">กำลังโหลด...</p>}
      {trend && <TrendBars points={trend.points} />}
    </div>
  );
}

/** Rounded-top-only bar path — sharp bottom corners so bars sit flush on the baseline. */
function roundedTopBarPath(x: number, y: number, width: number, height: number, radius: number) {
  const r = Math.min(radius, width / 2, Math.max(height, 0));
  if (height <= 0) return '';
  if (r <= 0) return `M ${x} ${y} h ${width} v ${height} h ${-width} Z`;
  return `
    M ${x} ${y + r}
    A ${r} ${r} 0 0 1 ${x + r} ${y}
    L ${x + width - r} ${y}
    A ${r} ${r} 0 0 1 ${x + width} ${y + r}
    L ${x + width} ${y + height}
    L ${x} ${y + height}
    Z
  `;
}

function TrendBars({ points }: { points: { label: string; count: number }[] }) {
  const [hovered, setHovered] = useState<number | null>(null);

  const max = Math.max(1, ...points.map((p) => p.count));
  const innerWidth = WIDTH - PADDING_LEFT - PADDING_RIGHT;
  const bandWidth = innerWidth / points.length;
  const barWidth = Math.max(2, Math.min(28, bandWidth * 0.6));

  // Direct value labels above every bar when there's room (month view); for the
  // 30-bar day view that would collide, so those rely on the hover tooltip instead.
  const showDirectLabels = points.length <= 12;
  const labelStride = Math.max(1, Math.ceil(points.length / 8));

  return (
    <svg viewBox={`0 0 ${WIDTH} ${HEIGHT}`} role="img" aria-label="กราฟยอดจอง" className="w-full">
      <defs>
        <linearGradient id="trendBarFill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#EE2020" />
          <stop offset="100%" stopColor="#B31818" />
        </linearGradient>
      </defs>

      <line x1={PADDING_LEFT} y1={BASELINE_Y} x2={WIDTH - PADDING_RIGHT} y2={BASELINE_Y} stroke="#E5E7EB" strokeWidth={1} />

      {points.map((p, i) => {
        const bandCenter = PADDING_LEFT + bandWidth * i + bandWidth / 2;
        const x = bandCenter - barWidth / 2;
        const barHeight = (p.count / max) * (BASELINE_Y - TOP_Y);
        const y = BASELINE_Y - barHeight;
        const isHovered = hovered === i;

        return (
          <g
            key={i}
            onMouseEnter={() => setHovered(i)}
            onMouseLeave={() => setHovered(null)}
          >
            {(showDirectLabels || isHovered) && p.count > 0 && (
              <text x={bandCenter} y={y - 6} textAnchor="middle" fontSize={11} fontWeight={600} fill="#374151">
                {p.count}
              </text>
            )}
            <path
              d={roundedTopBarPath(x, y, barWidth, Math.max(barHeight, 1), 3)}
              fill="url(#trendBarFill)"
              opacity={isHovered ? 1 : 0.9}
              style={{ transition: 'opacity 120ms' }}
            >
              <title>
                {p.label}: {p.count} การจอง
              </title>
            </path>
            {i % labelStride === 0 && (
              <text x={bandCenter} y={HEIGHT - 4} textAnchor="middle" fontSize={10} fill="#6B7280">
                {p.label}
              </text>
            )}
          </g>
        );
      })}
    </svg>
  );
}
