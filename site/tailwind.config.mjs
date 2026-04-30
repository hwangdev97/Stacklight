/** @type {import('tailwindcss').Config} */
export default {
  content: ["./src/**/*.{astro,html,js,jsx,ts,tsx,md,mdx}"],
  theme: {
    extend: {
      colors: {
        ink: "#0a0a0a",
        muted: "#6b6b6b",
        soft: "#a3a3a3",
        accent: "#0066ff",
        surface: "#fafafa",
        sunken: "#f4f4f5",
        hairline: "#e7e7e7",
        success: "#16a34a",
        danger: "#dc2626",
        building: "#f59e0b",
      },
      boxShadow: {
        card: "0 1px 0 rgba(10, 10, 10, 0.04), 0 6px 24px -12px rgba(10, 10, 10, 0.08)",
        menu: "0 12px 48px -16px rgba(10, 10, 10, 0.20), 0 2px 8px -2px rgba(10, 10, 10, 0.08)",
      },
      animation: {
        "pulse-slow": "pulse 2.5s cubic-bezier(0.4, 0, 0.6, 1) infinite",
      },
      fontFamily: {
        sans: [
          "-apple-system",
          "BlinkMacSystemFont",
          "SF Pro Display",
          "SF Pro Text",
          "Segoe UI",
          "Roboto",
          "sans-serif",
        ],
        mono: [
          "ui-monospace",
          "SFMono-Regular",
          "SF Mono",
          "Menlo",
          "Consolas",
          "monospace",
        ],
      },
      fontSize: {
        "display-xl": ["clamp(3rem, 7vw, 5.5rem)", { lineHeight: "1.05", letterSpacing: "-0.025em" }],
        "display-lg": ["clamp(2rem, 4vw, 3rem)", { lineHeight: "1.1", letterSpacing: "-0.02em" }],
        "display-md": ["clamp(1.5rem, 2.5vw, 2rem)", { lineHeight: "1.2", letterSpacing: "-0.015em" }],
      },
      maxWidth: {
        container: "1120px",
      },
      backgroundImage: {
        "hero-glow":
          "radial-gradient(ellipse 60% 50% at 50% 0%, rgba(0, 102, 255, 0.08), transparent 70%)",
      },
    },
  },
  plugins: [],
};
