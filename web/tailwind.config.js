/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  corePlugins: { preflight: false },
  theme: { extend: {
    colors: { surface: '#090c17', raised: '#121729', accent: '#9956ed', border: 'rgba(173,126,255,.22)', muted: '#aaa6b7', control: '#29203c' },
    boxShadow: { focus: '0 0 0 3px rgba(189,130,255,.65)', device: '0 30px 100px #000c' },
    screens: { compact: { max: '700px' } },
  } },
  plugins: [],
}
