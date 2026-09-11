<script lang="ts">
	import { onMount } from 'svelte';
	import {
		listAllPhotos,
		toggleFavorite,
		deletePhoto,
		addPhotosToAlbum,
		photoUrl,
		type Photo
	} from '$lib/api/client';
	import AuthImage from '$lib/components/AuthImage.svelte';
	import EmptyState from '$lib/components/EmptyState.svelte';
	import ErrorState from '$lib/components/ErrorState.svelte';
	import SelectBar from '$lib/components/SelectBar.svelte';
	import AlbumPicker from '$lib/components/AlbumPicker.svelte';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';
	import Icon from '$lib/components/Icon.svelte';
	import { showToast } from '$lib/toast';

	let photos = $state<Photo[]>([]);
	let loading = $state(true);
	let error = $state<string | null>(null);
	let selectMode = $state(false);
	let selected = $state<Set<number>>(new Set());
	let albumOpen = $state(false);
	let confirmBulk = $state(false);

	onMount(async () => {
		await load();
	});

	async function load() {
		loading = true;
		error = null;
		try {
			const all = await listAllPhotos();
			photos = all.filter((p) => p.is_favorite);
		} catch (e: any) {
			error = e?.message || 'Не удалось загрузить избранное';
			photos = [];
		}
		loading = false;
	}

	async function handleUnfavorite(id: number) {
		try {
			await toggleFavorite(id);
			photos = photos.filter((p) => p.id !== id);
		} catch (err: any) {
			showToast(err?.message || 'Ошибка', 'danger');
		}
	}

	function exitSelect() {
		selectMode = false;
		selected = new Set();
	}

	async function bulkFavorite() {
		const ids = [...selected];
		try {
			for (const id of ids) await toggleFavorite(id);
			photos = photos.filter((p) => !ids.includes(p.id));
			showToast('Убрано из избранного', 'info');
			exitSelect();
		} catch (err: any) {
			showToast(err?.message || 'Ошибка', 'danger');
		}
	}

	async function bulkDelete() {
		confirmBulk = false;
		const ids = [...selected];
		try {
			for (const id of ids) await deletePhoto(id);
			photos = photos.filter((p) => !ids.includes(p.id));
			exitSelect();
		} catch (err: any) {
			showToast(err?.message || 'Ошибка', 'danger');
		}
	}

	async function onAlbumPick(albumId: number) {
		albumOpen = false;
		try {
			await addPhotosToAlbum(albumId, [...selected]);
			showToast('Добавлено в альбом', 'success');
			exitSelect();
		} catch (err: any) {
			showToast(err?.message || 'Ошибка', 'danger');
		}
	}
</script>

<div class="max-w-7xl mx-auto px-4 py-6">
	<div class="flex items-center justify-between mb-6">
		<h1 class="text-xl font-semibold text-[var(--text)]">Избранное</h1>
		{#if photos.length > 0 && !selectMode}
			<button
				type="button"
				onclick={() => {
					selectMode = true;
					selected = new Set();
				}}
				class="h-10 px-3 rounded-[6px] text-sm text-[var(--muted)] border border-[var(--hairline)]"
				>Выбрать</button
			>
		{/if}
	</div>

	{#if loading}
		<div class="photo-grid -mx-4 sm:mx-0">
			{#each Array(8) as _}
				<div class="photo-tile skeleton-pulse"></div>
			{/each}
		</div>
	{:else if error}
		<ErrorState message={error} onretry={load} />
	{:else if photos.length === 0}
		<EmptyState message="В избранном пока пусто" ctaLabel="К ленте" href="/photos" />
	{:else}
		<div class="photo-grid -mx-4 sm:mx-0">
			{#each photos as photo}
				{@const isSel = selected.has(photo.id)}
				<div class="photo-tile group">
					<a
						href={selectMode ? undefined : `/photos/${photo.id}`}
						class="block w-full h-full"
						onclick={(e) => {
							if (selectMode) {
								e.preventDefault();
								const next = new Set(selected);
								if (next.has(photo.id)) next.delete(photo.id);
								else next.add(photo.id);
								selected = next;
							}
						}}
					>
						<AuthImage
							src={photoUrl(photo.id, true)}
							alt={photo.filename}
							class="w-full h-full object-cover"
						/>
					</a>
					{#if selectMode}
						<span
							class="absolute top-1.5 right-1.5 w-6 h-6 rounded-full border flex items-center justify-center pointer-events-none
								{isSel
								? 'bg-[var(--accent)] border-[var(--accent)] text-[var(--accent-ink)]'
								: 'border-[var(--accent)] bg-black/40'}"
						>
							{#if isSel}<Icon name="check" size={14} />{/if}
						</span>
					{:else}
						<button
							type="button"
							onclick={() => handleUnfavorite(photo.id)}
							class="absolute top-1.5 right-1.5 w-9 h-9 flex items-center justify-center rounded-full bg-black/50 text-[var(--accent)] opacity-0 group-hover:opacity-100 transition-opacity duration-[160ms]"
							aria-label="Убрать из избранного"
						>
							<Icon name="heart-fill" size={16} />
						</button>
					{/if}
				</div>
			{/each}
		</div>
	{/if}
</div>

<SelectBar
	count={selected.size}
	oncancel={exitSelect}
	onfavorite={bulkFavorite}
	favoriteLabel="Убрать"
	onalbum={() => (albumOpen = true)}
	ondelete={() => (confirmBulk = true)}
/>
<AlbumPicker open={albumOpen} onpick={onAlbumPick} oncancel={() => (albumOpen = false)} />
<ConfirmDialog
	open={confirmBulk}
	title="Удалить выбранные?"
	message="Фотографии будут перемещены в корзину."
	onconfirm={bulkDelete}
	oncancel={() => (confirmBulk = false)}
/>
