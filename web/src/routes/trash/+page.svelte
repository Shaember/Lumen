<script lang="ts">
	import { onMount } from 'svelte';
	import { listTrash, restorePhoto, photoUrl, type Photo } from '$lib/api/client';
	import AuthImage from '$lib/components/AuthImage.svelte';
	import EmptyState from '$lib/components/EmptyState.svelte';
	import ErrorState from '$lib/components/ErrorState.svelte';
	import ConfirmDialog from '$lib/components/ConfirmDialog.svelte';
	import Icon from '$lib/components/Icon.svelte';
	import { showToast } from '$lib/toast';

	let photos = $state<Photo[]>([]);
	let loading = $state(true);
	let error = $state<string | null>(null);
	let selectMode = $state(false);
	let selected = $state<Set<number>>(new Set());
	let emptyConfirm = $state(false);
	/** API gap: no empty-trash / permanent-delete endpoint yet. */
	const EMPTY_TRASH_API = false;

	onMount(async () => {
		await loadTrash();
	});

	async function loadTrash() {
		loading = true;
		error = null;
		try {
			photos = await listTrash();
		} catch (e: any) {
			error = e?.message || 'Не удалось загрузить корзину';
			photos = [];
		}
		loading = false;
	}

	async function handleRestore(id: number) {
		try {
			await restorePhoto(id);
			photos = photos.filter((p) => p.id !== id);
			showToast('Восстановлено', 'success');
		} catch (err: any) {
			showToast(err?.message || 'Ошибка восстановления', 'danger');
		}
	}

	async function bulkRestore() {
		const ids = [...selected];
		try {
			for (const id of ids) await restorePhoto(id);
			photos = photos.filter((p) => !ids.includes(p.id));
			selected = new Set();
			selectMode = false;
			showToast('Восстановлено', 'success');
		} catch (err: any) {
			showToast(err?.message || 'Ошибка', 'danger');
		}
	}

	function requestEmpty() {
		if (!EMPTY_TRASH_API) {
			showToast('Очистка корзины: нужен API (см. docs/API_GAPS.md)', 'danger');
			emptyConfirm = false;
			return;
		}
	}
</script>

<div class="relative w-full">
	<div class="wall-toolbar">
		{#if photos.length > 0 && !selectMode}
			<button
				type="button"
				onclick={() => {
					selectMode = true;
					selected = new Set();
				}}
				class="btn-ghost">Выбрать</button
			>
		{/if}
		{#if photos.length > 0}
			<button type="button" onclick={() => (emptyConfirm = true)} class="btn-ghost" style="color: var(--danger)">
				Очистить
			</button>
		{/if}
	</div>

	{#if loading}
		<div class="photo-grid pt-14">
			{#each Array(6) as _}
				<div class="photo-tile skeleton-pulse opacity-70"></div>
			{/each}
		</div>
	{:else if error}
		<div class="px-4 pt-20">
			<ErrorState message={error} onretry={loadTrash} />
		</div>
	{:else if photos.length === 0}
		<div class="pt-20">
			<EmptyState message="Корзина пуста" />
		</div>
	{:else}
		<div class="photo-grid pt-14">
			{#each photos as photo}
				{@const isSel = selected.has(photo.id)}
				<div class="photo-tile opacity-70 hover:opacity-100 transition-opacity duration-[160ms] group">
					<AuthImage
						src={photoUrl(photo.id, true)}
						alt={photo.filename}
						class="w-full h-full object-cover"
					/>
					{#if selectMode}
						<button
							type="button"
							class="absolute inset-0"
							onclick={() => {
								const next = new Set(selected);
								if (next.has(photo.id)) next.delete(photo.id);
								else next.add(photo.id);
								selected = next;
							}}
							aria-label="Выбрать"
						>
							<span
								class="absolute top-1.5 right-1.5 w-6 h-6 rounded-[6px] border flex items-center justify-center
									{isSel
									? 'bg-[var(--accent)] border-[var(--accent)] text-[var(--accent-ink)]'
									: 'border-[var(--accent)] bg-black/40'}"
							>
								{#if isSel}<Icon name="check" size={14} />{/if}
							</span>
						</button>
					{:else}
						<div
							class="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-colors duration-[160ms] flex items-center justify-center opacity-0 group-hover:opacity-100"
						>
							<button
								type="button"
								onclick={() => handleRestore(photo.id)}
								class="h-10 px-4 bg-[var(--accent)] text-[var(--accent-ink)] rounded-[6px] text-sm font-medium flex items-center gap-2"
							>
								<Icon name="restore" size={16} />
								Восстановить
							</button>
						</div>
					{/if}
				</div>
			{/each}
		</div>
	{/if}

	{#if selectMode && selected.size > 0}
		<div
			class="fixed left-0 right-0 z-60 glass-chrome border-t border-[var(--hairline)] flex items-center gap-3 px-4 py-3 trash-select-bar"
			style="padding-bottom: max(0.75rem, env(safe-area-inset-bottom))"
		>
			<button
				type="button"
				class="text-sm text-[var(--muted)]"
				onclick={() => {
					selectMode = false;
					selected = new Set();
				}}>Отмена</button
			>
			<span class="text-sm font-semibold">{selected.size}</span>
			<button
				type="button"
				onclick={bulkRestore}
				class="ml-auto h-10 px-4 bg-[var(--accent)] text-[var(--accent-ink)] rounded-[6px] text-sm font-medium"
			>
				Восстановить
			</button>
		</div>
	{/if}
</div>

<ConfirmDialog
	open={emptyConfirm}
	title="Очистить корзину?"
	message={EMPTY_TRASH_API
		? 'Все фото будут удалены безвозвратно.'
		: 'API очистки корзины ещё нет. Кнопка зарезервирована (см. docs/API_GAPS.md).'}
	confirmLabel={EMPTY_TRASH_API ? 'Очистить' : 'Понятно'}
	onconfirm={requestEmpty}
	oncancel={() => (emptyConfirm = false)}
/>

<style>
	.trash-select-bar {
		bottom: 0;
	}
	@media (max-width: 767px) {
		.trash-select-bar {
			bottom: 56px;
		}
	}
</style>
