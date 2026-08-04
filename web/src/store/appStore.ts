// appStore.ts — Port of AppStore.swift to Zustand
// Single source of truth. A continuous `reveal` (0 Results · 1 Overview · 2 Trip)
// drives the curtain morph; the views frame-interpolate against it.

import { create } from 'zustand';
import { MOCK_THREADS } from '../data/mockData';
import type { Thread, ResultCard } from '../data/mockData';

// ---- reveal stages (matches AppStore.swift static lets) ----
export const stageResults = 0;
export const stageOverview = 1;
export const stageTrip = 2;

// ---- launch windows on the 0…1 driver ----
export const launchBlackoutEnd = 0.18;
export const launchCollapseEnd = 0.34;
export const launchSwapEnd = 0.62;
export const launchLoadFadeStart = 0.72;
export const launchLoadFadeEnd = 0.92;

// ---- beat durations (ms) ----
export const launchClearBeat = 780;
export const launchCardPopBeat = 80;
export const launchSwapToExpandBeat = 260;
export const minLoadDuration = 4500;
export const launchLoadFloor = 500;

export type LaunchPhase = 'collapsing' | 'expanding';

export interface AppState {
  // ---- threads / navigation ----
  threads: Thread[];
  openThreadID: string | null;
  showHome: boolean;
  canvasDismissing: boolean;
  lastOpenThreadID: string | null;

  // ---- reveal driver (0=results, 1=overview, 2=trip) ----
  reveal: number;
  /** morphReveal: during a launch this is derived from the launch driver */
  morphReveal: number;

  // ---- composer state ----
  composerActive: boolean;
  /** 0=closed, 1=fully docked/open */
  composerEntrance: number;
  /** 0=docked, 1=full takeover */
  composerReveal: number;
  composerPrompt: string;

  // ---- launch state ----
  launching: boolean;
  launchPhase: LaunchPhase;
  /** 0…1 continuous driver for the launch sequence */
  launch: number;
  launchFromCurrent: boolean;
  /** Thread IDs for the card-swap overlay */
  swapOutThreadID: string | null;
  swapInThreadID: string | null;

  // ---- loading ----
  isLoading: boolean;
  homeSubmitLoading: boolean;
  loadingQuery: string;

  // ---- detail card ----
  detailCard: ResultCard | null;
  detailReveal: number;

  // ---- inline answer / conversation ----
  inlineAnswerDraft: string | null;
  openConversation: string | null;

  // ---- pill / follow-up ----
  followUpPillRect: DOMRect | null;

  // ---- map ----
  mapCoverage: number;
  mapSplitRequest: number;

  // ---- actions ----
  setReveal: (v: number) => void;
  openThreadByID: (id: string) => void;
  dismissCanvasToHome: () => void;
  goHome: () => void;
  teardown: () => void;
  openComposer: (prompt?: string) => void;
  closeComposer: () => void;
  setComposerReveal: (v: number) => void;
  submitQuery: (query: string) => void;
  openDetailCard: (card: ResultCard) => void;
  closeDetailCard: () => void;
  setMapCoverage: (v: number) => void;
  setFollowUpPillRect: (r: DOMRect | null) => void;
}

// Selectors (computed values as pure functions of state)
export const selectIsEmpty = (s: AppState) => s.threads.length === 0;
export const selectOpenThread = (s: AppState): Thread | null =>
  s.threads.find(t => t.id === s.openThreadID) ?? null;

