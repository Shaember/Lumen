<script lang="ts">
	import { goto } from '$app/navigation';
	import { tokens, setup, login } from '$lib/api/client';
	import { onMount } from 'svelte';
	import Icon from '$lib/components/Icon.svelte';

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

	async function handleSubmit(e: Event) {
		e.preventDefault();
		loading = true;
		error = '';

		try {
			if (isSetup) {
				if (password !== confirmPassword) {
					error = 'Пароли не совпадают';
					loading = false;
					return;
				}
				if (password.length < 8) {
					error = 'Пароль не короче 8 символов';
					loading = false;
					return;
				}
				await setup(username, password);
				await login(username, password);
			} else {
				await login(username, password);
			}
			goto('/photos');
		} catch (err: any) {
			error = err.message || 'Ошибка входа';
		} finally {
			loading = false;
		}
	}

	const fieldClass = (name: string) =>
		`w-full h-12 px-3 bg-[var(--raised)] border rounded-[6px] text-[var(--text)] text-sm focus:outline-none transition-colors duration-[160ms] placeholder:text-[var(--muted)]/60 ${
			focusedField === name ? 'border-[var(--accent)]' : 'border-[var(--hairline)]'
		}`;
</script>

<div class="min-h-screen flex items-center justify-center bg-[var(--bg)] px-4">
	<div class="w-full max-w-[360px]">
		<div class="flex flex-col items-center mb-10">
			<div class="mb-5 text-[var(--accent)]">
				<Icon name="aperture" size={48} />
			</div>
			<h1 class="text-3xl font-semibold text-[var(--text)] tracking-tight" style="letter-spacing: -0.02em">
				Lumen
			</h1>
			<p class="text-sm text-[var(--muted)] mt-2">
				{#if checkingSetup}
					Проверка…
				{:else if isSetup}
					Создайте учётную запись администратора
				{:else}
					Your photos, your server
				{/if}
			</p>
		</div>

		{#if !checkingSetup}
			<form onsubmit={handleSubmit} class="space-y-3">
				<input type="text" value={serverURL} readonly class="{fieldClass('')} opacity-70 cursor-not-allowed" />

				<input
					type="text"
					bind:value={username}
					onfocus={() => (focusedField = 'username')}
					onblur={() => (focusedField = '')}
					required
					placeholder="Имя пользователя"
					class={fieldClass('username')}
				/>

				<input
					type="password"
					bind:value={password}
					onfocus={() => (focusedField = 'password')}
					onblur={() => (focusedField = '')}
					required
					minlength="8"
					placeholder="Пароль (мин. 8)"
					class={fieldClass('password')}
				/>

				{#if isSetup}
					<input
						type="password"
						bind:value={confirmPassword}
						onfocus={() => (focusedField = 'confirm')}
						onblur={() => (focusedField = '')}
						required
						minlength="8"
						placeholder="Повторите пароль"
						class={fieldClass('confirm')}
					/>
				{/if}

				{#if error}
					<div class="px-3 py-2 border border-[var(--hairline)] rounded-[6px] text-[var(--danger)] text-sm">
						{error}
					</div>
				{/if}

				<button
					type="submit"
					disabled={loading || username.length < 1 || password.length < 8 || (isSetup && password !== confirmPassword)}
					class="w-full h-11 bg-[var(--accent)] hover:bg-[var(--accent-hover)] text-[var(--accent-ink)] rounded-[6px] text-sm font-semibold transition-opacity duration-[160ms] disabled:opacity-40 disabled:cursor-not-allowed mt-1"
				>
					{#if loading}
						{isSetup ? 'Создание…' : 'Вход…'}
					{:else if isSetup}
						Создать аккаунт
					{:else}
						Войти
					{/if}
				</button>
			</form>

			{#if !isSetup}
				<p class="text-center text-xs text-[var(--muted)] mt-6">
					Первый раз?
					<button type="button" onclick={() => (isSetup = true)} class="text-[var(--accent)] hover:underline">
						Создать аккаунт
					</button>
				</p>
			{:else}
				<p class="text-center text-xs text-[var(--muted)] mt-6">
					Уже есть аккаунт?
					<button type="button" onclick={() => (isSetup = false)} class="text-[var(--accent)] hover:underline">
						Войти
					</button>
				</p>
			{/if}
		{:else}
			<div class="flex justify-center">
				<div class="w-8 h-8 rounded-[6px] skeleton-pulse"></div>
			</div>
		{/if}
	</div>
</div>
