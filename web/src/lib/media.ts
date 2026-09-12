import { tokens } from '$lib/api/client';
import { withAuth } from '$lib/utils/auth';

const cache = new Map<string, string>();

/** Fetch protected media with Bearer JWT and return an object URL. */
export async function fetchMediaObjectUrl(apiPath: string): Promise<string> {
	const cached = cache.get(apiPath);
	if (cached) return cached;

	tokens.load();
	const res = await fetch(apiPath, {
		headers: withAuth(tokens.getAccessToken())
	});

	if (res.status === 401 && tokens.getRefreshToken()) {
		const refreshed = await tryRefresh();
		if (refreshed) {
			const retry = await fetch(apiPath, {
				headers: withAuth(tokens.getAccessToken())
			});
			if (!retry.ok) throw new Error(`media ${retry.status}`);
			return storeBlob(apiPath, await retry.blob());
		}
		tokens.clear();
		throw new Error('media 401');
	}

	if (!res.ok) throw new Error(`media ${res.status}`);
	return storeBlob(apiPath, await res.blob());
}

function storeBlob(apiPath: string, blob: Blob): string {
	const url = URL.createObjectURL(blob);
	const prev = cache.get(apiPath);
	if (prev) URL.revokeObjectURL(prev);
	cache.set(apiPath, url);
	return url;
}

async function tryRefresh(): Promise<boolean> {
	try {
		const res = await fetch('/api/v1/auth/refresh', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ refresh_token: tokens.getRefreshToken() })
		});
		if (!res.ok) return false;
		const data = await res.json();
		tokens.setTokens(data.data.access_token, data.data.refresh_token);
		return true;
	} catch {
		return false;
	}
}

/** Download a protected media URL as a named file. */
export async function downloadMedia(apiPath: string, filename: string): Promise<void> {
	const objectUrl = await fetchMediaObjectUrl(apiPath);
	const a = document.createElement('a');
	a.href = objectUrl;
	a.download = filename;
	document.body.appendChild(a);
	a.click();
	a.remove();
}

export function invalidateMediaCache(apiPath?: string) {
	if (apiPath) {
		const prev = cache.get(apiPath);
		if (prev) URL.revokeObjectURL(prev);
		cache.delete(apiPath);
		return;
	}
	for (const url of cache.values()) URL.revokeObjectURL(url);
	cache.clear();
}
