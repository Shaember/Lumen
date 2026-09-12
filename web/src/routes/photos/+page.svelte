<script lang="ts">
	import { onMount } from 'svelte';
	import {
		listAllPhotos,
		toggleFavorite,
		deletePhoto,
		uploadPhoto,
		photoUrl,
		addPhotosToAlbum,
		type Photo
	} from '$lib/api/client';
	import AuthImage from '$lib/components/AuthImage.svelte';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';
	import EmptyState from '$lib/components/EmptyState.svelte';
	import ErrorState from '$lib/components/ErrorState.svelte';
	import SelectBar from '$lib/components/SelectBar.svelte';
	import AlbumPicker from '$lib/components/AlbumPicker.svelte';
	import Icon from '$lib/components/Icon.svelte';
	import { buildTimelineSections } from '$lib/utils/dates';
	import { showToast } from '$lib/toast';

	let photos = $state<Photo[]>([]);
	let loading = $state(true);
	let error = $state<string | null>(null);
	let uploading = $state(false);
	let uploadProgress = $state(0);
	let selectMode = $state(false);
	let selected = $state<Set<number>>(new Set());
	let confirmBulk = $state(false);
	let albumOpen = $state(false);
	let dragOver = $state(false);
	let fileInput: HTMLInputElement | undefined = $state();

	const sections = $derived(buildTimelineSections(photos).sections);

	onMount(async () => {
		await loadPhotos();
	});

	async function loadPhotos() {
		loading = true;
		error = null;
		try {
			photos = await listAllPhotos();
		} catch (e: any) {
			error = e?.message || 'Не удалось загрузить фото';
			photos = [];
		}
		loading = false;
	}

	async function handleFiles(files: FileList | File[]) {
		const list = Array.from(files).filter((f) => f.type.startsWith('image/'));
		if (!list.length) return;
		uploading = true;
		uploadProgress = 0;
		let done = 0;
		try {
			for (const file of list) {
				await uploadPhoto(file);
				done++;
				uploadProgress = done / list.length;
			}
			showToast(`Загружено: ${done}`, 'success');
			await loadPhotos();
		} catch (err: any) {
			showToast(err?.message || 'Ошибка загрузки', 'danger');
		}
		uploading = false;
		uploadProgress = 0;
		if (fileInput) fileInput.value = '';
	}

	function onFileInput(e: Event) {
		const input = e.target as HTMLInputElement;
		if (input.files?.length) handleFiles(input.files);
	}

	function onDrop(e: DragEvent) {
		e.preventDefault();
		dragOver = false;
		if (e.dataTransfer?.files?.length) handleFiles(e.dataTransfer.files);
	}

	function toggleSelect(id: number) {
		const next = new Set(selected);
		if (next.has(id)) next.delete(id);
		else next.add(id);
		selected = next;
	}

	function enterSelect() {
		selectMode = true;
		selected = new Set();
	}

	function exitSelect() {
		selectMode = false;
		selected = new Set();
	}

	async function bulkFavorite() {
		const ids = [...selected];
		try {
			for (const id of ids) {
				await toggleFavorite(id);
				photos = photos.map((p) => (p.id === id ? { ...p, is_favorite: !p.is_favorite } : p));
			}
			showToast('Избранное обновлено', 'success');
			exitSelect();
		} catch (err: any) {
			showToast(err?.message || 'Ошибка', 'danger');
		}
	}

	async function bulkDelete() {
		confirmBulk = false;
		const ids = [...selected];
		try {
			for (const id of ids) {
				await deletePhoto(id);
			}
			photos = photos.filter((p) => !ids.includes(p.id));
			showToast('Перемещено в корзину', 'info');
			exitSelect();
		} catch (err: any) {
			showToast(err?.message || 'Ошибка удаления', 'danger');
		}
	}

	async function onAlbumPick(albumId: number) {
		albumOpen = false;
		const ids = [...selected];
		try {
			await addPhotosToAlbum(albumId, ids);
			showToast('Добавлено в альбом', 'success');
			exitSelect();
		} catch (err: any) {
			showToast(err?.message || 'Не удалось добавить', 'danger');
		}
	}

	function onTileClick(e: MouseEvent, photo: Photo) {
		if (selectMode) {
			e.preventDefault();
			toggleSelect(photo.id);
		}
	}

	function onTileLongPress(photo: Photo) {
		if (!selectMode) {
			selectMode = true;
			selected = new Set([photo.id]);
		}
	}
</script>

<svelte:window
	ondragover={(e) => {
		e.preventDefault();
		dragOver = true;
	}}
	ondragleave={() => {
		dragOver = false;
	}}
	ondrop={onDrop}
