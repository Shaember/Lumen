<script lang="ts">
	import { onMount } from 'svelte';
	import { listAlbums, createAlbum, deleteAlbum, photoUrl, type Album } from '$lib/api/client';
	import AuthImage from '$lib/components/AuthImage.svelte';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';
	import EmptyState from '$lib/components/EmptyState.svelte';
	import ErrorState from '$lib/components/ErrorState.svelte';
	import Icon from '$lib/components/Icon.svelte';
	import { showToast } from '$lib/toast';

	let albums = $state<Album[]>([]);
	let loading = $state(true);
	let error = $state<string | null>(null);
	let showNew = $state(false);
	let newName = $state('');
	let confirmId = $state<number | null>(null);

	const mosaicPositions = ['0% 0%', '100% 0%', '0% 100%', '100% 100%'];

	onMount(async () => {
		await loadAlbums();
	});

	async function loadAlbums() {
		loading = true;
		error = null;
		try {
			albums = await listAlbums();
		} catch (e: any) {
			error = e?.message || 'Не удалось загрузить альбомы';
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
			showToast(err?.message || 'Не удалось создать альбом', 'danger');
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
			showToast(err?.message || 'Ошибка удаления', 'danger');
		}
	}
</script>

<div class="relative w-full pt-14">
	<div class="wall-toolbar">
		<button type="button" onclick={() => (showNew = !showNew)} class="btn-primary">
			<Icon name="plus" size={18} />
			Новый
		</button>
	</div>

	{#if showNew}
		<form
			onsubmit={handleCreate}
			class="mx-3 mt-2 mb-4 p-4 bg-[var(--raised)] border border-[var(--hairline)] rounded-[8px] flex gap-2"
		>
			<input
				type="text"
				bind:value={newName}
				placeholder="Название альбома"
				class="flex-1 h-12 px-3 bg-[var(--bg)] border border-[var(--hairline)] rounded-[6px] text-[var(--text)] focus:outline-none focus:border-[var(--accent)]"
			/>
			<button
				type="submit"
				class="h-12 px-4 bg-[var(--accent)] text-[var(--accent-ink)] rounded-[6px] text-sm font-medium"
			>
				Создать
			</button>
		</form>
	{/if}

	{#if loading}
		<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3 px-3 pt-2">
			{#each Array(4) as _}
				<div class="mosaic-cover skeleton-pulse" style="animation: none; opacity: 0.55"></div>
			{/each}
		</div>
	{:else if error}
		<div class="px-4 pt-6">
			<ErrorState message={error} onretry={loadAlbums} />
		</div>
	{:else if albums.length === 0}
		<div class="pt-6">
			<EmptyState message="Альбомов пока нет" ctaLabel="Создать альбом" oncta={() => (showNew = true)} />
		</div>
	{:else}
		<div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3 px-3 pt-2 pb-6">
			{#each albums as album}
				<div class="block group relative">
					<a href="/albums/{album.id}" class="block">
						{#if album.cover_photo_id}
							<div class="mosaic-cover">
								{#each mosaicPositions as pos}
									<div class="cell">
										<AuthImage
											src={photoUrl(album.cover_photo_id, true)}
											alt={album.name}
											class="w-full h-full object-cover"
											style="object-position: {pos}"
										/>
									</div>
								{/each}
							</div>
						{:else}
							<div class="mosaic-cover empty-mosaic">
								<Icon name="albums" size={28} />
							</div>
						{/if}
						<div class="mt-2 px-0.5">
							<p class="font-medium text-sm text-[var(--text)]">{album.name}</p>
							<p class="text-xs text-[var(--muted)]">{album.photo_count} фото</p>
						</div>
					</a>
					<button
						type="button"
						onclick={(e) => {
							e.preventDefault();
							e.stopPropagation();
							confirmId = album.id;
						}}
						class="absolute top-2 right-2 w-9 h-9 flex items-center justify-center rounded-[6px] bg-black/50 text-[var(--text)] opacity-0 group-hover:opacity-100 transition-opacity duration-[160ms]"
						aria-label="Удалить альбом"
					>
						<Icon name="trash" size={16} />
					</button>
				</div>
			{/each}
		</div>
	{/if}
</div>

<ConfirmDialog
	open={confirmId != null}
	title="Удалить альбом?"
	message="Альбом будет удалён. Фотографии внутри останутся."
	confirmLabel="Удалить"
	onconfirm={confirmDelete}
	oncancel={() => (confirmId = null)}
/>
