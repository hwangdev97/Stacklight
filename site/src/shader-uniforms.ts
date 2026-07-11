// Single source of truth for the hero mesh-gradient shader uniforms.
// Imported by both Hero.astro (runtime mount on desktop) and the
// scripts/bake-hero-gradient.mjs headless bake (static asset for iOS).
// When colors / wave params change here, re-run `npm run bake:hero`.

export const HERO_SHADER_COLORS = ["#ff3a8c", "#7a1fff", "#ff6ad5", "#ffd1ec"] as const;

export const HERO_SHADER_PARAMS = {
  u_colorsCount: HERO_SHADER_COLORS.length,
  u_positions: 2,
  u_waveX: 1,
  u_waveXShift: 0.6,
  u_waveY: 1,
  u_waveYShift: 0.21,
  u_mixing: 0.93,
  u_grainMixer: 0.15,
  u_grainOverlay: 0.06,
  // Sizing — fit:cover, neutral transform. Note: u_fit must be set at call-site
  // to ShaderFitOptions.cover (imported from @paper-design/shaders).
  u_scale: 1,
  u_rotation: 270,
  u_originX: 0.5,
  u_originY: 0.5,
  u_offsetX: 0,
  u_offsetY: 0,
  u_worldWidth: 0,
  u_worldHeight: 0,
} as const;
