import { Resvg } from "@resvg/resvg-js";
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const publicDir = resolve(here, "..", "public");

function render(svgFile, outFile, width) {
  const svg = readFileSync(resolve(publicDir, svgFile), "utf8");
  const resvg = new Resvg(svg, {
    fitTo: { mode: "width", value: width },
    font: { loadSystemFonts: true },
  });
  const png = resvg.render().asPng();
  const outPath = resolve(publicDir, outFile);
  writeFileSync(outPath, png);
  console.log(`Wrote ${outFile} (${(png.byteLength / 1024).toFixed(1)} KB, ${width}px wide)`);
}

render("og.svg", "og.png", 1200);
render("favicon.svg", "apple-touch-icon.png", 180);
