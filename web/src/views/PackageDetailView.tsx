// PackageDetailView.tsx — Full-screen package detail with hero morph
// Port of PackageDetailView.swift: springDetailMorph (cubic-bezier(0.4,0,0.18,1) 1.55s)
// Windowed cinematic beats: fly hero → chrome → rest content, all driven by detailReveal.

import React from 'react';
import { motion } from 'framer-motion';
import { useAppStore } from '../store/appStore';
import { Theme } from '../theme/theme';
import { MorphProgress } from '../morph/morphProgress';

const PackageDetailView: React.FC = () => {
  const { detailCard, detailReveal, closeDetailCard } = useAppStore();

  if (!detailCard) return null;

  // Windowed beats over the 0→1 driver (mirrors PackageDetailView.swift beat windows)
  const heroMorph = new MorphProgress(detailReveal, 0, 0.5);
  const chromeMorph = new MorphProgress(detailReveal, 0.3, 0.65);
  const contentMorph = new MorphProgress(detailReveal, 0.5, 0.85);
  const restMorph = new MorphProgress(detailReveal, 0.65, 1.0);

  return (
    <motion.div
      key="detail"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.22, ease: 'easeOut' }}
      style={{
        position: 'absolute',
        inset: 0,
        zIndex: 60,
        background: '#000',
        overflow: 'hidden',
      }}
    >
      {/* Hero image — flies in with springDetailMorph */}
      <motion.div
        initial={{ scale: 1.08, opacity: 0 }}
        animate={{
          scale: 1,
          opacity: heroMorph.fadeIn,
        }}
        transition={{
          duration: 1.55,
          ease: [0.4, 0, 0.18, 1],
        }}
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          height: '55%',
          overflow: 'hidden',
        }}
      >
        <img
          src={detailCard.imageUrl}
          alt={detailCard.title}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            display: 'block',
          }}
        />
        {/* Gradient overlay on hero */}
        <div style={{
          position: 'absolute',
          inset: 0,
          background: 'linear-gradient(0deg, rgba(0,0,0,0.5) 0%, transparent 50%)',
        }} />
      </motion.div>

      {/* Chrome (back button, title) — fades in as beat 2 */}
      <motion.div
        initial={{ opacity: 0, y: -8 }}
        animate={{
          opacity: chromeMorph.fadeIn,
          y: chromeMorph.lerp(-8, 0),
        }}
        transition={{ duration: 0.8, ease: [0.4, 0, 0.18, 1], delay: 0.3 }}
        style={{
          position: 'absolute',
          top: 24,
          left: 24,
          right: 24,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          zIndex: 10,
        }}
      >
        <button
          onClick={closeDetailCard}
          style={{
            width: 40,
            height: 40,
            borderRadius: '50%',
            background: 'rgba(0,0,0,0.35)',
            backdropFilter: 'blur(12px)',
            WebkitBackdropFilter: 'blur(12px)',
            border: '1px solid rgba(255,255,255,0.2)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            cursor: 'pointer',
          }}
        >
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
            <path d="M19 12H5M12 19l-7-7 7-7" stroke="white" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </button>

        <FavoriteButton />
      </motion.div>

      {/* Content card — slides up from below hero */}
      <motion.div
        initial={{ y: 40, opacity: 0 }}
        animate={{
          y: contentMorph.lerp(40, 0),
          opacity: contentMorph.fadeIn,
        }}
        transition={{ duration: 1.1, ease: [0.4, 0, 0.18, 1], delay: 0.5 }}
        style={{
          position: 'absolute',
          top: '48%',
          left: 0,
          right: 0,
          bottom: 0,
          background: '#ffffff',
          borderRadius: '28px 28px 0 0',
          padding: '28px 24px',
          overflowY: 'auto',
        }}
      >
        {/* Title */}
        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{
            opacity: contentMorph.fadeIn,
            y: contentMorph.lerp(12, 0),
          }}
          transition={{ duration: 0.8, ease: [0.4, 0, 0.18, 1], delay: 0.6 }}
        >
          <div style={{
            fontSize: 26,
            fontWeight: 800,
            color: Theme.ink,
            letterSpacing: '-0.03em',
            marginBottom: 4,
          }}>
            {detailCard.title}
          </div>
          <div style={{
            fontSize: 14,
            color: Theme.onSurfaceVariant,
            marginBottom: 16,
          }}>
            {detailCard.subtitle}
          </div>
        </motion.div>

        {/* Price + book */}
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{
            opacity: restMorph.fadeIn,
            y: restMorph.lerp(10, 0),
          }}
          transition={{ duration: 0.7, ease: [0.4, 0, 0.18, 1], delay: 0.75 }}
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: 24,
            padding: '16px 20px',
            background: Theme.cardItem,
            borderRadius: 16,
          }}
        >
          <div>
            <div style={{
              fontSize: 28,
              fontWeight: 800,
              color: Theme.ink,
              letterSpacing: '-0.04em',
            }}>
              {detailCard.price}
            </div>
            <div style={{ fontSize: 12, color: Theme.onSurfaceVariant }}>
              {detailCard.priceNote}
            </div>
          </div>
          <button style={{
            padding: '12px 24px',
            borderRadius: 100,
            background: Theme.ink,
            color: '#fff',
            fontSize: 15,
            fontWeight: 700,
            letterSpacing: '-0.01em',
            cursor: 'pointer',
            border: 'none',
            fontFamily: 'inherit',
          }}>
            View deal
          </button>
        </motion.div>

        {/* Info blocks — staggered in after content */}
        {[
          { label: 'All-inclusive', value: 'Food, drinks, activities' },
          { label: 'Check-in', value: 'Aug 10 — Aug 17 · 7 nights' },
          { label: 'Guests', value: '2 adults' },
        ].map((item, i) => (
          <motion.div
            key={item.label}
            initial={{ opacity: 0, y: 8 }}
            animate={{
              opacity: restMorph.fadeIn,
              y: restMorph.lerp(8, 0),
            }}
            transition={{
              duration: 0.55,
              ease: [0.42, 0.1, 0.24, 1],
              delay: 0.85 + i * 0.08,
            }}
            style={{
              padding: '14px 0',
              borderTop: '1px solid rgba(12,14,28,0.07)',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
            }}
          >
            <span style={{ fontSize: 14, color: Theme.inkMuted, fontWeight: 500 }}>
              {item.label}
            </span>
            <span style={{ fontSize: 14, color: Theme.ink, fontWeight: 600 }}>
              {item.value}
            </span>
          </motion.div>
        ))}
      </motion.div>
    </motion.div>
  );
};

const FavoriteButton: React.FC = () => {
  const [isFav, setIsFav] = React.useState(false);
  return (
    <button
      onClick={() => setIsFav(v => !v)}
      style={{
        width: 40,
        height: 40,
        borderRadius: '50%',
        background: 'rgba(0,0,0,0.35)',
        backdropFilter: 'blur(12px)',
        WebkitBackdropFilter: 'blur(12px)',
        border: '1px solid rgba(255,255,255,0.2)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        cursor: 'pointer',
        transition: `transform 0.39s cubic-bezier(0.42,0.1,0.24,1)`,
        transform: isFav ? 'scale(1.18)' : 'scale(1)',
      }}
    >
      <svg width="16" height="16" viewBox="0 0 24 24" fill={isFav ? '#e74c3c' : 'none'}>
        <path
          d="M12 21C12 21 3 14 3 8a5 5 0 0110 0 5 5 0 0110 0c0 6-9 13-9 13z"
          stroke={isFav ? '#e74c3c' : 'white'}
          strokeWidth="2"
        />
      </svg>
    </button>
  );
};

export default PackageDetailView;
