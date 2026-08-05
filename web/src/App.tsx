// App.tsx — Port of RootView.swift
// Hosts the store and the curtain-reveal layer stack.
// Key motions:
//   • Composer opens → canvas scales to 0.92, blurs 15px, white wash 0.5 (springCanvas)
//   • Launch sequence → canvas fades out while card-swap overlay runs (springMorph)
//   • Reveal scrub → CurtainSheet morphs from full → collapsed trip card
//   • Detail tap → PackageDetailView hero morph (springDetailMorph)

import React, { useCallback, useRef, useState } from 'react';
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
import SearchResultsView from './views/SearchResultsView';
import MapView from './views/MapView';
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

  const [selectedMapCard, setSelectedMapCard] = useState<ResultCard | null>(null);
  const [splitRatio, setSplitRatio] = useState(0.5); // 0..1, left panel fraction
  const isDraggingDivider = useRef(false);
  const [askExpanded, setAskExpanded] = useState(false);
  const [askText, setAskText] = useState('');
  const askInputRef = useRef<HTMLInputElement>(null);
  const { submitQuery: storeSubmitQuery } = useAppStore();
  const handleAskSubmit = (text: string) => {
    const q = text.trim();
    if (!q) return;
    setAskText('');
    setAskExpanded(false);
    storeSubmitQuery(q);
  };

  const handleCardClick = useCallback((card: ResultCard) => {
    // Toggle the map pin popup instead of opening a detail page
    setSelectedMapCard(prev => prev?.id === card.id ? null : card);
  }, []);

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

        {/* Canvas wrapper — no dismiss transform, handled per-layer */}
        <div style={{ position: 'absolute', inset: 0 }}>
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
                initial={{ opacity: 1, y: 0 }}
                animate={{
                  opacity: canvasDismissing ? 0 : homeCanvasOpacity,
                  y: canvasDismissing ? 24 : homeCanvasOffset,
                  scale: canvasDismissing ? 0.97 : 1,
                  filter: canvasDismissing ? 'blur(4px)' : 'blur(0px)',
                }}
                exit={{ opacity: 0, y: 24, scale: 0.97 }}
                transition={
                  canvasDismissing
                    ? { duration: 0.42, ease: [0.4, 0, 0.2, 1] }
                    : { duration: 0.75, ease: [0.75, 0, 0, 1] }
                }
                style={{
                  position: 'absolute',
                  inset: 0,
                  display: 'flex',
                }}
              >
                {/* Left: results + embedded resize handle */}
                <div style={{
                  width: openThread.showsMap ? `${splitRatio * 100}%` : '100%',
                  flexShrink: 0,
                  position: 'relative',
                  background: '#fff',
                  borderRight: openThread.showsMap ? '1px solid rgba(12,14,28,0.07)' : undefined,
                }}>
                  <SearchResultsView
                    thread={openThread}
                    onCardClick={handleCardClick}
                  />
                  {/* Resize handle — lives inside left sheet, at its right edge */}
                  {openThread.showsMap && (
                    <div
                      onMouseDown={e => {
                        e.preventDefault();
                        isDraggingDivider.current = true;
                        const onMove = (mv: MouseEvent) => {
                          if (!isDraggingDivider.current) return;
                          const pct = mv.clientX / window.innerWidth;
                          setSplitRatio(Math.min(0.75, Math.max(0.25, pct)));
                        };
                        const onUp = () => {
                          isDraggingDivider.current = false;
                          window.removeEventListener('mousemove', onMove);
                          window.removeEventListener('mouseup', onUp);
                        };
                        window.addEventListener('mousemove', onMove);
                        window.addEventListener('mouseup', onUp);
                      }}
                      style={{
                        position: 'absolute',
                        top: 0, right: 0, bottom: 0,
                        width: 20,
                        cursor: 'col-resize',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'flex-end',
                        paddingRight: 6,
                        zIndex: 10,
                      }}
                    >
                      <div style={{
                        width: 3,
                        height: 36,
                        borderRadius: 99,
                        background: 'rgba(12,14,28,0.1)',
                      }} />
                    </div>
                  )}
                </div>

                {/* Right: map */}
                {openThread.showsMap && (
                  <div
                    className="map-bg"
                    style={{
                      flex: 1,
                      position: 'relative',
                      overflow: 'hidden',
                    }}
                  >
                    <MapView
                      destination={openThread.destination}
                      cards={openThread.results}
                      onPinClick={handleCardClick}
                      selectedCard={selectedMapCard}
                      onSelectedCardChange={setSelectedMapCard}
                      ready={!homeSubmitLoading}
                    />
                  </div>
                )}
              </motion.div>
            )}
          </AnimatePresence>

        </div>
      </motion.div>

      {/* Nav header removed — SearchResultsView has its own header */}

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
            variants={{
              initial: { opacity: 0, y: 12, scale: 1 },
              enter: {
                opacity: 1,
                y: 0,
                scale: 1,
                transition: { type: 'spring', stiffness: 320, damping: 34 },
              },
              exit: {
                opacity: 0,
                scale: 0.97,
                y: 0,
                transition: { duration: 0.45, ease: [0.42, 0, 0.58, 1] as [number, number, number, number] },
              },
            }}
            initial="initial"
            animate="enter"
            exit="exit"
            style={{
              position: 'absolute',
              inset: 0,
              zIndex: 20,
            }}
          >
            <LoadingOverlay />
          </motion.div>
        )}
      </AnimatePresence>

      {/* ── Ask anything — full-page bottom center ── */}
      <AnimatePresence>
        {openThreadID != null && !homeSubmitLoading && (
          <motion.div
            key="ask-anything"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 20 }}
            transition={{ type: 'spring', stiffness: 400, damping: 36, delay: 0.4 }}
            style={{
              position: 'absolute',
              bottom: 20,
              left: 0,
              right: 0,
              marginLeft: 'auto',
              marginRight: 'auto',
              width: 'min(560px, calc(100vw - 48px))',
              zIndex: 25,
              pointerEvents: 'all',
              fontFamily: "'Centra No2', -apple-system, sans-serif",
            }}
          >
            <AnimatePresence mode="wait" initial={false}>
              {!askExpanded ? (
                <motion.button
                  key="pill"
                  initial={{ opacity: 0, scale: 0.97 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.97 }}
                  transition={{ duration: 0.18, ease: [0.25, 0.46, 0.45, 0.94] }}
                  whileHover={{ scale: 1.015 }}
                  whileTap={{ scale: 0.975 }}
                  onClick={() => { setAskExpanded(true); setTimeout(() => askInputRef.current?.focus(), 50); }}
                  style={{
                    width: '100%', height: 50, borderRadius: 999,
                    border: '1px solid white',
                    background: 'linear-gradient(179.99deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.5) 95.923%), linear-gradient(90deg, rgba(247,244,243,0.9) 0%, rgba(247,244,243,0.9) 100%)',
                    backdropFilter: 'blur(15px)', WebkitBackdropFilter: 'blur(15px)',
                    boxShadow: '0 12px 32px rgba(12,14,28,0.12)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    cursor: 'pointer', padding: '12px 8px',
                  }}
                >
                  <span style={{ fontFamily: "'Centra No2', -apple-system, sans-serif", fontSize: 14, fontWeight: 400, color: 'rgba(12,14,28,0.5)', whiteSpace: 'nowrap', lineHeight: '18px' }}>
                    Ask anything
                  </span>
                </motion.button>
              ) : (
                <motion.div
                  key="expanded"
                  initial={{ opacity: 0, scale: 0.97 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.97 }}
                  transition={{ duration: 0.18, ease: [0.25, 0.46, 0.45, 0.94] }}
                  style={{
                    borderRadius: 20,
                    border: '1px solid rgba(12,14,28,0.08)',
                    background: 'rgba(255,255,255,0.95)',
                    backdropFilter: 'blur(40px)', WebkitBackdropFilter: 'blur(40px)',
                    boxShadow: '0 12px 40px rgba(12,14,28,0.14)',
                    padding: '20px 24px',
                    display: 'flex', flexDirection: 'column', gap: 14,
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <input
                      ref={askInputRef}
                      value={askText}
                      onChange={e => setAskText(e.target.value)}
                      onKeyDown={e => {
                        if (e.key === 'Enter') handleAskSubmit(askText);
                        if (e.key === 'Escape') { setAskExpanded(false); setAskText(''); }
                      }}
                      onBlur={() => { if (!askText) setAskExpanded(false); }}
                      placeholder="Ask anything"
                      style={{
                        flex: 1, border: 'none', outline: 'none', background: 'transparent',
                        fontSize: 13, fontWeight: 500,
                        fontFamily: "'Centra No2', -apple-system, sans-serif",
                        color: askText ? '#0c0e1c' : 'rgba(12,14,28,0.4)', minWidth: 0,
                      }}
                    />
                    <motion.button
                      whileTap={{ scale: 0.9 }}
                      onClick={() => { setAskExpanded(false); setAskText(''); }}
                      style={{
                        width: 28, height: 28, borderRadius: 100,
                        background: 'rgba(12,14,28,0.06)', border: 'none',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        cursor: 'pointer', flexShrink: 0,
                      }}
                    >
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                        <path d="M6 15l6-6 6 6" stroke="rgba(12,14,28,0.4)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                      </svg>
                    </motion.button>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div style={{ display: 'flex', gap: 6, flex: 1, minWidth: 0, overflowX: 'auto', scrollbarWidth: 'none' as const, alignItems: 'center' }}>
                      {openThread && [
                        'Show more',
                        `Tell me more about ${openThread.destination}`,
                        openThread.results.length >= 3 ? 'Compare all three' : 'More options',
                      ].map((s, i) => (
                        <motion.button
                          key={i}
                          onClick={() => handleAskSubmit(s)}
                          whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.95 }}
                          style={{
                            display: 'flex', alignItems: 'center',
                            height: 36, padding: '0 16px', borderRadius: 100,
                            background: 'rgba(12,14,28,0.07)', border: 'none',
                            cursor: 'pointer', flexShrink: 0,
                            fontFamily: "'Centra No2', -apple-system, sans-serif",
                          }}
                        >
                          <span style={{ fontSize: 13, fontWeight: 500, color: '#0c0e1c', whiteSpace: 'nowrap' }}>{s}</span>
                        </motion.button>
                      ))}
                    </div>
                    <motion.button
                      whileTap={{ scale: 0.93 }}
                      onClick={() => handleAskSubmit(askText)}
                      animate={{ background: askText ? '#0c0e1c' : 'rgba(12,14,28,0.07)', boxShadow: askText ? '0 4px 16px rgba(12,14,28,0.28)' : 'none' }}
                      transition={{ duration: 0.2 }}
                      style={{ width: 36, height: 36, borderRadius: 100, border: 'none', flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}
                    >
                      <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                        <path d="M5 12h14M12 5l7 7-7 7" stroke={askText ? 'white' : 'rgba(12,14,28,0.4)'} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
                      </svg>
                    </motion.button>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
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

const SHIMMER_PULSE = {
  animate: { opacity: [0.4, 0.75, 0.4] as number[] },
  transition: { duration: 1.6, ease: 'easeInOut' as const, repeat: Infinity },
};

const LOAD_ONEKEY  = 'https://www.figma.com/api/mcp/asset/d617af3a-aa1b-4e75-a9b5-85d5158f483a';
const LOAD_HISTORY = 'https://www.figma.com/api/mcp/asset/16be5bd4-cc1d-411e-adcc-98c4d34757a6';
const LOAD_HEADSET = 'https://www.figma.com/api/mcp/asset/966d2582-93bc-4458-9df3-f3d3b5fd608a';
const LoadIconTrips = () => (
  <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><path d="M16.3613 10.0005C18.1654 10.0005 19.1739 11.4864 19.167 12.9185C19.16 14.3643 18.3184 15.5292 17.4199 16.4116C16.6824 17.136 15.7989 17.7698 15.0947 18.2749C14.94 18.3858 14.7942 18.4912 14.6602 18.5894C14.367 18.8042 13.968 18.804 13.6748 18.5894C13.5406 18.4911 13.3931 18.385 13.2383 18.2739C12.5342 17.7689 11.6524 17.1358 10.915 16.4116C10.0165 15.5291 9.17408 14.3645 9.16699 12.9185C9.16017 11.4864 10.1688 10.0007 11.9727 10.0005C12.8602 10.0005 13.5714 10.3286 14.165 10.7769C14.7607 10.3281 15.4742 10.0005 16.3613 10.0005ZM11.251 0.833496C12.1713 0.833672 12.917 1.58012 12.917 2.50049V4.1665H14.167C15.5476 4.1665 16.6668 5.28594 16.667 6.6665V7.9165C16.667 8.14651 16.4809 8.33332 16.251 8.3335H15.417C15.1871 8.33332 15.001 8.14651 15.001 7.9165V6.6665C15.0008 6.20642 14.6271 5.8335 14.167 5.8335H5.83398C5.37386 5.8335 5.00115 6.20642 5.00098 6.6665V15.0005C5.00115 15.4606 5.37386 15.8335 5.83398 15.8335H8.16113C8.27164 15.8335 8.37797 15.8775 8.45605 15.9556L9.28906 16.7886C9.55149 17.051 9.36608 17.5002 8.99512 17.5005H6.66699V17.9165C6.66699 18.1465 6.48094 18.3333 6.25098 18.3335H5.41699C5.18703 18.3333 5.00098 18.1465 5.00098 17.9165V17.3579C4.03008 17.0148 3.33412 16.0888 3.33398 15.0005V6.6665C3.33416 5.28594 4.45338 4.1665 5.83398 4.1665H7.08398V2.50049C7.08398 1.58001 7.8305 0.833496 8.75098 0.833496H11.251ZM16.3613 11.6665C15.7867 11.6665 15.3027 11.9323 14.7461 12.4751C14.4225 12.7903 13.9066 12.7904 13.583 12.4751C13.0251 11.931 12.5461 11.6665 11.9727 11.6665C11.2865 11.6667 10.8306 12.1953 10.834 12.9106C10.8378 13.6877 11.2931 14.4483 12.082 15.2231C12.7175 15.8472 13.4667 16.385 14.167 16.8882C14.8673 16.385 15.6166 15.8472 16.252 15.2231C17.041 14.4482 17.4961 13.6876 17.5 12.9106C17.5034 12.1951 17.0476 11.6665 16.3613 11.6665ZM8.75098 4.1665H11.251V2.50049H8.75098V4.1665Z" fill="#0C0E1C"/></svg>
);
const LoadIconAccount = () => (
  <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><path d="M3 9a7 7 0 0 1 14 0" stroke="#0C0E1C" strokeWidth="1.5" strokeLinecap="round"/><rect x="1.5" y="9" width="3" height="4.5" rx="1.5" stroke="#0C0E1C" strokeWidth="1.5"/><rect x="15.5" y="9" width="3" height="4.5" rx="1.5" stroke="#0C0E1C" strokeWidth="1.5"/><path d="M17 13.5v1a3 3 0 0 1-3 3h-1.5" stroke="#0C0E1C" strokeWidth="1.5" strokeLinecap="round"/></svg>
);
const loadGlassBtn: React.CSSProperties = {
  width: 44, height: 44, borderRadius: 14,
  background: 'rgba(255,255,255,0.7)',
  backdropFilter: 'blur(12px)', WebkitBackdropFilter: 'blur(12px)',
  border: '1px solid rgba(255,255,255,0.6)',
  boxShadow: '0 2px 8px rgba(12,14,28,0.08)',
  display: 'flex', alignItems: 'center', justifyContent: 'center',
  cursor: 'default', flexShrink: 0,
};

const LoadingOverlay: React.FC = () => {
  const loadingQuery = useAppStore(s => s.loadingQuery);
  const F = "'Centra No2', -apple-system, sans-serif";

  return (
    <div style={{
      position: 'absolute',
      inset: 0,
      display: 'flex',
      background: '#f5f4f2',
      fontFamily: F,
    }}>
      {/* ── Left panel (50%) ── */}
      <div style={{
        width: '50%',
        flexShrink: 0,
        borderRight: '1px solid rgba(12,14,28,0.07)',
        background: '#f5f4f2',
        display: 'flex',
        overflow: 'hidden',
        position: 'relative',
      }}>
        {/* Sidebar — matches SearchResultsView sidebar exactly */}
        <div style={{
          width: 92, flexShrink: 0,
          display: 'flex', flexDirection: 'column', alignItems: 'center',
          gap: 24, padding: '24px 24px',
        }}>
          <img src={LOAD_ONEKEY} alt="OneKey" style={{ width: 44, height: 23, objectFit: 'contain', flexShrink: 0 }} />
          <div style={loadGlassBtn}><img src={LOAD_HISTORY} alt="History" style={{ width: 17, height: 17, objectFit: 'contain' }} /></div>
          <div style={loadGlassBtn}><LoadIconTrips /></div>
          <div style={loadGlassBtn}><img src={LOAD_HEADSET} alt="Support" style={{ width: 17, height: 17, objectFit: 'contain' }} /></div>
          <div style={loadGlassBtn}><LoadIconAccount /></div>
        </div>

        {/* Content column */}
        <div style={{
          flex: 1, display: 'flex', flexDirection: 'column',
          alignItems: 'center', justifyContent: 'center',
          padding: '24px 24px 120px',
          gap: 20, position: 'relative',
        }}>
          {/* Pictogram only — radial mask fades out gradient background edges */}
          <motion.video
            src="/usa/carousel.mp4"
            autoPlay loop muted playsInline
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.5, ease: [0.25, 0.46, 0.45, 0.94] }}
            style={{
              width: '100%', display: 'block',
              maskImage: 'radial-gradient(ellipse 60% 48% at 50% 50%, black 0%, transparent 65%)',
              WebkitMaskImage: 'radial-gradient(ellipse 60% 48% at 50% 50%, black 0%, transparent 65%)',
            }}
          />

          {/* Search query label */}
          <motion.p
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.35, duration: 0.4, ease: 'easeOut' }}
            style={{
              margin: 0,
              fontSize: 15, fontWeight: 500,
              color: 'rgba(12,14,28,0.55)',
              letterSpacing: '-0.01em',
              fontFamily: F,
              textAlign: 'center',
            }}
          >
            {loadingQuery
              ? `Finding ${loadingQuery}…`
              : 'Searching for the best options…'}
          </motion.p>
        </div>

      </div>

      {/* ── Right panel — static map placeholder (real map animates after load) ── */}
      <div style={{ flex: 1, position: 'relative', overflow: 'hidden', background: '#e8f0e8',
        backgroundImage: 'repeating-linear-gradient(0deg,rgba(0,0,0,0.03) 0px,transparent 1px,transparent 40px),repeating-linear-gradient(90deg,rgba(0,0,0,0.03) 0px,transparent 1px,transparent 40px)',
      }}>
        <motion.div
          animate={{ opacity: [0, 0.15, 0] }}
          transition={{ duration: 2.8, ease: 'easeInOut', repeat: Infinity }}
          style={{
            position: 'absolute', inset: 0,
            background: 'rgba(255,255,255,0.5)',
            pointerEvents: 'none',
          }}
        />
      </div>

      {/* ── Ask anything pill skeleton — centered at page bottom ── */}
      <motion.div
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.3, type: 'spring', stiffness: 300, damping: 32 }}
        style={{
          position: 'absolute',
          bottom: 20,
          left: 0, right: 0,
          marginLeft: 'auto', marginRight: 'auto',
          width: 'min(560px, calc(100vw - 48px))',
          height: 50,
          borderRadius: 999,
          background: 'linear-gradient(179.99deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.5) 95.923%), linear-gradient(90deg, rgba(247,244,243,0.9) 0%, rgba(247,244,243,0.9) 100%)',
          backdropFilter: 'blur(15px)', WebkitBackdropFilter: 'blur(15px)',
          border: '1px solid white',
          boxShadow: '0 12px 32px rgba(12,14,28,0.08)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}
      >
        <motion.div
          animate={{ opacity: [0.3, 0.6, 0.3] }}
          transition={{ duration: 1.8, ease: 'easeInOut', repeat: Infinity }}
          style={{ width: 80, height: 12, borderRadius: 6, background: 'rgba(12,14,28,0.12)' }}
        />
      </motion.div>
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
