import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: '#EE2020',
          dark: '#B31818',
          darker: '#8F1313',
          light: '#FDE9E9',
          deep: '#530B0B',
        },
      },
    },
  },
  plugins: [],
};
export default config;
