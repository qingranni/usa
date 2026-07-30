// MapView.tsx
// Owner: Jerome Bediones
//
// This component owns the full-height map panel on the left side of the
// search results canvas. It receives the destination string and the list
// of result cards so pins can be placed on the map.
//
// Suggested libraries (not yet installed — pick one):
//   - react-map-gl + Mapbox GL JS  (mapbox.com — needs API key)
//   - @vis.gl/react-google-maps    (Google Maps — needs API key)
//   - react-leaflet + OpenStreetMap (free, no key needed)
//
// To install react-leaflet (free option):
//   npm install react-leaflet leaflet @types/leaflet
//
// For now this file exports a placeholder with the correct interface.
// Replace the contents of MapView when ready to implement.

import React from 'react';
import type { ResultCard } from '../data/mockData';
import { Theme } from '../theme/theme';

interface Props {
  destination: string;
  cards?: ResultCard[];        // result cards to pin on the map
  onCardHover?: (id: string | null) => void;  // highlight a card on hover
  onPinClick?: (card: ResultCard) => void;    // select a card from map pin
}

const MapView: React.FC<Props> = ({ destination, cards = [], onCardHover, onPinClick }) => {
  // TODO Jerome: replace this placeholder with a real map implementation.
  // The Props interface above is the contract with App.tsx — feel free to
  // extend it but keep the existing props stable.

  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        background: 'linear-gradient(135deg, #e8f0f7 0%, #d4e6f1 50%, #c8dfe8 100%)',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 16,
      }}
    >
      {/* Map grid lines (placeholder visual) */}
      <svg
        style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity: 0.15 }}
        xmlns="http://www.w3.org/2000/svg"
      >
        <defs>
          <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
            <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#0C0E1C" strokeWidth="0.5"/>
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#grid)" />
      </svg>

      {/* Center pin */}
      <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, zIndex: 1 }}>
        <div
          style={{
            width: 48,
            height: 48,
            borderRadius: '50% 50% 50% 0',
            background: '#0C0E1C',
            transform: 'rotate(-45deg)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: '0 4px 12px rgba(12,14,28,0.25)',
          }}
        >
          <div
            style={{
              width: 16,
              height: 16,
              borderRadius: '50%',
              background: '#ffffff',
              transform: 'rotate(45deg)',
            }}
          />
        </div>

        <div
          style={{
            background: 'rgba(12,14,28,0.85)',
            backdropFilter: 'blur(8px)',
            borderRadius: 12,
            padding: '8px 16px',
            color: '#ffffff',
            fontSize: 14,
            fontWeight: 600,
            letterSpacing: '-0.2px',
            fontFamily: "'Centra No2', -apple-system, sans-serif",
          }}
        >
          {destination}
        </div>

        <span
          style={{
            fontSize: 12,
            color: 'rgba(12,14,28,0.5)',
            fontFamily: "'Centra No2', -apple-system, sans-serif",
          }}
        >
          Interactive map coming soon
        </span>
      </div>

      {/* Card pins (placeholder dots) */}
      {cards.slice(0, 5).map((card, i) => (
        <button
          key={card.id}
          onClick={() => onPinClick?.(card)}
          onMouseEnter={() => onCardHover?.(card.id)}
          onMouseLeave={() => onCardHover?.(null)}
          style={{
            position: 'absolute',
            top: `${30 + (i * 12)}%`,
            left: `${20 + (i * 13)}%`,
            background: '#ffffff',
            border: 'none',
            borderRadius: 8,
            padding: '4px 10px',
            fontSize: 13,
            fontWeight: 700,
            color: '#0C0E1C',
            boxShadow: '0 2px 8px rgba(12,14,28,0.18)',
            cursor: 'pointer',
            fontFamily: "'Centra No2', -apple-system, sans-serif",
            whiteSpace: 'nowrap',
            zIndex: 1,
          }}
        >
          {card.price ?? '···'}
        </button>
      ))}
    </div>
  );
};

export default MapView;
