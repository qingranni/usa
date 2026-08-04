// SearchResultsView.tsx
// Figma ref: node 3031:64841

import React, { useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';
import type { Thread, ResultCard } from '../data/mockData';
import { spring } from '../theme/theme';
import { useAppStore } from '../store/appStore';

interface Props {
  thread: Thread;
  onCardClick: (card: ResultCard) => void;
}

const F = "'Centra No2', -apple-system, sans-serif";

const glassBtn: React.CSSProperties = {
  width: 48, height: 48, borderRadius: 999,
  backgroundImage: 'linear-gradient(179.9deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.5) 95.923%), linear-gradient(90deg, #F6F5F4 0%, #F6F5F4 100%)',
  border: '1px solid #fff',
  boxShadow: '0px 12px 16px rgba(12,14,28,0.08)',
  display: 'flex', alignItems: 'center', justifyContent: 'center',
  cursor: 'pointer', flexShrink: 0,
};

// ── Sidebar assets — same URLs as EmptySearchView ─────────────────────────────

const ASSET_ONEKEY   = 'https://www.figma.com/api/mcp/asset/d617af3a-aa1b-4e75-a9b5-85d5158f483a';
const ASSET_HISTORY  = 'https://www.figma.com/api/mcp/asset/16be5bd4-cc1d-411e-adcc-98c4d34757a6';
const ASSET_HEADSET  = 'https://www.figma.com/api/mcp/asset/966d2582-93bc-4458-9df3-f3d3b5fd608a';

const IconAccount = () => (
  <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
    <path d="M3 9a7 7 0 0 1 14 0" stroke="#0C0E1C" strokeWidth="1.5" strokeLinecap="round"/>
    <rect x="1.5" y="9" width="3" height="4.5" rx="1.5" stroke="#0C0E1C" strokeWidth="1.5"/>
    <rect x="15.5" y="9" width="3" height="4.5" rx="1.5" stroke="#0C0E1C" strokeWidth="1.5"/>
    <path d="M17 13.5v1a3 3 0 0 1-3 3h-1.5" stroke="#0C0E1C" strokeWidth="1.5" strokeLinecap="round"/>
    <rect x="11" y="15.5" width="2" height="3" rx="1" stroke="#0C0E1C" strokeWidth="1.5"/>
  </svg>
);

const IconTrips = () => (
  <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M16.3613 10.0005C18.1654 10.0005 19.1739 11.4864 19.167 12.9185C19.16 14.3643 18.3184 15.5292 17.4199 16.4116C16.6824 17.136 15.7989 17.7698 15.0947 18.2749C14.94 18.3858 14.7942 18.4912 14.6602 18.5894C14.367 18.8042 13.968 18.804 13.6748 18.5894C13.5406 18.4911 13.3931 18.385 13.2383 18.2739C12.5342 17.7689 11.6524 17.1358 10.915 16.4116C10.0165 15.5291 9.17408 14.3645 9.16699 12.9185C9.16017 11.4864 10.1688 10.0007 11.9727 10.0005C12.8602 10.0005 13.5714 10.3286 14.165 10.7769C14.7607 10.3281 15.4742 10.0005 16.3613 10.0005ZM11.251 0.833496C12.1713 0.833672 12.917 1.58012 12.917 2.50049V4.1665H14.167C15.5476 4.1665 16.6668 5.28594 16.667 6.6665V7.9165C16.667 8.14651 16.4809 8.33332 16.251 8.3335H15.417C15.1871 8.33332 15.001 8.14651 15.001 7.9165V6.6665C15.0008 6.20642 14.6271 5.8335 14.167 5.8335H5.83398C5.37386 5.8335 5.00115 6.20642 5.00098 6.6665V15.0005C5.00115 15.4606 5.37386 15.8335 5.83398 15.8335H8.16113C8.27164 15.8335 8.37797 15.8775 8.45605 15.9556L9.28906 16.7886C9.55149 17.051 9.36608 17.5002 8.99512 17.5005H6.66699V17.9165C6.66699 18.1465 6.48094 18.3333 6.25098 18.3335H5.41699C5.18703 18.3333 5.00098 18.1465 5.00098 17.9165V17.3579C4.03008 17.0148 3.33412 16.0888 3.33398 15.0005V6.6665C3.33416 5.28594 4.45338 4.1665 5.83398 4.1665H7.08398V2.50049C7.08398 1.58001 7.8305 0.833496 8.75098 0.833496H11.251ZM16.3613 11.6665C15.7867 11.6665 15.3027 11.9323 14.7461 12.4751C14.4225 12.7903 13.9066 12.7904 13.583 12.4751C13.0251 11.931 12.5461 11.6665 11.9727 11.6665C11.2865 11.6667 10.8306 12.1953 10.834 12.9106C10.8378 13.6877 11.2931 14.4483 12.082 15.2231C12.7175 15.8472 13.4667 16.385 14.167 16.8882C14.8673 16.385 15.6166 15.8472 16.252 15.2231C17.041 14.4482 17.4961 13.6876 17.5 12.9106C17.5034 12.1951 17.0476 11.6665 16.3613 11.6665ZM8.75098 4.1665H11.251V2.50049H8.75098V4.1665Z" fill="#0C0E1C"/>
  </svg>
);

// ── Content icons ─────────────────────────────────────────────────────────────

const IconBack = () => (
  <svg width="9" height="15" viewBox="0 0 9 15" fill="none">
    <path d="M7.5 1L1 7.5 7.5 14" stroke="#0c0e1c" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
);

const IconHistory = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
    <path d="M3 12a9 9 0 1 0 9-9 9 9 0 0 0-6.36 2.64L3 3" stroke="#0c0e1c" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
    <path d="M3 3v6h6" stroke="#0c0e1c" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
    <path d="M12 7v5l3 3" stroke="#0c0e1c" strokeWidth="1.8" strokeLinecap="round"/>
  </svg>
);