/>

<!-- Full-bleed photo wall — no max-width, no SaaS page title -->
<!-- content starts below fixed chrome -->
<div class="relative w-full pt-14">
	{#if !selectMode}
		<div class="wall-toolbar">
			<button type="button" onclick={enterSelect} class="btn-ghost">Выбрать</button>
			<button
				type="button"
				onclick={() => fileInput?.click()}
				disabled={uploading}
				class="btn-primary"
			>
				<Icon name="upload" size={18} />
				{uploading ? 'Загрузка…' : 'Загрузить'}
			</button>
			<input bind:this={fileInput} type="file" accept="image/*" multiple class="hidden" onchange={onFileInput} />
		</div>
	{/if}

	{#if uploading}
		<div class="fixed top-14 inset-x-0 z-[45] h-0.5 bg-[var(--raised)] overflow-hidden">
			<div class="h-full bg-[var(--accent)] transition-all duration-[160ms]" style="width: {uploadProgress * 100}%"></div>
		</div>
	{/if}

	{#if loading}
		<div class="photo-grid">
			{#each Array(12) as _}
				<div class="photo-tile skeleton-pulse"></div>
			{/each}
		</div>
	{:else if error}
		<div class="px-4 pt-6">
			<ErrorState message={error} onretry={loadPhotos} />
		</div>
	{:else if photos.length === 0}
		<div class="pt-6">
			<EmptyState message="Пока нет фотографий" ctaLabel="Загрузить" oncta={() => fileInput?.click()} />
		</div>
	{:else}
		{#each sections as section (section.key)}
			{#if section.kind === 'year'}
				<div class="year-sticky font-display">
					<h2>{section.label}</h2>
				</div>
			{:else if section.kind === 'month'}
				<div class="month-sticky">
					<h3>{section.label}</h3>
				</div>
			{:else}
				<div class="timeline-day">
					<div class="px-4 pt-10 pb-1">
						<p class="text-xs text-[var(--muted)]">{section.label}</p>
					</div>
					<div class="photo-grid">
						{#each section.items as photo (photo.id)}
							{@const isSel = selected.has(photo.id)}
							<!-- svelte-ignore a11y_no_static_element_interactions -->
							<a
								href={selectMode ? undefined : `/photos/${photo.id}`}
								class="photo-tile group"
								class:opacity-90={isSel}
								onclick={(e) => onTileClick(e, photo as Photo)}
								oncontextmenu={(e) => {
									e.preventDefault();
									onTileLongPress(photo as Photo);
								}}
							>
								<AuthImage
									src={photoUrl(photo.id, true)}
									alt={photo.filename}
									class="w-full h-full object-cover"
								/>
								{#if selectMode}
									<span
										class="absolute top-1.5 right-1.5 w-6 h-6 rounded-[6px] border flex items-center justify-center
											{isSel
											? 'bg-[var(--accent)] border-[var(--accent)] text-[var(--accent-ink)]'
											: 'border-[var(--accent)] bg-black/40 text-transparent'}"
									>
										{#if isSel}<Icon name="check" size={14} />{/if}
									</span>
								{:else if photo.is_favorite}
									<span class="absolute top-1.5 left-1.5 text-[var(--accent)] drop-shadow">
										<Icon name="heart-fill" size={16} />
									</span>
								{/if}
								{#if isSel}
									<span class="absolute inset-0 ring-1 ring-inset ring-[var(--accent)] pointer-events-none"></span>
								{/if}
							</a>
						{/each}
					</div>
				</div>
			{/if}
		{/each}
	{/if}

	{#if dragOver}
		<div
			class="fixed inset-0 z-[90] pointer-events-none flex items-center justify-center"
			style="background: var(--overlay)"
		>
			<div
				class="px-8 py-10 border border-[var(--accent)] rounded-[8px] bg-[var(--raised)] text-[var(--text)] text-sm"
			>
				Отпустите файлы для загрузки
			</div>
		</div>
	{/if}
</div>

<SelectBar
	count={selected.size}
	oncancel={exitSelect}
	onfavorite={bulkFavorite}
	onalbum={() => (albumOpen = true)}
	ondelete={() => (confirmBulk = true)}
/>

<AlbumPicker open={albumOpen} onpick={onAlbumPick} oncancel={() => (albumOpen = false)} />

<ConfirmDialog
	open={confirmBulk}
	title="Удалить выбранные?"
	message="Фотографии будут перемещены в корзину."
	confirmLabel="Удалить"
	onconfirm={bulkDelete}
	oncancel={() => (confirmBulk = false)}
/>
