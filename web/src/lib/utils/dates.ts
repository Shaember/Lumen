export interface DatedItem {
	id: number;
	taken_at?: string;
	created_at?: string;
}

export type TimelineSection =
	| { kind: 'year'; key: string; label: string }
	| { kind: 'month'; key: string; label: string }
	| { kind: 'day'; key: string; label: string; items: DatedItem[] };

function itemDate(item: DatedItem): Date | null {
	const raw = item.taken_at || item.created_at;
	if (!raw) return null;
	const d = new Date(raw);
	return Number.isNaN(d.getTime()) ? null : d;
}

const monthFmt = new Intl.DateTimeFormat('ru-RU', { month: 'long', year: 'numeric' });
const dayFmt = new Intl.DateTimeFormat('ru-RU', { day: 'numeric', month: 'long' });

/** Build sticky hierarchy: Year → Month Year → day captions with items. */
export function buildTimelineSections<T extends DatedItem>(items: T[]): {
	sections: Array<
		| { kind: 'year'; key: string; label: string }
		| { kind: 'month'; key: string; label: string }
		| { kind: 'day'; key: string; label: string; items: T[] }
	>;
} {
	const sorted = [...items].sort((a, b) => {
		const da = itemDate(a)?.getTime() ?? 0;
		const db = itemDate(b)?.getTime() ?? 0;
		return db - da;
	});

	const sections: Array<
		| { kind: 'year'; key: string; label: string }
		| { kind: 'month'; key: string; label: string }
		| { kind: 'day'; key: string; label: string; items: T[] }
	> = [];

	let lastYear = '';
	let lastMonth = '';
	let currentDayKey = '';
	let currentDayItems: T[] = [];
	let currentDayLabel = '';

	function flushDay() {
		if (currentDayKey) {
			sections.push({
				kind: 'day',
				key: currentDayKey,
				label: currentDayLabel,
				items: currentDayItems
			});
			currentDayItems = [];
			currentDayKey = '';
		}
	}

	for (const item of sorted) {
		const d = itemDate(item);
		const year = d ? String(d.getFullYear()) : 'unknown';
		const month = d ? `${year}-${String(d.getMonth() + 1).padStart(2, '0')}` : 'unknown';
		const day = d
			? `${month}-${String(d.getDate()).padStart(2, '0')}`
			: 'unknown';

		if (year !== lastYear) {
			flushDay();
			lastYear = year;
			lastMonth = '';
			sections.push({
				kind: 'year',
				key: `y-${year}`,
				label: year === 'unknown' ? 'Без даты' : year
			});
		}
		if (month !== lastMonth) {
			flushDay();
			lastMonth = month;
			sections.push({
				kind: 'month',
				key: `m-${month}`,
				label: d ? capitalize(monthFmt.format(d)) : 'Без даты'
			});
		}
		if (day !== currentDayKey) {
			flushDay();
			currentDayKey = day;
			currentDayLabel = d ? dayFmt.format(d) : 'Без даты';
		}
		currentDayItems.push(item);
	}
	flushDay();

	return { sections };
}

function capitalize(s: string) {
	return s.charAt(0).toUpperCase() + s.slice(1);
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
	if (dateKey === 'unknown') return 'Без даты';
	const d = new Date(dateKey + 'T00:00:00');
	if (Number.isNaN(d.getTime())) return dateKey;
	return dayFmt.format(d);
}
