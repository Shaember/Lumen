<script lang="ts">
	import { toasts } from '$lib/toast';
</script>

<div class="toast-host" aria-live="polite">
	{#each $toasts as t (t.id)}
		<div class="toast" class:danger={t.tone === 'danger'}>{t.text}</div>
	{/each}
</div>

<style>
	.toast-host {
		position: fixed;
		left: 50%;
		bottom: 1.25rem;
		transform: translateX(-50%);
		z-index: 200;
		display: flex;
		flex-direction: column;
		gap: 0.5rem;
		pointer-events: none;
		width: min(24rem, calc(100vw - 2rem));
	}
	.toast {
		background: var(--raised, #141414);
		border: 1px solid var(--hairline, rgba(232, 228, 217, 0.12));
		border-radius: 6px;
		color: var(--text, #f4f1ea);
		padding: 0.75rem 1rem;
		font-size: 0.875rem;
		box-shadow: 0 8px 24px rgba(0, 0, 0, 0.4);
		animation: toast-in 160ms ease-out;
	}
	.toast.danger {
		border-color: color-mix(in srgb, var(--danger, #e24b4b) 40%, transparent);
		color: var(--text, #f4f1ea);
	}
	@keyframes toast-in {
		from {
			opacity: 0;
			transform: translateY(8px);
		}
		to {
			opacity: 1;
			transform: translateY(0);
		}
	}
</style>
