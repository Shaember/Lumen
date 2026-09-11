import { writable } from 'svelte/store';

export type ToastMessage = {
	id: number;
	text: string;
	tone?: 'danger' | 'info';
};

let seq = 0;

export const toasts = writable<ToastMessage[]>([]);

export function showToast(text: string, tone: 'danger' | 'info' = 'danger') {
	const id = ++seq;
	toasts.update((list) => [...list, { id, text, tone }]);
	setTimeout(() => {
		toasts.update((list) => list.filter((t) => t.id !== id));
	}, 4000);
}
