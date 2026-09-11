/** Build Authorization headers from a raw access token (pure helper). */
export function bearerHeaders(accessToken: string | null | undefined): Record<string, string> {
	if (!accessToken) return {};
	return { Authorization: `Bearer ${accessToken}` };
}

/** Merge Authorization into existing headers without inventing new auth APIs. */
export function withAuth(
	accessToken: string | null | undefined,
	headers: Record<string, string> = {}
): Record<string, string> {
	return { ...headers, ...bearerHeaders(accessToken) };
}

export function isAuthenticated(accessToken: string | null | undefined): boolean {
	return typeof accessToken === 'string' && accessToken.length > 0;
}

/** Paths that do not require a session. */
export function isPublicPath(pathname: string): boolean {
	return pathname === '/auth/login' || pathname.startsWith('/auth/');
}
