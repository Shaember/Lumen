<script lang="ts">
	import { onMount } from 'svelte';
	import { listAlbums, createAlbum, deleteAlbum, photoUrl, type Album } from '$lib/api/client';
	import AuthImage from '$lib/components/AuthImage.svelte';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';
	import EmptyState from '$lib/components/EmptyState.svelte';
	import ErrorState from '$lib/components/ErrorState.svelte';
	import { showToast } from '$lib/toast';

	let albums = $state<Album[]>([]);
	let loading = $state(true);
	let error = $state<string | null>(null);
	let showNew = $state(false);
	let newName = $state('');
	let confirmId = $state<number | null>(null);

	onMount(async () => {
		await loadAlbums();
	});

	async function loadAlbums() {
		loading = true;
		error = null;
		try {
			albums = await listAlbums();
		} catch (e: any) {
			error = e?.message || 'Failed to load albums';
			albums = [];
		}
		loading = false;
	}

	async function handleCreate(e: Event) {
		e.preventDefault();
		if (!newName.trim()) return;
		try {
			await createAlbum(newName.trim());
			newName = '';
			showNew = false;
			await loadAlbums();
		} catch (err: any) {
			showToast(err?.message || 'Failed to create album', 'danger');
		}
	}

	async function confirmDelete() {
		if (confirmId == null) return;
		const id = confirmId;
		confirmId = null;
		try {
			await deleteAlbum(id);
			albums = albums.filter((a) => a.id !== id);
		} catch (err: any) {
			showToast(err?.message || 'Delete failed', 'danger');
		}
	}
</script>

<div class="max-w-7xl mx-auto px-4 py-6">
	<div class="flex items-center justify-between mb-6">
		<h1 class="text-xl font-semibold text-[var(--text)]">Albums</h1>
		<button
			onclick={() => (showNew = !showNew)}
			class="px-4 py-2 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-[var(--bg)] rounded-[6px] text-sm transition-colors"
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
				class="flex-1 px-3 py-2 bg-[var(--raised)] border border-[var(--hairline)] rounded-[6px] text-[var(--text)] focus:outline-none focus:border-[var(--accent)]"
			/>
			<button
				type="submit"
				class="px-4 py-2 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-[var(--bg)] rounded-[6px] text-sm transition-colors"
			>
				Create
			</button>
		</form>
	{/if}

	{#if loading}
		<div class="text-center py-20 text-[var(--muted)]">Loading albums...</div>
	{:else if error}
		<ErrorState message={error} onretry={loadAlbums} />
	{:else if albums.length === 0}
		<EmptyState
			message="No albums yet"
			ctaLabel="Создать альбом"
			oncta={() => (showNew = true)}
		/>
	{:else}
		<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
			{#each albums as album}
				<div class="block group relative">
					<a href="/albums/{album.id}" class="block">
						<div class="aspect-square bg-[var(--raised)] rounded-[8px] overflow-hidden relative border border-[var(--hairline)]">
							{#if album.cover_photo_id}
								<AuthImage
									src={photoUrl(album.cover_photo_id, true)}
									alt={album.name}
									class="w-full h-full object-cover"
								/>
							{:else}
								<div class="w-full h-full flex items-center justify-center text-sm text-[var(--muted)]">
									Empty
								</div>
							{/if}
						</div>
						<div class="mt-2">
							<p class="font-medium text-sm text-[var(--text)]">{album.name}</p>
							<p class="text-xs text-[var(--muted)]">{album.photo_count} photos</p>
						</div>
					</a>
					<button
						onclick={(e) => {
							e.preventDefault();
							e.stopPropagation();
							confirmId = album.id;
						}}
						class="absolute top-2 right-2 w-7 h-7 flex items-center justify-center rounded-full bg-black/50 text-[var(--text)] text-xs opacity-0 group-hover:opacity-100 transition-opacity"
						aria-label="Delete album"
					>
						×
					</button>
				</div>
			{/each}
		</div>
	{/if}
</div>

<ConfirmDialog
	open={confirmId != null}
	title="Delete album?"
	message="This will permanently delete the album. Photos inside are not deleted."
	confirmLabel="Delete"
	onconfirm={confirmDelete}
	oncancel={() => (confirmId = null)}
/>
