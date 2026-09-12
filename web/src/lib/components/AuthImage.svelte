<script lang="ts">
	import { onDestroy } from 'svelte';
	import { fetchMediaObjectUrl, invalidateMediaCache } from '$lib/media';

	interface Props {
		src: string;
		alt?: string;
		class?: string;
		style?: string;
		loading?: 'lazy' | 'eager';
	}

	let { src, alt = '', class: className = '', style = '', loading = 'lazy' }: Props = $props();

	let objectUrl = $state<string | null>(null);
	let failed = $state(false);
	let loadingImg = $state(true);
	let generation = 0;

	async function load() {
		const gen = ++generation;
		loadingImg = true;
		failed = false;
		objectUrl = null;
		try {
			const url = await fetchMediaObjectUrl(src);
			if (gen !== generation) return;
			objectUrl = url;
			failed = false;
		} catch {
			if (gen !== generation) return;
			failed = true;
			objectUrl = null;
		} finally {
			if (gen === generation) loadingImg = false;
		}
	}

	$effect(() => {
		src;
		load();
	});

	async function retry() {
		invalidateMediaCache(src);
		await load();
	}

	onDestroy(() => {
		generation++;
	});
</script>

{#if failed}
	<button type="button" onclick={retry} class="auth-img-fail {className}" title="Повторить" {style}>
		<span>не загрузилось</span>
	</button>
{:else if objectUrl}
	<img src={objectUrl} {alt} {loading} class={className} {style} />
{:else if loadingImg}
	<div class="auth-img-loading skeleton-pulse {className}" aria-hidden="true" {style}></div>
{/if}

<style>
	.auth-img-fail {
		display: flex;
		align-items: center;
		justify-content: center;
		width: 100%;
		height: 100%;
		min-height: 4rem;
		background: var(--raised, #141414);
		border: 1px solid var(--hairline, rgba(232, 228, 217, 0.12));
		border-radius: 0;
		color: var(--muted, #8a8578);
		font-size: 0.75rem;
		cursor: pointer;
		padding: 0.5rem;
		text-align: center;
	}
	.auth-img-fail:hover {
		color: var(--text, #f4f1ea);
	}
	.auth-img-loading {
		width: 100%;
		height: 100%;
		min-height: 4rem;
		background: var(--raised, #141414);
		border-radius: 0;
	}
</style>
