<script lang="ts">
import { onMount } from 'svelte';
	import { listPhotos, toggleFavorite, deletePhoto, photoUrl, type Photo } from '$lib/api/client';

	let photos = $state<Photo[]>([]);
	let loading = $state(true);

	onMount(async () => {
		try {
			const all = await listPhotos();
			photos = all.filter(p => p.is_favorite);
		} catch (e) {
			console.error('Failed to load favorites:', e);
		}
		loading = false;
	});

	async function handleUnfavorite(id: number) {
		await toggleFavorite(id);
		photos = photos.filter(p => p.id !== id);
	}
</script>

<div class="max-w-7xl mx-auto px-4 py-6">
	<h1 class="text-xl font-semibold mb-6">Favorites</h1>

	{#if loading}
		<div class="text-center py-20 text-[var(--text-secondary)]">Loading...</div>
	{:else if photos.length === 0}
		<div class="text-center py-20 text-[var(--text-secondary)]">
			<p class="text-lg mb-2">No favorites yet</p>
			<p class="text-sm">Star photos in Timeline to add them here</p>
		</div>
	{:else}
		<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-2">
			{#each photos as photo}
				<div class="group relative aspect-square bg-[var(--bg-secondary)] rounded-lg overflow-hidden">
					<a href="/photos/{photo.id}">
						<img
							src={photoUrl(photo.id, true)}
							alt={photo.filename}
							loading="lazy"
							class="w-full h-full object-cover"
						/>
					</a>
					<div class="absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity">
						<button
							onclick={() => handleUnfavorite(photo.id)}
							class="w-8 h-8 flex items-center justify-center rounded-full bg-black/60 hover:bg-black/80 text-sm"
						>
							⭐
						</button>
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>
