const API_BASE = '/api/v1';

class TokenManager {
	private access: string | null = null;
	private refresh: string | null = null;

	setTokens(access: string, refresh: string) {
		this.access = access;
		this.refresh = refresh;
		if (typeof localStorage !== 'undefined') {
			localStorage.setItem('lumen_access', access);
			localStorage.setItem('lumen_refresh', refresh);
		}
	}

	load() {
		if (typeof localStorage !== 'undefined') {
			this.access = localStorage.getItem('lumen_access');
			this.refresh = localStorage.getItem('lumen_refresh');
		}
	}

	clear() {
		this.access = null;
		this.refresh = null;
		if (typeof localStorage !== 'undefined') {
			localStorage.removeItem('lumen_access');
			localStorage.removeItem('lumen_refresh');
		}
	}

	getAccessToken() { return this.access; }
	getRefreshToken() { return this.refresh; }
}

export const tokens = new TokenManager();

async function request(path: string, opts: RequestInit = {}): Promise<any> {
	const headers: Record<string, string> = {
		...(opts.headers as Record<string, string>)
	};

	if (tokens.getAccessToken()) {
		headers['Authorization'] = `Bearer ${tokens.getAccessToken()}`;
	}

	const res = await fetch(`${API_BASE}${path}`, { ...opts, headers });
	const json = await res.json();

	if (res.status === 401 && tokens.getRefreshToken()) {
		const refreshed = await refreshTokens();
		if (refreshed) {
			headers['Authorization'] = `Bearer ${tokens.getAccessToken()}`;
			const retry = await fetch(`${API_BASE}${path}`, { ...opts, headers });
			return retry.json();
		}
		tokens.clear();
		window.location.href = '/auth/login';
		return;
	}

	if (!res.ok) {
		throw new Error(json.error || `HTTP ${res.status}`);
	}
	return json.data;
}

async function refreshTokens(): Promise<boolean> {
	try {
		const res = await fetch(`${API_BASE}/auth/refresh`, {
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

// Auth API
export async function setup(username: string, password: string) {
	return request('/auth/setup', {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ username, password })
	});
}

export async function login(username: string, password: string) {
	const data = await request('/auth/login', {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ username, password })
	});
	tokens.setTokens(data.access_token, data.refresh_token);
	return data.user;
}

export async function logout() {
	const refresh = tokens.getRefreshToken();
	tokens.clear();
	return request('/auth/logout', {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ refresh_token: refresh })
	});
}

export async function getMe() {
	return request('/auth/me');
}

// Photo API
export interface Photo {
	id: number;
	filename: string;
	mime_type: string;
	file_size: number;
	taken_at?: string;
	is_favorite: boolean;
	thumbnail_path?: string;
	width?: number;
	height?: number;
	created_at: string;
}

export async function listPhotos(month?: string, offset = 0, limit = 50): Promise<Photo[]> {
	let url = `/photos?offset=${offset}&limit=${limit}`;
	if (month) url += `&month=${month}`;
	return request(url);
}

/** Page through the existing max-200 API without changing its contract. */
export async function listAllPhotos(max = 5000): Promise<Photo[]> {
	const pageSize = 200;
	const all: Photo[] = [];
	while (all.length < max) {
		const batch = await listPhotos(undefined, all.length, Math.min(pageSize, max - all.length));
		all.push(...batch);
		if (batch.length < pageSize) break;
	}
	return all;
}

export async function getPhoto(id: number): Promise<Photo> {
	return request(`/photos/${id}`);
}

export async function uploadPhoto(file: File, takenAt?: string, deviceId?: number) {
	const form = new FormData();
	form.append('file', file);
	if (takenAt) form.append('taken_at', takenAt);
	if (deviceId) form.append('device_id', String(deviceId));

	return request('/photos/upload', { method: 'POST', body: form });
}

export async function toggleFavorite(id: number): Promise<{ is_favorite: boolean }> {
	return request(`/photos/${id}/favorite`, { method: 'PATCH' });
}

export async function deletePhoto(id: number) {
	return request(`/photos/${id}`, { method: 'DELETE' });
}

export async function restorePhoto(id: number) {
	return request(`/photos/${id}/restore`, { method: 'POST' });
}

export async function listTrash(): Promise<Photo[]> {
	return request('/photos/trash');
}

export function photoUrl(id: number, thumb = false) {
	return `${API_BASE}/photos/${id}/${thumb ? 'thumbnail' : 'original'}`;
}

// Album API
export interface Album {
	id: number;
	name: string;
	cover_photo_id?: number;
	created_at: string;
	updated_at: string;
	photo_count: number;
	photos?: Photo[];
}

export async function listAlbums(): Promise<Album[]> {
	return request('/albums');
}

export async function createAlbum(name: string): Promise<Album> {
	return request('/albums', {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ name })
	});
}

export async function getAlbum(id: number): Promise<Album> {
	return request(`/albums/${id}`);
}

export async function updateAlbum(id: number, name: string) {
	return request(`/albums/${id}`, {
		method: 'PATCH',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ name })
	});
}

export async function deleteAlbum(id: number) {
	return request(`/albums/${id}`, { method: 'DELETE' });
}

export async function addPhotosToAlbum(id: number, photoIds: number[]) {
	return request(`/albums/${id}/photos`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ photo_ids: photoIds })
	});
}

export async function removePhotoFromAlbum(albumId: number, photoId: number) {
	return request(`/albums/${albumId}/photos/${photoId}`, { method: 'DELETE' });
}
