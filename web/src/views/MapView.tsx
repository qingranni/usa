// MapView.tsx — react-leaflet with CartoDB Positron tiles
// Figma ref: right panel of node 3031:64841

import React, { useMemo, useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { MapContainer, TileLayer, Marker, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import type { ResultCard } from '../data/mockData';

// ── Coordinate lookup ──────────────────────────────────────────────────────────

const COORDS: Record<string, [number, number]> = {
  'cancun':            [21.162,  -86.852],
  'puerto vallarta':   [20.653, -105.225],
  'playa del carmen':  [20.630,  -87.074],
  'mexico city':       [19.432,  -99.133],
  'miami':             [25.762,  -80.192],
  'new york':          [40.713,  -74.006],
  'los angeles':       [34.052, -118.244],
  'san francisco':     [37.775, -122.419],
  'chicago':           [41.878,  -87.630],
  'houston':           [29.760,  -95.370],
  'seattle':           [47.606, -122.332],
  'boston':            [42.360,  -71.059],
  'washington dc':     [38.907,  -77.037],
  'london':            [51.507,   -0.128],
  'paris':             [48.857,    2.352],
  'tokyo':             [35.676,  139.650],
  'bali':              [-8.340,  115.092],
  'sydney':            [-33.869, 151.209],
  'barcelona':         [41.385,    2.173],
  'rome':              [41.902,   12.496],
  'amsterdam':         [52.370,    4.895],
};

// Origin — default to Houston; expand as needed
const ORIGIN: [number, number] = [29.760, -95.370];
const ORIGIN_LABEL = 'Houston';

function cardCoords(card: ResultCard): [number, number] | null {
  return COORDS[card.title.toLowerCase()] ?? null;
}

// ── Custom div markers ─────────────────────────────────────────────────────────

function makePriceIcon(price: string, selected: boolean, title: string, anchorOffsetX = 0) {
  const bg     = selected ? '#191E3B'               : 'rgba(255,255,255,0.96)';
  const fg     = selected ? '#ffffff'               : '#0c0e1c';
  const border = selected ? 'rgba(255,255,255,0.12)': 'rgba(12,14,28,0.08)';
  const shadow = selected
    ? '0 4px 14px rgba(25,30,59,0.45), 0 1px 3px rgba(0,0,0,0.3)'
    : '0 2px 10px rgba(12,14,28,0.14), 0 1px 2px rgba(0,0,0,0.08)';

  return L.divIcon({
    className: '',
    // iconSize / iconAnchor: use a large nominal size so Leaflet doesn't clip,
    // then anchor at the horizontal center and full height (tip of caret)
    iconSize: [120, 52],
    iconAnchor: [60 + anchorOffsetX, 52],
    html: `
      <div class="pin-enter" style="display:inline-flex; flex-direction:column; align-items:center; pointer-events:all; cursor:pointer;">
        <div style="
          background:${bg}; border:1px solid ${border};
          border-radius:20px; padding:7px 13px;
          box-shadow:${shadow};
          display:flex; flex-direction:column; align-items:center; gap:1px;
          white-space:nowrap;
          font-family:'Centra No2',-apple-system,sans-serif;
          backdrop-filter:blur(12px); -webkit-backdrop-filter:blur(12px);
        ">
          <span style="color:${fg}; font-size:13px; font-weight:600; line-height:1.3; letter-spacing:-0.01em;">${title}</span>
          <span style="color:${fg}; font-size:11px; font-weight:500; opacity:${selected ? 0.75 : 0.6}; line-height:1.2;">${price}</span>
        </div>
        <div style="
          width:0; height:0;
          border-left:5px solid transparent;
          border-right:5px solid transparent;
          border-top:6px solid ${bg};
          margin-top:-1px;
        "></div>
      </div>`,
  });
}

function makeOriginIcon(_label: string) {
  return L.divIcon({
    className: '',
    iconSize: [28, 28],
    iconAnchor: [14, 14],
    html: `
      <div class="pin-enter" style="
        width:28px; height:28px; border-radius:50%;
        background:#FF2D9B;
        display:flex; align-items:center; justify-content:center;
        box-shadow:0 3px 10px rgba(255,45,155,0.5), 0 0 0 2px rgba(255,255,255,0.9);
      ">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
          <path d="M3 10.5L12 3L21 10.5V21C21 21.55 20.55 22 20 22H15V16H9V22H4C3.45 22 3 21.55 3 21V10.5Z"
            fill="white" stroke="white" stroke-width="0.5" stroke-linejoin="round"/>
        </svg>
      </div>`,
  });
}

// Flight-duration badge along the midpoint of the path
function FlightBadge({ from, to, label }: {
  from: [number, number]; to: [number, number]; label: string;
}) {
  const mid: [number, number] = [
    (from[0] + to[0]) / 2,
    (from[1] + to[1]) / 2,
  ];
  const icon = L.divIcon({
    className: '',
    iconAnchor: [0, 0],
    html: `
      <div style="
        display:flex; align-items:center; gap:5px;
        background:rgba(255,255,255,0.95); border:1px solid rgba(12,14,28,0.08);
        border-radius:999px; padding:6px 11px;
        backdrop-filter:blur(12px); -webkit-backdrop-filter:blur(12px);
        box-shadow:0 2px 10px rgba(12,14,28,0.12);
        white-space:nowrap;
        font-family:'Centra No2',-apple-system,sans-serif;
        font-size:12px; color:#0c0e1c; font-weight:500;
      ">
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none">
          <path d="M21 16v-2l-8-5V3.5c0-.83-.67-1.5-1.5-1.5S10 2.67 10 3.5V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5l8 2.5z"
            fill="#0c0e1c"/>
        </svg>
        ${label}
      </div>`,
  });
  return <Marker position={mid} icon={icon} />;
}

// ── Animated intro ────────────────────────────────────────────────────────────

type AnimPhase = 'wide' | 'zooming' | 'pins';

function AnimatedIntro({ points, onPhase, ready }: {
  points: [number, number][];
  onPhase: (p: AnimPhase) => void;
  ready: boolean;
}) {
  const map = useMap();
  const started = React.useRef(false);

  useEffect(() => {
    if (!ready || started.current || points.length < 2) return;
    started.current = true;

    // Start wide so the fly-in is visible after loading ends
    map.setView([28, -95], 3, { animate: false });

    const t = setTimeout(() => {
      const bounds = L.latLngBounds(points.map(p => L.latLng(p[0], p[1])));
      onPhase('zooming');
      map.flyToBounds(bounds.pad(0.3), { animate: true, duration: 1.8, maxZoom: 7, easeLinearity: 0.25 });
      map.once('moveend', () => setTimeout(() => onPhase('pins'), 300));
    }, 400);

    return () => clearTimeout(t);
  }, [ready, map]); // eslint-disable-line react-hooks/exhaustive-deps

  return null;
}

// ── Carousel overlay ──────────────────────────────────────────────────────────

const CarouselOverlay: React.FC<{
  cards: ResultCard[];
  onPinClick?: (card: ResultCard) => void;
  selectedCard?: ResultCard | null;
}> = ({ cards, onPinClick, selectedCard }) => {
  const [activeCardId, setActiveCardId] = useState<string | null>(null);

  if (cards.length === 0) return null;

  return (
    <div
      style={{
        position: 'absolute',
        bottom: 20,
        left: 16,
        right: 16,
        zIndex: 10,
        display: 'flex',
        flexDirection: 'row',
        gap: 12,
        overflowX: 'auto',
        scrollbarWidth: 'none',
        paddingBottom: 2,
      }}
    >
      {cards.map((card, i) => {
        const isActive = activeCardId === card.id || selectedCard?.id === card.id;
        return (
          <motion.div
            key={card.id}
            initial={{ y: 16, opacity: 0 }}
            animate={{ y: 0, opacity: 1, scale: isActive ? 1.02 : 1 }}
            transition={{
              y: { delay: i * 0.06, type: 'spring', stiffness: 300, damping: 30 },
              opacity: { delay: i * 0.06, duration: 0.25 },
              scale: { type: 'spring', stiffness: 300, damping: 30 },
            }}
            onClick={() => {
              setActiveCardId(card.id);
              onPinClick?.(card);
            }}
            style={{
              width: 200,
              flexShrink: 0,
              borderRadius: 16,
              background: 'rgba(255,255,255,0.88)',
              backdropFilter: 'blur(20px)',
              WebkitBackdropFilter: 'blur(20px)',
              border: `1px solid ${isActive ? 'rgba(12,14,28,0.2)' : 'rgba(255,255,255,0.9)'}`,
              boxShadow: '0 4px 16px rgba(12,14,28,0.12)',
              overflow: 'hidden',
              cursor: 'pointer',
              fontFamily: "'Centra No2', -apple-system, sans-serif",
              transition: 'border-color 0.15s ease',
            }}
          >
            <img
              src={card.imageUrl}
              alt={card.title}
              style={{
                width: '100%',
                height: 110,
                objectFit: 'cover',
                borderRadius: '12px 12px 0 0',
                display: 'block',
              }}
            />
            <div
              style={{
                padding: '10px 12px 12px',
                display: 'flex',
                flexDirection: 'column',
                gap: 4,
              }}
            >
              <div
                style={{
                  fontSize: 15,
                  fontWeight: 600,
                  color: '#0c0e1c',
                  lineHeight: 1.2,
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                }}
              >
                {card.title}
              </div>
              <div
                style={{
                  fontSize: 12,
                  color: 'rgba(12,14,28,0.5)',
                  lineHeight: 1.3,
                  whiteSpace: 'nowrap',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                }}
              >
                {card.subtitle}
              </div>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'baseline',
                  gap: 3,
                  marginTop: 2,
                }}
              >
                <span style={{ fontSize: 12, color: 'rgba(12,14,28,0.5)' }}>from</span>
                <span style={{ fontSize: 15, fontWeight: 600, color: '#0c0e1c' }}>
                  {card.price}
                </span>
              </div>
            </div>
          </motion.div>
        );
      })}
    </div>
  );
};

