// CurtainSheet.tsx — The morphing white results canvas
// Port of CurtainSheet.swift: driven by `reveal` (0=full, 2=collapsed to trip slot).
// On desktop: full-height panel on the right side, with drag handle to dismiss.
// Interactive drag scrubs reveal; fling snaps to results or trip.

import React, { useRef, useCallback, useState } from 'react';
import { motion } from 'framer-motion';
import { useAppStore, stageResults, stageTrip } from '../store/appStore';
import type { Thread, ResultCard } from '../data/mockData';
import { Theme } from '../theme/theme';
import { lerp, progress, eased } from '../morph/morphProgress';

interface Props {
  thread: Thread;
  onCardClick: (card: ResultCard) => void;
}

const CurtainSheet: React.FC<Props> = ({ thread, onCardClick }) => {
  const { reveal, setReveal, teardown, morphReveal } = useAppStore();

  // Drag state for reveal scrub
  const [dragStartY, setDragStartY] = useState(0);
  const [dragStartReveal, setDragStartReveal] = useState(0);
  const isDragging = useRef(false);

  const onPointerDown = useCallback((e: React.PointerEvent) => {
    isDragging.current = true;
    setDragStartY(e.clientY);
    setDragStartReveal(reveal);
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
  }, [reveal]);

  const onPointerMove = useCallback((e: React.PointerEvent) => {
    if (!isDragging.current) return;
    const dy = e.clientY - dragStartY;
    // 280px of drag maps to full reveal range (0→2), same as iOS morphScrub distance
    const newReveal = Math.max(0, Math.min(stageTrip, dragStartReveal + (dy / 280) * stageTrip));
    setReveal(newReveal);
  }, [dragStartY, dragStartReveal, setReveal]);

  const onPointerUp = useCallback((e: React.PointerEvent) => {
    if (!isDragging.current) return;
    isDragging.current = false;
    const dy = e.clientY - dragStartY;
    const flingVelocity = dy; // approximate
    let target: number;
    if (Math.abs(flingVelocity) > 100) {
      target = flingVelocity > 0 ? stageTrip : stageResults;
    } else {
      target = reveal < 1 ? stageResults : stageTrip;
    }

    if (target >= stageTrip) {
      setReveal(stageTrip);
      setTimeout(() => teardown(), 750);
    } else {
      setReveal(stageResults);
    }
  }, [dragStartY, reveal, setReveal, teardown]);

  // The sheet's vertical position driven by morphReveal
  // 0 = full height (results), 2 = collapsed to bottom (trip)
  const revealProgress = progress(morphReveal, 0, stageTrip);
  const sheetTranslateY = lerp(0, 100, eased(revealProgress)); // % of sheet height
  const sheetOpacity = lerp(1, 0, eased(progress(morphReveal, 1.5, 2)));
  const sheetScale = lerp(1, 0.94, eased(revealProgress));

  return (
    <motion.div
      key="curtain"
      initial={{ y: '100%', opacity: 0 }}
      animate={{
        y: `${sheetTranslateY}%`,
        opacity: sheetOpacity,
        scale: sheetScale,
      }}
      exit={{ y: '100%', opacity: 0 }}
      transition={{
        duration: isDragging.current ? 0 : 0.75,
        ease: [0.75, 0, 0, 1],
      }}
      style={{
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        background: '#ffffff',
        borderRadius: `${lerp(0, 28, eased(revealProgress))}px`,
        overflow: 'hidden',
        display: 'flex',
        flexDirection: 'column',
        boxShadow: '0 -4px 40px rgba(0,0,0,0.14), 0 2.5px 25px rgba(0,0,0,0.08)',
        transformOrigin: 'top center',
      }}
    >
      {/* Drag handle area */}
      <div
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        style={{
          padding: '12px 0 8px',
          display: 'flex',
          justifyContent: 'center',
          cursor: 'ns-resize',
          flexShrink: 0,
          userSelect: 'none',
        }}
      >
        <div style={{
          width: 36,
          height: 4,
          borderRadius: 2,
          background: 'rgba(12,14,28,0.12)',
        }} />
      </div>

      {/* Query summary chips */}
      <div style={{
        padding: '0 20px 12px',
        display: 'flex',
        flexWrap: 'wrap',
        gap: 6,
        flexShrink: 0,
      }}>
        {thread.chips.map(chip => (
          <span
            key={chip}
            style={{
              padding: '5px 12px',
              borderRadius: 100,
              background: Theme.figmaChipFill,
              fontSize: 12,
              fontWeight: 600,
              color: Theme.ink,
              letterSpacing: '-0.005em',
            }}
          >
            {chip}
          </span>
        ))}
      </div>

      {/* Results scroll area */}
      <div style={{
        flex: 1,
        overflowY: 'auto',
        padding: '0 20px 24px',
        display: 'flex',
        flexDirection: 'column',
        gap: 14,
      }}>
        {thread.results.length === 0 ? (
          <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flex: 1,
            color: Theme.inkMuted,
            fontSize: 15,
          }}>
            No results
          </div>
        ) : (
          thread.results.map((card, i) => (
            <ResultCardView
              key={card.id}
              card={card}
              index={i}
              onClick={() => onCardClick(card)}
            />
          ))
        )}
      </div>
    </motion.div>
  );
};

