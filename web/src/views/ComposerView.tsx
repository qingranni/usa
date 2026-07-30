// ComposerView.tsx — AI composer sheet
// Port of ComposerView.swift: pill → docked sheet → full-screen takeover.
// The key motion: springMorph (cubic-bezier(0.75,0,0,1) 750ms) drives the
// entrance from the pill position; composerReveal scrubs docked→full via
// a drag gesture (threshold 80px down = dismiss, drag up = full reveal).

import React, { useState, useRef, useCallback, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Theme } from '../theme/theme';
import { useAppStore } from '../store/appStore';
import { QUICK_ANSWERS, SUGGESTIONS } from '../data/mockData';

const ComposerView: React.FC = () => {
  const {
    composerActive,
    composerEntrance,
    composerReveal,
    composerPrompt,
    closeComposer,
    setComposerReveal,
    submitQuery,
    followUpPillRect,
  } = useAppStore();

  const [inputValue, setInputValue] = useState('');
  const [isDragging, setIsDragging] = useState(false);
  const [dragStartY, setDragStartY] = useState(0);
  const [dragOffsetY, setDragOffsetY] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);

  // Focus input when composer opens
  useEffect(() => {
    if (composerActive && composerEntrance >= 0.5) {
      setTimeout(() => inputRef.current?.focus(), 300);
    }
  }, [composerActive, composerEntrance]);

  const handleSubmit = useCallback(() => {
    if (!inputValue.trim()) return;
    const query = inputValue;
    setInputValue('');
    submitQuery(query);
  }, [inputValue, submitQuery]);

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Enter') handleSubmit();
    if (e.key === 'Escape') closeComposer();
  }, [handleSubmit, closeComposer]);

  // Drag handlers for the dismiss gesture (drag handle at top)
  const onDragStart = useCallback((e: React.PointerEvent) => {
    setIsDragging(true);
    setDragStartY(e.clientY);
    setDragOffsetY(0);
    (e.target as HTMLElement).setPointerCapture(e.pointerId);
  }, []);

  const onDragMove = useCallback((e: React.PointerEvent) => {
    if (!isDragging) return;
    const dy = e.clientY - dragStartY;
    setDragOffsetY(Math.max(0, dy));
    // Scrub composerReveal based on upward drag
    if (dy < 0) {
      const rev = Math.min(1, Math.abs(dy) / 260);
      setComposerReveal(rev);
    }
  }, [isDragging, dragStartY, setComposerReveal]);

  const onDragEnd = useCallback(() => {
    setIsDragging(false);
    if (dragOffsetY > 80) {
      closeComposer();
    } else if (dragOffsetY > 0) {
      setDragOffsetY(0);
    }
    setComposerReveal(0);
  }, [dragOffsetY, closeComposer, setComposerReveal]);

  if (!composerActive) return null;

  // The sheet height interpolates from pill height (50px) to full-screen
  // based on composerEntrance (0→1). On desktop we anchor to a max height.
  const sheetMaxHeight = 'min(640px, 80vh)';
  const isFullReveal = composerReveal > 0.45;

  const sheetY = dragOffsetY;

  return (
    <motion.div
      key="composer"
      initial={{ opacity: 0, scale: 0.96, y: 20 }}
      animate={{
        opacity: 1,
        scale: 1,
        y: sheetY,
      }}
      exit={{ opacity: 0, scale: 0.96, y: 20 }}
      transition={{
        opacity: { duration: 0.22, ease: 'easeOut' },
        scale: { duration: 0.75, ease: [0.75, 0, 0, 1] },
        y: isDragging ? { duration: 0 } : { duration: 0.75, ease: [0.75, 0, 0, 1] },
      }}
      style={{
        position: 'absolute',
        bottom: 0,
        left: 0,
        right: 0,
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'flex-end',
        padding: '0 16px 24px',
        zIndex: 50,
        pointerEvents: 'none',
      }}
    >
      <div
        style={{
          width: '100%',
          maxWidth: 680,
          background: 'rgba(255,255,255,0.96)',
          backdropFilter: 'blur(32px) saturate(1.8)',
          WebkitBackdropFilter: 'blur(32px) saturate(1.8)',
          borderRadius: 28,
          boxShadow: '0 8px 64px rgba(0,0,0,0.18), 0 0 0 1px rgba(255,255,255,0.6) inset',
          overflow: 'hidden',
          pointerEvents: 'all',
          maxHeight: isFullReveal ? '80vh' : sheetMaxHeight,
          transition: `max-height 0.75s cubic-bezier(0.75,0,0,1), border-radius 0.75s cubic-bezier(0.75,0,0,1)`,
        }}
      >
        {/* Drag handle */}
        <div
          onPointerDown={onDragStart}
          onPointerMove={onDragMove}
          onPointerUp={onDragEnd}
          style={{
            display: 'flex',
            justifyContent: 'center',
            padding: '12px 0 6px',
            cursor: 'grab',
            userSelect: 'none',
          }}
        >
          <div style={{
            width: 36,
            height: 4,
            borderRadius: 2,
            background: 'rgba(12,14,28,0.14)',
          }} />
        </div>

        <div style={{ padding: '8px 20px 20px' }}>
          {/* Header */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: 16,
          }}>
            <span style={{
              fontSize: 13,
              fontWeight: 600,
              letterSpacing: '0.12em',
              textTransform: 'uppercase',
              color: Theme.inkMuted,
            }}>
              Universal Search
            </span>
            <button
              onClick={closeComposer}
              style={{
                width: 32,
                height: 32,
                borderRadius: '50%',
                background: Theme.figmaChipFill,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer',
                border: 'none',
              }}
            >
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none">
                <path d="M18 6L6 18M6 6l12 12" stroke={Theme.ink} strokeWidth="2.5" strokeLinecap="round"/>
              </svg>
            </button>
          </div>

          {/* Search input */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            background: Theme.figmaChipFill,
            borderRadius: 14,
            padding: '12px 16px',
            marginBottom: 16,
          }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" style={{ opacity: 0.45, flexShrink: 0 }}>
              <circle cx="11" cy="11" r="7" stroke={Theme.ink} strokeWidth="2.2"/>
              <path d="M16.5 16.5L21 21" stroke={Theme.ink} strokeWidth="2.2" strokeLinecap="round"/>
            </svg>
            <input
              ref={inputRef}
              value={inputValue}
              onChange={e => setInputValue(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder={composerPrompt}
              style={{
                flex: 1,
                background: 'none',
                border: 'none',
                outline: 'none',
                fontSize: 16,
                fontWeight: 500,
                color: Theme.ink,
                fontFamily: 'inherit',
                letterSpacing: '-0.01em',
              }}
            />
            {inputValue && (
              <button
                onClick={handleSubmit}
                style={{
                  width: 32,
                  height: 32,
                  borderRadius: '50%',
                  background: Theme.ink,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                  border: 'none',
                  flexShrink: 0,
                  transition: 'transform 120ms ease-out',
                }}
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                  <path d="M5 12h14M12 5l7 7-7 7" stroke="white" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              </button>
            )}
          </div>

          {/* Quick suggestions */}
          <div style={{ marginBottom: 12 }}>
            <div style={{
              fontSize: 11,
              fontWeight: 600,
              letterSpacing: '0.1em',
              textTransform: 'uppercase',
              color: Theme.inkMuted,
              marginBottom: 10,
            }}>
              Suggestions
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              {SUGGESTIONS.slice(0, 4).map((s, i) => (
                <motion.button
                  key={s.label}
                  initial={{ opacity: 0, x: -8 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{
                    duration: 0.35,
                    ease: [0.42, 0.1, 0.24, 1],
                    delay: i * 0.05,
                  }}
                  onClick={() => {
                    setInputValue(s.label);
                    inputRef.current?.focus();
                  }}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 10,
                    padding: '10px 12px',
                    borderRadius: 10,
                    cursor: 'pointer',
                    background: 'transparent',
                    border: 'none',
                    textAlign: 'left',
                    width: '100%',
                    transition: 'background 100ms ease',
                    fontFamily: 'inherit',
                  }}
                  onMouseEnter={e => {
                    (e.currentTarget as HTMLButtonElement).style.background = Theme.figmaChipFill;
                  }}
                  onMouseLeave={e => {
                    (e.currentTarget as HTMLButtonElement).style.background = 'transparent';
                  }}
                >
                  <span style={{ fontSize: 16 }}>{s.icon}</span>
                  <span style={{
                    fontSize: 15,
                    fontWeight: 500,
                    color: Theme.ink,
                    letterSpacing: '-0.01em',
                  }}>
                    {s.label}
                  </span>
                </motion.button>
              ))}
            </div>
          </div>

          {/* Quick answers */}
          <div>
            <div style={{
              fontSize: 11,
              fontWeight: 600,
              letterSpacing: '0.1em',
              textTransform: 'uppercase',
              color: Theme.inkMuted,
              marginBottom: 10,
            }}>
              Ask a question
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              {QUICK_ANSWERS.map((q, i) => (
                <motion.button
                  key={q}
                  initial={{ opacity: 0, x: -8 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{
                    duration: 0.35,
                    ease: [0.42, 0.1, 0.24, 1],
                    delay: 0.2 + i * 0.05,
                  }}
                  onClick={() => {
                    setInputValue(q);
                    inputRef.current?.focus();
                  }}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 10,
                    padding: '10px 12px',
                    borderRadius: 10,
                    cursor: 'pointer',
                    background: 'transparent',
                    border: 'none',
                    textAlign: 'left',
                    width: '100%',
                    fontFamily: 'inherit',
                    transition: 'background 100ms ease',
                  }}
                  onMouseEnter={e => {
                    (e.currentTarget as HTMLButtonElement).style.background = Theme.figmaChipFill;
                  }}
                  onMouseLeave={e => {
                    (e.currentTarget as HTMLButtonElement).style.background = 'transparent';
                  }}
                >
                  <span style={{ opacity: 0.4, flexShrink: 0 }}>
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
                      <path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10z" stroke={Theme.ink} strokeWidth="2"/>
                      <path d="M12 8v4M12 16h.01" stroke={Theme.ink} strokeWidth="2.2" strokeLinecap="round"/>
                    </svg>
                  </span>
                  <span style={{
                    fontSize: 14,
                    fontWeight: 450,
                    color: Theme.ink,
                    letterSpacing: '-0.005em',
                  }}>
                    {q}
                  </span>
                </motion.button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </motion.div>
  );
};

export default ComposerView;
