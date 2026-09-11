export interface DatedItem {
	id: number;
	taken_at?: string;
	created_at?: string;
}

/** Group items by calendar day (YYYY-MM-DD) using taken_at, falling back to created_at. */
export function groupByDate<T extends DatedItem>(items: T[]): { date: string; items: T[] }[] {
	const map = new Map<string, T[]>();
	for (const item of items) {
		const raw = item.taken_at || item.created_at || '';
		const key = raw ? raw.slice(0, 10) : 'unknown';
		const list = map.get(key);
		if (list) list.push(item);
		else map.set(key, [item]);
	}
	return Array.from(map.entries())
		.sort(([a], [b]) => (a < b ? 1 : a > b ? -1 : 0))
		.map(([date, grouped]) => ({ date, items: grouped }));
}

export function formatDayLabel(dateKey: string): string {
	if (dateKey === 'unknown') return 'Unknown date';
	const d = new Date(dateKey + 'T00:00:00');
	if (Number.isNaN(d.getTime())) return dateKey;
	return d.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' });
}
