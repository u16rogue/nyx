{{! CLANKER EDITED: the output of `sv create` with adapter-bun instead of adapter-auto, ./do sets its output and build options }}
import adapter from '@sveltejs/adapter-bun';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [
		sveltekit({
			compilerOptions: {
				// Force runes mode for the project, except for libraries. Can be removed in svelte 6.
				runes: ({ filename }) =>
					filename.split(/[/\\]/).includes('node_modules') ? undefined : true
			},
			// set by ./do
			adapter: adapter({
				out: process.env.ADAPTER_OUT || '.build/adapter',
				buildOptions: JSON.parse(process.env.ADAPTER_BUILD_OPTIONS || '{}')
			})
		})
	]
});
