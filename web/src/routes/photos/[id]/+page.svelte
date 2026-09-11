<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import {
		getPhoto,
		listAllPhotos,
		toggleFavorite,
		deletePhoto,
		photoUrl,
		type Photo
	} from '$lib/api/client';
	import AuthImage from '$lib/components/AuthImage.svelte';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';
	import Icon from '$lib/components/Icon.svelte';
	import { downloadMedia } from '$lib/media';
	import { showToast } from '$lib/toast';

	let photo = $state<Photo | null>(null);
	let loading = $state(true);
	let notFound = $state(false);
	let ids = $state<number[]>([]);
	let filmstrip = $state<Photo[]>([]);
	let confirmOpen = $state(false);
	let loadedId = $state<number | null>(null);
	let scale = $state(1);
	let chromeVisible = $state(true);

	let touchStartX = 0;
	let touchStartY = 0;
	let swiping = false;

	async function load(id: number) {
		if (loadedId === id && photo) return;
		loading = true;
		notFound = false;
		photo = null;
		loadedId = id;
		scale = 1;
		try {
			photo = await getPhoto(id);
		} catch {
			notFound = true;
			photo = null;
		}
		loading = false;
	}

	onMount(() => {
		listAllPhotos()
			.then((all) => {
				ids = all.map((p) => p.id);
				filmstrip = all;
			})
			.catch(() => {
				ids = [];
				filmstrip = [];
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
			showToast(err?.message || 'Ошибка', 'danger');
		}
	}

	async function confirmDelete() {
		if (!photo) return;
		confirmOpen = false;
		try {
			await deletePhoto(photo.id);
			goto('/photos');
		} catch (err: any) {
			showToast(err?.message || 'Ошибка удаления', 'danger');
		}
	}

	async function handleDownload() {
		if (!photo) return;
		try {
			await downloadMedia(photoUrl(photo.id), photo.filename);
		} catch (err: any) {
			showToast(err?.message || 'Ошибка скачивания', 'danger');
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

	function onTouchStart(e: TouchEvent) {
		if (e.touches.length !== 1) return;
		touchStartX = e.touches[0].clientX;
		touchStartY = e.touches[0].clientY;
		swiping = true;
	}

	function onTouchEnd(e: TouchEvent) {
		if (!swiping || e.changedTouches.length !== 1) return;
		swiping = false;
		const dx = e.changedTouches[0].clientX - touchStartX;
		const dy = e.changedTouches[0].clientY - touchStartY;
		if (Math.abs(dy) > 80 && Math.abs(dy) > Math.abs(dx) && dy > 0 && scale <= 1.05) {
			goto('/photos');
			return;
		}
		if (Math.abs(dx) > 60 && Math.abs(dx) > Math.abs(dy) && scale <= 1.05) {
			if (dx > 0) goPrev();
			else goNext();
		}
	}

	function onDblClick() {
		scale = scale > 1.05 ? 1 : 2;
	}

	const idx = $derived(photo ? ids.indexOf(photo.id) : -1);
</script>

<div
	role="presentation"
	class="viewer fixed inset-0 z-[70] bg-[var(--viewer-bg)] flex flex-col"
	ontouchstart={onTouchStart}
	ontouchend={onTouchEnd}
>
	{#if chromeVisible}
		<div
			class="absolute top-0 inset-x-0 z-20 flex items-center justify-between px-3 h-14 glass-chrome border-b border-[var(--hairline)]"
		>
			<button
				type="button"
				onclick={() => goto('/photos')}
				class="w-11 h-11 flex items-center justify-center text-[var(--text)]"
				aria-label="Закрыть"
				title="Esc"
			>
				<Icon name="close" size={22} />
			</button>
			<div class="flex items-center gap-1">
				<button
					type="button"
					onclick={handleFavorite}
					class="w-11 h-11 flex items-center justify-center text-[var(--text)]"
					aria-label="Избранное"
					disabled={!photo}
				>
					<Icon name={photo?.is_favorite ? 'heart-fill' : 'heart'} size={22} />
				</button>
				<button
					type="button"
					onclick={handleDownload}
					class="w-11 h-11 flex items-center justify-center text-[var(--text)]"
					aria-label="Скачать"
					disabled={!photo}
				>
					<Icon name="download" size={22} />
				</button>
				<button
					type="button"
					onclick={() => (confirmOpen = true)}
					class="w-11 h-11 flex items-center justify-center text-[var(--danger)]"
					aria-label="Удалить"
					disabled={!photo}
				>
					<Icon name="trash" size={22} />
				</button>
			</div>
		</div>
	{/if}

	<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
	<div
		role="presentation"
		class="flex-1 flex items-center justify-center relative min-h-0 px-2"
		onclick={() => (chromeVisible = !chromeVisible)}
		ondblclick={(e) => {
			e.stopPropagation();
			onDblClick();
		}}
	>
		{#if loading}
			<div class="w-24 h-24 skeleton-pulse rounded-[6px]"></div>
		{:else if photo}
			{#if idx > 0}
				<button
					type="button"
					onclick={(e) => {
						e.stopPropagation();
						goPrev();
					}}
					class="absolute left-1 z-10 w-11 h-11 flex items-center justify-center text-[var(--text)]/80 hover:text-[var(--text)]"
					aria-label="Назад"
				>
					<Icon name="chevron-left" size={28} />
				</button>
			{/if}
			<div
				class="max-h-[calc(100vh-9rem)] max-w-full transition-transform duration-[160ms] ease-out"
				style="transform: scale({scale})"
			>
				<AuthImage
					src={photoUrl(photo.id)}
					alt={photo.filename}
					class="max-h-[calc(100vh-9rem)] max-w-full object-contain"
					loading="eager"
				/>
			</div>
			{#if idx >= 0 && idx < ids.length - 1}
				<button
					type="button"
					onclick={(e) => {
						e.stopPropagation();
						goNext();
					}}
					class="absolute right-1 z-10 w-11 h-11 flex items-center justify-center text-[var(--text)]/80 hover:text-[var(--text)]"
					aria-label="Вперёд"
				>
					<Icon name="chevron-right" size={28} />
				</button>
			{/if}
		{:else}
			<div class="text-center px-4">
				<p class="text-[var(--text)] text-lg mb-4">Снимок не найден</p>
				<a
					href="/photos"
					class="inline-flex h-11 items-center px-4 rounded-[6px] bg-[var(--accent)] text-[var(--accent-ink)] text-sm font-medium"
				>
					К ленте
				</a>
			</div>
		{/if}
	</div>

	{#if chromeVisible && filmstrip.length > 0 && photo}
		<div
			class="h-[72px] shrink-0 glass-chrome border-t border-[var(--hairline)] overflow-x-auto flex items-center gap-0.5 px-2"
		>
			{#each filmstrip as p (p.id)}
				<button
					type="button"
					onclick={() => goto(`/photos/${p.id}`)}
					class="w-14 h-14 shrink-0 overflow-hidden {p.id === photo.id
						? 'ring-1 ring-[var(--accent)] ring-offset-1 ring-offset-black'
						: 'opacity-70'}"
					aria-label={p.filename}
				>
					<AuthImage src={photoUrl(p.id, true)} alt="" class="w-full h-full object-cover" />
				</button>
			{/each}
		</div>
	{/if}
</div>

<ConfirmDialog
	open={confirmOpen}
	title="Удалить фото?"
	message="Фотография будет перемещена в корзину."
	confirmLabel="Удалить"
	onconfirm={confirmDelete}
	oncancel={() => (confirmOpen = false)}
/>
