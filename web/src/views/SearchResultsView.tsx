// SearchResultsView.tsx
// Owner: Jerome Bediones
//
// This component owns the right-side search results panel that slides up
// after a search query is submitted. It lives alongside MapView (left side).
//
// Data arrives via the `thread` prop (type: Thread from mockData.ts).
// The app store provides reveal state for the curtain drag animation.
//
// Key interactions to build:
//  - Result cards list (hotels, flights, packages, etc.)
//  - Filter/sort bar at the top
//  - Clicking a card → calls onCardClick(card) to open PackageDetailView
//  - Drag handle at top to collapse/expand the panel (see CurtainSheet.tsx
//    for the existing drag logic you can reuse or replace)
//
// For reference, the existing results rendering is in CurtainSheet.tsx —
// feel free to migrate pieces from there into this file, or start fresh.

import React from 'react';
import { motion } from 'framer-motion';
import type { Thread, ResultCard } from '../data/mockData';
import { useAppStore } from '../store/appStore';

interface Props {
  thread: Thread;
  onCardClick: (card: ResultCard) => void;
}

const SearchResultsView: React.FC<Props> = ({ thread, onCardClick }) => {
  const { reveal } = useAppStore();

  // TODO Jerome: build the results list here
  // thread.narratives contains the result cards to display
  // thread.query is the search query string

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        background: '#ffffff',
        overflow: 'hidden',
      }}
    >
      {/* Drag handle */}
      <div
        style={{
          width: 36,
          height: 4,
          borderRadius: 2,
          background: 'rgba(12,14,28,0.15)',
          margin: '12px auto 0',
          flexShrink: 0,
          cursor: 'grab',
        }}
      />

      {/* Header */}
      <div
        style={{
          padding: '16px 24px 12px',
          borderBottom: '1px solid rgba(12,14,28,0.06)',
          flexShrink: 0,
        }}
      >
        <p
          style={{
            fontSize: 13,
            fontWeight: 400,
            color: 'rgba(12,14,28,0.45)',
            marginBottom: 4,
          }}
        >
          Results for
        </p>
        <h2
          style={{
            fontSize: 20,
            fontWeight: 600,
            color: '#0C0E1C',
            letterSpacing: '-0.3px',
          }}
        >
          {thread.query ?? thread.destination}
        </h2>
      </div>

      {/* Results list — Jerome: replace this placeholder */}
      <div
        style={{
          flex: 1,
          overflowY: 'auto',
          padding: '16px 16px',
          display: 'flex',
          flexDirection: 'column',
          gap: 12,
        }}
      >
        {thread.narratives.map(narrative =>
          narrative.cards.map(card => (
            <motion.button
              key={card.id}
              whileHover={{ scale: 1.01 }}
              whileTap={{ scale: 0.99 }}
              onClick={() => onCardClick(card)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 14,
                padding: '14px 16px',
                borderRadius: 16,
                border: '1px solid rgba(12,14,28,0.07)',
                background: '#ffffff',
                boxShadow: '0 2px 8px rgba(12,14,28,0.05)',
                cursor: 'pointer',
                textAlign: 'left',
                width: '100%',
              }}
            >
              {/* Thumbnail */}
              {card.heroImage && (
                <img
                  src={card.heroImage}
                  alt={card.name}
                  style={{
                    width: 72,
                    height: 72,
                    borderRadius: 10,
                    objectFit: 'cover',
                    flexShrink: 0,
                  }}
                />
              )}

              {/* Info */}
              <div style={{ flex: 1, minWidth: 0 }}>
                <p
                  style={{
                    fontSize: 15,
                    fontWeight: 600,
                    color: '#0C0E1C',
                    letterSpacing: '-0.2px',
                    marginBottom: 2,
                    whiteSpace: 'nowrap',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                  }}
                >
                  {card.name}
                </p>
                {card.subtitle && (
                  <p
                    style={{
                      fontSize: 13,
                      fontWeight: 400,
                      color: 'rgba(12,14,28,0.55)',
                      marginBottom: 4,
                    }}
                  >
                    {card.subtitle}
                  </p>
                )}
                {card.price && (
                  <p
                    style={{
                      fontSize: 15,
                      fontWeight: 700,
                      color: '#0C0E1C',
                    }}
                  >
                    {card.price}
                  </p>
                )}
              </div>

              {/* Rating badge */}
              {card.rating != null && (
                <div
                  style={{
                    flexShrink: 0,
                    background: '#0C9300',
                    borderRadius: 8,
                    padding: '4px 8px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: 4,
                  }}
                >
                  <span
                    style={{
                      fontSize: 13,
                      fontWeight: 700,
                      color: '#ffffff',
                    }}
                  >
                    {card.rating.toFixed(1)}
                  </span>
                </div>
              )}
            </motion.button>
          ))
        )}

        {thread.narratives.length === 0 && (
          <div
            style={{
              flex: 1,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              color: 'rgba(12,14,28,0.35)',
              fontSize: 14,
            }}
          >
            No results yet
          </div>
        )}
      </div>

      {/* TODO Jerome: add filter bar, sort options, map toggle */}
      <div
        style={{
          padding: '12px 16px',
          borderTop: '1px solid rgba(12,14,28,0.06)',
          display: 'flex',
          gap: 8,
          flexShrink: 0,
        }}
      >
        {['All', 'Hotels', 'Flights', 'Packages'].map(filter => (
          <button
            key={filter}
            style={{
              padding: '6px 14px',
              borderRadius: 20,
              border: '1px solid rgba(12,14,28,0.12)',
              background: filter === 'All' ? '#0C0E1C' : 'transparent',
              color: filter === 'All' ? '#ffffff' : '#0C0E1C',
              fontSize: 13,
              fontWeight: 500,
              cursor: 'pointer',
              fontFamily: "'Centra No2', -apple-system, sans-serif",
            }}
          >
            {filter}
          </button>
        ))}
      </div>
    </div>
  );
};

export default SearchResultsView;
