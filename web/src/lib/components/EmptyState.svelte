<script lang="ts">
	interface Props {
		message: string;
		ctaLabel?: string;
		oncta?: () => void;
		href?: string;
	}

	let { message, ctaLabel, oncta, href }: Props = $props();
</script>

<div class="empty">
	<p>{message}</p>
	{#if ctaLabel && href}
		<a {href} class="cta">{ctaLabel}</a>
	{:else if ctaLabel && oncta}
		<button type="button" class="cta" onclick={oncta}>{ctaLabel}</button>
	{/if}
</div>

<style>
	.empty {
		text-align: center;
		padding: 5rem 1rem;
		color: var(--muted, #8a8578);
	}
	.empty p {
		margin: 0 0 1rem;
		font-size: 0.95rem;
	}
	.cta {
		display: inline-block;
		padding: 0.5rem 1rem;
		border-radius: 6px;
		background: var(--accent, #e8e4d9);
		color: #0a0a0a;
		font-size: 0.875rem;
		border: none;
		cursor: pointer;
		text-decoration: none;
	}
</style>
