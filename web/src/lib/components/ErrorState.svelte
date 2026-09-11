<script lang="ts">
	interface Props {
		message?: string;
		onretry: () => void;
	}

	let { message = 'Что-то пошло не так', onretry }: Props = $props();
</script>

<div class="error-box" role="alert">
	<p>{message}</p>
	<button type="button" onclick={onretry}>Повторить</button>
</div>

<style>
	.error-box {
		margin: 2rem auto;
		max-width: 28rem;
		padding: 1rem 1.25rem;
		border: 1px solid var(--hairline, rgba(232, 228, 217, 0.12));
		border-radius: 8px;
		background: transparent;
		color: var(--danger, #e24b4b);
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 1rem;
	}
	error-box p {
		margin: 0;
		font-size: 0.875rem;
	}
	button {
		flex-shrink: 0;
		border-radius: 6px;
		padding: 0.4rem 0.75rem;
		border: 1px solid var(--danger, #e24b4b);
		background: transparent;
		color: var(--danger, #e24b4b);
		font-size: 0.8rem;
		cursor: pointer;
		min-height: 44px;
	}
	button:hover {
		background: color-mix(in srgb, var(--danger, #e24b4b) 15%, transparent);
	}
</style>
