<script lang="ts">
import { onMount } from 'svelte';
	import { listPhotos, toggleFavorite, deletePhoto, uploadPhoto, photoUrl, type Photo } from '$lib/api/client';

	let photos = $state<Photo[]>([]);
	let loading = $state(true);
	let uploading = $state(false);
	let selectedPhotos = $state<Set<number>>(new Set());
	let showUpload = $state(false);

	onMount(async () => {
		await loadPhotos();
	});

	async function loadPhotos() {
		loading = true;
		try {
			photos = await listPhotos();
		} catch (e) {
			console.error('Failed to load photos:', e);
		}
		loading = false;
	}

	async function handleUpload(e: Event) {
		const input = e.target as HTMLInputElement;
		if (!input.files?.length) return;
		uploading = true;
		try {
			for (const file of Array.from(input.files)) {
				await uploadPhoto(file);
			}
			await loadPhotos();
		} catch (err) {
			console.error('Upload failed:', err);
		}
		uploading = false;
		showUpload = false;
		input.value = '';
	}

	async function handleFavorite(id: number) {
		await toggleFavorite(id);
		photos = photos.map(p => p.id === id ? { ...p, is_favorite: !p.is_favorite } : p);
	}

	async function handleDelete(id: number) {
		await deletePhoto(id);
		photos = photos.filter(p => p.id !== id);
	}

	function formatDate(d?: string): string {
		if (!d) return '';
		return new Date(d).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
	}

	function formatSize(bytes: number): string {
		if (bytes < 1024) return `${bytes} B`;
		if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
		return `${(bytes / 1048576).toFixed(1)} MB`;
	}
</script>

<div class="max-w-7xl mx-auto px-4 py-6">
	<div class="flex items-center justify-between mb-6">
		<h1 class="text-xl font-semibold">Timeline</h1>
		<button
			onclick={() => showUpload = !showUpload}
			class="px-4 py-2 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-white rounded-lg text-sm transition-colors"
		>
			{uploading ? 'Uploading...' : '+ Upload'}
		</button>
	</div>

	{#if showUpload}
		<div class="mb-6 p-4 bg-[var(--bg-secondary)] rounded-xl border border-[var(--border)]">
			<input
				type="file"
				accept="image/*"
				multiple
				onchange={handleUpload}
				class="block w-full text-sm text-[var(--text-secondary)]
					file:mr-4 file:py-2 file:px-4
					file:rounded-lg file:border-0
					file:text-sm file:font-semibold
					file:bg-[var(--accent)] file:text-white
					hover:file:bg-[var(--accent-hover)]
					file:cursor-pointer file:transition-colors"
			/>
		</div>
	{/if}

	{#if loading}
		<div class="text-center py-20 text-[var(--text-secondary)]">Loading photos...</div>
	{:else if photos.length === 0}
		<div class="text-center py-20 text-[var(--text-secondary)]">
			<p class="text-lg mb-2">No photos yet</p>
			<p class="text-sm">Upload photos to get started</p>
		</div>
	{:else}
		<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-2">
			{#each photos as photo}
				<div class="group relative aspect-square bg-[var(--bg-secondary)] rounded-lg overflow-hidden cursor-pointer">
					<img
						src={photoUrl(photo.id, true)}
						alt={photo.filename}
						loading="lazy"
						class="w-full h-full object-cover"
					/>
					<div class="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-colors flex items-end p-2 opacity-0 group-hover:opacity-100">
						<div class="flex-1">
							<p class="text-xs text-white/80">{formatDate(photo.taken_at)}</p>
							<p class="text-xs text-white/60">{formatSize(photo.file_size)}</p>
						</div>
						<div class="flex gap-1">
							<button
								onclick={(e) => { e.stopPropagation(); handleFavorite(photo.id); }}
								class="w-8 h-8 flex items-center justify-center rounded-full bg-black/40 hover:bg-black/60 text-sm transition-colors"
							>
								{photo.is_favorite ? '⭐' : '☆'}
							</button>
							<button
								onclick={(e) => { e.stopPropagation(); handleDelete(photo.id); }}
								class="w-8 h-8 flex items-center justify-center rounded-full bg-black/40 hover:bg-red-600/80 text-sm transition-colors"
							>
								🗑️
							</button>
						</div>
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>
