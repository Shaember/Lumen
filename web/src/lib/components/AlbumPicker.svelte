<script lang="ts">
	import { listAlbums, createAlbum, type Album } from '$lib/api/client';
	import { showToast } from '$lib/toast';

	interface Props {
		open: boolean;
		onpick: (albumId: number) => void;
		oncancel: () => void;
	}

	let { open, onpick, oncancel }: Props = $props();
	let albums = $state<Album[]>([]);
	let loading = $state(false);
	let newName = $state('');

	$effect(() => {
		if (open) load();
	});

	async function load() {
		loading = true;
		try {
			albums = await listAlbums();
		} catch (e: any) {
			showToast(e?.message || 'Не удалось загрузить альбомы', 'danger');
		}
		loading = false;
	}

	async function handleCreate(e: Event) {
		e.preventDefault();
		if (!newName.trim()) return;
		try {
			const a = await createAlbum(newName.trim());
			newName = '';
			onpick(a.id);
		} catch (err: any) {
			showToast(err?.message || 'Не удалось создать альбом', 'danger');
		}
	}
</script>

{#if open}
	<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
	<div class="backdrop" onclick={oncancel} role="presentation">
		<div class="sheet" role="dialog" tabindex="-1" aria-modal="true" onclick={(e) => e.stopPropagation()}>
			<h2>В альбом</h2>
			{#if loading}
				<p class="muted">Загрузка…</p>
			{:else}
				<ul>
					{#each albums as album}
						<li>
							<button type="button" onclick={() => onpick(album.id)}>{album.name}</button>
						</li>
					{/each}
				</ul>
				<form onsubmit={handleCreate} class="create">
					<input type="text" bind:value={newName} placeholder="Новый альбом" />
					<button type="submit">Создать</button>
				</form>
			{/if}
			<button type="button" class="cancel" onclick={oncancel}>Отмена</button>
		</div>
	</div>
{/if}

<style>
	.backdrop {
		position: fixed;
		inset: 0;
		z-index: 110;
		background: var(--overlay);
		display: flex;
		align-items: flex-end;
		justify-content: center;
		padding: 1rem;
	}
	@media (min-width: 640px) {
		.backdrop {
			align-items: center;
		}
	}
	.sheet {
		width: 100%;
		max-width: 22rem;
		background: var(--raised);
		border: 1px solid var(--hairline);
		border-radius: 8px;
		padding: 1.25rem;
	}
	h2 {
		margin: 0 0 0.75rem;
		font-size: 1rem;
		font-weight: 600;
	}
	.muted {
		color: var(--muted);
		font-size: 0.875rem;
	}
	ul {
		list-style: none;
		margin: 0;
		padding: 0;
		max-height: 40vh;
		overflow: auto;
	}
	li button {
		width: 100%;
		text-align: left;
		padding: 0.75rem;
		background: transparent;
		border: none;
		border-bottom: 1px solid var(--hairline);
		color: var(--text);
		cursor: pointer;
		font-size: 0.9rem;
		min-height: 44px;
	}
	li button:hover {
		background: var(--raised-2);
	}
	.create {
		display: flex;
		gap: 0.5rem;
		margin-top: 0.75rem;
	}
	.create input {
		flex: 1;
		height: 44px;
		padding: 0 0.75rem;
		background: var(--bg);
		border: 1px solid var(--hairline);
		border-radius: 6px;
		color: var(--text);
	}
	.create button {
		height: 44px;
		padding: 0 0.875rem;
		background: var(--accent);
		color: var(--accent-ink);
		border: none;
		border-radius: 6px;
		cursor: pointer;
		font-size: 0.875rem;
	}
	.cancel {
		margin-top: 0.75rem;
		width: 100%;
		height: 44px;
		background: transparent;
		border: 1px solid var(--hairline);
		border-radius: 6px;
		color: var(--muted);
		cursor: pointer;
	}
</style>