const IconPin = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
    <path d="M12 2C8.69 2 6 4.69 6 8c0 5 6 13 6 13s6-8 6-13c0-3.31-2.69-6-6-6z" fill="#0c0e1c" opacity="0.65"/>
    <circle cx="12" cy="8.5" r="2.2" fill="white"/>
  </svg>
);

const IconCalendar = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
    <rect x="3" y="4" width="18" height="17" rx="3" stroke="#0c0e1c" strokeWidth="1.8" opacity="0.65"/>
    <path d="M3 9h18" stroke="#0c0e1c" strokeWidth="1.8" opacity="0.65"/>
    <path d="M8 2v4M16 2v4" stroke="#0c0e1c" strokeWidth="1.8" strokeLinecap="round" opacity="0.65"/>
  </svg>
);

const IconPeople = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
    <circle cx="9" cy="7" r="3" stroke="#0c0e1c" strokeWidth="1.8" opacity="0.65"/>
    <path d="M3 20c0-3.31 2.69-6 6-6s6 2.69 6 6" stroke="#0c0e1c" strokeWidth="1.8" strokeLinecap="round" opacity="0.65"/>
    <circle cx="17.5" cy="8" r="2.3" stroke="#0c0e1c" strokeWidth="1.6" opacity="0.38"/>
    <path d="M21 20c0-2.76-1.6-5-3.5-5" stroke="#0c0e1c" strokeWidth="1.6" strokeLinecap="round" opacity="0.38"/>
  </svg>
);

const IconFilters = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
    <path d="M3 6h18M7 12h10M11 18h2" stroke="#0c0e1c" strokeWidth="2" strokeLinecap="round" opacity="0.7"/>
  </svg>
);

const IconChevronUp = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
    <path d="M18 15l-6-6-6 6" stroke="rgba(12,14,28,0.45)" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
);

const IconArrow = ({ color = 'white' }: { color?: string }) => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
    <path d="M5 12h14M12 5l7 7-7 7" stroke={color} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
);

