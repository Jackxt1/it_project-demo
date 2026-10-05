const baht = new Intl.NumberFormat('th-TH');

/** e.g. 12900 → "12,900 บาท" */
export function formatBaht(value: number): string {
  return `${baht.format(value)} บาท`;
}

/** "09:00-10:00" and "09:00" both render as "09:00 น." */
export function formatTimeSlot(timeSlot: string): string {
  return `${timeSlot.split('-')[0].trim()} น.`;
}

/** Hour of the day a slot starts, for splitting a day into morning and afternoon. */
export function slotStartHour(timeSlot: string): number {
  return Number(timeSlot.split('-')[0].trim().split(':')[0]) || 0;
}
