import { describe, it, expect } from 'vitest';
import { bearerHeaders, withAuth, isAuthenticated, isPublicPath } from './auth';
import { groupByDate, formatDayLabel } from './dates';

describe('bearerHeaders', () => {
	it('returns empty object when no token', () => {
		expect(bearerHeaders(null)).toEqual({});
		expect(bearerHeaders(undefined)).toEqual({});
		expect(bearerHeaders('')).toEqual({});
	});

	it('returns Bearer Authorization when token present', () => {
		expect(bearerHeaders('abc')).toEqual({ Authorization: 'Bearer abc' });
	});
});

describe('withAuth', () => {
	it('merges Authorization into existing headers', () => {
		expect(withAuth('tok', { Accept: 'image/*' })).toEqual({
			Accept: 'image/*',
			Authorization: 'Bearer tok'
		});
	});
});

describe('isAuthenticated', () => {
	it('detects non-empty tokens', () => {
		expect(isAuthenticated('x')).toBe(true);
		expect(isAuthenticated('')).toBe(false);
		expect(isAuthenticated(null)).toBe(false);
	});
});

describe('isPublicPath', () => {
	it('allows auth routes', () => {
		expect(isPublicPath('/auth/login')).toBe(true);
		expect(isPublicPath('/photos')).toBe(false);
	});
});

describe('groupByDate', () => {
	it('groups and sorts newest first', () => {
		const groups = groupByDate([
			{ id: 1, taken_at: '2024-01-02T10:00:00Z' },
			{ id: 2, taken_at: '2024-01-01T10:00:00Z' },
			{ id: 3, created_at: '2024-01-02T12:00:00Z' }
		]);
		expect(groups.map((g) => g.date)).toEqual(['2024-01-02', '2024-01-01']);
		expect(groups[0].items.map((i) => i.id)).toEqual([1, 3]);
	});
});

describe('formatDayLabel', () => {
	it('handles unknown', () => {
		expect(formatDayLabel('unknown')).toBe('Без даты');
	});
});
