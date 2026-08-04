// theme.ts — Design tokens ported 1:1 from Theme.swift
// Motion curves match the Framer-origin CSS cubic-beziers in the iOS source.

export const Theme = {
  // ---- colors ----
  ink: '#0C0E1C',
  inkMuted: 'rgba(12,14,28,0.5)',
  cardItem: '#F7F4F3',
  canvasFilterChipFill: '#F9F7F6',
  figmaChipFill: 'rgba(12,14,28,0.05)',
  darkBG: '#000000',
  darkSurface: 'rgba(255,255,255,0.05)',
  cardSurface: 'rgb(30,33,50)',
  darkText: '#ffffff',
  darkTextMuted: 'rgba(255,255,255,0.5)',
  glassTint: 'rgb(233,239,248)',
  onSurfaceVariant: '#676A7D',
  pillGlow: 'rgba(193,201,214,0.25)',

  // ---- corner radii ----
  radiusCard: 32,
  radiusChip: 100,
  radiusPill: 300,
  radiusHotelCard: 24,
  radiusHotelImage: 16,

  // ---- shadows ----
  cardShadow: '0 2.5px 25px rgba(0,0,0,0.25)',
  hotelCardShadow: '0 6px 18px rgba(0,0,0,0.08)',

  // ---- motion curves ----
  // Primary: screen depth-stack transitions & shared-element card morphs.
  // Framer {stiffness:320, damping:34, mass:0.9} → critically damped ~333ms
  springPrimary: 'cubic-bezier(0.48, 0.1, 0.22, 1)',
  springPrimaryDuration: 333,

  // Softer: lighter content. SPRING_SOFT (260, 30, 1)
  springSoft: 'cubic-bezier(0.42, 0.1, 0.24, 1)',
  springSoftDuration: 390,

  // Large surface morphs (pill ↔ panel, sheet slide, canvas ↔ card).
  // Hard accel, no overshoot — kinder to the map during morphs.
  springMorph: 'cubic-bezier(0.75, 0, 0, 1)',
  springMorphDuration: 750,

  // Mexico → Cancun map fly — same curve, slower.
  mapFly: 'cubic-bezier(0.75, 0, 0, 1)',
  mapFlyDuration: 1000,

  // Composer-initiated card swap — same curve, 2× longer.
  springMorphCardSwap: 'cubic-bezier(0.75, 0, 0, 1)',
  springMorphCardSwapDuration: 1500,

  // Package-detail hero morph — long, gentle ease.
  springDetailMorph: 'cubic-bezier(0.4, 0, 0.18, 1)',
  springDetailMorphDuration: 1550,

  // Siri-style canvas shrink — critically damped, no overshoot.
  springCanvas: 'cubic-bezier(0.42, 0, 0.58, 1)',
  springCanvasDuration: 500,

  // Sheet drag interactive spring — snappy release
  interactiveSpring: 'cubic-bezier(0.32, 0.72, 0, 1)',
  interactiveSpringDuration: 480,

  // Short crossfade
  fade: 'ease-in-out',
  fadeDuration: 180,

  // Blur radii for mid-morph
  morphBlurRadius: 3.5,
  canvasMorphBlurRadius: 6.5,
  canvasLaunchSettleBlurRadius: 9,
} as const;

// Helper: build a CSS transition string
export function transition(
  prop: string,
  curve: string,
  durationMs: number,
  delayMs = 0
): string {
  return `${prop} ${durationMs}ms ${curve}${delayMs ? ` ${delayMs}ms` : ''}`;
}

// Helper: build multiple CSS transition strings
export function transitions(
  entries: [string, string, number, number?][]
): string {
  return entries
    .map(([p, c, d, delay]) => transition(p, c, d, delay))
    .join(', ');
}

// ── Framer Motion spring presets ──────────────────────────────────────────────
export const spring = {
  std:    { type: 'spring' as const, stiffness: 380, damping: 34 },
  snap:   { type: 'spring' as const, stiffness: 500, damping: 38 },
  gentle: { type: 'spring' as const, stiffness: 260, damping: 30 },
};

// ── Easing helpers ────────────────────────────────────────────────────────────
export const ease = {
  out:   [0.25, 0.46, 0.45, 0.94] as [number,number,number,number],
  inOut: [0.42, 0, 0.58, 1]       as [number,number,number,number],
  morph: [0.75, 0, 0, 1]          as [number,number,number,number],
};

// ── Glass surface tokens ──────────────────────────────────────────────────────
export const glass = {
  card: {
    background:          'rgba(255,255,255,0.82)',
    backdropFilter:      'blur(20px) saturate(1.8)',
    WebkitBackdropFilter:'blur(20px) saturate(1.8)',
    border:              '1px solid rgba(255,255,255,0.5)',
    boxShadow:           '0 2.5px 25px rgba(0,0,0,0.12), 0 0 0 1px rgba(193,201,214,0.25) inset',
  },
  pill: {
    background:          'rgba(255,255,255,0.88)',
    backdropFilter:      'blur(20px) saturate(1.8)',
    WebkitBackdropFilter:'blur(20px) saturate(1.8)',
    border:              '1px solid rgba(255,255,255,0.5)',
    boxShadow:           '0 2px 12px rgba(0,0,0,0.08)',
  },
  elevated: {
    background:          'rgba(255,255,255,0.92)',
    backdropFilter:      'blur(32px) saturate(1.8)',
    WebkitBackdropFilter:'blur(32px) saturate(1.8)',
    border:              '1px solid rgba(255,255,255,0.6)',
    boxShadow:           '0 8px 32px rgba(12,14,28,0.12), 0 1px 0 rgba(255,255,255,0.9) inset',
  },
};
