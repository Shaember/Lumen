<script lang="ts">
	import { goto } from '$app/navigation';
	import { tokens, setup, login } from '$lib/api/client';
	import { onMount } from 'svelte';

	let isSetup = $state(false);
	let username = $state('');
	let password = $state('');
	let confirmPassword = $state('');
	let serverURL = $state('');
	let error = $state('');
	let loading = $state(false);
	let focusedField = $state('');
	let checkingSetup = $state(true);

	onMount(async () => {
		tokens.load();
		if (tokens.getAccessToken()) {
			goto('/photos');
			return;
		}
		serverURL = window.location.origin;
		
		// Check if we need setup or login
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
		checkingSetup = false;
	});

	async function handleSubmit() {
		loading = true;
		error = '';
		
		try {
			if (isSetup) {
				// Validate passwords match
				if (password !== confirmPassword) {
					error = 'Passwords do not match';
					loading = false;
					return;
				}
				if (password.length < 8) {
					error = 'Password must be at least 8 characters';
					loading = false;
					return;
				}
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

<div class="min-h-screen flex items-center justify-center bg-[var(--bg-primary)] px-4">
	<div class="w-full max-w-sm">
		<!-- Logo -->
		<div class="flex flex-col items-center mb-10">
			<div class="w-20 h-20 rounded-full bg-[var(--accent)] flex items-center justify-center mb-5">
				<svg class="w-10 h-10 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
					<path stroke-linecap="round" stroke-linejoin="round" d="M6.827 6.175A2.31 2.31 0 015.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 002.25 2.25h15A2.25 2.25 0 0021.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 00-1.134-.175 2.31 2.31 0 01-1.64-1.055l-.822-1.316a2.192 2.192 0 00-1.736-1.039 48.774 48.774 0 00-5.232 0 2.192 2.192 0 00-1.736 1.039l-.821 1.316z" />
					<path stroke-linecap="round" stroke-linejoin="round" d="M16.5 12.75a4.5 4.5 0 11-9 0 4.5 4.5 0 019 0zM18.75 10.5h.008v.008h-.008V10.5z" />
				</svg>
			</div>
			<h1 class="text-3xl font-bold text-[var(--text-primary)] tracking-tight">Lumen</h1>
			<p class="text-sm text-[var(--text-secondary)] mt-2">
				{#if checkingSetup}
					Checking setup...
				{:else if isSetup}
					Create your admin account
				{:else}
					Your photos, your server
				{/if}
			</p>
		</div>

		{#if !checkingSetup}
			<!-- Form -->
			<form onsubmit={handleSubmit} class="space-y-4">
				<!-- Server URL (readonly) -->
				<div class="relative">
					<div class="absolute left-3.5 top-1/2 -translate-y-1/2 text-[var(--text-secondary)]">
						<svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
							<path stroke-linecap="round" stroke-linejoin="round" d="M12 21a9.004 9.004 0 008.716-6.747M12 21a9.004 9.004 0 01-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 017.843 4.582M12 3a8.997 8.997 0 00-7.843 4.582m15.686 0A11.953 11.953 0 0112 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0121 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0112 16.5c-3.162 0-6.133-.815-8.716-2.247m0 0A9.015 9.015 0 013 12c0-1.605.42-3.113 1.157-4.418" />
						</svg>
					</div>
					<input
						type="text"
						value={serverURL}
						readonly
						class="w-full pl-11 pr-4 py-3.5 bg-[var(--bg-secondary)] border border-[var(--border)] rounded-xl text-[var(--text-primary)] text-sm focus:outline-none focus:border-[var(--accent)] transition-colors cursor-not-allowed opacity-70"
					/>
				</div>

				<!-- Username -->
				<div class="relative">
					<div class="absolute left-3.5 top-1/2 -translate-y-1/2 text-[var(--text-secondary)]">
						<svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
							<path stroke-linecap="round" stroke-linejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
						</svg>
					</div>
					<input
						type="text"
						bind:value={username}
						onfocus={() => focusedField = 'username'}
						onblur={() => focusedField = ''}
						required
						placeholder="Username"
						class="w-full pl-11 pr-4 py-3.5 bg-[var(--bg-secondary)] border rounded-xl text-[var(--text-primary)] text-sm focus:outline-none transition-colors placeholder:text-[var(--text-secondary)]/50
							{focusedField === 'username' ? 'border-[var(--accent)]' : 'border-[var(--border)]'}"
					/>
				</div>

				<!-- Password -->
				<div class="relative">
					<div class="absolute left-3.5 top-1/2 -translate-y-1/2 text-[var(--text-secondary)]">
						<svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
							<path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
						</svg>
					</div>
					<input
						type="password"
						bind:value={password}
						onfocus={() => focusedField = 'password'}
						onblur={() => focusedField = ''}
						required
						minlength="8"
						placeholder="Password (min 8 characters)"
						class="w-full pl-11 pr-4 py-3.5 bg-[var(--bg-secondary)] border rounded-xl text-[var(--text-primary)] text-sm focus:outline-none transition-colors placeholder:text-[var(--text-secondary)]/50
							{focusedField === 'password' ? 'border-[var(--accent)]' : 'border-[var(--border)]'}"
					/>
				</div>

				<!-- Confirm Password (setup only) -->
				{#if isSetup}
					<div class="relative">
						<div class="absolute left-3.5 top-1/2 -translate-y-1/2 text-[var(--text-secondary)]">
							<svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="1.5">
								<path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
							</svg>
						</div>
						<input
							type="password"
							bind:value={confirmPassword}
							onfocus={() => focusedField = 'confirmPassword'}
							onblur={() => focusedField = ''}
							required
							minlength="8"
							placeholder="Confirm password"
							class="w-full pl-11 pr-4 py-3.5 bg-[var(--bg-secondary)] border rounded-xl text-[var(--text-primary)] text-sm focus:outline-none transition-colors placeholder:text-[var(--text-secondary)]/50
								{focusedField === 'confirmPassword' ? 'border-[var(--accent)]' : 'border-[var(--border)]'}"
						/>
					</div>
				{/if}

				{#if error}
					<div class="flex items-center gap-2 px-3 py-2 bg-red-500/10 border border-red-500/20 rounded-xl">
						<svg class="w-4 h-4 text-red-400 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
							<path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
						</svg>
						<p class="text-red-400 text-sm">{error}</p>
					</div>
				{/if}

				<button
					type="submit"
					disabled={loading || username.length < 1 || password.length < 8 || (isSetup && password !== confirmPassword)}
					class="w-full py-3.5 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-white rounded-xl text-sm font-semibold transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed mt-2"
				>
					{#if loading}
						<div class="flex items-center justify-center gap-2">
							<div class="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
							<span>{isSetup ? 'Creating account...' : 'Signing in...'}</span>
						</div>
					{:else if isSetup}
						Create Admin Account
					{:else}
						Sign In
					{/if}
				</button>
			</form>

			<!-- Toggle setup/login -->
			{#if !isSetup}
				<p class="text-center text-xs text-[var(--text-secondary)] mt-6">
					First time? 
					<button 
						type="button"
						onclick={() => isSetup = true}
						class="text-[var(--accent)] hover:underline"
					>
						Create admin account
					</button>
				</p>
			{:else}
				<p class="text-center text-xs text-[var(--text-secondary)] mt-6">
					Already have an account? 
					<button 
						type="button"
						onclick={() => isSetup = false}
						class="text-[var(--accent)] hover:underline"
					>
						Sign in
					</button>
				</p>
			{/if}
		{:else}
			<!-- Loading state -->
			<div class="flex justify-center">
				<div class="w-8 h-8 border-2 border-[var(--accent)] border-t-transparent rounded-full animate-spin"></div>
			</div>
		{/if}

		<!-- Footer -->
		<p class="text-center text-xs text-[var(--text-secondary)] mt-8">
			Self-hosted photo backup
		</p>
	</div>
</div>
