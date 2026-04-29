import { defineConfig } from "astro/config";
import tailwind from "@astrojs/tailwind";

export default defineConfig({
  site: "https://stacklight.pages.dev",
  integrations: [tailwind({ applyBaseStyles: false })],
});