// ── Selected card popup ───────────────────────────────────────────────────────

const SelectedCardPopup: React.FC<{ card: ResultCard }> = ({ card }) => (
  <motion.div
    initial={{ opacity: 0, y: 16, scale: 0.95 }}
    animate={{ opacity: 1, y: 0, scale: 1 }}
    exit={{ opacity: 0, y: 12, scale: 0.95 }}
    transition={{ type: 'spring', stiffness: 320, damping: 28 }}
    style={{
      position: 'absolute',
      bottom: 90,
      left: 16,
      zIndex: 20,
      width: 330,
      padding: 8,
      borderRadius: 24,
      background: 'linear-gradient(180deg, rgba(247,244,244,0.5) 0%, rgba(247,244,243,0.5) 96%), linear-gradient(90deg, rgb(246,245,244) 0%, rgb(246,245,244) 100%)',
      backdropFilter: 'blur(64px)',
      WebkitBackdropFilter: 'blur(64px)',
      border: '1px solid rgba(255,255,255,0.9)',
      boxShadow: '0px 12px 16px rgba(0,0,0,0.12)',
      display: 'flex',
      flexDirection: 'row',
      gap: 12,
      fontFamily: "'Centra No2', -apple-system, sans-serif",
    }}
  >
    {/* Left — image */}
    <div style={{ position: 'relative', width: 124, height: 124, borderRadius: 16, overflow: 'hidden', flexShrink: 0 }}>
      <img
        src={card.imageUrl}
        alt={card.title}
        style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
      />
      {/* Blue gradient overlay */}
      <div style={{
        position: 'absolute', inset: 0,
        background: 'linear-gradient(152deg, rgba(38,111,170,0.5) 15%, rgba(38,111,170,0) 47%)',
        pointerEvents: 'none',
      }} />
      {/* Heart button */}
      <div style={{
        position: 'absolute', top: 8, left: 8,
        width: 32, height: 32, borderRadius: 30,
        background: 'rgba(12,14,28,0.05)',
        backdropFilter: 'blur(7.5px)',
        WebkitBackdropFilter: 'blur(7.5px)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        cursor: 'pointer',
      }}>
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
          <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z" stroke="rgba(255,255,255,0.9)" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      </div>
    </div>

    {/* Right — info */}
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'space-between', height: 124, padding: 4 }}>
      <div>
        <div style={{ fontSize: 16, fontWeight: 500, color: '#0c0e1c', lineHeight: 1.25, marginBottom: 4 }}>
          {card.title}
        </div>
        <div style={{ fontSize: 14, fontWeight: 400, color: 'rgba(12,14,28,0.5)', lineHeight: 1.3 }}>
          {card.subtitle}
        </div>
      </div>
      <div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
          <span style={{ fontSize: 15, color: 'rgba(12,14,28,0.6)' }}>from</span>
          <span style={{ fontSize: 16, fontWeight: 500, color: '#1a0e2a', letterSpacing: '-0.5px' }}>
            {card.price}
          </span>
        </div>
        <div style={{ fontSize: 12, color: 'rgba(12,14,28,0.5)', marginTop: 2 }}>
          {card.priceNote}
        </div>
      </div>
    </div>
  </motion.div>
);

