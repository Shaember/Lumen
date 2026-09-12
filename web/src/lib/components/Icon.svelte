<script lang="ts">
	type Name =
		| 'timeline'
		| 'albums'
		| 'heart'
		| 'heart-fill'
		| 'trash'
		| 'close'
		| 'chevron-left'
		| 'chevron-right'
		| 'check'
		| 'upload'
		| 'download'
		| 'share'
		| 'search'
		| 'more'
		| 'logout'
		| 'aperture'
		| 'plus'
		| 'restore'
		| 'select';

	interface Props {
		name: Name;
		size?: number;
		class?: string;
	}

	let { name, size = 22, class: className = '' }: Props = $props();

	const paths: Record<Name, string> = {
		/* photo/grid stroke — not hamburger */
		timeline:
			'M4 4h7v7H4V4zm9 0h7v7h-7V4zM4 13h7v7H4v-7zm9 0h7v7h-7v-7z',
		albums:
			'M4 7a2 2 0 012-2h8a2 2 0 012 2v10a2 2 0 01-2 2H6a2 2 0 01-2-2V7zm4-3h8a2 2 0 012 2v1',
		heart:
			'M12 21s-7-4.5-9.5-8.5C.5 9 2.5 5.5 6 5.5c2 0 3.5 1.2 4 2.5.5-1.3 2-2.5 4-2.5 3.5 0 5.5 3.5 3.5 7C19 16.5 12 21 12 21z',
		'heart-fill':
			'M12 21s-7-4.5-9.5-8.5C.5 9 2.5 5.5 6 5.5c2 0 3.5 1.2 4 2.5.5-1.3 2-2.5 4-2.5 3.5 0 5.5 3.5 3.5 7C19 16.5 12 21 12 21z',
		trash:
			'M5 7h14M10 11v6M14 11v6M8 7V5a1 1 0 011-1h6a1 1 0 011 1v2M6 7l1 12a2 2 0 002 2h6a2 2 0 002-2l1-12',
		close: 'M6 6l12 12M18 6L6 18',
		'chevron-left': 'M15 6l-6 6 6 6',
		'chevron-right': 'M9 6l6 6-6 6',
		check: 'M5 12l5 5L19 7',
		upload: 'M12 16V5M8 9l4-4 4 4M5 19h14',
		download: 'M12 5v11M8 12l4 4 4-4M5 19h14',
		share: 'M12 14V4M8 7l4-4 4 4M5 14v4a1 1 0 001 1h12a1 1 0 001-1v-4',
		search: 'M11 11a5 5 0 110-10 5 5 0 010 10zm0 0l7 7',
		more: 'M6 12h.01M12 12h.01M18 12h.01',
		logout: 'M10 5H6a1 1 0 00-1 1v12a1 1 0 001 1h4M14 16l4-4-4-4M18 12H10',
		aperture:
			'M12 3a9 9 0 100 18 9 9 0 000-18zm0 6a3 3 0 110 6 3 3 0 010-6zM12 3v3M12 18v3M3 12h3M18 12h3',
		plus: 'M12 5v14M5 12h14',
		restore: 'M4 12a8 8 0 111.5 4.75M4 12V7m0 5h5',
		select: 'M9 11l3 3L22 4M21 12v7a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2h11'
	};
</script>

<svg
	class={className}
	width={size}
	height={size}
	viewBox="0 0 24 24"
	fill={name === 'heart-fill' ? 'currentColor' : 'none'}
	stroke="currentColor"
	stroke-width="1.6"
	stroke-linecap="round"
	stroke-linejoin="round"
	aria-hidden="true"
>
	<path d={paths[name]} />
</svg>
