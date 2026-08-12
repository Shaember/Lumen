<script lang="ts">
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';

	onMount(() => {
		goto('/photos');
	});
</script>

<div class="min-h-screen flex items-center justify-center">
	<p class="text-[var(--text-secondary)]">Redirecting...</p>
</div>
