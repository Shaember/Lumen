<script lang="ts">
import { onMount } from 'svelte';
	import { listTrash, restorePhoto, photoUrl, type Photo } from '$lib/api/client';

	let photos = $state<Photo[]>([]);
	let loading = $state(true);

	onMount(async () => {
		await loadTrash();
	});

	async function loadTrash() {
		loading = true;
		try {
			photos = await listTrash();
		} catch (e) {
			console.error('Failed to load trash:', e);
		}
		loading = false;
	}

	async function handleRestore(id: number) {
		await restorePhoto(id);
		photos = photos.filter(p => p.id !== id);
	}
</script>

<div class="max-w-7xl mx-auto px-4 py-6">
	<h1 class="text-xl font-semibold mb-6">Trash</h1>

	{#if loading}
		<div class="text-center py-20 text-[var(--text-secondary)]">Loading...</div>
	{:else if photos.length === 0}
		<div class="text-center py-20 text-[var(--text-secondary)]">
			<p class="text-lg mb-2">Trash is empty</p>
		</div>
	{:else}
		<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-2">
			{#each photos as photo}
				<div class="group relative aspect-square bg-[var(--bg-secondary)] rounded-lg overflow-hidden opacity-60 hover:opacity-100 transition-opacity">
					<img
						src={photoUrl(photo.id, true)}
						alt={photo.filename}
						loading="lazy"
						class="w-full h-full object-cover"
					/>
					<div class="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-colors flex items-center justify-center opacity-0 group-hover:opacity-100">
						<button
							onclick={() => handleRestore(photo.id)}
							class="px-4 py-2 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-white rounded-lg text-sm transition-colors"
						>
							Restore
						</button>
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>