export const useAppStore = create<AppState>()((set, get) => ({
  // ---- initial state ----
  threads: [],
  openThreadID: null,
  showHome: false,
  canvasDismissing: false,
  lastOpenThreadID: null,

  reveal: stageResults,
  morphReveal: stageResults,

  composerActive: false,
  composerEntrance: 0,
  composerReveal: 0,
  composerPrompt: 'Ask or follow up',

  launching: false,
  launchPhase: 'collapsing',
  launch: 0,
  launchFromCurrent: false,
  swapOutThreadID: null,
  swapInThreadID: null,

  isLoading: false,
  homeSubmitLoading: false,
  loadingQuery: '',

  detailCard: null,
  detailReveal: 0,

  inlineAnswerDraft: null,
  openConversation: null,

  followUpPillRect: null,

  mapCoverage: 0,
  mapSplitRequest: 0,

  // ---- actions ----
  setReveal: (v) => set({ reveal: v, morphReveal: v }),

  openThreadByID: (id) => {
    const thread = get().threads.find(t => t.id === id);
    if (!thread) return;
    set({
      openThreadID: id,
      reveal: stageResults,
      morphReveal: stageResults,
      showHome: false,
    });
  },

  dismissCanvasToHome: () => {
    set({ canvasDismissing: true, showHome: true });
    setTimeout(() => {
      set({
        canvasDismissing: false,
        openThreadID: null,
        reveal: stageResults,
        morphReveal: stageResults,
      });
    }, 600);
  },

  goHome: () => {
    set({ showHome: true, openThreadID: null });
  },

  teardown: () => {
    set({
      openThreadID: null,
      reveal: stageResults,
      morphReveal: stageResults,
      launching: false,
    });
  },

  openComposer: (prompt) => {
    set({
      composerActive: true,
      composerEntrance: 0,
      composerPrompt: prompt ?? get().composerPrompt,
    });
    requestAnimationFrame(() => {
      set({ composerEntrance: 1 });
    });
  },

  closeComposer: () => {
    set({ composerEntrance: 0 });
    setTimeout(() => {
      set({ composerActive: false, composerReveal: 0 });
    }, 800);
  },

  setComposerReveal: (v) => set({ composerReveal: v }),

  submitQuery: (query: string) => {
    const { threads, openThreadID } = get();
    const fromCurrent = threads.length > 0 && openThreadID !== null;

    const existing = MOCK_THREADS.find(
      t => t.query.toLowerCase().includes(query.toLowerCase().split(' ')[0])
    );
    const newThread = existing ?? MOCK_THREADS[0];
    const threadToAdd = { ...newThread, id: `t-${Date.now()}` };

    set(state => ({
      composerActive: false,
      composerEntrance: 0,
      composerReveal: 0,
      launching: true,
      launchPhase: 'collapsing',
      launchFromCurrent: fromCurrent,
      launch: 0,
      swapOutThreadID: fromCurrent ? openThreadID : null,
      swapInThreadID: threadToAdd.id,
      homeSubmitLoading: !fromCurrent,
      loadingQuery: query,
      isLoading: true,
      // Pre-mount thread + canvas immediately so MapView animates during loading
      threads: [threadToAdd, ...state.threads.filter(t => t.id !== threadToAdd.id)],
      openThreadID: threadToAdd.id,
      lastOpenThreadID: threadToAdd.id,
      showHome: false,
    }));

    const start = Date.now();
    const totalDuration = fromCurrent
      ? launchClearBeat + launchCardPopBeat + launchSwapToExpandBeat + 600
      : minLoadDuration;

    const tick = () => {
      const elapsed = Date.now() - start;
      const raw = Math.min(1, elapsed / totalDuration);
      const phase: LaunchPhase = raw < launchSwapEnd ? 'collapsing' : 'expanding';

      set({
        launch: raw,
        launchPhase: phase,
        morphReveal: raw < launchSwapEnd ? stageResults : stageResults + (raw - launchSwapEnd) / (1 - launchSwapEnd),
      });

      if (raw < 1) {
        requestAnimationFrame(tick);
      } else {
        set({
          launching: false,
          launchPhase: 'expanding',
          launch: 1,
          morphReveal: stageResults,
          reveal: stageResults,
          isLoading: false,
          homeSubmitLoading: false,
          swapOutThreadID: null,
          swapInThreadID: null,
        });
      }
    };
    requestAnimationFrame(tick);
  },

  openDetailCard: (card) => {
    set({ detailCard: card, detailReveal: 0 });
    requestAnimationFrame(() => {
      set({ detailReveal: 1 });
    });
  },

  closeDetailCard: () => {
    set({ detailReveal: 0 });
    setTimeout(() => set({ detailCard: null }), 1600);
  },

  setMapCoverage: (v) => set({ mapCoverage: v }),
  setFollowUpPillRect: (r) => set({ followUpPillRect: r }),
}));