const IconSparkle = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
    <path d="M12 2l1.8 5.5 4.2 1-3.6 3.3 1.1 5.7L12 15l-3.5 2.5 1.1-5.7L6 8.5l4.2-1z" fill="#0c0e1c" opacity="0.55"/>
    <path d="M19 2l.8 2.2 2.2.8-2.2.8-.8 2.2-.8-2.2-2.2-.8 2.2-.8z" fill="#0c0e1c" opacity="0.4"/>
    <path d="M5 15l.5 1.5 1.5.5-1.5.5-.5 1.5-.5-1.5-1.5-.5 1.5-.5z" fill="#0c0e1c" opacity="0.3"/>
  </svg>
);

function chipIcon(chip: string) {
  if (/\d+\s*(adult|traveler|people|guest|person)/i.test(chip) || /^(solo|couple|family)/i.test(chip)) return <IconPeople />;
  if (/\d|week|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|spring|summer|winter|fall/i.test(chip)) return <IconCalendar />;
  return <IconPin />;
}

// ── Main component ────────────────────────────────────────────────────────────

const SearchResultsView: React.FC<Props> = ({ thread, onCardClick }) => {
  const { dismissCanvasToHome, submitQuery } = useAppStore();
  const [saved, setSaved] = useState<Set<string>>(new Set());
  const [composerText, setComposerText] = useState('');
  const contentRef = useRef<HTMLDivElement>(null);
  const [contentWidth, setContentWidth] = useState(0);

  useEffect(() => {
    const el = contentRef.current;
    if (!el) return;
    const ro = new ResizeObserver(([entry]) => setContentWidth(entry.contentRect.width));
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  // ≥720px → 3 cols, otherwise 2 cols
  const cols = contentWidth >= 720 ? 3 : 2;
  const cardWidth = `calc(${100 / cols}% - ${(16 * (cols - 1)) / cols}px)`;

  const handleComposerSubmit = (text: string) => {
    const q = text.trim();
    if (!q) return;
    setComposerText('');
    submitQuery(q);
  };

  const toggle = (id: string) =>
    setSaved(prev => { const n = new Set(prev); n.has(id) ? n.delete(id) : n.add(id); return n; });

  const firstResult = thread.results[0];
  const suggestions = [
    'Show more',
    `Tell me more about ${firstResult?.title ?? thread.destination}`,
    thread.results.length >= 3 ? 'Compare all three' : 'More options',
  ];

  return (
    <div style={{
      display: 'flex',
      height: '100%',
      background: '#ffffff',
      overflow: 'hidden',
      fontFamily: F,
    }}>

      {/* ── Left nav sidebar — px-[24px], gap-[24px] ── */}
      <div style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: 24,
        padding: '24px 24px',
        flexShrink: 0,
      }}>
        {/* OneKey brand logo — same asset as landing page */}
        <img src={ASSET_ONEKEY} alt="OneKey" style={{ width: 44, height: 23, objectFit: 'contain', flexShrink: 0 }} />

        {/* Nav icon buttons — same style as landing page sidebarBtnStyle */}
        <button style={glassBtn} title="History">
          <img src={ASSET_HISTORY} alt="History" style={{ width: 17, height: 17, objectFit: 'contain' }} />
        </button>
        <button style={glassBtn} title="Trips">
          <IconTrips />
        </button>
        <button style={glassBtn} title="Support">
          <img src={ASSET_HEADSET} alt="Support" style={{ width: 17, height: 17, objectFit: 'contain' }} />
        </button>
        <button style={glassBtn} title="Account">
          <IconAccount />
        </button>
      </div>

      {/* ── Main content — flex-1, flex-col, gap-[24px] ── */}
      <div ref={contentRef} style={{
        flex: 1,
        minWidth: 0,
        display: 'flex',
        flexDirection: 'column',
        gap: 24,
        paddingTop: 24,
        paddingRight: 24,
        paddingBottom: 24,
        overflow: 'visible',
        position: 'relative',
        zIndex: 2,
      }}>

        {/* Header: back + centered title + invisible spacer */}
        <motion.div
          initial={{ opacity: 0, x: -8 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ ...spring.std, delay: 0.05 }}
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            flexShrink: 0,
            padding: '6px 6px',
            margin: '-6px -6px',
          }}
        >
          <motion.button
            whileTap={{ scale: 0.9 }}
            onClick={() => dismissCanvasToHome()}
            style={glassBtn}
          >
            <IconBack />
          </motion.button>
          <p style={{
            flex: 1, margin: 0,
            fontSize: 15, fontWeight: 500,
            color: '#0c0e1c',
            letterSpacing: '-0.2px', lineHeight: '20px',
            textAlign: 'center', fontFamily: F,
          }}>
            {thread.title}
          </p>
          {/* Invisible spacer — mirrors back button to keep title centered */}
          <div style={{ width: 48, height: 48, flexShrink: 0, pointerEvents: 'none' }} />
        </motion.div>

        {/* Filter chips — h-[48px], gap-[6px] */}
        <div style={{
          display: 'flex',
          alignItems: 'center',
          gap: 6,
          height: 48,
          overflowX: 'auto',
          scrollbarWidth: 'none',
          flexShrink: 0,
          position: 'relative',
          padding: '10px 6px 6px',
          margin: '-10px -6px -6px',
        }}>
          {/* Filter button with count badge */}
          <div style={{ position: 'relative', flexShrink: 0 }}>
            <button style={{
              width: 48, height: 48, borderRadius: 100,
              background: 'rgba(247,244,243,0.75)',
              border: 'none', cursor: 'pointer',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <IconFilters />
            </button>
            <div style={{
              position: 'absolute', top: -2, left: 30,
              width: 18, height: 18, borderRadius: 100,
              background: '#0c0e1c',
              border: '1px solid rgba(255,255,255,0.15)',
              boxShadow: '0 4px 12px rgba(12,14,28,0.24)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <span style={{ fontSize: 10, fontWeight: 700, color: 'white', lineHeight: 1 }}>
                {thread.chips.length}
              </span>
            </div>
          </div>

          {thread.chips.map((chip, i) => (
            <motion.button
              key={i}
              initial={{ opacity: 0, x: 6 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ ...spring.snap, delay: i * 0.04 }}
              style={{
                display: 'flex', alignItems: 'center', gap: 4,
                height: 48, padding: '0 16px',
                borderRadius: 100,
                background: 'rgba(247,244,243,0.75)',
                border: 'none', cursor: 'pointer', flexShrink: 0,
              }}
            >
              {chipIcon(chip)}
              <span style={{ fontSize: 13, fontWeight: 500, color: '#0c0e1c', whiteSpace: 'nowrap', fontFamily: F }}>
                {chip}
              </span>
            </motion.button>
          ))}
        </div>

        {/* Scrollable section content */}
        <div style={{
          flex: 1,
          overflowY: 'auto',
          overflowX: 'visible',
          scrollbarWidth: 'none',
          display: 'flex',
          flexDirection: 'column',
          gap: 24,
          paddingBottom: 148,
          paddingLeft: 4,
          paddingRight: 4,
          marginLeft: -4,
          marginRight: -4,
        }}>
          {/* Section title + description — gap-[4px] */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4, flexShrink: 0 }}>
            <p style={{
              margin: 0,
              fontSize: 13, fontWeight: 500,
              color: '#0c0e1c',
              letterSpacing: '-0.1px', lineHeight: '18px',
              fontFamily: F,
            }}>
              Explore the best of {thread.destination}
            </p>
            <p style={{
              margin: 0,
              fontSize: 13, fontWeight: 400,
              color: 'rgba(12,14,28,0.5)',
              lineHeight: 1.35, fontFamily: F,
            }}>
              {thread.description ?? thread.query}
            </p>
          </div>

          {/* Responsive destination cards — 1/2/3 cols based on panel width */}
          {thread.results.length > 0 ? (
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 16, alignItems: 'flex-start' }}>
              {thread.results.map((card, i) => (
                <div key={card.id} style={{ width: cardWidth, flexShrink: 0 }}>
                  <DestCard
                    card={card}
                    index={i}
                    saved={saved.has(card.id)}
                    onSave={() => toggle(card.id)}
                    onClick={() => onCardClick(card)}
                  />
                </div>
              ))}
            </div>
          ) : (
            <div style={{
              padding: '60px 0',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              color: 'rgba(12,14,28,0.35)', fontSize: 14,
            }}>
              No results yet
            </div>
          )}
        </div>

        {/* ── Ask anything composer bar — absolute bottom ── */}
        <motion.div
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ ...spring.gentle, delay: 0.3 }}
          style={{
            position: 'absolute',
            bottom: 16, left: 0, right: 24,
            borderRadius: 20,
            border: '1px solid rgba(12,14,28,0.08)',
            background: 'rgba(255,255,255,0.92)',
            backdropFilter: 'blur(40px)',
            WebkitBackdropFilter: 'blur(40px)',
            boxShadow: '0 8px 32px rgba(12,14,28,0.14), 0 1px 0 rgba(255,255,255,0.9) inset',
            padding: '20px 24px',
            display: 'flex', flexDirection: 'column', gap: 14,
          }}
        >
          {/* Top row: input + collapse */}
          <div style={{
            display: 'flex', alignItems: 'center',
            justifyContent: 'space-between', gap: 12,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, flex: 1, minWidth: 0 }}>
              <input
                value={composerText}
                onChange={e => setComposerText(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && handleComposerSubmit(composerText)}
                placeholder="Ask anything"
                style={{
                  flex: 1, border: 'none', outline: 'none', background: 'transparent',
                  fontSize: 13, fontWeight: 500, fontFamily: F, letterSpacing: '-0.01em',
                  color: composerText ? '#0c0e1c' : 'rgba(12,14,28,0.4)',
                  minWidth: 0,
                }}
              />
            </div>
            <IconChevronUp />
          </div>

          {/* Suggestion pills row */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
            <div style={{
              display: 'flex', gap: 6, flex: 1, minWidth: 0,
              overflowX: 'auto', scrollbarWidth: 'none',
              alignItems: 'center',
              paddingTop: 4, paddingBottom: 4,
              marginTop: -4, marginBottom: -4,
            }}>
              {suggestions.map((s, i) => (
                <motion.button
                  key={i}
                  onClick={() => handleComposerSubmit(s)}
                  whileHover={{ scale: 1.02 }}
                  whileTap={{ scale: 0.95 }}
                  style={{
                    display: 'flex', alignItems: 'center',
                    height: 48, padding: '0 20px',
                    borderRadius: 100,
                    background: 'rgba(12,14,28,0.07)',
                    border: 'none',
                    cursor: 'pointer', flexShrink: 0,
                    fontFamily: F,
                  }}
                >
                  <span style={{ fontSize: 13, fontWeight: 500, color: '#0c0e1c', whiteSpace: 'nowrap', lineHeight: '18px' }}>{s}</span>
                </motion.button>
              ))}
            </div>

            <motion.button
              whileTap={{ scale: 0.93 }}
              onClick={() => handleComposerSubmit(composerText)}
              animate={{
                background: composerText ? '#0c0e1c' : 'rgba(12,14,28,0.07)',
                boxShadow: composerText
                  ? '0 4px 16px rgba(12,14,28,0.28)'
                  : 'none',
              }}
              transition={{ duration: 0.2, ease: 'easeOut' }}
              style={{
                width: 36, height: 36, borderRadius: 100,
                border: 'none',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                cursor: 'pointer', flexShrink: 0, marginLeft: 8,
              }}
            >
              <IconArrow color={composerText ? 'white' : 'rgba(12,14,28,0.4)'} />
            </motion.button>
          </div>
        </motion.div>
      </div>
    </div>
  );
};

