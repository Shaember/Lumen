<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import {
		getAlbum,
		updateAlbum,
		listAllPhotos,
		addPhotosToAlbum,
		removePhotoFromAlbum,
		deletePhoto,
		photoUrl,
		type Album,
		type Photo
	} from '$lib/api/client';
	import AuthImage from '$lib/components/AuthImage.svelte';
	import EmptyState from '$lib/components/EmptyState.svelte';
	import ErrorState from '$lib/components/ErrorState.svelte';
	import SelectBar from '$lib/components/SelectBar.svelte';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';
	import Icon from '$lib/components/Icon.svelte';
	import { showToast } from '$lib/toast';

	let album = $state<Album | null>(null);
	let loading = $state(true);
	let error = $state<string | null>(null);
	let editing = $state(false);
	let editName = $state('');
	let selectMode = $state(false);
	let selected = $state<Set<number>>(new Set());
	let addOpen = $state(false);
	let library = $state<Photo[]>([]);
	let librarySelected = $state<Set<number>>(new Set());
	let confirmDelete = $state(false);
	let confirmRemove = $state(false);

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
			error = e?.message || 'Не удалось загрузить альбом';
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
			showToast(err?.message || 'Ошибка сохранения', 'danger');
		}
	}

	async function openAdd() {
		addOpen = true;
		try {
			library = await listAllPhotos();
			const inAlbum = new Set((album?.photos || []).map((p) => p.id));
			library = library.filter((p) => !inAlbum.has(p.id));
			librarySelected = new Set();
		} catch (err: any) {
			showToast(err?.message || 'Ошибка', 'danger');
		}
	}

	async function confirmAdd() {
		if (!album || librarySelected.size === 0) return;
		try {
			await addPhotosToAlbum(album.id, [...librarySelected]);
			showToast('Фото добавлены', 'success');
			addOpen = false;
			await loadAlbum();
		} catch (err: any) {
			showToast(err?.message || 'Не удалось добавить', 'danger');
		}
	}

	function exitSelect() {
		selectMode = false;
		selected = new Set();
	}

	async function bulkRemoveFromAlbum() {
		confirmRemove = false;
		if (!album) return;
		const ids = [...selected];
		try {
			for (const id of ids) {
				await removePhotoFromAlbum(album.id, id);
			}
			showToast('Удалено из альбома', 'info');
			exitSelect();
			await loadAlbum();
		} catch (err: any) {
			showToast(err?.message || 'Ошибка', 'danger');
		}
	}

	async function bulkDelete() {
		confirmDelete = false;
		const ids = [...selected];
		try {
			for (const id of ids) {
				await deletePhoto(id);
			}
			showToast('В корзине', 'info');
			exitSelect();
			await loadAlbum();
		} catch (err: any) {
			showToast(err?.message || 'Ошибка', 'danger');
		}
	}

	function toggleLib(id: number) {
		const next = new Set(librarySelected);
		if (next.has(id)) next.delete(id);
		else next.add(id);
		librarySelected = next;
	}

	function toggleSel(id: number) {
		const next = new Set(selected);
		if (next.has(id)) next.delete(id);
		else next.add(id);
		selected = next;
	}
</script>

