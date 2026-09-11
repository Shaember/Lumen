<script lang="ts">
	import '../app.css';
	import { page } from '$app/stores';
	import { tokens, getMe, logout } from '$lib/api/client';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { isPublicPath } from '$lib/utils/auth';
	import ToastHost from '$lib/components/ToastHost.svelte';

	let { children } = $props();
	let user: any = $state(null);
	let loading = $state(true);

	onMount(async () => {
		tokens.load();
		const path = $page.url.pathname;

		if (tokens.getAccessToken()) {
			try {
				user = await getMe();
			} catch {
				tokens.clear();
				user = null;
			}
		}

		loading = false;

		if (!user && !isPublicPath(path)) {
			goto('/auth/login');
			return;
		}
		if (user && isPublicPath(path)) {
			goto('/photos');
		}
	});

	$effect(() => {
		const path = $page.url.pathname;
		if (loading) return;
		if (!user && !isPublicPath(path)) {
			goto('/auth/login');
		}
	});

	const navItems = [
		{ href: '/photos', label: 'Timeline' },
		{ href: '/albums', label: 'Albums' },
		{ href: '/favorites', label: 'Favorites' },
		{ href: '/trash', label: 'Trash' }
	];

	async function handleLogout() {
		try {
			await logout();
		} catch {
			/* ignore */
		}
		user = null;
		window.location.href = '/auth/login';
	}
</script>

{#if loading}
	<div class="flex items-center justify-center min-h-screen bg-[var(--bg)]">
		<div class="flex flex-col items-center gap-4">
			<div class="w-12 h-12 border-2 border-[var(--accent)] border-t-transparent rounded-full animate-spin"></div>
			<div class="text-[var(--muted)]">Loading...</div>
		</div>
	</div>
{:else if user}
	<div class="min-h-screen flex flex-col bg-[var(--bg)]">
		<header class="sticky top-0 z-50 border-b border-[var(--hairline)]" style="background: var(--glass); backdrop-filter: blur(24px) saturate(1.8);">
			<div class="max-w-7xl mx-auto px-4 h-14 flex items-center justify-between">
				<a href="/photos" class="text-lg font-semibold tracking-tight text-[var(--text)]">Lumen</a>
				<nav class="flex items-center gap-1">
					{#each navItems as item}
						<a
							href={item.href}
							class="px-3 py-1.5 rounded-[6px] text-sm transition-colors
								{$page.url.pathname.startsWith(item.href)
									? 'bg-[var(--accent)] text-[var(--bg)]'
									: 'text-[var(--muted)] hover:text-[var(--text)] hover:bg-[var(--raised)]'}"
						>
							{item.label}
						</a>
					{/each}
					<button
						onclick={handleLogout}
						class="ml-4 px-3 py-1.5 rounded-[6px] text-sm text-[var(--muted)] hover:text-[var(--text)] hover:bg-[var(--raised)] transition-colors"
					>
						Logout
					</button>
				</nav>
			</div>
		</header>
		<main class="flex-1">
			{@render children()}
		</main>
		<ToastHost />
	</div>
{:else}
	{@render children()}
	<ToastHost />
{/if}
