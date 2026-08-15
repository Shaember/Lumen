<script lang="ts">
	import '../app.css';
	import { page } from '$app/stores';
	import { tokens, getMe, logout } from '$lib/api/client';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';

	let { children } = $props();
	let user: any = $state(null);
	let loading = $state(true);

	onMount(async () => {
		tokens.load();
		if (tokens.getAccessToken()) {
			try {
				user = await getMe();
			} catch {
				tokens.clear();
			}
		}
		loading = false;
		
		// Redirect to login if not authenticated and not already on login page
		if (!user && !$page.url.pathname.startsWith('/auth')) {
			goto('/auth/login');
		}
	});

	const navItems = [
		{ href: '/photos', label: 'Timeline', icon: '📷' },
		{ href: '/albums', label: 'Albums', icon: '📁' },
		{ href: '/favorites', label: 'Favorites', icon: '⭐' },
		{ href: '/trash', label: 'Trash', icon: '🗑️' }
	];

	async function handleLogout() {
		await logout();
		user = null;
		window.location.href = '/auth/login';
	}
</script>

{#if loading}
	<div class="flex items-center justify-center min-h-screen bg-[var(--bg-primary)]">
		<div class="flex flex-col items-center gap-4">
			<div class="w-12 h-12 border-2 border-[var(--accent)] border-t-transparent rounded-full animate-spin"></div>
			<div class="text-[var(--text-secondary)]">Loading...</div>
		</div>
	</div>
{:else if user}
	<div class="min-h-screen flex flex-col bg-[var(--bg-primary)]">
		<header class="sticky top-0 z-50 bg-[var(--bg-primary)]/80 backdrop-blur-xl border-b border-[var(--border)]">
			<div class="max-w-7xl mx-auto px-4 h-14 flex items-center justify-between">
				<a href="/photos" class="text-lg font-semibold tracking-tight text-[var(--text-primary)]">Lumen</a>
				<nav class="flex items-center gap-1">
					{#each navItems as item}
						<a
							href={item.href}
							class="px-3 py-1.5 rounded-lg text-sm transition-colors
								{$page.url.pathname.startsWith(item.href) ? 'bg-[var(--accent)] text-white' : 'text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--bg-tertiary)]'}"
						>
							<span class="mr-1">{item.icon}</span>
							{item.label}
						</a>
					{/each}
					<button
						onclick={handleLogout}
						class="ml-4 px-3 py-1.5 rounded-lg text-sm text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--bg-tertiary)] transition-colors"
					>
						Logout
					</button>
				</nav>
			</div>
		</header>
		<main class="flex-1">
			{@render children()}
		</main>
	</div>
{:else}
	<!-- Redirecting to login... -->
	<div class="flex items-center justify-center min-h-screen bg-[var(--bg-primary)]">
		<div class="w-12 h-12 border-2 border-[var(--accent)] border-t-transparent rounded-full animate-spin"></div>
	</div>
{/if}
