// App.tsx — Port of RootView.swift
// Hosts the store and the curtain-reveal layer stack.
// Key motions:
//   • Composer opens → canvas scales to 0.92, blurs 15px, white wash 0.5 (springCanvas)
//   • Launch sequence → canvas fades out while card-swap overlay runs (springMorph)
//   • Reveal scrub → CurtainSheet morphs from full → collapsed trip card
//   • Detail tap → PackageDetailView hero morph (springDetailMorph)

import React, { useCallback } from 'react';
import { AnimatePresence, motion } from 'framer-motion';
import {
  useAppStore,
  selectIsEmpty,
  selectOpenThread,
  stageTrip,
  launchBlackoutEnd,
  launchSwapEnd,
} from './store/appStore';
import { Theme } from './theme/theme';
import { progress, eased, lerp } from './morph/morphProgress';
import EmptySearchView from './views/EmptySearchView';
import TripOverviewView from './views/TripOverviewView';
import CurtainSheet from './views/CurtainSheet';
import ComposerView from './views/ComposerView';
import NavHeader from './views/NavHeader';
import PackageDetailView from './views/PackageDetailView';
import type { ResultCard } from './data/mockData';

const CARD_SCALE = 0.92;

const App: React.FC = () => {
  const store = useAppStore();
  const isEmpty = useAppStore(selectIsEmpty);
  const openThread = useAppStore(selectOpenThread);

  const {
    composerActive,
    composerEntrance,
    composerReveal,
    launching,
    launchPhase,
    launch,
    launchFromCurrent,
    homeSubmitLoading,
    openThreadID,
    showHome,
    canvasDismissing,
    openDetailCard,
    detailCard,
    teardown,
    setReveal,
  } = store;

  const showHome_ = isEmpty || showHome;

  // Siri-style canvas transform when composer is active
  const composerShrink = (composerActive) || (launching && launchFromCurrent && launchPhase === 'collapsing');
  const canvasScale = composerShrink ? CARD_SCALE : 1;
  const canvasBlur = composerShrink ? 15 : 0;
  const canvasWash = composerShrink ? 0.5 : 0;
  const canvasCorner = composerShrink ? 34 / CARD_SCALE : 0;
  const canvasShadow = composerShrink ? 0.28 : 0;

  // Launch blackout fades the canvas
  const blackingOut = launching && launchFromCurrent && launchPhase === 'collapsing';
  const blackoutP = progress(launch, 0, launchBlackoutEnd);
  const canvasLaunchOpacity = blackingOut ? lerp(1, 0, eased(blackoutP)) : 1;

  // composerReveal scrubs the canvas behind full-screen composer
  const composerRevealFade = lerp(1, 0, eased(progress(composerReveal, 0.45, 1.0)));
  const canvasOpacity = canvasLaunchOpacity * composerRevealFade;

  // Homepage launch entrance animation
  const homeLaunchEntrance = launching && !launchFromCurrent && launchPhase === 'expanding';
  const homeLaunchP = progress(launch, launchSwapEnd, 1.0);
  const homeCanvasOpacity = homeLaunchEntrance ? lerp(0, 1, eased(homeLaunchP)) : 1;
  const homeCanvasOffset = homeLaunchEntrance ? lerp(48, 0, eased(homeLaunchP)) : 0;

  const handleCardClick = useCallback((card: ResultCard) => {
    openDetailCard(card);
  }, [openDetailCard]);

  // SpringCanvas vs springMorph for the canvas transform animation
  const canvasTransition = {
    duration: launching ? 0.75 : 0.5,
    ease: (launching ? [0.75, 0, 0, 1] : [0.42, 0, 0.58, 1]) as [number, number, number, number],
  };

  return (
    <div style={{
      position: 'relative',
      width: '100vw',
      height: '100vh',
      overflow: 'hidden',
      background: Theme.ink,
    }}>
      {/* Warm backdrop behind the shrunk canvas */}
      <div style={{
        position: 'absolute',
        inset: 0,
        background: 'white',
        opacity: composerActive || launching ? 1 : 0,
        transition: 'opacity 0.22s ease',
        pointerEvents: 'none',
        zIndex: 1,
      }} />

      {/* ---- Live canvas (L0) ---- */}
      <motion.div
        animate={{
          scale: canvasScale,
          filter: `blur(${canvasBlur}px)`,
          opacity: canvasOpacity,
          borderRadius: canvasCorner,
        }}
        transition={canvasTransition}
        style={{
          position: 'absolute',
          inset: 0,
          transformOrigin: 'top center',
          overflow: 'hidden',
          boxShadow: canvasShadow > 0
            ? `0 10px 24px rgba(0,0,0,${canvasShadow})`
            : undefined,
          zIndex: 2,
        }}
      >
        {/* White wash overlay when composer is open */}
        <div style={{
          position: 'absolute',
          inset: 0,
          background: 'white',
          opacity: canvasWash,
          pointerEvents: 'none',
          zIndex: 100,
          transition: `opacity 0.5s cubic-bezier(0.42,0,0.58,1)`,
        }} />

        {/* Dismiss slide-down */}
        <div style={{
          position: 'absolute',
          inset: 0,
          transform: canvasDismissing ? 'translateY(100vh)' : 'translateY(0)',
          transition: canvasDismissing ? 'transform 0.55s cubic-bezier(0.75,0,0,1)' : undefined,
        }}>
          {/* Background: home or trip overview */}
          <AnimatePresence mode="wait">
            {showHome_ ? (
              <motion.div
                key="home"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.22, ease: 'easeOut' }}
                style={{ position: 'absolute', inset: 0 }}
              >
                <EmptySearchView />
              </motion.div>
            ) : !launching ? (
              <motion.div
                key="trip"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.22, ease: 'easeOut' }}
                style={{ position: 'absolute', inset: 0 }}
              >
                <TripOverviewView />
              </motion.div>
            ) : null}
          </AnimatePresence>

          {/* Canvas: map + curtain when a thread is open */}
          <AnimatePresence>
            {openThreadID != null && openThread != null && !canvasDismissing && (
              <motion.div
                key={`canvas-${openThreadID}`}
                initial={{ opacity: 0 }}
                animate={{
                  opacity: homeCanvasOpacity,
                  y: homeCanvasOffset,
                }}
                exit={{ opacity: 0, y: 32 }}
                transition={{ duration: 0.75, ease: [0.75, 0, 0, 1] }}
                style={{
                  position: 'absolute',
                  inset: 0,
                  display: 'flex',
                }}
              >
                {/* Left: map */}
                {openThread.showsMap && (
                  <div
                    className="map-bg"
                    style={{
                      flex: 1,
                      position: 'relative',
                      overflow: 'hidden',
                    }}
                  >
                    <MapPlaceholder destination={openThread.destination} />
                  </div>
                )}

                {/* Right: results curtain */}
                <div style={{
                  width: openThread.showsMap ? 440 : '100%',
                  position: 'relative',
                  flexShrink: 0,
                  background: '#fff',
                  borderLeft: openThread.showsMap
                    ? '1px solid rgba(12,14,28,0.07)'
                    : undefined,
                }}>
                  <CurtainSheet
                    thread={openThread}
                    onCardClick={handleCardClick}
                  />
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Bottom dock */}
          <AnimatePresence>
            {!showHome_ && !launching && (
              <motion.div
                key="dock"
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: composerEntrance > 0.02 ? 0 : 1, y: 0 }}
                exit={{ opacity: 0, y: 20 }}
                transition={{ duration: 0.75, ease: [0.75, 0, 0, 1] }}
                style={{
                  position: 'absolute',
                  bottom: 0,
                  left: 0,
                  right: openThread?.showsMap ? 440 : 0,
                  zIndex: 10,
                  pointerEvents: composerEntrance > 0.02 ? 'none' : 'all',
                }}
              >
                <BottomDock />
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </motion.div>

      {/* ---- Nav header (unscaled, above canvas) ---- */}
      <AnimatePresence>
        {!showHome_ && !launching && (
          <motion.div
            key="nav"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.22, ease: 'easeInOut' }}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              right: openThread?.showsMap ? 440 : 0,
              zIndex: 16,
              pointerEvents: 'none',
            }}
          >
            <NavHeader />
          </motion.div>
        )}
      </AnimatePresence>

      {/* ---- Composer sheet ---- */}
      <AnimatePresence>
        {composerActive && (
          <div
            key="composer"
            style={{ position: 'absolute', inset: 0, zIndex: 15, pointerEvents: 'none' }}
          >
            <ComposerView />
          </div>
        )}
      </AnimatePresence>

      {/* ---- Homepage loading overlay ---- */}
      <AnimatePresence>
        {((launching && !launchFromCurrent) || homeSubmitLoading) && (
          <motion.div
            key="homeLoading"
            initial={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.55, ease: 'easeOut' }}
            style={{
              position: 'absolute',
              inset: 0,
              zIndex: 20,
              background: Theme.ink,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <LoadingOverlay />
          </motion.div>
        )}
      </AnimatePresence>

      {/* ---- Card-swap overlay (canvas → canvas launch) ---- */}
      <AnimatePresence>
        {launching && launchFromCurrent && store.swapOutThreadID != null && (
          <div
            key="cardSwap"
            style={{
              position: 'absolute',
              inset: 0,
              zIndex: 20,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              pointerEvents: 'none',
            }}
          >
            <SwapCard threadID={store.swapOutThreadID} />
          </div>
        )}
      </AnimatePresence>

      {/* ---- Package detail (top layer) ---- */}
      <AnimatePresence>
        {detailCard && (
          <div key="detail" style={{ position: 'absolute', inset: 0, zIndex: 30 }}>
            <PackageDetailView />
          </div>
        )}
      </AnimatePresence>
    </div>
  );
};

