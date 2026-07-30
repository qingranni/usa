// TripOverviewView.tsx — Trip list / journeys screen
// Port of TripOverviewView.swift: list of ThreadNodes with opacity/scale vs reveal.
// Each row morphs into the CurtainSheet canvas slot (slot frames captured here).

import React from 'react';
import { motion } from 'framer-motion';
import { useAppStore } from '../store/appStore';
import type { Thread } from '../data/mockData';
import { Theme } from '../theme/theme';
import { progress, eased, lerp } from '../morph/morphProgress';

const TripOverviewView: React.FC = () => {
  const { threads, reveal, openThreadByID } = useAppStore();

  // Rows fade/scale in as reveal approaches stageTrip
  const listOpacity = lerp(0, 1, eased(progress(reveal, 1.5, 2)));
  const listScale = lerp(0.96, 1, eased(progress(reveal, 1.5, 2)));

  return (
    <div style={{
      position: 'absolute',
      inset: 0,
      background: Theme.cardItem,
      display: 'flex',
      flexDirection: 'column',
    }}>
      {/* Header */}
      <div style={{
        padding: '24px 24px 16px',
        flexShrink: 0,
      }}>
        <div style={{
          fontSize: 13,
          fontWeight: 600,
          letterSpacing: '0.14em',
          textTransform: 'uppercase',
          color: Theme.inkMuted,
          marginBottom: 6,
        }}>
          Journeys
        </div>
        <div style={{
          fontSize: 28,
          fontWeight: 700,
          color: Theme.ink,
          letterSpacing: '-0.03em',
        }}>
          Your trips
        </div>
      </div>

      {/* Thread list */}
      <div
        style={{
          flex: 1,
          overflowY: 'auto',
          padding: '0 16px 32px',
          display: 'flex',
          flexDirection: 'column',
          gap: 10,
          opacity: listOpacity,
          transform: `scale(${listScale})`,
          transformOrigin: 'top center',
          transition: 'none', // driven by scroll/reveal, not CSS transition
        }}
      >
        {threads.length === 0 ? (
          <div style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            flex: 1,
            gap: 12,
            opacity: 0.45,
            paddingTop: 60,
          }}>
            <svg width="40" height="40" viewBox="0 0 24 24" fill="none">
              <path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10z" stroke={Theme.ink} strokeWidth="1.5"/>
              <path d="M12 8v4M12 16h.01" stroke={Theme.ink} strokeWidth="2" strokeLinecap="round"/>
            </svg>
            <span style={{ fontSize: 15, color: Theme.inkMuted, fontWeight: 500 }}>
              No trips yet. Search to get started.
            </span>
          </div>
        ) : (
          threads.map((thread, i) => (
            <TripRow
              key={thread.id}
              thread={thread}
              index={i}
              onClick={() => openThreadByID(thread.id)}
            />
          ))
        )}
      </div>
    </div>
  );
};

// ---- TripRow ---- mirrors OverviewCardRow in the iOS source ----
interface TripRowProps {
  thread: Thread;
  index: number;
  onClick: () => void;
}

const TripRow: React.FC<TripRowProps> = ({ thread, index, onClick }) => {
  return (
    <motion.div
      initial={{ opacity: 0, y: 12 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{
        duration: 0.42,
        ease: [0.42, 0.1, 0.24, 1],
        delay: index * 0.06,
      }}
      onClick={onClick}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 14,
        padding: '14px 16px',
        borderRadius: 20,
        background: 'rgba(255,255,255,0.65)',
        backdropFilter: 'blur(12px)',
        WebkitBackdropFilter: 'blur(12px)',
        border: '1px solid rgba(255,255,255,0.7)',
        boxShadow: '0 1px 10px rgba(0,0,0,0.05)',
        cursor: 'pointer',
        transition: 'transform 120ms ease-out, box-shadow 120ms ease-out',
      }}
      whileHover={{ scale: 1.015, transition: { duration: 0.1 } }}
      whileTap={{ scale: 0.985 }}
    >
      {/* Fan images / thumbnail */}
      <div style={{
        width: 52,
        height: 52,
        borderRadius: 14,
        overflow: 'hidden',
        flexShrink: 0,
        background: 'rgba(12,14,28,0.06)',
      }}>
        <img
          src={thread.heroImage}
          alt={thread.destination}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
          }}
          loading="lazy"
        />
      </div>

      {/* Text */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontSize: 10,
          fontWeight: 600,
          letterSpacing: '0.1em',
          textTransform: 'uppercase',
          color: Theme.inkMuted,
          marginBottom: 2,
        }}>
          Results
        </div>
        <div style={{
          fontSize: 16,
          fontWeight: 700,
          color: Theme.ink,
          letterSpacing: '-0.02em',
          whiteSpace: 'nowrap',
          overflow: 'hidden',
          textOverflow: 'ellipsis',
        }}>
          {thread.title}
        </div>
        <div style={{
          fontSize: 12,
          color: Theme.inkMuted,
          marginTop: 2,
          fontWeight: 450,
        }}>
          {thread.chips.slice(0, 3).join(' · ')}
        </div>
      </div>

      {/* Chevron */}
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" style={{ opacity: 0.3, flexShrink: 0 }}>
        <path d="M9 18l6-6-6-6" stroke={Theme.ink} strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
    </motion.div>
  );
};

export default TripOverviewView;
