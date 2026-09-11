<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { getAlbum, updateAlbum, photoUrl, type Album } from '$lib/api/client';
	import AuthImage from '$lib/components/AuthImage.svelte';
	import EmptyState from '$lib/components/EmptyState.svelte';
	import ErrorState from '$lib/components/ErrorState.svelte';
	import { showToast } from '$lib/toast';

	let album = $state<Album | null>(null);
	let loading = $state(true);
	let error = $state<string | null>(null);
	let editing = $state(false);
	let editName = $state('');

	onMount(async () => {
		await loadAlbum();
	});

	async function loadAlbum() {
		loading = true;
		error = null;
		const id = Number($page.params.id);
		try {
			album = await getAlbum(id);
			editName = album.name;
		} catch (e: any) {
			error = e?.message || 'Failed to load album';
			album = null;
		}
		loading = false;
	}

	async function handleUpdate(e: Event) {
		e.preventDefault();
		if (!album || !editName.trim()) return;
		try {
			await updateAlbum(album.id, editName.trim());
			album = { ...album, name: editName.trim() };
			editing = false;
		} catch (err: any) {
			showToast(err?.message || 'Update failed', 'danger');
		}
	}
</script>

<div class="max-w-7xl mx-auto px-4 py-6">
	{#if loading}
		<div class="text-center py-20 text-[var(--muted)]">Loading...</div>
	{:else if error}
		<ErrorState message={error} onretry={loadAlbum} />
	{:else if album}
		<div class="flex items-center gap-4 mb-6">
			{#if editing}
				<form onsubmit={handleUpdate} class="flex gap-2 flex-1">
					<input
						type="text"
						bind:value={editName}
						class="flex-1 px-3 py-1.5 bg-[var(--raised)] border border-[var(--hairline)] rounded-[6px] text-[var(--text)] focus:outline-none focus:border-[var(--accent)]"
					/>
					<button type="submit" class="px-3 py-1.5 bg-[var(--accent)] text-[var(--bg)] rounded-[6px] text-sm"
						>Save</button
					>
					<button
						type="button"
						onclick={() => (editing = false)}
						class="px-3 py-1.5 text-[var(--muted)] text-sm">Cancel</button
					>
				</form>
			{:else}
				<h1 class="text-xl font-semibold flex-1 text-[var(--text)]">{album.name}</h1>
				<button
					onclick={() => (editing = true)}
					class="px-3 py-1.5 text-[var(--muted)] hover:text-[var(--text)] text-sm rounded-[6px] hover:bg-[var(--raised)] transition-colors"
				>
					Edit
				</button>
			{/if}
		</div>

		{#if album.photos && album.photos.length > 0}
			<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-2">
				{#each album.photos as photo}
					<a
						href="/photos/{photo.id}"
						class="aspect-square bg-[var(--raised)] rounded-[6px] overflow-hidden border border-[var(--hairline)]"
					>
						<AuthImage
							src={photoUrl(photo.id, true)}
							alt={photo.filename}
							class="w-full h-full object-cover"
						/>
					</a>
				{/each}
			</div>
		{:else}
			<EmptyState message="No photos in this album" ctaLabel="Загрузить" href="/photos" />
		{/if}
	{:else}
		<div class="text-center py-20 text-[var(--muted)]">Album not found</div>
	{/if}
</div>
