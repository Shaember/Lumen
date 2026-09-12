<script lang="ts">
	import Icon from './Icon.svelte';

	interface Props {
		count: number;
		oncancel: () => void;
		onfavorite: () => void;
		onalbum: () => void;
		ondelete: () => void;
		favoriteLabel?: string;
		extra?: 'restore' | 'remove-album' | null;
		onextra?: () => void;
		extraLabel?: string;
		showFavorite?: boolean;
		showAlbum?: boolean;
	}

	let {
		count,
		oncancel,
		onfavorite,
		onalbum,
		ondelete,
		favoriteLabel = 'В избранное',
		extra = null,
		onextra,
		extraLabel = '',
		showFavorite = true,
		showAlbum = true
	}: Props = $props();
</script>

{#if count > 0}
	<div class="bar glass-chrome" role="toolbar" aria-label="Действия с выбранными">
		<button type="button" class="ghost" onclick={oncancel}>Отмена</button>
		<span class="count">{count}</span>
		<div class="actions">
			{#if showFavorite}
				<button type="button" class="act" onclick={onfavorite} title={favoriteLabel} aria-label={favoriteLabel}>
					<Icon name="heart" size={20} />
					<span class="label">{favoriteLabel}</span>
				</button>
			{/if}
			{#if showAlbum}
				<button type="button" class="act" onclick={onalbum} title="В альбом" aria-label="В альбом">
					<Icon name="albums" size={20} />
					<span class="label">В альбом</span>
				</button>
			{/if}
			{#if extra && onextra}
				<button type="button" class="act" onclick={onextra} title={extraLabel} aria-label={extraLabel}>
					<Icon name={extra === 'restore' ? 'restore' : 'close'} size={20} />
					<span class="label">{extraLabel}</span>
				</button>
			{/if}
			<button type="button" class="act danger" onclick={ondelete} title="Удалить" aria-label="Удалить">
				<Icon name="trash" size={20} />
				<span class="label">Удалить</span>
			</button>
		</div>
	</div>
{/if}

<style>
	.bar {
		position: fixed;
		left: 0;
		right: 0;
		bottom: 0;
		z-index: 60;
		display: flex;
		align-items: center;
		gap: 0.75rem;
		padding: 0.75rem 1rem;
		padding-bottom: max(0.75rem, env(safe-area-inset-bottom));
		border-top: 1px solid var(--hairline);
		min-height: 56px;
	}
	@media (max-width: 767px) {
		.bar {
			bottom: 56px;
		}
	}
	.ghost {
		background: transparent;
		border: none;
		color: var(--muted);
		font-size: 0.875rem;
		cursor: pointer;
		padding: 0.5rem;
	}
	.count {
		font-size: 0.875rem;
		color: var(--text);
		font-weight: 600;
		min-width: 1.5rem;
	}
	.actions {
		margin-left: auto;
		display: flex;
		gap: 0.25rem;
	}
	.act {
		display: flex;
		align-items: center;
		gap: 0.35rem;
		background: transparent;
		border: none;
		color: var(--text);
		cursor: pointer;
		padding: 0.5rem 0.65rem;
		border-radius: 6px;
		font-size: 0.8rem;
		min-height: 44px;
	}
	.act:hover {
		background: var(--raised-2);
	}
	.act.danger {
		color: var(--danger);
	}
	.label {
		display: none;
	}
	@media (min-width: 640px) {
		.label {
			display: inline;
		}
	}
</style>