// ---- Sub-components ----

const BottomDock: React.FC = () => {
  const { openComposer, dismissCanvasToHome, setReveal, teardown, openThreadID } = useAppStore();

  return (
    <div style={{ padding: '0 28px 28px' }}>
      <div style={{
        position: 'absolute',
        bottom: 0,
        left: 0,
        right: 0,
        height: 120,
        background: 'linear-gradient(0deg, rgba(0,0,0,0.1) 0%, transparent 100%)',
        pointerEvents: 'none',
      }} />
      <div style={{
        display: 'flex',
        alignItems: 'center',
        gap: 14,
        position: 'relative',
      }}>
        <CircleBtn onClick={() => openThreadID ? dismissCanvasToHome() : undefined} title="Home">
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none">
            <path d="M3 12L12 3l9 9" stroke={Theme.ink} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            <path d="M5 10v9a1 1 0 001 1h4v-5h4v5h4a1 1 0 001-1v-9" stroke={Theme.ink} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </CircleBtn>

        <button
          onClick={() => openComposer()}
          className="glass-pill"
          style={{
            flex: 1,
            height: 44,
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            paddingInline: 18,
            cursor: 'pointer',
            border: 'none',
          }}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" style={{ opacity: 0.5 }}>
            <circle cx="11" cy="11" r="7" stroke={Theme.ink} strokeWidth="2.2"/>
            <path d="M16.5 16.5L21 21" stroke={Theme.ink} strokeWidth="2.2" strokeLinecap="round"/>
          </svg>
          <span style={{
            fontSize: 14,
            fontWeight: 500,
            color: Theme.inkMuted,
            letterSpacing: '-0.01em',
          }}>
            Ask or follow up
          </span>
        </button>

        <CircleBtn
          onClick={() => { setReveal(stageTrip); setTimeout(() => teardown(), 800); }}
          title="Trips"
        >
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none">
            <path d="M9 11l3 3L22 4" stroke={Theme.ink} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            <path d="M21 12v7a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2h11" stroke={Theme.ink} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </CircleBtn>
      </div>
    </div>
  );
};

