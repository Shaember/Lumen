<script lang="ts">
import { onMount } from 'svelte';
	import { listAlbums, createAlbum, deleteAlbum, type Album } from '$lib/api/client';

	let albums = $state<Album[]>([]);
	let loading = $state(true);
	let showNew = $state(false);
	let newName = $state('');

	onMount(async () => {
		await loadAlbums();
	});

	async function loadAlbums() {
		loading = true;
		try {
			albums = await listAlbums();
		} catch (e) {
			console.error('Failed to load albums:', e);
		}
		loading = false;
	}

	async function handleCreate() {
		if (!newName.trim()) return;
		try {
			await createAlbum(newName.trim());
			newName = '';
			showNew = false;
			await loadAlbums();
		} catch (e) {
			console.error('Failed to create album:', e);
		}
	}

	async function handleDelete(id: number) {
		if (!confirm('Delete this album?')) return;
		await deleteAlbum(id);
		albums = albums.filter(a => a.id !== id);
	}
</script>

<div class="max-w-7xl mx-auto px-4 py-6">
	<div class="flex items-center justify-between mb-6">
		<h1 class="text-xl font-semibold">Albums</h1>
		<button
			onclick={() => showNew = !showNew}
			class="px-4 py-2 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-white rounded-lg text-sm transition-colors"
		>
			+ New Album
		</button>
	</div>

	{#if showNew}
		<form onsubmit={handleCreate} class="mb-6 flex gap-2">
			<input
				type="text"
				bind:value={newName}
				placeholder="Album name"
				class="flex-1 px-3 py-2 bg-[var(--bg-secondary)] border border-[var(--border)] rounded-lg text-[var(--text-primary)] focus:outline-none focus:border-[var(--accent)]"
			/>
			<button
				type="submit"
				class="px-4 py-2 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-white rounded-lg text-sm transition-colors"
			>
				Create
			</button>
		</form>
	{/if}

	{#if loading}
		<div class="text-center py-20 text-[var(--text-secondary)]">Loading albums...</div>
	{:else if albums.length === 0}
		<div class="text-center py-20 text-[var(--text-secondary)]">
			<p class="text-lg mb-2">No albums yet</p>
			<p class="text-sm">Create an album to organize your photos</p>
		</div>
	{:else}
		<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
			{#each albums as album}
				<a href="/albums/{album.id}" class="block group">
					<div class="aspect-square bg-[var(--bg-secondary)] rounded-xl overflow-hidden relative">
						{#if album.cover_photo_id}
							<img
								src="/api/v1/photos/{album.cover_photo_id}/thumbnail"
								alt={album.name}
								class="w-full h-full object-cover"
							/>
						{:else}
							<div class="w-full h-full flex items-center justify-center text-3xl text-[var(--text-secondary)]">
								📁
							</div>
						{/if}
						<div class="absolute inset-0 bg-black/0 group-hover:bg-black/30 transition-colors"></div>
					</div>
					<div class="mt-2 flex items-center justify-between">
						<div>
							<p class="font-medium text-sm">{album.name}</p>
							<p class="text-xs text-[var(--text-secondary)]">{album.photo_count} photos</p>
						</div>
						<button
							onclick={(e) => { e.stopPropagation(); handleDelete(album.id); }}
							class="w-7 h-7 flex items-center justify-center rounded-full hover:bg-[var(--bg-tertiary)] text-[var(--text-secondary)] hover:text-red-400 text-xs transition-colors opacity-0 group-hover:opacity-100"
						>
							×
						</button>
					</div>
				</a>
			{/each}
		</div>
	{/if}
</div>
