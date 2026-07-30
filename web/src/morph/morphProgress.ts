// morphProgress.ts — Port of MorphProgress.swift
// Windowed 0…1 driver: maps a raw progress value through a sub-window and
// provides eased, midPeak, fadeIn, fadeOut, lerp helpers exactly like the iOS source.

/** Map rawProgress through the window [start…end] → [0…1], clamped. */
export function progress(raw: number, start: number, end: number): number {
  if (end <= start) return raw >= end ? 1 : 0;
  return Math.max(0, Math.min(1, (raw - start) / (end - start)));
}

/** Ease-in-out cubic (matches SwiftUI .easeInOut for windowed smoothstep) */
export function eased(t: number): number {
  return t * t * (3 - 2 * t); // smoothstep
}

/** Peaks at 0.5, is 0 at both ends — used for mid-morph blur. */
export function midPeak(t: number): number {
  return 1 - Math.abs(2 * t - 1);
}

/** 0→1 fade-in over the full range */
export function fadeIn(t: number): number {
  return eased(t);
}

/** 1→0 fade-out over the full range */
export function fadeOut(t: number): number {
  return eased(1 - t);
}

/** Linear interpolation */
export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

/** Rect lerp for morphing between two DOMRect positions */
export function lerpRect(
  a: DOMRect | null,
  b: DOMRect | null,
  t: number
): { x: number; y: number; width: number; height: number } {
  const ea = a ?? new DOMRect(0, 0, 0, 0);
  const eb = b ?? new DOMRect(0, 0, 0, 0);
  return {
    x: lerp(ea.x, eb.x, t),
    y: lerp(ea.y, eb.y, t),
    width: lerp(ea.width, eb.width, t),
    height: lerp(ea.height, eb.height, t),
  };
}

/** Smooth Hermite step — 0 below lo, 1 above hi, smooth S-curve between. */
export function smoothstep(lo: number, hi: number, x: number): number {
  const t = Math.max(0, Math.min(1, (x - lo) / (hi - lo)));
  return t * t * (3 - 2 * t);
}

/** Ramp: linear 0→1 between lo and hi. */
export function ramp(lo: number, hi: number, x: number): number {
  return Math.max(0, Math.min(1, (x - lo) / (hi - lo)));
}

/**
 * MorphProgress object — mirrors Swift's windowed driver.
 * Given a global driver value and a [start, end] window, exposes all the
 * same computed properties used in the SwiftUI source.
 */
export class MorphProgress {
  readonly raw: number;
  readonly t: number;

  constructor(driver: number, start: number, end: number) {
    this.raw = driver;
    this.t = progress(driver, start, end);
  }

  get eased(): number { return eased(this.t); }
  get midPeak(): number { return midPeak(this.t); }
  get fadeIn(): number { return fadeIn(this.t); }
  get fadeOut(): number { return fadeOut(this.t); }

  lerp(a: number, b: number): number { return lerp(a, b, this.eased); }
}