// ── Destination card ──────────────────────────────────────────────────────────

interface CardProps {
  card: ResultCard;
  index: number;
  saved: boolean;
  onSave: () => void;
  onClick: () => void;
}

const DestCard: React.FC<CardProps> = ({ card, index, saved, onSave, onClick }) => (
  <motion.div
    initial={{ opacity: 0, y: 16, filter: 'blur(4px)' }}
    animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
    transition={{ ...spring.gentle, delay: 0.08 + index * 0.06 }}
    onClick={onClick}
    whileTap={{ scale: 0.98 }}
    style={{
      width: '100%',
      background: '#f6f5f4',
      borderRadius: 32,
      padding: 8,
      cursor: 'pointer',
      boxSizing: 'border-box',
    }}
  >
    {/* Photo — h-280, rounded-26, p-24 */}
    <motion.div
      whileHover={{ scale: 1.008 }}
      style={{
        width: '100%', aspectRatio: '1 / 1', height: 'auto',
        borderRadius: 26,
        overflow: 'hidden',
        position: 'relative',
        border: '1px solid rgba(0,0,0,0.05)',
        cursor: 'pointer',
      }}
    >
      {card.imageUrl && (
        <img
          src={card.imageUrl}
          alt={card.title}
          style={{
            position: 'absolute', inset: 0,
            width: '100%', height: '100%',
            objectFit: 'cover', pointerEvents: 'none',
          }}
        />
      )}
      <div style={{
        position: 'absolute', inset: 0,
        background: 'linear-gradient(153.86deg, rgba(38,111,170,0.5) 15.014%, rgba(38,111,170,0) 46.863%)',
        pointerEvents: 'none',
      }} />

      {/* Title + heart — positioned top p-14 */}
      <div style={{
        position: 'absolute',
        top: 14, left: 14, right: 14,
        display: 'flex', alignItems: 'flex-start', gap: 8,
      }}>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 4, minWidth: 0 }}>
          <p style={{
            margin: 0,
            fontSize: 13, fontWeight: 600,
            color: 'white',
            letterSpacing: '-0.1px', lineHeight: '16px',
            fontFamily: F,
          }}>
            {card.title}
          </p>
          <p style={{
            margin: 0,
            fontSize: 12, fontWeight: 400,
            color: 'white', lineHeight: '16px',
            fontFamily: F,
          }}>
            {card.subtitle}
          </p>
        </div>

        <motion.button
          whileTap={{ scale: 0.85 }}
          onClick={e => { e.stopPropagation(); onSave(); }}
          style={{
            width: 30, height: 30, borderRadius: 30,
            background: 'rgba(12,14,28,0.05)',
            backdropFilter: 'blur(7.5px)',
            WebkitBackdropFilter: 'blur(7.5px)',
            border: 'none',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            cursor: 'pointer', flexShrink: 0,
          }}
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
            <path
              d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"
              stroke="white" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"
              fill={saved ? 'rgba(255,255,255,0.88)' : 'none'}
            />
          </svg>
        </motion.button>
      </div>
    </motion.div>

    {/* Body — p-16, gap-12 */}
    <div style={{ padding: '12px 16px 12px 12px', display: 'flex', flexDirection: 'column', gap: 8 }}>
      {card.description && (
        <p style={{
          margin: 0,
          fontSize: 12, fontWeight: 400,
          color: 'rgba(26,14,42,0.85)',
          lineHeight: 1.35, fontFamily: F,
        }}>
          {card.description}
        </p>
      )}

      {/* Price — right-aligned, gap-4 */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 2 }}>
          <span style={{
            fontSize: 12, fontWeight: 400,
            color: 'rgba(26,14,42,0.6)',
            letterSpacing: '-0.1px', lineHeight: '18px',
            fontFamily: F,
          }}>from</span>
          <span style={{
            fontSize: 14, fontWeight: 600,
            color: '#0c0e1c',
            letterSpacing: '-0.2px', lineHeight: '18px',
            fontFamily: F,
          }}>
            {card.price}
          </span>
        </div>
        <span style={{
          fontSize: 10, fontWeight: 400,
          color: 'rgba(26,14,42,0.5)',
          lineHeight: '14px', fontFamily: F,
          whiteSpace: 'nowrap',
        }}>
          {card.priceNote}
        </span>
      </div>
    </div>
  </motion.div>
);

export default SearchResultsView;
