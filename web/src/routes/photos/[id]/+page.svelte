<script lang="ts">
import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { getPhoto, toggleFavorite, deletePhoto, restorePhoto, photoUrl, type Photo } from '$lib/api/client';

	let photo = $state<Photo | null>(null);
	let loading = $state(true);

	onMount(async () => {
		const id = Number($page.params.id);
		try {
			photo = await getPhoto(id);
		} catch (e) {
			console.error('Failed to load photo:', e);
		}
		loading = false;
	});

	async function handleFavorite() {
		if (!photo) return;
		const result = await toggleFavorite(photo.id);
		photo = { ...photo, is_favorite: result.is_favorite };
	}

	async function handleDelete() {
		if (!photo) return;
		await deletePhoto(photo.id);
		history.back();
	}
</script>

<div class="min-h-screen bg-black flex items-center justify-center">
	{#if loading}
		<p class="text-white/60">Loading...</p>
	{:else if photo}
		<div class="relative max-w-full max-h-screen">
			<img src={photoUrl(photo.id)} alt={photo.filename} class="max-h-screen max-w-full object-contain" />
			<div class="absolute top-4 right-4 flex gap-2">
				<button
					onclick={handleFavorite}
					class="w-10 h-10 flex items-center justify-center rounded-full bg-black/60 hover:bg-black/80 text-lg transition-colors"
				>
					{photo.is_favorite ? '⭐' : '☆'}
				</button>
				<button
					onclick={handleDelete}
					class="w-10 h-10 flex items-center justify-center rounded-full bg-black/60 hover:bg-red-600/80 text-lg transition-colors"
				>
					🗑️
				</button>
				<a
					href={photoUrl(photo.id)}
					target="_blank"
					class="w-10 h-10 flex items-center justify-center rounded-full bg-black/60 hover:bg-black/80 text-sm transition-colors"
				>
					↗
				</a>
			</div>
		</div>
	{:else}
		<p class="text-white/60">Photo not found</p>
	{/if}
</div>
