<script lang="ts">
	import '../app.css';
	import { page } from '$app/stores';
	import { tokens, getMe, logout } from '$lib/api/client';
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { isPublicPath } from '$lib/utils/auth';
	import ToastHost from '$lib/components/ToastHost.svelte';
	import Icon from '$lib/components/Icon.svelte';

	let { children } = $props();
	let user: any = $state(null);
	let loading = $state(true);
	let menuOpen = $state(false);

	const isViewer = $derived(/^\/photos\/\d+/.test($page.url.pathname));

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

	/* Toggle viewer-mode on body: pure #000, no grain/wash */
	$effect(() => {
		if (typeof document === 'undefined') return;
		document.body.classList.toggle('viewer-mode', isViewer);
		return () => document.body.classList.remove('viewer-mode');
	});

	const navItems = [
		{ href: '/photos', label: 'Лента', icon: 'timeline' as const },
		{ href: '/albums', label: 'Альбомы', icon: 'albums' as const },
		{ href: '/favorites', label: 'Избранное', icon: 'heart' as const },
		{ href: '/trash', label: 'Корзина', icon: 'trash' as const }
	];

	async function handleLogout() {
		menuOpen = false;
		try {
			await logout();
		} catch {
			/* ignore */
		}
		user = null;
		window.location.href = '/auth/login';
	}

	function isActive(href: string) {
		const path = $page.url.pathname;
		if (href === '/photos') return path === '/photos' || path.startsWith('/photos/');
		return path.startsWith(href);
	}
</script>

{#if loading}
	<div class="flex items-center justify-center min-h-screen">
		<div class="w-10 h-10 rounded-[6px] border border-[var(--hairline)] skeleton-pulse" aria-hidden="true"></div>
	</div>
{:else if user && !isViewer}
	<!-- Transparent shell: body washes + grain show through; glass chrome overlays tiles -->
	<div class="app-shell">
		<header class="fixed top-0 inset-x-0 z-50 h-14 border-b border-[var(--hairline)] glass-chrome">
			<div class="px-3 sm:px-4 h-full flex items-center justify-between gap-3">
				<a
					href="/photos"
					class="font-display text-lg font-semibold text-[var(--text)] shrink-0"
					>Lumen</a
				>
				<nav class="hidden md:flex items-center gap-0.5">
					{#each navItems as item}
						<a
							href={item.href}
							class="nav-tab {isActive(item.href) ? 'active' : ''}"
						>
							{item.label}
						</a>
					{/each}
					<div class="relative ml-1">
						<button
							type="button"
							onclick={() => (menuOpen = !menuOpen)}
							class="w-10 h-10 flex items-center justify-center rounded-[6px] text-[var(--muted)] hover:text-[var(--text)] hover:bg-[var(--raised)]/60"
							aria-label="Ещё"
						>
							<Icon name="more" size={20} />
						</button>
						{#if menuOpen}
							<div
								class="absolute right-0 top-11 w-40 bg-[var(--raised)] border border-[var(--hairline)] rounded-[8px] overflow-hidden shadow-lg"
							>
								<button
									type="button"
									onclick={handleLogout}
									class="w-full flex items-center gap-2 px-3 py-2.5 text-sm text-[var(--muted)] hover:text-[var(--text)] hover:bg-[var(--raised-2)]"
								>
									<Icon name="logout" size={18} />
									Выйти
								</button>
							</div>
						{/if}
					</div>
				</nav>
				<button
					type="button"
					class="md:hidden w-10 h-10 flex items-center justify-center text-[var(--muted)] rounded-[6px]"
					onclick={handleLogout}
					aria-label="Выйти"
				>
					<Icon name="logout" size={20} />
				</button>
			</div>
		</header>

		<!-- Full-bleed content scrolls under fixed chrome; pt via sticky top offsets -->
		<main class="min-h-screen pb-14 md:pb-0">
			{@render children()}
		</main>

		<nav
			class="md:hidden fixed bottom-0 inset-x-0 z-50 border-t border-[var(--hairline)] glass-chrome"
			style="padding-bottom: env(safe-area-inset-bottom)"
		>
			<div class="grid grid-cols-4 h-14">
				{#each navItems as item}
					<a
						href={item.href}
						class="flex flex-col items-center justify-center gap-0.5 text-[10px] transition-colors duration-[160ms]
							{isActive(item.href) ? 'text-[var(--accent-ink)]' : 'text-[var(--muted)]'}"
					>
						<span
							class="flex items-center justify-center w-8 h-8 rounded-[6px]
								{isActive(item.href) ? 'bg-[var(--accent)] text-[var(--accent-ink)]' : ''}"
						>
							<Icon name={item.icon} size={20} />
						</span>
						<span class={isActive(item.href) ? 'text-[var(--accent)]' : ''}>{item.label}</span>
					</a>
				{/each}
			</div>
		</nav>
		<ToastHost />
	</div>
{:else if user && isViewer}
	<div class="min-h-screen bg-[var(--viewer-bg)]">
		{@render children()}
		<ToastHost />
	</div>
{:else}
	{@render children()}
	<ToastHost />
{/if}
