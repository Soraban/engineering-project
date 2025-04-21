import type { Config } from "tailwindcss";

export default {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ["Inter", "sans-serif"],
      },
      fontSize: {
        "5xl": "40px",
      },
      fontWeight: {
        heavy: "900",
      },
      colors: {
        background: "var(--background)",
        foreground: "var(--foreground)",
        black: "#0D0D0D",
        primary: "#4EA8DE",
        secondary: "#5E60CE",
        blue: "#1E6F9F",
        gray: {
          100: "#F2F2F2",
          200: "#D9D9D9",
          300: "#D4D4D4",
          400: "#A3A3A3",
          500: "#808080",
          600: "#333333",
          700: "#1A1A1A",
          750: "#262626",
          800: "#262626",
          900: "#171717",
        },
      },
    },
  },
  plugins: [],
} satisfies Config;