// ---- ResultCardView ----
interface ResultCardProps {
  card: ResultCard;
  index: number;
  onClick: () => void;
}

const ResultCardView: React.FC<ResultCardProps> = ({ card, index, onClick }) => {
  const [isFav, setIsFav] = useState(false);

  return (
    <motion.div
      initial={{ opacity: 0, y: 18 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{
        duration: 0.45,
        ease: [0.42, 0.1, 0.24, 1],
        delay: index * 0.07,
      }}
      onClick={onClick}
      style={{
        borderRadius: Theme.radiusHotelCard,
        background: '#ffffff',
        boxShadow: Theme.hotelCardShadow,
        overflow: 'hidden',
        cursor: 'pointer',
        border: '1px solid rgba(12,14,28,0.06)',
        transition: 'transform 120ms ease-out, box-shadow 120ms ease-out',
      }}
      whileHover={{ scale: 1.01, transition: { duration: 0.12 } }}
      whileTap={{ scale: 0.98 }}
    >
      {/* Image */}
      <div style={{
        height: 180,
        overflow: 'hidden',
        position: 'relative',
        borderRadius: `${Theme.radiusHotelImage}px ${Theme.radiusHotelImage}px 0 0`,
      }}>
        <img
          src={card.imageUrl}
          alt={card.title}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            display: 'block',
          }}
          loading="lazy"
        />
        {card.badge && (
          <span style={{
            position: 'absolute',
            top: 12,
            left: 12,
            padding: '4px 10px',
            borderRadius: 100,
            background: 'rgba(255,255,255,0.9)',
            backdropFilter: 'blur(8px)',
            fontSize: 11,
            fontWeight: 700,
            color: Theme.ink,
            letterSpacing: '0.02em',
          }}>
            {card.badge}
          </span>
        )}
        {/* Favorite button */}
        <button
          onClick={e => { e.stopPropagation(); setIsFav(v => !v); }}
          style={{
            position: 'absolute',
            top: 12,
            right: 12,
            width: 34,
            height: 34,
            borderRadius: '50%',
            background: 'rgba(255,255,255,0.88)',
            backdropFilter: 'blur(8px)',
            border: 'none',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
            transition: 'transform 0.39s cubic-bezier(0.42,0.1,0.24,1)',
            transform: isFav ? 'scale(1.2)' : 'scale(1)',
          }}
        >
          <svg width="14" height="14" viewBox="0 0 24 24" fill={isFav ? '#e74c3c' : 'none'}>
            <path
              d="M12 21C12 21 3 14 3 8a5 5 0 0110 0 5 5 0 0110 0c0 6-9 13-9 13z"
              stroke={isFav ? '#e74c3c' : Theme.ink}
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </button>
      </div>

      {/* Info */}
      <div style={{ padding: '14px 16px' }}>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'flex-start',
          marginBottom: 4,
        }}>
          <div>
            <div style={{
              fontSize: 16,
              fontWeight: 700,
              color: Theme.ink,
              letterSpacing: '-0.02em',
              marginBottom: 2,
            }}>
              {card.title}
            </div>
            <div style={{
              fontSize: 13,
              color: Theme.onSurfaceVariant,
              fontWeight: 450,
            }}>
              {card.subtitle}
            </div>
          </div>
          {card.rating && (
            <div style={{
              display: 'flex',
              alignItems: 'center',
              gap: 3,
              flexShrink: 0,
            }}>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="#f5a623">
                <path d="M12 2l3.09 6.26L22 9.27l-5 4.87L18.18 21 12 17.77 5.82 21 7 14.14 2 9.27l6.91-1.01L12 2z"/>
              </svg>
              <span style={{ fontSize: 13, fontWeight: 600, color: Theme.ink }}>
                {card.rating}
              </span>
            </div>
          )}
        </div>
        <div style={{
          fontSize: 13,
          color: Theme.onSurfaceVariant,
          marginTop: 4,
        }}>
          <span style={{
            fontSize: 18,
            fontWeight: 700,
            color: Theme.ink,
            letterSpacing: '-0.03em',
          }}>
            {card.price}
          </span>
          {' '}{card.priceNote}
        </div>
      </div>
    </motion.div>
  );
};

export { ResultCardView };
export default CurtainSheet;
