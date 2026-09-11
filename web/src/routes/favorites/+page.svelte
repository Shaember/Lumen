<script lang="ts">
	import { onMount } from 'svelte';
	import { listPhotos, toggleFavorite, photoUrl, type Photo } from '$lib/api/client';
	import AuthImage from '$lib/components/AuthImage.svelte';
	import EmptyState from '$lib/components/EmptyState.svelte';
	import ErrorState from '$lib/components/ErrorState.svelte';
	import { showToast } from '$lib/toast';

	let photos = $state<Photo[]>([]);
	let loading = $state(true);
	let error = $state<string | null>(null);

	onMount(async () => {
		await load();
	});

	async function load() {
		loading = true;
		error = null;
		try {
			const all = await listPhotos();
			photos = all.filter((p) => p.is_favorite);
		} catch (e: any) {
			error = e?.message || 'Failed to load favorites';
			photos = [];
		}
		loading = false;
	}

	async function handleUnfavorite(id: number) {
		try {
			await toggleFavorite(id);
			photos = photos.filter((p) => p.id !== id);
		} catch (err: any) {
			showToast(err?.message || 'Failed', 'danger');
		}
	}
</script>

<div class="max-w-7xl mx-auto px-4 py-6">
	<h1 class="text-xl font-semibold mb-6 text-[var(--text)]">Favorites</h1>

	{#if loading}
		<div class="text-center py-20 text-[var(--muted)]">Loading...</div>
	{:else if error}
		<ErrorState message={error} onretry={load} />
	{:else if photos.length === 0}
		<EmptyState message="No favorites yet" ctaLabel="Загрузить" href="/photos" />
	{:else}
		<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-2">
			{#each photos as photo}
				<div class="group relative aspect-square bg-[var(--raised)] rounded-[6px] overflow-hidden">
					<a href="/photos/{photo.id}" class="block w-full h-full">
						<AuthImage
							src={photoUrl(photo.id, true)}
							alt={photo.filename}
							class="w-full h-full object-cover"
						/>
					</a>
					<div class="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
						<button
							onclick={() => handleUnfavorite(photo.id)}
							class="w-8 h-8 flex items-center justify-center rounded-full bg-black/60 hover:bg-black/80 text-sm text-white"
							aria-label="Unfavorite"
						>
							★
						</button>
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>