<div class="max-w-7xl mx-auto px-4 py-6">
	{#if loading}
		<div class="photo-grid">
			{#each Array(8) as _}
				<div class="photo-tile skeleton-pulse"></div>
			{/each}
		</div>
	{:else if error}
		<ErrorState message={error} onretry={loadAlbum} />
	{:else if album}
		<div class="flex items-center gap-3 mb-6 flex-wrap">
			{#if editing}
				<form onsubmit={handleUpdate} class="flex gap-2 flex-1 min-w-[200px]">
					<input
						type="text"
						bind:value={editName}
						class="flex-1 h-10 px-3 bg-[var(--raised)] border border-[var(--hairline)] rounded-[6px] text-[var(--text)] focus:outline-none focus:border-[var(--accent)]"
					/>
					<button type="submit" class="h-10 px-3 bg-[var(--accent)] text-[var(--accent-ink)] rounded-[6px] text-sm"
						>Сохранить</button
					>
					<button type="button" onclick={() => (editing = false)} class="h-10 px-3 text-[var(--muted)] text-sm"
						>Отмена</button
					>
				</form>
			{:else}
				<h1 class="text-xl font-semibold flex-1 text-[var(--text)]">{album.name}</h1>
				{#if !selectMode}
					<button
						type="button"
						onclick={() => {
							selectMode = true;
							selected = new Set();
						}}
						class="h-10 px-3 rounded-[6px] text-sm text-[var(--muted)] border border-[var(--hairline)]"
						>Выбрать</button
					>
					<button
						type="button"
						onclick={openAdd}
						class="h-10 px-4 bg-[var(--accent)] text-[var(--accent-ink)] rounded-[6px] text-sm font-medium flex items-center gap-2"
					>
						<Icon name="plus" size={16} />
						Добавить
					</button>
					<button
						type="button"
						onclick={() => (editing = true)}
						class="h-10 px-3 text-[var(--muted)] hover:text-[var(--text)] text-sm rounded-[6px] hover:bg-[var(--raised)]"
						>Изменить</button
					>
				{/if}
			{/if}
		</div>

		{#if album.photos && album.photos.length > 0}
			<div class="photo-grid -mx-4 sm:mx-0">
				{#each album.photos as photo}
					{@const isSel = selected.has(photo.id)}
					<a
						href={selectMode ? undefined : `/photos/${photo.id}`}
						class="photo-tile"
						onclick={(e) => {
							if (selectMode) {
								e.preventDefault();
								toggleSel(photo.id);
							}
						}}
					>
						<AuthImage
							src={photoUrl(photo.id, true)}
							alt={photo.filename}
							class="w-full h-full object-cover"
						/>
						{#if selectMode}
							<span
								class="absolute top-1.5 right-1.5 w-6 h-6 rounded-full border flex items-center justify-center
									{isSel
									? 'bg-[var(--accent)] border-[var(--accent)] text-[var(--accent-ink)]'
									: 'border-[var(--accent)] bg-black/40'}"
							>
								{#if isSel}<Icon name="check" size={14} />{/if}
							</span>
						{/if}
					</a>
				{/each}
			</div>
		{:else}
			<EmptyState message="В альбоме нет фотографий" ctaLabel="Добавить" oncta={openAdd} />
		{/if}
	{:else}
		<div class="text-center py-20 text-[var(--muted)]">Альбом не найден</div>
	{/if}
</div>

<SelectBar
	count={selected.size}
	oncancel={exitSelect}
	onfavorite={async () => {}}
	onalbum={() => {}}
	ondelete={() => (confirmDelete = true)}
	showFavorite={false}
	showAlbum={false}
	extra="remove-album"
	extraLabel="Из альбома"
	onextra={() => (confirmRemove = true)}
/>

{#if addOpen}
	<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
	<div role="presentation" class="fixed inset-0 z-[110] bg-[var(--overlay)] flex items-end sm:items-center justify-center p-4" onclick={() => (addOpen = false)}>
		<div
			class="w-full max-w-lg max-h-[80vh] bg-[var(--raised)] border border-[var(--hairline)] rounded-[8px] flex flex-col"
			onclick={(e) => e.stopPropagation()}
			role="dialog"
			tabindex="-1"
		>
			<div class="flex items-center justify-between p-4 border-b border-[var(--hairline)]">
				<h2 class="font-semibold">Добавить фото</h2>
				<button type="button" class="text-sm text-[var(--muted)]" onclick={() => (addOpen = false)}>Отмена</button>
			</div>
			<div class="overflow-auto p-2 photo-grid flex-1">
				{#each library as p}
					<button type="button" class="photo-tile" onclick={() => toggleLib(p.id)}>
						<AuthImage src={photoUrl(p.id, true)} alt="" class="w-full h-full object-cover" />
						{#if librarySelected.has(p.id)}
							<span class="absolute top-1 right-1 w-6 h-6 rounded-full bg-[var(--accent)] text-[var(--accent-ink)] flex items-center justify-center">
								<Icon name="check" size={14} />
							</span>
						{/if}
					</button>
				{/each}
			</div>
			<div class="p-4 border-t border-[var(--hairline)]">
				<button
					type="button"
					disabled={librarySelected.size === 0}
					onclick={confirmAdd}
					class="w-full h-11 bg-[var(--accent)] text-[var(--accent-ink)] rounded-[6px] text-sm font-medium disabled:opacity-40"
				>
					Добавить ({librarySelected.size})
				</button>
			</div>
		</div>
	</div>
{/if}

<ConfirmDialog
	open={confirmDelete}
	title="Удалить фото?"
	message="Фотографии будут перемещены в корзину."
	onconfirm={bulkDelete}
	oncancel={() => (confirmDelete = false)}
/>
<ConfirmDialog
	open={confirmRemove}
	title="Убрать из альбома?"
	message="Фотографии останутся в ленте."
	confirmLabel="Убрать"
	danger={false}
	onconfirm={bulkRemoveFromAlbum}
	oncancel={() => (confirmRemove = false)}
/>