// ── Props ──────────────────────────────────────────────────────────────────────

interface Props {
  destination: string;
  cards?: ResultCard[];
  onCardHover?: (id: string | null) => void;
  onPinClick?: (card: ResultCard) => void;
  selectedCard?: ResultCard | null;
  onSelectedCardChange?: (card: ResultCard | null) => void;
  ready?: boolean;
}

// ── Component ─────────────────────────────────────────────────────────────────

const MapView: React.FC<Props> = ({ destination, cards = [], onPinClick, selectedCard: selectedCardProp, onSelectedCardChange, ready = true }) => {
  const [animPhase, setAnimPhase] = useState<AnimPhase>('wide');
  const [visiblePinCount, setVisiblePinCount] = useState(0);
  const [internalSelected, setInternalSelected] = useState<ResultCard | null>(null);

  // Use external selectedCard if provided, otherwise internal
  const selectedCard = selectedCardProp !== undefined ? selectedCardProp : internalSelected;
  const setSelectedCard = (card: ResultCard | null) => {
    setInternalSelected(card);
    onSelectedCardChange?.(card);
  };

  const pinned = useMemo(
    () => cards.map(c => ({ card: c, pos: cardCoords(c) })).filter(x => x.pos !== null) as { card: ResultCard; pos: [number, number] }[],
    [cards],
  );

  // Fit to origin + all destination pins
  const allPoints: [number, number][] = useMemo(
    () => [ORIGIN, ...pinned.map(p => p.pos)],
    [pinned],
  );

  // Stagger pin reveal after flyTo completes
  useEffect(() => {
    if (animPhase !== 'pins') return;
    setVisiblePinCount(0);
    const timers: ReturnType<typeof setTimeout>[] = [];
    for (let i = 0; i < pinned.length; i++) {
      timers.push(setTimeout(() => setVisiblePinCount(i + 1), i * 180));
    }
    return () => timers.forEach(clearTimeout);
  }, [animPhase, pinned.length]);

  // Memoize icons so re-renders from selectedCard/visiblePinCount don't recreate them
  const originIcon = useMemo(() => makeOriginIcon(''), []);
  const pinIcons = useMemo(() => {
    // Simple overlap-spread: for each pin, check if it's within ~1.5° of any earlier pin.
    // If so, shift later pin right and earlier pin left to separate their labels.
    const OVERLAP_DEG = 1.5;
    const offsets = pinned.map(() => 0);
    for (let a = 0; a < pinned.length; a++) {
      for (let b = a + 1; b < pinned.length; b++) {
        const [latA, lonA] = pinned[a].pos;
        const [latB, lonB] = pinned[b].pos;
        const dist = Math.sqrt((latA - latB) ** 2 + (lonA - lonB) ** 2);
        if (dist < OVERLAP_DEG) {
          // Spread: shift left pin's anchor right, right pin's anchor left
          const aIsLeft = lonA < lonB;
          offsets[a] += aIsLeft ? -28 : 28;
          offsets[b] += aIsLeft ? 28 : -28;
        }
      }
    }
    return pinned.map(({ card }, i) => makePriceIcon(card.price, i === 0, card.title, offsets[i]));
  }, [pinned]);

  return (
    <div style={{ position: 'absolute', inset: 0 }}>
      <style>{`
        .leaflet-control-attribution { font-size: 10px; opacity: 0.5; }
        .leaflet-container { font-family: 'Centra No2', -apple-system, sans-serif; }
        .leaflet-container ::-webkit-scrollbar { display: initial; }

        /* Carousel scrollbar — hide */
        .map-carousel::-webkit-scrollbar { display: none; }

        /* Pin pop-in animation */
        @keyframes pin-pop {
          0%   { transform: scale(0.3) translateY(10px); opacity: 0; }
          65%  { transform: scale(1.15) translateY(-3px); opacity: 1; }
          100% { transform: scale(1)   translateY(0);    opacity: 1; }
        }
        .pin-enter { animation: pin-pop 0.4s cubic-bezier(0.34,1.56,0.64,1) both; }

        /* Zoom control — glass pill style */
        .leaflet-control-zoom {
          border: none !important;
          border-radius: 14px !important;
          overflow: hidden;
          box-shadow: 0 4px 16px rgba(12,14,28,0.12), 0 1px 0 rgba(255,255,255,0.8) inset !important;
          backdrop-filter: blur(20px);
          -webkit-backdrop-filter: blur(20px);
        }
        .leaflet-control-zoom a {
          width: 36px !important;
          height: 36px !important;
          line-height: 36px !important;
          background: rgba(255,255,255,0.82) !important;
          color: #0c0e1c !important;
          font-size: 18px !important;
          font-weight: 400 !important;
          border: none !important;
          border-bottom: 1px solid rgba(12,14,28,0.06) !important;
          transition: background 0.15s ease;
        }
        .leaflet-control-zoom a:last-child {
          border-bottom: none !important;
        }
        .leaflet-control-zoom a:hover {
          background: rgba(255,255,255,0.97) !important;
        }
        .leaflet-control-zoom-in { border-radius: 14px 14px 0 0 !important; }
        .leaflet-control-zoom-out { border-radius: 0 0 14px 14px !important; }
      `}</style>

      <MapContainer
        center={[28, -95]}
        zoom={3}
        zoomControl
        style={{ width: '100%', height: '100%' }}
        scrollWheelZoom
      >
        {/* CartoDB Positron — clean, light, free */}
        <TileLayer
          url="https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png"
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/attributions">CARTO</a>'
          subdomains="abcd"
          maxZoom={19}
        />

        {/* Animated intro — replaces FitBounds */}
        {allPoints.length > 1 && (
          <AnimatedIntro points={allPoints} onPhase={setAnimPhase} ready={ready} />
        )}

        {/* Origin marker — revealed at pins phase */}
        {animPhase === 'pins' && (
          <Marker position={ORIGIN} icon={originIcon} />
        )}


        {/* Destination price-tag markers — revealed one by one */}
        {pinned.slice(0, visiblePinCount).map(({ card, pos }, i) => (
          <Marker
            key={card.id}
            position={pos}
            icon={pinIcons[i]}
            zIndexOffset={(pinned.length - i) * 10000}
            eventHandlers={{ click: () => {
              setSelectedCard(selectedCard?.id === card.id ? null : card);
              onPinClick?.(card);
            } }}
          />
        ))}
      </MapContainer>

      {/* CarouselOverlay removed — destination cards live in the left panel */}

      {/* Selected card popup — animated overlay above carousel */}
      <AnimatePresence>
        {selectedCard !== null && (
          <SelectedCardPopup key={selectedCard.id} card={selectedCard} />
        )}
      </AnimatePresence>
    </div>
  );
};

export default MapView;
