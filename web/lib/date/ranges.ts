export type RangePreset = "7d" | "30d" | "90d" | "custom";

export type DateRange = {
  preset: RangePreset;
  from: string;
  to: string;
};

export function toDateInputValue(date: Date) {
  return date.toISOString().slice(0, 10);
}

export function startOfDay(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

export function endOfDay(date: Date) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate(), 23, 59, 59, 999);
}

export function defaultRange(days = 30): DateRange {
  const to = startOfDay(new Date());
  const from = new Date(to);
  from.setDate(from.getDate() - (days - 1));

  return {
    preset: days === 7 ? "7d" : days === 90 ? "90d" : "30d",
    from: toDateInputValue(from),
    to: toDateInputValue(to)
  };
}

export function rangeToBounds(range: DateRange) {
  const from = startOfDay(new Date(`${range.from}T00:00:00`));
  const to = endOfDay(new Date(`${range.to}T00:00:00`));

  return {
    from,
    to,
    fromIso: from.toISOString(),
    toIso: to.toISOString()
  };
}

export function previousRange(range: DateRange) {
  const { from, to } = rangeToBounds(range);
  const days = Math.max(1, Math.round((to.getTime() - from.getTime()) / 86_400_000));
  const previousTo = new Date(from);
  previousTo.setDate(previousTo.getDate() - 1);
  const previousFrom = new Date(previousTo);
  previousFrom.setDate(previousFrom.getDate() - days);

  return {
    fromIso: startOfDay(previousFrom).toISOString(),
    toIso: endOfDay(previousTo).toISOString()
  };
}

export function eachDay(range: DateRange) {
  const { from, to } = rangeToBounds(range);
  const days: string[] = [];
  const cursor = startOfDay(from);

  while (cursor <= to) {
    days.push(toDateInputValue(cursor));
    cursor.setDate(cursor.getDate() + 1);
  }

  return days;
}

export function formatShortDate(value: string) {
  return new Intl.DateTimeFormat("es", { day: "2-digit", month: "short" }).format(new Date(value));
}

export function percentChange(current: number, previous: number) {
  if (previous === 0) return current === 0 ? 0 : 100;
  return Math.round(((current - previous) / previous) * 100);
}
