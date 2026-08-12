<script lang="ts">
import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { getAlbum, updateAlbum, photoUrl, type Album, type Photo } from '$lib/api/client';

	let album = $state<Album | null>(null);
	let loading = $state(true);
	let editing = $state(false);
	let editName = $state('');

	onMount(async () => {
		const id = Number($page.params.id);
		try {
			album = await getAlbum(id);
			editName = album.name;
		} catch (e) {
			console.error('Failed to load album:', e);
		}
		loading = false;
	});

	async function handleUpdate() {
		if (!album || !editName.trim()) return;
		await updateAlbum(album.id, editName.trim());
		album = { ...album, name: editName.trim() };
		editing = false;
	}
</script>

<div class="max-w-7xl mx-auto px-4 py-6">
	{#if loading}
		<div class="text-center py-20 text-[var(--text-secondary)]">Loading...</div>
	{:else if album}
		<div class="flex items-center gap-4 mb-6">
			{#if editing}
				<form onsubmit={handleUpdate} class="flex gap-2 flex-1">
					<input
						type="text"
						bind:value={editName}
						class="flex-1 px-3 py-1.5 bg-[var(--bg-secondary)] border border-[var(--border)] rounded-lg text-[var(--text-primary)] focus:outline-none focus:border-[var(--accent)]"
					/>
					<button type="submit" class="px-3 py-1.5 bg-[var(--accent)] text-white rounded-lg text-sm">Save</button>
					<button type="button" onclick={() => editing = false} class="px-3 py-1.5 text-[var(--text-secondary)] text-sm">Cancel</button>
				</form>
			{:else}
				<h1 class="text-xl font-semibold flex-1">{album.name}</h1>
				<button
					onclick={() => editing = true}
					class="px-3 py-1.5 text-[var(--text-secondary)] hover:text-[var(--text-primary)] text-sm rounded-lg hover:bg-[var(--bg-tertiary)] transition-colors"
				>
					Edit
				</button>
			{/if}
		</div>

		{#if album.photos && album.photos.length > 0}
			<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-2">
				{#each album.photos as photo}
					<a href="/photos/{photo.id}" class="aspect-square bg-[var(--bg-secondary)] rounded-lg overflow-hidden">
						<img
							src={photoUrl(photo.id, true)}
							alt={photo.filename}
							loading="lazy"
							class="w-full h-full object-cover"
						/>
					</a>
				{/each}
			</div>
		{:else}
			<div class="text-center py-20 text-[var(--text-secondary)]">
				<p class="text-lg mb-2">No photos in this album</p>
				<p class="text-sm">Add photos from the Timeline</p>
			</div>
		{/if}
	{:else}
		<div class="text-center py-20 text-[var(--text-secondary)]">Album not found</div>
	{/if}
</div>
