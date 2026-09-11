<script lang="ts">
	import { onMount } from 'svelte';
	import { listTrash, restorePhoto, photoUrl, type Photo } from '$lib/api/client';
	import AuthImage from '$lib/components/AuthImage.svelte';
	import EmptyState from '$lib/components/EmptyState.svelte';
	import ErrorState from '$lib/components/ErrorState.svelte';
	import { showToast } from '$lib/toast';

	let photos = $state<Photo[]>([]);
	let loading = $state(true);
	let error = $state<string | null>(null);

	onMount(async () => {
		await loadTrash();
	});

	async function loadTrash() {
		loading = true;
		error = null;
		try {
			photos = await listTrash();
		} catch (e: any) {
			error = e?.message || 'Failed to load trash';
			photos = [];
		}
		loading = false;
	}

	async function handleRestore(id: number) {
		try {
			await restorePhoto(id);
			photos = photos.filter((p) => p.id !== id);
		} catch (err: any) {
			showToast(err?.message || 'Restore failed', 'danger');
		}
	}
</script>

<div class="max-w-7xl mx-auto px-4 py-6">
	<h1 class="text-xl font-semibold mb-6 text-[var(--text)]">Trash</h1>

	{#if loading}
		<div class="text-center py-20 text-[var(--muted)]">Loading...</div>
	{:else if error}
		<ErrorState message={error} onretry={loadTrash} />
	{:else if photos.length === 0}
		<EmptyState message="Trash is empty" />
	{:else}
		<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-2">
			{#each photos as photo}
				<div
					class="group relative aspect-square bg-[var(--raised)] rounded-[6px] overflow-hidden opacity-60 hover:opacity-100 transition-opacity border border-[var(--hairline)]"
				>
					<AuthImage
						src={photoUrl(photo.id, true)}
						alt={photo.filename}
						class="w-full h-full object-cover"
					/>
					<div
						class="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-colors flex items-center justify-center opacity-0 group-hover:opacity-100"
					>
						<button
							onclick={() => handleRestore(photo.id)}
							class="px-4 py-2 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-[var(--bg)] rounded-[6px] text-sm transition-colors"
						>
							Restore
						</button>
					</div>
				</div>
			{/each}
		</div>
	{/if}
</div>
