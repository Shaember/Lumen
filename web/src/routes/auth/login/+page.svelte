<script lang="ts">
	import { goto } from '$app/navigation';
	import { tokens, setup, login } from '$lib/api/client';
	import { onMount } from 'svelte';

	let isSetup = $state(true);
	let username = $state('');
	let password = $state('');
	let error = $state('');
	let loading = $state(false);

	onMount(async () => {
		tokens.load();
		if (tokens.getAccessToken()) {
			goto('/photos');
			return;
		}
		try {
			const res = await fetch('/api/v1/auth/login', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ username: '', password: '' })
			});
			const data = await res.json();
			if (res.status === 403 && data.error?.includes('no users')) {
				isSetup = true;
			} else {
				isSetup = false;
			}
		} catch {
			isSetup = true;
		}
	});

	async function handleSubmit() {
		loading = true;
		error = '';
		try {
			if (isSetup) {
				await setup(username, password);
				await login(username, password);
			} else {
				await login(username, password);
			}
			goto('/photos');
		} catch (e: any) {
			error = e.message;
		} finally {
			loading = false;
		}
	}
</script>

<div class="min-h-screen flex items-center justify-center px-4">
	<div class="w-full max-w-sm">
		<h1 class="text-2xl font-semibold text-center mb-8">Lumen</h1>
		<form onsubmit={handleSubmit} class="space-y-4">
			<div>
				<label for="username" class="block text-sm text-[var(--text-secondary)] mb-1">Username</label>
				<input
					id="username"
					type="text"
					bind:value={username}
					required
					class="w-full px-3 py-2 bg-[var(--bg-secondary)] border border-[var(--border)] rounded-lg text-[var(--text-primary)] focus:outline-none focus:border-[var(--accent)]"
				/>
			</div>
			<div>
				<label for="password" class="block text-sm text-[var(--text-secondary)] mb-1">Password</label>
				<input
					id="password"
					type="password"
					bind:value={password}
					required
					minlength="8"
					class="w-full px-3 py-2 bg-[var(--bg-secondary)] border border-[var(--border)] rounded-lg text-[var(--text-primary)] focus:outline-none focus:border-[var(--accent)]"
				/>
			</div>
			{#if error}
				<p class="text-red-400 text-sm">{error}</p>
			{/if}
			<button
				type="submit"
				disabled={loading}
				class="w-full py-2 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-white rounded-lg transition-colors disabled:opacity-50"
			>
				{#if loading}
					Loading...
				{:else if isSetup}
					Create Admin Account
				{:else}
					Sign In
				{/if}
			</button>
		</form>
	</div>
</div>
