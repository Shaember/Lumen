<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import {
		getPhoto,
		listPhotos,
		toggleFavorite,
		deletePhoto,
		photoUrl,
		type Photo
	} from '$lib/api/client';
	import AuthImage from '$lib/components/AuthImage.svelte';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';
	import { downloadMedia } from '$lib/media';
	import { showToast } from '$lib/toast';

	let photo = $state<Photo | null>(null);
	let loading = $state(true);
	let notFound = $state(false);
	let ids = $state<number[]>([]);
	let confirmOpen = $state(false);
	let loadedId = $state<number | null>(null);

	async function load(id: number) {
		if (loadedId === id && photo) return;
		loading = true;
		notFound = false;
		photo = null;
		loadedId = id;
		try {
			photo = await getPhoto(id);
		} catch {
			notFound = true;
			photo = null;
		}
		loading = false;
	}

	onMount(() => {
		listPhotos(undefined, 0, 500)
			.then((all) => {
				ids = all.map((p) => p.id);
			})
			.catch(() => {
				ids = [];
			});

		const unsub = page.subscribe((p) => {
			const id = Number(p.params.id);
			if (Number.isFinite(id)) load(id);
		});

		window.addEventListener('keydown', onKey);
		return () => {
			unsub();
			window.removeEventListener('keydown', onKey);
		};
	});

	function onKey(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			goto('/photos');
			return;
		}
		if (!photo || ids.length === 0) return;
		const idx = ids.indexOf(photo.id);
		if (e.key === 'ArrowLeft' && idx > 0) {
			goto(`/photos/${ids[idx - 1]}`);
		} else if (e.key === 'ArrowRight' && idx >= 0 && idx < ids.length - 1) {
			goto(`/photos/${ids[idx + 1]}`);
		}
	}

	async function handleFavorite() {
		if (!photo) return;
		try {
			const result = await toggleFavorite(photo.id);
			photo = { ...photo, is_favorite: result.is_favorite };
		} catch (err: any) {
			showToast(err?.message || 'Failed', 'danger');
		}
	}

	async function confirmDelete() {
		if (!photo) return;
		confirmOpen = false;
		try {
			await deletePhoto(photo.id);
			goto('/photos');
		} catch (err: any) {
			showToast(err?.message || 'Delete failed', 'danger');
		}
	}

	async function handleDownload() {
		if (!photo) return;
		try {
			await downloadMedia(photoUrl(photo.id), photo.filename);
		} catch (err: any) {
			showToast(err?.message || 'Download failed', 'danger');
		}
	}

	function goPrev() {
		if (!photo) return;
		const idx = ids.indexOf(photo.id);
		if (idx > 0) goto(`/photos/${ids[idx - 1]}`);
	}

	function goNext() {
		if (!photo) return;
		const idx = ids.indexOf(photo.id);
		if (idx >= 0 && idx < ids.length - 1) goto(`/photos/${ids[idx + 1]}`);
	}

	const idx = $derived(photo ? ids.indexOf(photo.id) : -1);
</script>

<div class="min-h-[calc(100vh-3.5rem)] bg-[var(--bg)] flex items-center justify-center relative">
	<button
		type="button"
		onclick={() => goto('/photos')}
		class="absolute top-4 left-4 z-10 w-10 h-10 flex items-center justify-center rounded-full bg-[var(--raised)] border border-[var(--hairline)] text-[var(--text)] hover:bg-[var(--bg-tertiary)] transition-colors text-xl leading-none"
		aria-label="Close"
		title="Close (Esc)"
	>
		×
	</button>

	{#if loading}
		<p class="text-[var(--muted)]">Loading...</p>
	{:else if photo}
		<div class="relative max-w-full max-h-[calc(100vh-3.5rem)] w-full flex items-center justify-center px-12">
			{#if idx > 0}
				<button
					type="button"
					onclick={goPrev}
					class="absolute left-2 z-10 w-10 h-10 flex items-center justify-center rounded-full bg-[var(--raised)] border border-[var(--hairline)] text-[var(--text)] text-xl"
					aria-label="Previous"
				>
					‹
				</button>
			{/if}
			<div class="max-h-[calc(100vh-5rem)] max-w-full">
				<AuthImage
					src={photoUrl(photo.id)}
					alt={photo.filename}
					class="max-h-[calc(100vh-5rem)] max-w-full object-contain"
					loading="eager"
				/>
			</div>
			{#if idx >= 0 && idx < ids.length - 1}
				<button
					type="button"
					onclick={goNext}
					class="absolute right-2 z-10 w-10 h-10 flex items-center justify-center rounded-full bg-[var(--raised)] border border-[var(--hairline)] text-[var(--text)] text-xl"
					aria-label="Next"
				>
					›
				</button>
			{/if}
			<div class="absolute top-4 right-4 flex gap-2">
				<button
					onclick={handleFavorite}
					class="w-10 h-10 flex items-center justify-center rounded-full bg-[var(--raised)] border border-[var(--hairline)] text-[var(--text)] hover:bg-[var(--bg-tertiary)] transition-colors"
					aria-label="Favorite"
				>
					{photo.is_favorite ? '★' : '☆'}
				</button>
				<button
					onclick={() => (confirmOpen = true)}
					class="w-10 h-10 flex items-center justify-center rounded-full bg-[var(--raised)] border border-[var(--hairline)] text-[var(--text)] hover:bg-[var(--danger)]/80 transition-colors text-xl leading-none"
					aria-label="Delete"
				>
					×
				</button>
				<button
					onclick={handleDownload}
					class="w-10 h-10 flex items-center justify-center rounded-full bg-[var(--raised)] border border-[var(--hairline)] text-[var(--text)] hover:bg-[var(--bg-tertiary)] text-sm transition-colors"
					aria-label="Download"
					title="Download"
				>
					↓
				</button>
			</div>
		</div>
	{:else}
		<div class="text-center px-4">
			<p class="text-[var(--text)] text-lg mb-4">Снимок не найден</p>
			<a
				href="/photos"
				class="inline-block px-4 py-2 rounded-[6px] bg-[var(--accent)] text-[var(--bg)] text-sm"
			>
				Timeline
			</a>
		</div>
	{/if}
</div>

<ConfirmDialog
	open={confirmOpen}
	title="Delete photo?"
	message="This will move the photo to Trash. You can restore it later."
	confirmLabel="Delete"
	onconfirm={confirmDelete}
	oncancel={() => (confirmOpen = false)}
/>