const CircleBtn: React.FC<{ onClick?: () => void; title?: string; children: React.ReactNode }> = ({
  onClick, title, children,
}) => (
  <button
    className="glass-pill"
    onClick={onClick}
    title={title}
    style={{
      width: 44,
      height: 44,
      borderRadius: '50%',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      flexShrink: 0,
      cursor: 'pointer',
      border: 'none',
      transition: 'transform 80ms ease-out',
    }}
    onMouseDown={e => { (e.currentTarget as HTMLElement).style.transform = 'scale(0.93)'; }}
    onMouseUp={e => { (e.currentTarget as HTMLElement).style.transform = ''; }}
    onMouseLeave={e => { (e.currentTarget as HTMLElement).style.transform = ''; }}
  >
    {children}
  </button>
);

const MapPlaceholder: React.FC<{ destination: string }> = ({ destination }) => (
  <div style={{
    position: 'absolute',
    inset: 0,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 12,
    opacity: 0.45,
  }}>
    <svg width="48" height="48" viewBox="0 0 24 24" fill="none">
      <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z" stroke={Theme.ink} strokeWidth="1.5"/>
      <circle cx="12" cy="10" r="3" stroke={Theme.ink} strokeWidth="1.5"/>
    </svg>
    <span style={{ fontSize: 16, fontWeight: 600, color: Theme.ink, letterSpacing: '-0.01em' }}>
      {destination}
    </span>
    <span style={{ fontSize: 12, color: Theme.inkMuted }}>Map coming soon</span>
  </div>
);

