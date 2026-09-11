<script lang="ts">
	import { onMount } from 'svelte';
	import {
		listPhotos,
		toggleFavorite,
		deletePhoto,
		uploadPhoto,
		photoUrl,
		type Photo
	} from '$lib/api/client';
	import AuthImage from '$lib/components/AuthImage.svelte';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';
	import EmptyState from '$lib/components/EmptyState.svelte';
	import ErrorState from '$lib/components/ErrorState.svelte';
	import { showToast } from '$lib/toast';

	let photos = $state<Photo[]>([]);
	let loading = $state(true);
	let error = $state<string | null>(null);
	let uploading = $state(false);
	let showUpload = $state(false);
	let confirmId = $state<number | null>(null);

	onMount(async () => {
		await loadPhotos();
	});

	async function loadPhotos() {
		loading = true;
		error = null;
		try {
			photos = await listPhotos();
		} catch (e: any) {
			error = e?.message || 'Failed to load photos';
			photos = [];
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
		} catch (err: any) {
			showToast(err?.message || 'Upload failed', 'danger');
		}
		uploading = false;
		showUpload = false;
		input.value = '';
	}

	async function handleFavorite(id: number) {
		try {
			await toggleFavorite(id);
			photos = photos.map((p) => (p.id === id ? { ...p, is_favorite: !p.is_favorite } : p));
		} catch (err: any) {
			showToast(err?.message || 'Failed to update favorite', 'danger');
		}
	}

	async function confirmDelete() {
		if (confirmId == null) return;
		const id = confirmId;
		confirmId = null;
		try {
			await deletePhoto(id);
			photos = photos.filter((p) => p.id !== id);
		} catch (err: any) {
			showToast(err?.message || 'Delete failed', 'danger');
		}
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
		<h1 class="text-xl font-semibold text-[var(--text)]">Timeline</h1>
		<button
			onclick={() => (showUpload = !showUpload)}
			class="px-4 py-2 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-[var(--bg)] rounded-[6px] text-sm transition-colors"
		>
			{uploading ? 'Uploading...' : '+ Upload'}
		</button>
	</div>

	{#if showUpload}
		<div class="mb-6 p-4 bg-[var(--raised)] rounded-[8px] border border-[var(--hairline)]">
			<input
				type="file"
				accept="image/*"
				multiple
				onchange={handleUpload}
				class="block w-full text-sm text-[var(--muted)]
					file:mr-4 file:py-2 file:px-4
					file:rounded-[6px] file:border-0
					file:text-sm file:font-semibold
					file:bg-[var(--accent)] file:text-[var(--bg)]
					hover:file:bg-[var(--accent-hover)]
					file:cursor-pointer file:transition-colors"
			/>
		</div>
	{/if}

	{#if loading}
		<div class="text-center py-20 text-[var(--muted)]">Loading photos...</div>
	{:else if error}
		<ErrorState message={error} onretry={loadPhotos} />
	{:else if photos.length === 0}
		<EmptyState
			message="No photos yet"
			ctaLabel="Загрузить"
			oncta={() => (showUpload = true)}
		/>
	{:else}
		<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-2">
			{#each photos as photo}
				<a
					href="/photos/{photo.id}"
					class="group relative aspect-square bg-[var(--raised)] rounded-[6px] overflow-hidden block"
				>
					<AuthImage
						src={photoUrl(photo.id, true)}
						alt={photo.filename}
						class="w-full h-full object-cover"
					/>
					<div
						class="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-colors flex items-end p-2 opacity-0 group-hover:opacity-100 pointer-events-none group-hover:pointer-events-auto"
					>
						<div class="flex-1">
							<p class="text-xs text-white/80">{formatDate(photo.taken_at)}</p>
							<p class="text-xs text-white/60">{formatSize(photo.file_size)}</p>
						</div>
						<div class="flex gap-1">
							<button
								onclick={(e) => {
									e.preventDefault();
									e.stopPropagation();
									handleFavorite(photo.id);
								}}
								class="w-8 h-8 flex items-center justify-center rounded-full bg-black/40 hover:bg-black/60 text-sm transition-colors text-white"
								aria-label="Favorite"
							>
								{photo.is_favorite ? '★' : '☆'}
							</button>
							<button
								onclick={(e) => {
									e.preventDefault();
									e.stopPropagation();
									confirmId = photo.id;
								}}
								class="w-8 h-8 flex items-center justify-center rounded-full bg-black/40 hover:bg-[var(--danger)]/80 text-sm transition-colors text-white"
								aria-label="Delete"
							>
								×
							</button>
						</div>
					</div>
				</a>
			{/each}
		</div>
	{/if}
</div>

<ConfirmDialog
	open={confirmId != null}
	title="Delete photo?"
	message="This will move the photo to Trash. You can restore it later."
	confirmLabel="Delete"
	onconfirm={confirmDelete}
	oncancel={() => (confirmId = null)}
/>
