<script lang="ts">
	interface Props {
		open: boolean;
		title?: string;
		message: string;
		confirmLabel?: string;
		cancelLabel?: string;
		danger?: boolean;
		onconfirm: () => void;
		oncancel: () => void;
	}

	let {
		open,
		title = 'Confirm',
		message,
		confirmLabel = 'Delete',
		cancelLabel = 'Cancel',
		danger = true,
		onconfirm,
		oncancel
	}: Props = $props();
</script>

{#if open}
	<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
	<div class="backdrop" onclick={oncancel} role="presentation">
		<div
			class="sheet"
			role="dialog" tabindex="-1"
			aria-modal="true"
			aria-labelledby="confirm-title"
			onclick={(e) => e.stopPropagation()}
		>
			<h2 id="confirm-title" class="title">{title}</h2>
			<p class="msg">{message}</p>
			<div class="actions">
				<button type="button" class="btn ghost" onclick={oncancel}>{cancelLabel}</button>
				<button type="button" class="btn {danger ? 'danger' : 'primary'}" onclick={onconfirm}>
					{confirmLabel}
				</button>
			</div>
		</div>
	</div>
{/if}

<style>
	.backdrop {
		position: fixed;
		inset: 0;
		z-index: 100;
		background: rgba(0, 0, 0, 0.55);
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 1rem;
	}
	.sheet {
		width: 100%;
		max-width: 22rem;
		background: var(--raised, #141414);
		border: 1px solid var(--hairline, rgba(232, 228, 217, 0.12));
		border-radius: 8px;
		padding: 1.25rem;
	}
	.title {
		margin: 0 0 0.5rem;
		font-size: 1rem;
		font-weight: 600;
		color: var(--text, #f4f1ea);
	}
	.msg {
		margin: 0 0 1.25rem;
		font-size: 0.875rem;
		color: var(--muted, #8a8578);
		line-height: 1.4;
	}
	.actions {
		display: flex;
		justify-content: flex-end;
		gap: 0.5rem;
	}
	.btn {
		border-radius: 6px;
		padding: 0.5rem 0.875rem;
		font-size: 0.875rem;
		border: 1px solid transparent;
		cursor: pointer;
	}
	.ghost {
		background: transparent;
		color: var(--muted, #8a8578);
		border-color: var(--hairline, rgba(232, 228, 217, 0.12));
	}
	.danger {
		background: var(--danger, #e24b4b);
		color: #fff;
	}
	.primary {
		background: var(--accent, #e8e4d9);
		color: #0a0a0a;
	}
</style>