const LoadingOverlay: React.FC = () => (
  <div style={{
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 24,
  }}>
    <DotGridLoading />
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.3, duration: 0.4, ease: 'easeOut' }}
      style={{
        fontSize: 12,
        fontWeight: 600,
        color: 'rgba(255,255,255,0.5)',
        letterSpacing: '0.1em',
        textTransform: 'uppercase',
      }}
    >
      Searching…
    </motion.div>
  </div>
);

const DotGridLoading: React.FC = () => {
  const cols = 9, rows = 6;
  return (
    <div style={{
      display: 'grid',
      gridTemplateColumns: `repeat(${cols}, 7px)`,
      gap: 14,
    }}>
      {Array.from({ length: cols * rows }).map((_, i) => (
        <motion.div
          key={i}
          initial={{ scale: 0.4, opacity: 0.15 }}
          animate={{ scale: [0.4, 1, 0.4], opacity: [0.15, 0.9, 0.15] }}
          transition={{
            duration: 1.4,
            ease: 'easeInOut',
            delay: (i % cols) * 0.035 + Math.floor(i / cols) * 0.06,
            repeat: Infinity,
          }}
          style={{
            width: 7,
            height: 7,
            borderRadius: '50%',
            background: 'rgba(255,255,255,0.6)',
          }}
        />
      ))}
    </div>
  );
};

const SwapCard: React.FC<{ threadID: string }> = ({ threadID }) => {
  const thread = useAppStore(s => s.threads.find(t => t.id === threadID));
  const launch = useAppStore(s => s.launch);

  if (!thread) return null;

  const popP = progress(launch, launchBlackoutEnd, launchSwapEnd * 0.55);
  const swapP = progress(launch, launchSwapEnd * 0.55, launchSwapEnd);

  const opacity = lerp(0, 1, eased(popP)) * lerp(1, 0, eased(swapP));
  const scale = lerp(0.94, 1, eased(popP)) * lerp(1, 0.97, eased(swapP));
  const blurVal = lerp(12, 0, eased(popP)) + lerp(0, 6, eased(swapP));
  const translateY = 18 * (1 - eased(popP)) - 12 * eased(swapP);

  return (
    <div style={{
      width: 340,
      background: '#fff',
      borderRadius: 24,
      padding: '16px 20px',
      opacity,
      transform: `scale(${scale}) translateY(${translateY}px)`,
      filter: `blur(${blurVal}px)`,
      boxShadow: Theme.cardShadow,
      display: 'flex',
      alignItems: 'center',
      gap: 14,
    }}>
      <div style={{
        width: 52,
        height: 52,
        borderRadius: 14,
        overflow: 'hidden',
        background: '#eee',
        flexShrink: 0,
      }}>
        <img
          src={thread.heroImage}
          alt=""
          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
        />
      </div>
      <div>
        <div style={{
          fontSize: 10,
          fontWeight: 700,
          color: Theme.inkMuted,
          textTransform: 'uppercase',
          letterSpacing: '0.12em',
          marginBottom: 3,
        }}>
          Results
        </div>
        <div style={{
          fontSize: 16,
          fontWeight: 700,
          color: Theme.ink,
          letterSpacing: '-0.02em',
        }}>
          {thread.title}
        </div>
      </div>
    </div>
  );
};

export default App;
