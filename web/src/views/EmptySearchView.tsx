// EmptySearchView.tsx — Desktop homepage matching Figma node 3031:55634
// Exact tokens from get_design_context: colors, shadows, radii, typography

import React, { useState, useCallback, useMemo, useEffect, useRef } from 'react';
import ReactDOM from 'react-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { useAppStore } from '../store/appStore';

// ─── Figma asset URLs (expire in ~7 days) ───────────────────────────────────
const ASSET_HERO   = 'https://www.figma.com/api/mcp/asset/9e170923-0c40-42a5-b0be-bb719f9d0c84';
const ASSET_HOTEL  = 'https://www.figma.com/api/mcp/asset/112787a9-e99a-45fe-bc7c-0aba65b8956f';
const ASSET_FLIGHT = 'https://www.figma.com/api/mcp/asset/365bbe7c-ac97-41df-b951-d2a4f9dc565b';
const ASSET_VOICE  = 'https://www.figma.com/api/mcp/asset/4ea091b0-2293-4b48-b245-8ea8d762678e';
const ASSET_STAYS  = 'https://www.figma.com/api/mcp/asset/d7aeccfb-bc61-4ca2-97b9-4df39029a4de';
const ASSET_FLIGHTS= 'https://www.figma.com/api/mcp/asset/d95a9290-3923-4305-8951-6c8e37ecf266';
const ASSET_CARS   = 'https://www.figma.com/api/mcp/asset/a12854cb-1251-4881-ab48-a2d2551a58a4';
const ASSET_PKG    = 'https://www.figma.com/api/mcp/asset/60cc8054-fe9e-4954-a31e-c3b8d3fe3f53';
const ASSET_TTD    = 'https://www.figma.com/api/mcp/asset/3032c053-25ba-4f8d-8651-a14cc6f45644';
const ASSET_CRUISE = 'https://www.figma.com/api/mcp/asset/2ccc2b22-0209-4f79-8b77-ca336473c659';

// ─── Design tokens (verbatim from Figma) ────────────────────────────────────
const T = {
  pageBg:       '#FFFFFF',
  cardBg:       '#F6F5F4',        // search card outer — visibly distinct from page
  cardShadow:   'none',
  inputBg:      '#ffffff',
  inputBorder:  '#E0E0E0',
  inputShadow:  '0px 6px 18px rgba(12,14,28,0.12)',
  inputRadius:  24,
  chipBg:       'rgba(12,14,28,0.05)',
  chipRadius:   100,
  textPrimary:  '#191E3B',
  textMuted:    '#595959',
  textVariant:  '#676A7D',
  textInk:      '#0C0E1C',
  voiceBg:      '#E9EBEF',
  // Submit button: always yellow (OneKey brand), darker stroke when focused+text
  submitBg:     'rgba(253,219,50,1)',
  submitBorder: 'rgba(253,219,50,0.3)',
  submitShadow: '0px 4px 16px rgba(253,219,50,0.35)',
  recapBg:      '#F7F4F3',
  recapRadius:  24,
  ratingBg:     '#0C9300',
  ratingText:   '#191E3B',
  sidebarBg:    '#FFFFFF',        // matches page bg
  sidebarBtnBg: 'linear-gradient(179.9deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.5) 95.923%), linear-gradient(90deg, #F0EDE8 0%, #F0EDE8 100%)',
  sidebarBtnShadow: '0px 12px 16px rgba(12,14,28,0.08)',
} as const;

const ease = [0.42, 0.1, 0.24, 1] as const;

const LOB_TABS = [
  { label: 'Stays',        img: ASSET_STAYS  },
  { label: 'Flights',      img: ASSET_FLIGHTS },
  { label: 'Cars',         img: ASSET_CARS   },
  { label: 'Packages',     img: ASSET_PKG    },
  { label: 'Things to Do', img: ASSET_TTD    },
  { label: 'Cruises',      img: ASSET_CRUISE },
];

const DESTINATIONS = [
  { label: 'Paris',    img: 'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?w=400&auto=format&fit=crop' },
  { label: 'Cancun',   img: 'https://images.unsplash.com/photo-1590523277543-a94d2e4eb00b?w=400&auto=format&fit=crop' },
  { label: 'Tokyo',    img: 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=400&auto=format&fit=crop' },
  { label: 'New York', img: 'https://images.unsplash.com/photo-1485871981521-5b1fd3805eee?w=400&auto=format&fit=crop' },
  { label: 'Rome',     img: 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=400&auto=format&fit=crop' },
];

// ─── Icons (inline SVGs matching Figma glyphs) ──────────────────────────────
const IconAdd = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
    <path d="M12 5v14M5 12h14" stroke="#0C0E1C" strokeWidth="2" strokeLinecap="round"/>
  </svg>
);
const IconCalendar = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
    <rect x="3" y="4" width="18" height="18" rx="2" stroke="#0C0E1C" strokeWidth="1.8"/>
    <path d="M3 9h18" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round"/>
    <path d="M8 2v4M16 2v4" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round"/>
  </svg>
);
const IconPeople = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
    <circle cx="9" cy="7" r="3.5" stroke="#0C0E1C" strokeWidth="1.8"/>
    <path d="M2 20c0-3.866 3.134-7 7-7s7 3.134 7 7" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round"/>
    <circle cx="17" cy="8" r="2.5" stroke="#0C0E1C" strokeWidth="1.8"/>
    <path d="M22 20c0-2.761-2.239-5-5-5" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round"/>
  </svg>
);
const IconPin = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
    <path d="M12 2C8.686 2 6 4.686 6 8c0 5.25 6 13 6 13s6-7.75 6-13c0-3.314-2.686-6-6-6z" stroke="#0C0E1C" strokeWidth="1.8"/>
    <circle cx="12" cy="8" r="2" stroke="#0C0E1C" strokeWidth="1.8"/>
  </svg>
);
const IconBudget = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
    <circle cx="12" cy="12" r="9" stroke="#0C0E1C" strokeWidth="1.8"/>
    <path d="M12 7v1m0 8v1M9.5 15a2.5 2.5 0 0 0 2.5 1.5A2.5 2.5 0 0 0 14.5 14c0-1.4-2.5-2-2.5-3.5A2 2 0 0 1 14.5 9" stroke="#0C0E1C" strokeWidth="1.6" strokeLinecap="round"/>
  </svg>
);
const IconArrow = ({ color = '#0C0E1C' }: { color?: string }) => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
    <path d="M5 12h14M12 5l7 7-7 7" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
);
const IconSearch = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
    <circle cx="11" cy="11" r="7" stroke="#676A7D" strokeWidth="1.8"/>
    <path d="M16.5 16.5L21 21" stroke="#676A7D" strokeWidth="1.8" strokeLinecap="round"/>
  </svg>
);
const IconChevronDown = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none">
    <path d="M6 9l6 6 6-6" stroke="#191E3B" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
);
const IconRouteTrip = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
    <path d="M4 12h16M16 8l4 4-4 4" stroke="#191E3B" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
    <path d="M8 8L4 12" stroke="#191E3B" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
);
const IconSeat = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
    <path d="M6 3v9a3 3 0 003 3h6" stroke="#191E3B" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
    <path d="M6 21h12" stroke="#191E3B" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
    <path d="M9 15v6" stroke="#191E3B" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
);
const IconPlane = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
    <path d="M22 2L11 13" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
    <path d="M22 2L15 22l-4-9-9-4 20-7z" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
);

// ─── Token parsing ────────────────────────────────────────────────────────────
type EntityType = 'date' | 'place' | 'people' | 'budget';
type Token =
  | { type: 'text'; value: string }
  | { type: 'chip'; value: string; entityType: EntityType; start: number; end: number };

type Segment =
  | { id: string; type: 'chip'; value: string; entityType: EntityType }
  | { id: string; type: 'text'; value: string };

type DisplayToken =
  | { id: string; type: 'chip'; value: string; entityType: EntityType }
  | { id: string; type: 'text'; value: string };

const ENTITY_PATTERNS: { entityType: EntityType; regex: RegExp }[] = [
  {
    entityType: 'date',
    regex: /\b(spring\s+break|summer|winter|fall|autumn|christmas|thanksgiving|new\s+year|january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec|\d+\s+nights?|\d+\s+weeks?|\d+\s+days?)\b/gi,
  },
  {
    entityType: 'place',
    regex: /\b(paris|london|tokyo|new\s+york|cancun|mexico|hawaii|bali|barcelona|rome|italy|france|spain|japan|thailand|greece|portugal|costa\s+rica|caribbean|miami|las\s+vegas|orlando|dubai|maldives|europe|asia)\b/gi,
  },
  {
    entityType: 'people',
    regex: /\b(\d+\s+adults?\s+and\s+\d+\s+(?:kids?|children|teenagers?|teens?)|\d+\s+adults?|\d+\s+people|family\s+of\s+\d+)\b/gi,
  },
  {
    entityType: 'budget',
    regex: /\b(under\s+\$[\d,]+|over\s+\$[\d,]+|around\s+\$[\d,]+|up\s+to\s+\$[\d,]+|\$[\d,]+\s+budget|cheap|luxury)\b/gi,
  },
];

function parseTokens(text: string): Token[] {
  if (!text) return [];

  interface Match { start: number; end: number; value: string; entityType: EntityType }
  const matches: Match[] = [];

  for (const { entityType, regex } of ENTITY_PATTERNS) {
    regex.lastIndex = 0;
    let m: RegExpExecArray | null;
    while ((m = regex.exec(text)) !== null) {
      const start = m.index;
      const end = m.index + m[0].length;
      const overlaps = matches.some(existing => start < existing.end && end > existing.start);
      if (!overlaps) matches.push({ start, end, value: m[0], entityType });
    }
  }

  matches.sort((a, b) => a.start - b.start);

  const tokens: Token[] = [];
  let cursor = 0;
  for (const match of matches) {
    if (match.start > cursor) {
      tokens.push({ type: 'text', value: text.slice(cursor, match.start) });
    }
    tokens.push({ type: 'chip', value: match.value, entityType: match.entityType, start: match.start, end: match.end });
    cursor = match.end;
  }
  if (cursor < text.length) {
    tokens.push({ type: 'text', value: text.slice(cursor) });
  }
  return tokens;
}

const ENTITY_ICON: Record<EntityType, React.ReactElement> = {
  date: <IconCalendar />,
  place: <IconPin />,
  people: <IconPeople />,
  budget: <IconBudget />,
};

// ─── Contextual suggestion chips ─────────────────────────────────────────────
type ContextChipIconType = 'calendar' | 'destination' | 'people' | 'star' | 'map' | 'tag';
interface ContextChip { id: string; icon: ContextChipIconType; label: string }

function deriveContextualChips(segments: Segment[], liveText: string): ContextChip[] {
  if (!liveText.trim() && segments.length === 0) {
    return [
      { id: 'destination', icon: 'destination', label: 'Add destination' },
      { id: 'dates',       icon: 'calendar',    label: 'Add dates'        },
      { id: 'travelers',   icon: 'people',      label: 'Add travelers'    },
    ];
  }

  const fullText = [...segments.map(s => s.value), liveText].join(' ').toLowerCase();

  const detectedTypes = new Set<EntityType>();
  for (const s of segments) {
    if (s.type === 'chip') detectedTypes.add(s.entityType);
  }
  for (const t of parseTokens(liveText)) {
    if (t.type === 'chip') detectedTypes.add(t.entityType);
  }

  const chips: ContextChip[] = [];

  if (!detectedTypes.has('place'))  chips.push({ id: 'destination', icon: 'destination', label: 'Add destination' });
  if (!detectedTypes.has('date'))   chips.push({ id: 'dates',       icon: 'calendar',    label: 'Add dates'        });
  if (!detectedTypes.has('people')) chips.push({ id: 'travelers',   icon: 'people',      label: 'Add travelers'    });

  const tropical = ['miami', 'cancun', 'caribbean', 'hawaii', 'bali', 'maldives', 'costa rica'];
  const culture  = ['paris', 'rome', 'barcelona', 'italy', 'france', 'spain', 'portugal', 'europe'];
  const asia     = ['tokyo', 'japan', 'thailand', 'asia'];

  if (tropical.some(kw => fullText.includes(kw))) {
    chips.push(
      { id: 'all-inclusive', icon: 'star', label: 'All inclusive' },
      { id: 'near-beaches',  icon: 'map',  label: 'Near beaches'  },
      { id: 'water-sports',  icon: 'tag',  label: 'Water sports'  },
    );
  } else if (culture.some(kw => fullText.includes(kw))) {
    chips.push(
      { id: 'best-museums',     icon: 'star', label: 'Best museums'     },
      { id: 'local-food-tours', icon: 'map',  label: 'Local food tours' },
      { id: 'city-walks',       icon: 'tag',  label: 'City walks'       },
    );
  } else if (asia.some(kw => fullText.includes(kw))) {
    chips.push(
      { id: 'local-experiences', icon: 'star', label: 'Local experiences' },
      { id: 'street-food',       icon: 'map',  label: 'Street food'       },
      { id: 'temple-tours',      icon: 'tag',  label: 'Temple tours'      },
    );
  } else if (fullText.includes('las vegas')) {
    chips.push(
      { id: 'shows-events',  icon: 'star', label: 'Shows & events' },
      { id: 'casino-resorts', icon: 'map', label: 'Casino resorts' },
      { id: 'nightlife',     icon: 'tag',  label: 'Nightlife'      },
    );
  } else if (fullText.includes('orlando')) {
    chips.push(
      { id: 'theme-parks',      icon: 'star', label: 'Theme parks'      },
      { id: 'family-resorts',   icon: 'map',  label: 'Family resorts'   },
      { id: 'discount-tickets', icon: 'tag',  label: 'Discount tickets' },
    );
  }

  if (fullText.includes('spring break')) {
    chips.push(
      { id: 'spring-break-pkgs', icon: 'tag', label: 'Spring break packages' },
      { id: 'beach-clubs',       icon: 'map', label: 'Beach clubs'            },
    );
  } else if (fullText.includes('summer')) {
    chips.push(
      { id: 'peak-season', icon: 'tag',  label: 'Peak season tips' },
      { id: 'early-bird',  icon: 'star', label: 'Early bird deals' },
    );
  } else if (
    fullText.includes('christmas') ||
    fullText.includes('thanksgiving') ||
    fullText.includes('holiday')
  ) {
    chips.push(
      { id: 'holiday-pkgs',      icon: 'tag',    label: 'Holiday packages'  },
      { id: 'family-gatherings', icon: 'people', label: 'Family gatherings' },
    );
  }

  if (/\b(family|kids|teenagers|children)\b/.test(fullText)) {
    chips.push(
      { id: 'family-friendly', icon: 'star', label: 'Family-friendly' },
      { id: 'kid-activities',  icon: 'map',  label: 'Kid activities'  },
    );
  } else if (fullText.includes('adults only')) {
    chips.push(
      { id: 'adults-only',       icon: 'star', label: 'Adults only'       },
      { id: 'romantic-getaways', icon: 'map',  label: 'Romantic getaways' },
    );
  }

  if (/\b(under|cheap)\b/.test(fullText)) {
    chips.push(
      { id: 'best-value',  icon: 'tag',  label: 'Best value stays' },
      { id: 'flight-deals', icon: 'star', label: 'Flight deals'    },
    );
  } else if (fullText.includes('luxury')) {
    chips.push(
      { id: '5-star',         icon: 'star', label: '5-star resorts' },
      { id: 'private-villas', icon: 'map',  label: 'Private villas' },
    );
  }

  return chips.slice(0, 5);
}

const ContextChipIcon: React.FC<{ icon: ContextChipIconType }> = ({ icon }) => {
  switch (icon) {
    case 'calendar':    return <IconCalendar />;
    case 'destination': return (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
        <path d="M12 2C8.686 2 6 4.686 6 8c0 5.25 6 13 6 13s6-7.75 6-13c0-3.314-2.686-6-6-6z" stroke="#0C0E1C" strokeWidth="1.8"/>
        <circle cx="12" cy="8" r="2" stroke="#0C0E1C" strokeWidth="1.8"/>
      </svg>
    );
    case 'people':      return <IconPeople />;
    case 'star':        return (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
        <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" stroke="#0C0E1C" strokeWidth="1.8" strokeLinejoin="round"/>
      </svg>
    );
    case 'map':         return (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
        <circle cx="12" cy="12" r="9" stroke="#0C0E1C" strokeWidth="1.8"/>
        <circle cx="12" cy="12" r="2" stroke="#0C0E1C" strokeWidth="1.8"/>
        <path d="M12 3v2M12 19v2M3 12h2M19 12h2" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round"/>
      </svg>
    );
    case 'tag':         return (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
        <path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z" stroke="#0C0E1C" strokeWidth="1.8" strokeLinejoin="round"/>
        <circle cx="7" cy="7" r="1.5" fill="#0C0E1C"/>
      </svg>
    );
    default:            return null;
  }
};

const _springPrimary = { type: 'spring' as const, duration: 0.333, ease: [0.48, 0.1, 0.24, 1] }; void _springPrimary;

// ─── Popover checkmark icon ───────────────────────────────────────────────────
const IconCheck = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" style={{ flexShrink: 0 }}>
    <path d="M5 12l5 5L19 7" stroke="#0C0E1C" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
);

// ─── Popover content per entity type ─────────────────────────────────────────
interface PopoverOption { label: string; prefixEmoji?: string; selected?: boolean }
interface PopoverData {
  title: string;
  subtitleParts: { text: string; bold?: boolean }[];
  options: PopoverOption[];
}

const POPOVER_CONTENT: Record<EntityType, PopoverData> = {
  date: {
    title: "When is your spring break?",
    subtitleParts: [
      { text: "Houston's typical window is " },
      { text: "Sat, Mar 14 – Sun, Mar 22.", bold: true },
    ],
    options: [
      { label: "Week of March 14th is correct", selected: true },
      { label: "I'm flexible" },
      { label: "Pick dates", prefixEmoji: "📅" },
    ],
  },
  place: {
    title: "Where are you heading?",
    subtitleParts: [
      { text: "Flights and hotels available for " },
      { text: "Mexico City & Cancun.", bold: true },
    ],
    options: [
      { label: "Mexico — confirm destination", selected: true },
      { label: "I'm flexible on location" },
      { label: "Search nearby", prefixEmoji: "📍" },
    ],
  },
  people: {
    title: "Who's coming along?",
    subtitleParts: [
      { text: "Pricing shown for " },
      { text: "1 adult and 2 teenagers.", bold: true },
    ],
    options: [
      { label: "That's correct", selected: true },
      { label: "Edit travelers" },
      { label: "Add more people", prefixEmoji: "👥" },
    ],
  },
  budget: {
    title: "What's your budget?",
    subtitleParts: [
      { text: "Showing trips " },
      { text: "under $5,000 total.", bold: true },
    ],
    options: [
      { label: "That's my budget", selected: true },
      { label: "I'm flexible" },
      { label: "Change budget", prefixEmoji: "💰" },
    ],
  },
};

// ─── ChipPopover component ────────────────────────────────────────────────────
const ChipPopover: React.FC<{
  entityType: EntityType;
  onClose: () => void;
  position: { top: number; left: number };
}> = ({ entityType, onClose, position }) => {
  const content = POPOVER_CONTENT[entityType];
  return (
    <motion.div
      data-popover="true"
      initial={{ opacity: 0, y: -8, scale: 0.97 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      exit={{ opacity: 0, y: -8, scale: 0.97 }}
      transition={{ type: 'spring', stiffness: 400, damping: 30 }}
      style={{
        position: 'fixed',
        top: position.top,
        left: position.left,
        background: 'white',
        borderRadius: 24,
        boxShadow: '0px 6px 36px rgba(12,14,28,0.12)',
        padding: 24,
        minWidth: 260,
        width: 380,
        zIndex: 100,
        pointerEvents: 'auto',
        display: 'flex',
        flexDirection: 'column',
        gap: 12,
        boxSizing: 'border-box',
      }}
    >
      {/* Header block */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        <p style={{
          fontFamily: "'Centra No2', -apple-system, sans-serif",
          fontSize: 20,
          fontWeight: 500,
          color: '#0C0E1C',
          letterSpacing: '-0.2px',
          lineHeight: 1.4,
          margin: 0,
        }}>
          {content.title}
        </p>
        <p style={{
          fontFamily: "'Centra No2', -apple-system, sans-serif",
          fontSize: 16,
          fontWeight: 400,
          color: '#0C0E1C',
          margin: 0,
          lineHeight: 1.4,
        }}>
          {content.subtitleParts.map((part, i) =>
            part.bold
              ? <strong key={i} style={{ fontWeight: 600 }}>{part.text}</strong>
              : <span key={i}>{part.text}</span>
          )}
        </p>
      </div>

      {/* Options list */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8, width: '100%' }}>
        {content.options.map((option, i) => (
          <button
            key={i}
            onClick={() => {
              console.log(`[ChipPopover:${entityType}] Selected: ${option.label}`);
              onClose();
            }}
            style={{
              background: '#F5F3F3',
              borderRadius: 16,
              padding: '16px 24px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              border: 'none',
              cursor: 'pointer',
              width: '100%',
              textAlign: 'left',
              boxSizing: 'border-box',
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              {option.prefixEmoji && (
                <span style={{ fontSize: 16, lineHeight: 1 }}>{option.prefixEmoji}</span>
              )}
              <span style={{
                fontFamily: "'Centra No2', -apple-system, sans-serif",
                fontSize: 14,
                fontWeight: 400,
                color: '#0C0E1C',
                whiteSpace: 'nowrap',
              }}>
                {option.label}
              </span>
            </div>
            {option.selected && <IconCheck />}
          </button>
        ))}
      </div>
    </motion.div>
  );
};

// ─── Blinking cursor ──────────────────────────────────────────────────────────
const blinkStyle = document.createElement('style');
blinkStyle.textContent = `
  @keyframes nlp-blink { 0%, 100% { opacity: 1; } 50% { opacity: 0; } }
  .nlp-cursor { animation: nlp-blink 1s step-end infinite; }
`;
if (!document.head.querySelector('[data-nlp-blink]')) {
  blinkStyle.setAttribute('data-nlp-blink', '');
  document.head.appendChild(blinkStyle);
}

const BlinkingCursor: React.FC = () => (
  <span className="nlp-cursor" style={{ userSelect: 'none', marginLeft: 1 }}>|</span>
);

// ─── Airport data for autocomplete ──────────────────────────────────────────
const AIRPORTS = [
  { code: 'JFK', city: 'New York',      country: 'United States', name: 'John F. Kennedy Intl' },
  { code: 'LAX', city: 'Los Angeles',   country: 'United States', name: 'Los Angeles Intl' },
  { code: 'ORD', city: 'Chicago',       country: 'United States', name: "O'Hare Intl" },
  { code: 'MIA', city: 'Miami',         country: 'United States', name: 'Miami Intl' },
  { code: 'SFO', city: 'San Francisco', country: 'United States', name: 'San Francisco Intl' },
  { code: 'LHR', city: 'London',        country: 'United Kingdom', name: 'Heathrow' },
  { code: 'CDG', city: 'Paris',         country: 'France',        name: 'Charles de Gaulle' },
  { code: 'NRT', city: 'Tokyo',         country: 'Japan',         name: 'Narita Intl' },
  { code: 'DXB', city: 'Dubai',         country: 'UAE',           name: 'Dubai Intl' },
  { code: 'CUN', city: 'Cancún',        country: 'Mexico',        name: 'Cancún Intl' },
  { code: 'BCN', city: 'Barcelona',     country: 'Spain',         name: 'El Prat' },
  { code: 'AMS', city: 'Amsterdam',     country: 'Netherlands',   name: 'Schiphol' },
  { code: 'SYD', city: 'Sydney',        country: 'Australia',     name: 'Kingsford Smith' },
  { code: 'HNL', city: 'Honolulu',      country: 'United States', name: 'Daniel K. Inouye Intl' },
  { code: 'MCO', city: 'Orlando',       country: 'United States', name: 'Orlando Intl' },
  { code: 'IAH', city: 'Houston',       country: 'United States', name: 'George Bush Intercontinental' },
  { code: 'ATL', city: 'Atlanta',       country: 'United States', name: 'Hartsfield-Jackson' },
  { code: 'SEA', city: 'Seattle',       country: 'United States', name: 'Seattle-Tacoma Intl' },
  { code: 'BOS', city: 'Boston',        country: 'United States', name: 'Logan Intl' },
  { code: 'LAS', city: 'Las Vegas',     country: 'United States', name: 'Harry Reid Intl' },
];

// ─── Ghost text examples ─────────────────────────────────────────────────────
const GHOST_EXAMPLES = [
  'Family trip in Mexico walkable to beach',
  'Weekend in Paris under $2000',
  '5 nights in Tokyo in March for 2',
  'All-inclusive Cancun resort, spring break',
  'Road trip through Italy for 3 weeks',
  'Luxury safari in Kenya, adults only',
  'Budget flights to Bali from New York',
  'Ski trip in Colorado for the holidays',
];

// ─── Component ───────────────────────────────────────────────────────────────
const EmptySearchView: React.FC = () => {
  const { openComposer, submitQuery } = useAppStore();
  const [activeTab, setActiveTab] = useState(1);
  const [selectedLob, setSelectedLob] = useState<string>('Flights');
  const [flightTrip, setFlightTrip] = useState<'Roundtrip' | 'One way' | 'Multi-city'>('Roundtrip');
  const [flightClass, setFlightClass] = useState<'Economy' | 'Business' | 'First'>('Economy');
  const [openFlightDropdown, setOpenFlightDropdown] = useState<'trip' | 'class' | null>(null);
  const [activeFlightField, setActiveFlightField] = useState<string>('origin');
  const [leavingFrom, setLeavingFrom] = useState('');
  const [leavingFocused, setLeavingFocused] = useState(false);
  const leavingInputRef = useRef<HTMLInputElement>(null);
  const [leavingSheetPos, setLeavingSheetPos] = useState<{ top: number; left: number; width: number } | null>(null);
  const [goingTo, setGoingTo] = useState(''); void goingTo;
  const [flightChipPopover, setFlightChipPopover] = useState<{
    chipId: string;
    pos: { top: number; left: number; width: number };
  } | null>(null);
  const [originSearch, setOriginSearch] = useState('');
  const [destinationSearch, setDestinationSearch] = useState('');
  const [travelersAdults, setTravelersAdults] = useState(1);
  const [travelersChildren, setTravelersChildren] = useState(0);
  const [flightDates, setFlightDates] = useState<{ depart: string; return: string }>({ depart: '', return: '' });
  const flightChipBtnRefs = useRef<Record<string, HTMLButtonElement | null>>({});
  const [segments, setSegments] = useState<Segment[]>([]);
  const [liveText, setLiveText] = useState('');
  const [isFocused, setIsFocused] = useState(false);
  const [ghostIndex, setGhostIndex] = useState(0);
  const inputRef = React.useRef<HTMLInputElement>(null);
  const cardRef = React.useRef<HTMLDivElement>(null);
  const [selectedChipId, setSelectedChipId] = useState<string | null>(null);
  const [popoverPosition, setPopoverPosition] = useState<{ top: number; left: number } | null>(null);
  // Rotate ghost text every 3 s when idle (not focused, no input)
  useEffect(() => {
    if (isFocused || liveText || segments.length > 0) return;
    const id = setInterval(() => {
      setGhostIndex(i => (i + 1) % GHOST_EXAMPLES.length);
    }, 3000);
    return () => clearInterval(id);
  }, [isFocused, liveText, segments.length]);

  // Close popover on outside mousedown
  useEffect(() => {
    if (!selectedChipId) return;
    const handleMouseDown = (e: MouseEvent) => {
      const target = e.target as Element;
      if (target.closest?.('[data-popover]')) return;
      if (target.closest?.('[data-chip-id]')) return;
      setSelectedChipId(null);
      setPopoverPosition(null);
    };
    document.addEventListener('mousedown', handleMouseDown);
    return () => document.removeEventListener('mousedown', handleMouseDown);
  }, [selectedChipId]);

  // Collapse card on click outside; also close flight dropdowns and flight chip popovers
  useEffect(() => {
    if (!isFocused && openFlightDropdown === null && !flightChipPopover) return;
    const handleMouseDown = (e: MouseEvent) => {
      const target = e.target as Element;
      if (target.closest?.('[data-flight-popover]')) return;
      if (cardRef.current && !cardRef.current.contains(e.target as Node)) {
        setIsFocused(false);
        setSelectedChipId(null);
        setPopoverPosition(null);
        setOpenFlightDropdown(null);
        setFlightChipPopover(null);
        inputRef.current?.blur();
      } else {
        setOpenFlightDropdown(null);
        setFlightChipPopover(null);
      }
    };
    document.addEventListener('mousedown', handleMouseDown);
    return () => document.removeEventListener('mousedown', handleMouseDown);
  }, [isFocused, openFlightDropdown, flightChipPopover]);

  const displayTokens = useMemo((): DisplayToken[] => {
    const committed: DisplayToken[] = segments.map(s => ({ ...s }));
    const tentative: DisplayToken[] = parseTokens(liveText).map((t, i) =>
      t.type === 'chip'
        ? { id: `tentative-${t.entityType}-${t.value}`, type: 'chip', value: t.value, entityType: t.entityType }
        : { id: `live-${i}`, type: 'text', value: t.value }
    );
    return [...committed, ...tentative];
  }, [segments, liveText]);

  const leavingMatches = useMemo(() => {
    const q = leavingFrom.trim().toLowerCase();
    if (!q) return AIRPORTS.slice(0, 6);
    return AIRPORTS.filter(a =>
      a.city.toLowerCase().includes(q) ||
      a.code.toLowerCase().includes(q) ||
      a.name.toLowerCase().includes(q) ||
      a.country.toLowerCase().includes(q)
    ).slice(0, 6);
  }, [leavingFrom]);

  const originMatches = useMemo(() => {
    const q = originSearch.trim().toLowerCase();
    if (!q) return AIRPORTS.slice(0, 6);
    return AIRPORTS.filter(a =>
      a.city.toLowerCase().includes(q) || a.code.toLowerCase().includes(q) ||
      a.name.toLowerCase().includes(q)
    ).slice(0, 6);
  }, [originSearch]);

  const destinationMatches = useMemo(() => {
    const q = destinationSearch.trim().toLowerCase();
    if (!q) return AIRPORTS.slice(0, 6);
    return AIRPORTS.filter(a =>
      a.city.toLowerCase().includes(q) || a.code.toLowerCase().includes(q) ||
      a.name.toLowerCase().includes(q)
    ).slice(0, 6);
  }, [destinationSearch]);

  const hasText = liveText.trim().length > 0 || segments.length > 0;
  const hasChips = displayTokens.some(t => t.type === 'chip'); void hasChips;

  const handleChange = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const newText = e.target.value;
    const liveParsed = parseTokens(newText);

    const committableChips = liveParsed.filter(
      (t): t is Extract<Token, { type: 'chip' }> =>
        t.type === 'chip' && t.end < newText.length
    );

    if (committableChips.length > 0) {
      const lastChip = committableChips[committableChips.length - 1];
      const lastChipIdx = liveParsed.indexOf(lastChip);

      const newSegs: Segment[] = [...segments];
      for (let i = 0; i <= lastChipIdx; i++) {
        const token = liveParsed[i];
        if (token.type === 'chip') {
          newSegs.push({
            id: `${token.entityType}-${token.value}-${Date.now()}-${Math.random()}`,
            type: 'chip',
            value: token.value,
            entityType: token.entityType,
          });
        } else if (token.value.trim()) {
          newSegs.push({
            id: `text-${Date.now()}-${Math.random()}`,
            type: 'text',
            value: token.value,
          });
        }
      }

      const remaining = newText.slice(lastChip.end);
      setSegments(newSegs);
      setLiveText(remaining);
    } else {
      setLiveText(newText);
    }
  }, [segments]);

  const handleSubmit = useCallback(() => {
    const committed = segments.map(s => s.value).join(' ');
    const full = (committed + ' ' + liveText).trim();
    if (full) submitQuery(full);
    else openComposer();
  }, [segments, liveText, openComposer, submitQuery]);

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Enter') handleSubmit();
    if (e.key === 'Escape') {
      if (selectedChipId) {
        setSelectedChipId(null);
        setPopoverPosition(null);
      } else {
        setSegments([]);
        setLiveText('');
        setIsFocused(false);
        inputRef.current?.blur();
      }
    }
  }, [handleSubmit, selectedChipId]);

  const handleInputBlur = useCallback((e: React.FocusEvent) => {
    const relatedTarget = e.relatedTarget as Node | null;
    // Stay expanded if focus moves to another element inside the card
    if (cardRef.current && relatedTarget && cardRef.current.contains(relatedTarget)) return;
    // Otherwise collapse — the mousedown-outside handler also covers this
    setIsFocused(false);
  }, []);

  return (
    <div style={{
      position: 'absolute',
      inset: 0,
      background: T.pageBg,
      overflowY: 'auto',
      overflowX: 'hidden',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'flex-start',
    }}>
      {/* ── Centered row: sidebar + content travel together ── */}
      <div style={{
        display: 'flex',
        width: '100%',
        maxWidth: 1340,   // 92px sidebar + 1248px content
      }}>
        {/* ── Left sidebar (92px) ── */}
        <LeftSidebar />

        {/* ── Main content ── */}
        <div style={{
          flex: 1,
          minWidth: 0,
          padding: '24px 24px 80px 24px',
          display: 'flex',
          flexDirection: 'column',
          gap: 20,
        }}>

        {/* Search card */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{
            opacity: 1,
            y: 0,
          }}
          transition={{
            opacity: { duration: 0.5, ease },
            y: { duration: 0.5, ease },
          }}
          style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 20,
            background: T.cardBg,
            padding: '56px 24px',
            borderRadius: 24,
            boxShadow: T.cardShadow,
          }}
        >
          {/* Headline — Reckless XPD serif display */}
          <p style={{
            fontFamily: "'Playfair Display', Georgia, serif",
            fontSize: 36,
            fontWeight: 400,
            lineHeight: '40px',
            letterSpacing: '-0.48px',
            margin: 0,
            textAlign: 'center',
          }}>
            <span style={{ color: T.textMuted }}>Hi Rosa, </span>
            <span style={{ color: T.textPrimary }}>Ready to plan your spring break getaway?</span>
          </p>

          {/* LOB tabs — always visible */}
          <div style={{ display: 'flex', alignItems: 'center', gap: 0, overflowX: 'auto', scrollbarWidth: 'none', WebkitOverflowScrolling: 'touch' as never }}>
            {LOB_TABS.map((tab, i) => {
              const isActive = activeTab === i;
              return (
                <motion.button
                  key={tab.label}
                  onClick={() => {
                    if (isActive) {
                      setActiveTab(-1);
                      setSelectedLob('');
                    } else {
                      setActiveTab(i);
                      setSelectedLob(tab.label);
                      setIsFocused(false);
                    }
                  }}
                  style={{
                    position: 'relative',
                    display: 'flex',
                    alignItems: 'center',
                    gap: 7,
                    height: 40,
                    padding: '0 14px 0 10px',
                    borderRadius: 1000,
                    border: 'none',
                    background: 'transparent',
                    cursor: 'pointer',
                    fontFamily: "'Centra No2', -apple-system, sans-serif",
                    fontSize: 15,
                    fontWeight: isActive ? 600 : 500,
                    color: isActive ? '#0C0E1C' : '#595959',
                    letterSpacing: '-0.2px',
                    whiteSpace: 'nowrap',
                    zIndex: 0,
                  }}
                  whileTap={{ scale: 0.94 }}
                  transition={{ duration: 0.12 }}
                >
                  {/* Glass pill background — slides between tabs */}
                  {isActive && (
                    <motion.span
                      layoutId="lob-pill"
                      style={{
                        position: 'absolute',
                        inset: 0,
                        borderRadius: 1000,
                        background: 'rgba(255,255,255,0.82)',
                        backdropFilter: 'blur(14px)',
                        WebkitBackdropFilter: 'blur(14px)',
                        border: '1px solid rgba(255,255,255,0.55)',
                        boxShadow: '0 2px 10px rgba(12,14,28,0.09), inset 0 1px 0 rgba(255,255,255,0.75)',
                        zIndex: -1,
                      }}
                      initial={{ opacity: 0, scale: 0.78 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 0.84 }}
                      transition={{ type: 'spring', stiffness: 420, damping: 30 }}
                    />
                  )}
                  <img src={tab.img} alt={tab.label} style={{ width: 22, height: 22, objectFit: 'cover', position: 'relative', zIndex: 1 }} />
                  <span style={{ position: 'relative', zIndex: 1, fontWeight: isActive ? 600 : 500 }}>{tab.label}</span>
                </motion.button>
              );
            })}
          </div>

          {/* NLP input card wrapper — provides positioning context for the gradient ring */}
          <motion.div
            animate={{ maxWidth: (isFocused || (selectedLob !== '' && selectedLob !== 'Stays')) ? 960 : 680 }}
            transition={isFocused
              ? { duration: 0.18, ease: [0.22, 1, 0.36, 1] }
              : { type: 'spring', stiffness: 480, damping: 36 }}
            style={{ position: 'relative', width: '100%' }}
          >

          {/* Gemini-style rotating gradient border — sibling to card so it's never clipped */}
          {isFocused && <div key="gemini-ring" className="gemini-ring" />}

          {/* NLP input card — morphs between idle and typing states */}
          <motion.div
            ref={cardRef}
            onClick={() => { if (selectedLob === '') { setIsFocused(true); setTimeout(() => inputRef.current?.focus(), 0); } }}
            whileTap={(isFocused || selectedLob !== '') ? {} : { scale: 0.985 }}
            animate={{
              borderRadius: (isFocused || selectedLob !== '') ? 24 : 36,
              boxShadow: (isFocused || selectedLob !== '') ? T.inputShadow : '0px 2px 6px rgba(12,14,28,0.08)',
            }}
            transition={{ type: 'spring', stiffness: 480, damping: 36 }}
            style={{
              position: 'relative',
              width: '100%',
              background: '#ffffff',
              border: `1px solid ${T.inputBorder}`,
              overflow: (isFocused || selectedLob !== '') ? 'visible' : 'hidden',
              cursor: (isFocused || selectedLob !== '') ? 'default' : 'pointer',
              display: 'flex',
              flexDirection: 'column',
              gap: 0,
            }}
          >
            {/* ─ Inner content — animated per LOB ─ */}
            <AnimatePresence mode="wait" initial={false}>
              <motion.div
                key={selectedLob === '' ? '__nlp__' : selectedLob}
                initial={{ opacity: 0, y: 6 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -6 }}
                transition={{ duration: 0.15, ease }}
                style={{ width: '100%', display: 'flex', flexDirection: 'column' }}
              >
                {selectedLob === '' ? (
                  <>
                    {/* ── Top zone ── */}
                    <motion.div
                      animate={{
                        paddingTop: isFocused ? 24 : 8,
                        paddingLeft: isFocused ? 24 : 16,
                        paddingRight: isFocused ? 24 : 8,
                        paddingBottom: isFocused ? 16 : 8,
                      }}
                      transition={isFocused
                        ? { duration: 0.18, ease: [0.22, 1, 0.36, 1] }
                        : { type: 'spring', stiffness: 480, damping: 36 }}
                      style={{
                        display: 'flex',
                        alignItems: isFocused ? 'flex-start' : 'center',
                        position: 'relative',
                        width: '100%',
                        boxSizing: 'border-box',
                        gap: 8,
                      }}
                    >
                      {/* AI scan-line shimmer — visible while user is actively typing */}
                      <AnimatePresence>
                        {isFocused && (liveText.length > 0 || segments.length > 0) && (
                          <motion.div
                            key="ai-scan"
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            exit={{ opacity: 0 }}
                            transition={{ duration: 0.3 }}
                            style={{
                              position: 'absolute',
                              inset: 0,
                              pointerEvents: 'none',
                              zIndex: 0,
                              overflow: 'hidden',
                            }}
                          >
                            <motion.div
                              animate={{ left: ['-40%', '120%'] }}
                              transition={{ duration: 2.2, ease: 'linear', repeat: Infinity, repeatDelay: 1.4 }}
                              style={{
                                position: 'absolute',
                                top: 0,
                                bottom: 0,
                                width: '35%',
                                background: 'linear-gradient(90deg, transparent, rgba(99,102,241,0.055), rgba(99,102,241,0.03), transparent)',
                                filter: 'blur(8px)',
                              }}
                            />
                          </motion.div>
                        )}
                      </AnimatePresence>

                      {/* Magnifying glass icon — idle state only */}
                      <AnimatePresence>
                        {!isFocused && (
                          <motion.div
                            key="search-icon"
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            exit={{ opacity: 0 }}
                            transition={{ duration: 0.1 }}
                            style={{ flexShrink: 0, display: 'flex', alignItems: 'center' }}
                          >
                            <IconSearch />
                          </motion.div>
                        )}
                      </AnimatePresence>

                      {/* Input or ghost text — takes remaining space */}
                      <div style={{ flex: 1, minWidth: 0, overflow: 'hidden' }}>
                        <AnimatePresence mode="sync" initial={false}>
                          {isFocused ? (
                            <motion.div
                              key="input-zone"
                              initial={{ opacity: 1 }}
                              animate={{ opacity: 1 }}
                              exit={{ opacity: 0 }}
                              transition={{ duration: 0.08, ease }}
                              style={{ position: 'relative', width: '100%' }}
                            >
                              {/* Hidden real input — keeps focus/keyboard/caret state */}
                              <input
                                ref={inputRef}
                                value={liveText}
                                onChange={handleChange}
                                onKeyDown={handleKeyDown}
                                onFocus={() => setIsFocused(true)}
                                onBlur={handleInputBlur}
                                autoFocus
                                placeholder=""
                                style={{
                                  position: 'absolute',
                                  inset: 0,
                                  width: '100%',
                                  height: '100%',
                                  border: 'none',
                                  outline: 'none',
                                  boxShadow: 'none',
                                  WebkitAppearance: 'none',
                                  appearance: 'none',
                                  background: 'transparent',
                                  WebkitBoxShadow: '0 0 0 1000px transparent inset',
                                  opacity: 0,
                                  cursor: 'text',
                                  caretColor: 'transparent',
                                  zIndex: 0,
                                }}
                              />
                              {/* Visual overlay — token chips + text */}
                              <div
                                style={{
                                  pointerEvents: 'none',
                                  position: 'relative',
                                  zIndex: 1,
                                  width: '100%',
                                  display: 'flex',
                                  flexWrap: 'wrap',
                                  alignItems: 'center',
                                  gap: 6,
                                  overflow: 'visible',
                                  padding: '3px 0',
                                  minHeight: 20,
                                  fontFamily: "'Centra No2', -apple-system, sans-serif",
                                  fontSize: 16,
                                  fontWeight: 400,
                                  lineHeight: '20px',
                                }}
                              >
                                <AnimatePresence mode="popLayout">
                                  {displayTokens.length === 0 ? (
                                    <motion.span
                                      key="cursor-only"
                                      style={{ color: '#191E3B' }}
                                    >
                                      <BlinkingCursor />
                                    </motion.span>
                                  ) : (
                                    displayTokens.map(token =>
                                      token.type === 'chip' ? (
                                        <motion.span
                                          key={`chip-${token.id}`}
                                          data-chip-id={token.id}
                                          initial={{ opacity: 0, scale: 0.8, y: 4, filter: 'blur(3px)' }}
                                          animate={{
                                            opacity: 1,
                                            scale: 1,
                                            y: 0,
                                            filter: 'blur(0px)',
                                            background: selectedChipId === token.id ? '#E8E5E1' : '#F5F3F3',
                                            boxShadow: selectedChipId === token.id
                                              ? '0 0 0 2px rgba(12,14,28,0.12)'
                                              : '0 0 0 0px rgba(12,14,28,0)',
                                          }}
                                          exit={{ opacity: 0, scale: 0.88, filter: 'blur(2px)' }}
                                          transition={{ type: 'spring', stiffness: 420, damping: 28, mass: 0.8 }}
                                          onClick={e => {
                                            e.stopPropagation();
                                            if (selectedChipId === token.id) {
                                              setSelectedChipId(null);
                                              setPopoverPosition(null);
                                            } else {
                                              const chipRect = (e.currentTarget as HTMLElement).getBoundingClientRect();
                                              setPopoverPosition({
                                                top: chipRect.bottom + 12,
                                                left: chipRect.left,
                                              });
                                              setSelectedChipId(token.id);
                                            }
                                          }}
                                          whileHover={{ scale: 1.04 }}
                                          whileTap={{ scale: 0.96 }}
                                          style={{
                                            display: 'inline-flex',
                                            alignItems: 'center',
                                            gap: 4,
                                            borderRadius: 100,
                                            padding: '8px 12px',
                                            color: '#191E3B',
                                            fontSize: 16,
                                            fontWeight: 500,
                                            whiteSpace: 'nowrap',
                                            lineHeight: '20px',
                                            pointerEvents: 'auto',
                                            cursor: 'pointer',
                                            userSelect: 'none',
                                            position: 'relative',
                                            overflow: 'hidden',
                                          }}
                                        >
                                          {/* One-shot shine sweep on chip formation */}
                                          <span className="chip-shine" aria-hidden style={{
                                            position: 'absolute', inset: 0, borderRadius: 100, pointerEvents: 'none',
                                          }} />
                                          {ENTITY_ICON[token.entityType]}
                                          {token.value}
                                        </motion.span>
                                      ) : (
                                        <motion.span
                                          key={`text-${token.id}`}
                                          initial={{ opacity: 0 }}
                                          animate={{ opacity: 1 }}
                                          exit={{ opacity: 0 }}
                                          transition={{ duration: 0.12 }}
                                          style={{ color: '#191E3B', whiteSpace: 'pre-wrap' }}
                                        >
                                          {token.value}
                                        </motion.span>
                                      )
                                    )
                                  )}
                                  {displayTokens.length > 0 && (
                                    <motion.span key="cursor" style={{ color: '#191E3B' }}>
                                      <BlinkingCursor />
                                    </motion.span>
                                  )}
                                </AnimatePresence>
                              </div>
                            </motion.div>
                          ) : (
                            <AnimatePresence mode="wait" initial={false}>
                              <motion.p
                                key={ghostIndex}
                                initial={{ opacity: 0, y: 10 }}
                                animate={{ opacity: 1, y: 0 }}
                                exit={{ opacity: 0, y: -10 }}
                                transition={{ duration: 0.38, ease: [0.42, 0.1, 0.24, 1] }}
                                style={{
                                  fontFamily: "'Centra No2', -apple-system, sans-serif",
                                  fontSize: 16,
                                  fontWeight: 400,
                                  color: T.textVariant,
                                  margin: 0,
                                  lineHeight: '20px',
                                  userSelect: 'none',
                                  pointerEvents: 'none',
                                }}
                              >
                                {GHOST_EXAMPLES[ghostIndex]}
                              </motion.p>
                            </AnimatePresence>
                          )}
                        </AnimatePresence>
                      </div>

                      {/* Voice + submit — idle state only, inline in the pill */}
                      <AnimatePresence>
                        {!isFocused && (
                          <motion.div
                            key="idle-actions"
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            exit={{ opacity: 0 }}
                            transition={{ duration: 0.1 }}
                            style={{ display: 'flex', alignItems: 'center', gap: 8, flexShrink: 0 }}
                          >
                            <button
                              onClick={e => { e.stopPropagation(); openComposer(); }}
                              style={{
                                width: 48,
                                height: 48,
                                borderRadius: 40000,
                                background: T.voiceBg,
                                border: 'none',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                cursor: 'pointer',
                                flexShrink: 0,
                              }}
                            >
                              <img
                                src={ASSET_VOICE}
                                alt="voice"
                                style={{ width: 15, height: 16.5, objectFit: 'contain' }}
                              />
                            </button>
                            <motion.button
                              onClick={e => { e.stopPropagation(); handleSubmit(); }}
                              whileTap={{ scale: 0.93 }}
                              style={{
                                width: 48,
                                height: 48,
                                borderRadius: 100,
                                background: 'rgba(253,219,50,0.5)',
                                border: 'none',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                cursor: 'pointer',
                                flexShrink: 0,
                              }}
                            >
                              <IconArrow color='#0C0E1C' />
                            </motion.button>
                          </motion.div>
                        )}
                      </AnimatePresence>
                    </motion.div>

                    {/* ── Divider ── */}
                    {hasText && isFocused && (
                      <div
                        style={{
                          marginLeft: 24,
                          marginRight: 24,
                          height: 1,
                          background: 'rgba(12,14,28,0.07)',
                          flexShrink: 0,
                        }}
                      />
                    )}

                    {/* ── Chips + actions row ── */}
                    {isFocused && (
                      <div
                        style={{
                          paddingTop: 16,
                          paddingLeft: 24,
                          paddingRight: 24,
                          paddingBottom: 16,
                          display: 'flex',
                          alignItems: 'center',
                          gap: 16,
                        }}
                      >
                        <div style={{ display: 'flex', flex: 1, gap: 8, alignItems: 'center', overflowX: 'auto', scrollbarWidth: 'none', WebkitOverflowScrolling: 'touch' as never, minWidth: 0 }}>
                          <motion.button
                            onClick={e => { e.stopPropagation(); openComposer(); }}
                            initial={{ opacity: 1, scale: 0.82 }}
                            animate={{ opacity: 1, scale: 1 }}
                            transition={{ type: 'spring', stiffness: 600, damping: 28, delay: 0 }}
                            style={{
                              width: 48,
                              height: 48,
                              borderRadius: 100,
                              background: T.chipBg,
                              border: 'none',
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              cursor: 'pointer',
                              flexShrink: 0,
                            }}
                          >
                            <IconAdd />
                          </motion.button>

                          <AnimatePresence mode="popLayout" initial={false}>
                            {deriveContextualChips(segments, liveText).map((chip, i) => (
                              <motion.button
                                key={chip.id}
                                layout
                                initial={{ opacity: 1, scale: 0.82, filter: 'blur(2px)' }}
                                animate={{ opacity: 1, scale: 1, filter: 'blur(0px)' }}
                                exit={{ opacity: 0, scale: 0.82, filter: 'blur(2px)' }}
                                transition={{ type: 'spring', stiffness: 560, damping: 26, delay: i * 0.015 }}
                                onClick={e => { e.stopPropagation(); openComposer(chip.label); }}
                                style={chipBtnStyle}
                              >
                                <ContextChipIcon icon={chip.icon} />
                                <span style={chipLabelStyle}>{chip.label}</span>
                              </motion.button>
                            ))}
                          </AnimatePresence>
                        </div>

                        <motion.button
                          onClick={e => { e.stopPropagation(); openComposer(); }}
                          initial={{ opacity: 1, scale: 0.82 }}
                          animate={{ opacity: 1, x: 0, scale: 1 }}
                          transition={{ type: 'spring', stiffness: 560, damping: 26, delay: 0 }}
                          style={{
                            width: 48,
                            height: 48,
                            borderRadius: 40000,
                            background: T.voiceBg,
                            border: 'none',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            cursor: 'pointer',
                            flexShrink: 0,
                          }}
                        >
                          <img
                            src={ASSET_VOICE}
                            alt="voice"
                            style={{ width: 15, height: 16.5, objectFit: 'contain' }}
                          />
                        </motion.button>

                        <motion.button
                          onClick={e => { e.stopPropagation(); handleSubmit(); }}
                          initial={{ opacity: 1, scale: 0.82 }}
                          animate={{
                            opacity: hasText ? 1 : 0.5,
                            x: 0,
                            scale: 1,
                            background: T.submitBg,
                            boxShadow: hasText ? T.submitShadow : 'none',
                            borderColor: T.submitBorder,
                          }}
                          transition={{ type: 'spring', stiffness: 560, damping: 26, delay: 0 }}
                          whileTap={{ scale: 0.93 }}
                          style={{
                            width: 48,
                            height: 48,
                            borderRadius: 100,
                            borderWidth: 1,
                            borderStyle: 'solid',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            cursor: hasText ? 'pointer' : 'default',
                            flexShrink: 0,
                          }}
                        >
                          <IconArrow color='#0C0E1C' />
                        </motion.button>
                      </div>
                    )}
                  </>
                ) : selectedLob === 'Flights' ? (
                  <>
                    {/* ── Flights structured form ── */}
                    <div style={{ padding: '24px 24px 0' }}>
                      {/* Top filter row */}
                      <div style={{ display: 'flex', gap: 16, marginBottom: 16 }}>
                        {/* Roundtrip dropdown */}
                        <div style={{ position: 'relative' }}>
                          <button
                            onClick={e => { e.stopPropagation(); setOpenFlightDropdown(o => o === 'trip' ? null : 'trip'); }}
                            style={{
                              display: 'flex', alignItems: 'center', gap: 6,
                              padding: '7px 14px 7px 10px', borderRadius: 20,
                              background: '#ffffff',
                              border: 'none',
                              boxShadow: '0 2px 8px rgba(12,14,28,0.08)',
                              fontSize: 14, fontWeight: 500, color: '#191E3B', cursor: 'pointer',
                              fontFamily: "'Centra No2', -apple-system, sans-serif",
                            }}
                          >
                            <IconRouteTrip />
                            {flightTrip}
                            <IconChevronDown />
                          </button>
                          <AnimatePresence>
                            {openFlightDropdown === 'trip' && (
                              <motion.div
                                initial={{ opacity: 0, y: -6, scale: 0.96 }}
                                animate={{ opacity: 1, y: 0, scale: 1 }}
                                exit={{ opacity: 0, y: -4, scale: 0.97 }}
                                transition={{ type: 'spring', stiffness: 400, damping: 28 }}
                                style={{
                                  position: 'absolute', top: 'calc(100% + 6px)', left: 0,
                                  background: '#ffffff', borderRadius: 14,
                                  boxShadow: '0 8px 24px rgba(12,14,28,0.14), 0 2px 6px rgba(12,14,28,0.06)',
                                  border: '1px solid rgba(12,14,28,0.07)',
                                  overflow: 'hidden', zIndex: 100, minWidth: 140,
                                }}
                              >
                                {(['Roundtrip', 'One way', 'Multi-city'] as const).map(opt => (
                                  <button
                                    key={opt}
                                    onClick={e => { e.stopPropagation(); setFlightTrip(opt); setOpenFlightDropdown(null); }}
                                    style={{
                                      display: 'block', width: '100%', textAlign: 'left',
                                      padding: '10px 16px', border: 'none', cursor: 'pointer',
                                      background: flightTrip === opt ? 'rgba(12,14,28,0.05)' : 'transparent',
                                      fontFamily: "'Centra No2', -apple-system, sans-serif",
                                      fontSize: 14, fontWeight: flightTrip === opt ? 600 : 400,
                                      color: '#191E3B',
                                    }}
                                  >{opt}</button>
                                ))}
                              </motion.div>
                            )}
                          </AnimatePresence>
                        </div>
                        {/* Economy dropdown */}
                        <div style={{ position: 'relative' }}>
                          <button
                            onClick={e => { e.stopPropagation(); setOpenFlightDropdown(o => o === 'class' ? null : 'class'); }}
                            style={{
                              display: 'flex', alignItems: 'center', gap: 6,
                              padding: '7px 14px 7px 10px', borderRadius: 20,
                              background: '#ffffff',
                              border: 'none',
                              boxShadow: '0 2px 8px rgba(12,14,28,0.08)',
                              fontSize: 14, fontWeight: 500, color: '#191E3B', cursor: 'pointer',
                              fontFamily: "'Centra No2', -apple-system, sans-serif",
                            }}
                          >
                            <IconSeat />
                            {flightClass}
                            <IconChevronDown />
                          </button>
                          <AnimatePresence>
                            {openFlightDropdown === 'class' && (
                              <motion.div
                                initial={{ opacity: 0, y: -6, scale: 0.96 }}
                                animate={{ opacity: 1, y: 0, scale: 1 }}
                                exit={{ opacity: 0, y: -4, scale: 0.97 }}
                                transition={{ type: 'spring', stiffness: 400, damping: 28 }}
                                style={{
                                  position: 'absolute', top: 'calc(100% + 6px)', left: 0,
                                  background: '#ffffff', borderRadius: 14,
                                  boxShadow: '0 8px 24px rgba(12,14,28,0.14), 0 2px 6px rgba(12,14,28,0.06)',
                                  border: '1px solid rgba(12,14,28,0.07)',
                                  overflow: 'hidden', zIndex: 100, minWidth: 130,
                                }}
                              >
                                {(['Economy', 'Business', 'First'] as const).map(opt => (
                                  <button
                                    key={opt}
                                    onClick={e => { e.stopPropagation(); setFlightClass(opt); setOpenFlightDropdown(null); }}
                                    style={{
                                      display: 'block', width: '100%', textAlign: 'left',
                                      padding: '10px 16px', border: 'none', cursor: 'pointer',
                                      background: flightClass === opt ? 'rgba(12,14,28,0.05)' : 'transparent',
                                      fontFamily: "'Centra No2', -apple-system, sans-serif",
                                      fontSize: 14, fontWeight: flightClass === opt ? 600 : 400,
                                      color: '#191E3B',
                                    }}
                                  >{opt}</button>
                                ))}
                              </motion.div>
                            )}
                          </AnimatePresence>
                        </div>
                      </div>
                      {/* Leaving from input */}
                      <input
                        ref={leavingInputRef}
                        placeholder="Leaving from"
                        value={leavingFrom}
                        onChange={e => setLeavingFrom(e.target.value)}
                        onFocus={() => {
                          setLeavingFocused(true);
                          const rect = leavingInputRef.current?.getBoundingClientRect();
                          if (rect) setLeavingSheetPos({ top: rect.bottom + 8, left: rect.left - 24, width: rect.width + 48 });
                        }}
                        onBlur={() => {
                          setTimeout(() => setLeavingFocused(false), 150);
                        }}
                        onKeyDown={e => {
                          if (e.key === 'Escape') { setLeavingFocused(false); leavingInputRef.current?.blur(); }
                        }}
                        style={{
                          border: 'none', outline: 'none', background: 'transparent',
                          fontSize: 16, fontWeight: 400, color: '#191E3B',
                          width: '100%', padding: 0, margin: 0,
                          fontFamily: "'Centra No2', -apple-system, sans-serif",
                        }}
                      />
                    </div>

                    {/* ── Divider ── */}
                    <div style={{ marginLeft: 24, marginRight: 24, height: 1, background: 'rgba(12,14,28,0.07)', marginTop: 16, flexShrink: 0 }} />

                    {/* ── Flights action chips ── */}
                    <div style={{ paddingTop: 16, paddingLeft: 24, paddingRight: 24, paddingBottom: 16, display: 'flex', alignItems: 'center', gap: 16 }}>
                      <div style={{ display: 'flex', flex: 1, gap: 8, alignItems: 'center', overflowX: 'auto', scrollbarWidth: 'none', WebkitOverflowScrolling: 'touch' as never, minWidth: 0 }}>
                        {([
                          { id: 'origin',      label: 'Add origin',      Icon: IconPlane    },
                          { id: 'destination', label: 'Add destination',  Icon: IconPin      },
                          { id: 'dates',       label: 'Add dates',        Icon: IconCalendar },
                          { id: 'travelers',   label: 'Add travelers',    Icon: IconPeople   },
                        ]).map((chip, i) => {
                          const isActiveChip = activeFlightField === chip.id;
                          return (
                            <motion.button
                              key={chip.id}
                              ref={el => { flightChipBtnRefs.current[chip.id] = el; }}
                              initial={{ opacity: 0, scale: 0.88, filter: 'blur(2px)' }}
                              animate={{ opacity: 1, scale: 1, filter: 'blur(0px)' }}
                              transition={{ type: 'spring', stiffness: 560, damping: 26, delay: i * 0.04 }}
                              onClick={e => {
                                e.stopPropagation();
                                setActiveFlightField(chip.id);
                                const btn = flightChipBtnRefs.current[chip.id];
                                if (btn) {
                                  const rect = btn.getBoundingClientRect();
                                  const minWidth = (chip.id === 'origin' || chip.id === 'destination') ? 340 : chip.id === 'dates' ? 300 : 260;
                                  setFlightChipPopover({ chipId: chip.id, pos: { top: rect.bottom + 8, left: rect.left, width: Math.max(rect.width, minWidth) } });
                                }
                              }}
                              style={{
                                display: 'flex', alignItems: 'center', gap: 8,
                                height: 48,
                                padding: isActiveChip ? '16px' : '14px 16px',
                                borderRadius: 999,
                                background: isActiveChip
                                  ? 'linear-gradient(179.9deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.8) 95.923%), linear-gradient(90deg, rgba(247,244,243,0.25) 0%, rgba(247,244,243,0.25) 100%)'
                                  : 'rgba(103,106,125,0.08)',
                                backdropFilter: isActiveChip ? 'blur(15px)' : 'none',
                                WebkitBackdropFilter: isActiveChip ? 'blur(15px)' : 'none',
                                border: isActiveChip ? '1px solid rgba(255,255,255,0.9)' : 'none',
                                boxShadow: isActiveChip ? '0px 12px 32px 0px rgba(12,14,28,0.08)' : 'none',
                                cursor: 'pointer', flexShrink: 0,
                                fontFamily: "'Centra No2', -apple-system, sans-serif",
                              }}
                            >
                              <chip.Icon />
                              <span style={{
                                fontFamily: "'Centra No2', -apple-system, sans-serif",
                                fontSize: 14, fontWeight: 500, lineHeight: '18px',
                                color: isActiveChip ? '#0C0E1C' : 'rgba(25,30,59,0.75)',
                                whiteSpace: 'nowrap',
                              }}>{chip.label}</span>
                            </motion.button>
                          );
                        })}
                      </div>
                      <button
                        onClick={e => { e.stopPropagation(); openComposer(); }}
                        style={{
                          width: 48, height: 48, borderRadius: 40000,
                          background: T.voiceBg, border: 'none',
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                          cursor: 'pointer', flexShrink: 0,
                        }}
                      >
                        <img src={ASSET_VOICE} alt="voice" style={{ width: 15, height: 16.5, objectFit: 'contain' }} />
                      </button>
                      <motion.button
                        onClick={e => { e.stopPropagation(); handleSubmit(); }}
                        whileTap={{ scale: 0.93 }}
                        animate={{ background: T.submitBg, boxShadow: T.submitShadow, borderColor: T.submitBorder }}
                        style={{
                          width: 48, height: 48, borderRadius: 100,
                          borderWidth: 1, borderStyle: 'solid',
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                          cursor: 'pointer', flexShrink: 0,
                        }}
                      >
                        <IconArrow color='#0C0E1C' />
                      </motion.button>
                    </div>
                  </>
                ) : (
                  /* ── Other LOBs placeholder ── */
                  <div style={{ padding: '32px 24px 28px', textAlign: 'center' }}>
                    <p style={{
                      fontFamily: "'Centra No2', -apple-system, sans-serif",
                      fontSize: 16, fontWeight: 400, color: T.textMuted, margin: 0,
                    }}>
                      {selectedLob} search coming soon
                    </p>
                  </div>
                )}
              </motion.div>
            </AnimatePresence>

          {/* Chip popover — rendered in a portal so it escapes card overflow:hidden */}
          {ReactDOM.createPortal(
            <AnimatePresence>
              {selectedChipId && popoverPosition && (() => {
                const sel = displayTokens.find(t => t.id === selectedChipId && t.type === 'chip');
                return sel && sel.type === 'chip' ? (
                  <ChipPopover
                    key={selectedChipId}
                    entityType={sel.entityType}
                    onClose={() => { setSelectedChipId(null); setPopoverPosition(null); }}
                    position={popoverPosition}
                  />
                ) : null;
              })()}
            </AnimatePresence>,
            document.body
          )}

          {ReactDOM.createPortal(
            <AnimatePresence>
              {flightChipPopover && (() => {
                const { chipId, pos } = flightChipPopover;
                const sharedPopoverStyle: React.CSSProperties = {
                  position: 'fixed',
                  top: pos.top,
                  left: pos.left,
                  width: pos.width,
                  background: '#ffffff',
                  borderRadius: 20,
                  boxShadow: '0 16px 48px rgba(12,14,28,0.14), 0 4px 12px rgba(12,14,28,0.06)',
                  border: '1px solid rgba(12,14,28,0.06)',
                  zIndex: 9999,
                  overflow: 'hidden',
                };

                if (chipId === 'origin' || chipId === 'destination') {
                  const search = chipId === 'origin' ? originSearch : destinationSearch;
                  const setSearch = chipId === 'origin' ? setOriginSearch : setDestinationSearch;
                  const matches = chipId === 'origin' ? originMatches : destinationMatches;
                  return (
                    <motion.div
                      key={chipId}
                      data-flight-popover="true"
                      initial={{ opacity: 0, y: -8, scale: 0.97 }}
                      animate={{ opacity: 1, y: 0, scale: 1 }}
                      exit={{ opacity: 0, y: -6, scale: 0.98 }}
                      transition={{ type: 'spring', stiffness: 420, damping: 30 }}
                      style={sharedPopoverStyle}
                    >
                      <input
                        autoFocus
                        placeholder="Search airports..."
                        value={search}
                        onChange={e => setSearch(e.target.value)}
                        style={{
                          display: 'block', width: '100%', border: 'none',
                          borderBottom: '1px solid rgba(12,14,28,0.06)',
                          padding: '16px 20px', fontSize: 15,
                          fontFamily: "'Centra No2', -apple-system, sans-serif",
                          outline: 'none', boxSizing: 'border-box', color: '#191E3B',
                        }}
                      />
                      {matches.map((airport, i) => (
                        <button
                          key={airport.code}
                          onMouseDown={e => {
                            e.preventDefault();
                            if (chipId === 'origin') {
                              setLeavingFrom(`${airport.city} (${airport.code})`);
                            } else {
                              setGoingTo(`${airport.city} (${airport.code})`);
                            }
                            setFlightChipPopover(null);
                          }}
                          style={{
                            display: 'flex', alignItems: 'center', gap: 14,
                            width: '100%', padding: '13px 20px',
                            border: 'none', background: 'transparent',
                            cursor: 'pointer', textAlign: 'left',
                            borderBottom: i < matches.length - 1 ? '1px solid rgba(12,14,28,0.05)' : 'none',
                            fontFamily: "'Centra No2', -apple-system, sans-serif",
                            boxSizing: 'border-box',
                          }}
                          onMouseEnter={e => (e.currentTarget.style.background = 'rgba(12,14,28,0.03)')}
                          onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                        >
                          <div style={{
                            width: 44, height: 44, borderRadius: 12,
                            background: 'rgba(12,14,28,0.05)',
                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                            flexShrink: 0,
                          }}>
                            <span style={{ fontSize: 12, fontWeight: 700, color: '#191E3B', letterSpacing: '0.5px' }}>
                              {airport.code}
                            </span>
                          </div>
                          <div style={{ flex: 1, minWidth: 0 }}>
                            <div style={{ fontSize: 15, fontWeight: 500, color: '#0C0E1C', lineHeight: '20px' }}>
                              {airport.city}
                            </div>
                            <div style={{ fontSize: 13, fontWeight: 400, color: 'rgba(12,14,28,0.45)', lineHeight: '18px', marginTop: 1 }}>
                              {airport.name} · {airport.country}
                            </div>
                          </div>
                        </button>
                      ))}
                    </motion.div>
                  );
                }

                if (chipId === 'dates') {
                  return (
                    <motion.div
                      key="dates"
                      data-flight-popover="true"
                      initial={{ opacity: 0, y: -8, scale: 0.97 }}
                      animate={{ opacity: 1, y: 0, scale: 1 }}
                      exit={{ opacity: 0, y: -6, scale: 0.98 }}
                      transition={{ type: 'spring', stiffness: 420, damping: 30 }}
                      style={sharedPopoverStyle}
                    >
                      <div style={{ padding: '20px 20px', display: 'flex', gap: 12 }}>
                        <div style={{ flex: 1 }}>
                          <div style={{ fontSize: 11, fontWeight: 600, color: 'rgba(12,14,28,0.4)', letterSpacing: '0.6px', marginBottom: 6, textTransform: 'uppercase' }}>Depart</div>
                          <input
                            type="date"
                            value={flightDates.depart}
                            onChange={e => setFlightDates(d => ({ ...d, depart: e.target.value }))}
                            style={{ width: '100%', border: '1px solid rgba(12,14,28,0.12)', borderRadius: 10, padding: '8px 10px', fontSize: 14, fontFamily: "'Centra No2', -apple-system, sans-serif", outline: 'none', color: '#191E3B', boxSizing: 'border-box' }}
                          />
                        </div>
                        <div style={{ flex: 1 }}>
                          <div style={{ fontSize: 11, fontWeight: 600, color: 'rgba(12,14,28,0.4)', letterSpacing: '0.6px', marginBottom: 6, textTransform: 'uppercase' }}>Return</div>
                          <input
                            type="date"
                            value={flightDates.return}
                            onChange={e => setFlightDates(d => ({ ...d, return: e.target.value }))}
                            style={{ width: '100%', border: '1px solid rgba(12,14,28,0.12)', borderRadius: 10, padding: '8px 10px', fontSize: 14, fontFamily: "'Centra No2', -apple-system, sans-serif", outline: 'none', color: '#191E3B', boxSizing: 'border-box' }}
                          />
                        </div>
                      </div>
                    </motion.div>
                  );
                }

                if (chipId === 'travelers') {
                  return (
                    <motion.div
                      key="travelers"
                      data-flight-popover="true"
                      initial={{ opacity: 0, y: -8, scale: 0.97 }}
                      animate={{ opacity: 1, y: 0, scale: 1 }}
                      exit={{ opacity: 0, y: -6, scale: 0.98 }}
                      transition={{ type: 'spring', stiffness: 420, damping: 30 }}
                      style={sharedPopoverStyle}
                    >
                      <div style={{ padding: '8px 0' }}>
                        {([
                          { label: 'Adults', sub: '18+', val: travelersAdults, set: setTravelersAdults, min: 1 },
                          { label: 'Children', sub: 'Under 18', val: travelersChildren, set: setTravelersChildren, min: 0 },
                        ] as { label: string; sub: string; val: number; set: React.Dispatch<React.SetStateAction<number>>; min: number }[]).map(row => (
                          <div key={row.label} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '14px 20px' }}>
                            <div>
                              <div style={{ fontSize: 15, fontWeight: 500, color: '#0C0E1C' }}>{row.label}</div>
                              <div style={{ fontSize: 12, color: 'rgba(12,14,28,0.45)', marginTop: 1 }}>{row.sub}</div>
                            </div>
                            <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                              <button
                                onClick={() => row.set(v => Math.max(row.min, v - 1))}
                                style={{ width: 32, height: 32, borderRadius: 99, border: '1.5px solid rgba(12,14,28,0.15)', background: 'transparent', cursor: 'pointer', fontSize: 18, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#0C0E1C', lineHeight: 1 }}
                              >−</button>
                              <span style={{ fontSize: 16, fontWeight: 500, minWidth: 16, textAlign: 'center', color: '#0C0E1C' }}>{row.val}</span>
                              <button
                                onClick={() => row.set(v => v + 1)}
                                style={{ width: 32, height: 32, borderRadius: 99, border: '1.5px solid rgba(12,14,28,0.15)', background: 'transparent', cursor: 'pointer', fontSize: 18, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#0C0E1C', lineHeight: 1 }}
                              >+</button>
                            </div>
                          </div>
                        ))}
                        <div style={{ padding: '12px 20px 16px' }}>
                          <button
                            onClick={() => setFlightChipPopover(null)}
                            style={{ width: '100%', padding: '10px', borderRadius: 12, background: '#0C0E1C', color: '#fff', border: 'none', cursor: 'pointer', fontFamily: "'Centra No2', -apple-system, sans-serif", fontSize: 14, fontWeight: 500 }}
                          >Done</button>
                        </div>
                      </div>
                    </motion.div>
                  );
                }

                return null;
              })()}
            </AnimatePresence>,
            document.body
          )}

          {ReactDOM.createPortal(
            <AnimatePresence>
              {leavingFocused && leavingSheetPos && leavingMatches.length > 0 && (
                <motion.div
                  initial={{ opacity: 0, y: -8 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -6 }}
                  transition={{ type: 'spring', stiffness: 420, damping: 30 }}
                  style={{
                    position: 'fixed',
                    top: leavingSheetPos.top,
                    left: leavingSheetPos.left,
                    width: leavingSheetPos.width,
                    background: '#ffffff',
                    borderRadius: 20,
                    boxShadow: '0 16px 48px rgba(12,14,28,0.14), 0 4px 12px rgba(12,14,28,0.06)',
                    border: '1px solid rgba(12,14,28,0.06)',
                    zIndex: 9999,
                    overflow: 'hidden',
                  }}
                >
                  {leavingMatches.map((airport, i) => (
                    <button
                      key={airport.code}
                      onMouseDown={e => {
                        e.preventDefault();
                        setLeavingFrom(`${airport.city} (${airport.code})`);
                        setLeavingFocused(false);
                      }}
                      style={{
                        display: 'flex', alignItems: 'center', gap: 14,
                        width: '100%', padding: '13px 20px',
                        border: 'none', background: 'transparent',
                        cursor: 'pointer', textAlign: 'left',
                        borderBottom: i < leavingMatches.length - 1 ? '1px solid rgba(12,14,28,0.05)' : 'none',
                        fontFamily: "'Centra No2', -apple-system, sans-serif",
                      }}
                      onMouseEnter={e => (e.currentTarget.style.background = 'rgba(12,14,28,0.03)')}
                      onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                    >
                      <div style={{
                        width: 44, height: 44, borderRadius: 12,
                        background: 'rgba(12,14,28,0.05)',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        flexShrink: 0,
                      }}>
                        <span style={{ fontSize: 12, fontWeight: 700, color: '#191E3B', letterSpacing: '0.5px' }}>
                          {airport.code}
                        </span>
                      </div>
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ fontSize: 15, fontWeight: 500, color: '#0C0E1C', lineHeight: '20px' }}>
                          {airport.city}
                        </div>
                        <div style={{ fontSize: 13, fontWeight: 400, color: 'rgba(12,14,28,0.45)', lineHeight: '18px', marginTop: 1 }}>
                          {airport.name} · {airport.country}
                        </div>
                      </div>
                    </button>
                  ))}
                </motion.div>
              )}
            </AnimatePresence>,
            document.body
          )}

        </motion.div>
          {/* end NLP card wrapper */}
          </motion.div>
        </motion.div>

        {/* Trip recap banner */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, ease, delay: 0.07 }}
          style={{
            background: T.recapBg,
            borderRadius: T.recapRadius,
            overflow: 'hidden',
            position: 'relative',
            height: 280,
            display: 'flex',
            alignItems: 'stretch',
          }}
        >
          {/* Hero photo */}
          <img
            src={ASSET_HERO}
            alt="Cancun"
            style={{
              position: 'absolute',
              inset: 0,
              width: '100%',
              height: '100%',
              objectFit: 'cover',
              objectPosition: 'center 30%',
            }}
          />

          {/* Blue-to-transparent gradient overlay */}
          <div style={{
            position: 'absolute',
            top: 0,
            left: 0,
            right: 0,
            height: 278,
            background: 'linear-gradient(180deg, rgba(0,70,149,0.75) 0%, rgba(0,70,149,0) 100%)',
            pointerEvents: 'none',
          }} />

          {/* Inner content */}
          <div style={{
            position: 'relative',
            zIndex: 1,
            display: 'flex',
            alignItems: 'flex-start',
            justifyContent: 'space-between',
            width: '100%',
            padding: '36px 36px 56px',
          }}>
            {/* Left: title + tags */}
            <div style={{
              display: 'flex',
              flexDirection: 'column',
              gap: 12,
              flex: 1,
            }}>
              <p style={{
                fontFamily: "'Centra No2', -apple-system, sans-serif",
                fontSize: 32,
                fontWeight: 500,
                color: '#fff',
                margin: 0,
                lineHeight: '1.2',
                letterSpacing: '-0.32px',
                textShadow: '0px 0px 15px rgba(4,51,112,0.5)',
                maxWidth: 208,
              }}>
                2025 Spring Break recap
              </p>
              <div style={{ display: 'flex', gap: 8 }}>
                {['5 nights', '3 people'].map(tag => (
                  <span key={tag} style={{
                    backdropFilter: 'blur(7.5px)',
                    WebkitBackdropFilter: 'blur(7.5px)',
                    background: 'rgba(255,255,255,0.05)',
                    border: '1px solid rgba(255,255,255,0.1)',
                    borderRadius: 24,
                    padding: '8px 14px',
                    fontFamily: "'Centra No2', -apple-system, sans-serif",
                    fontSize: 14,
                    fontWeight: 400,
                    color: '#fff',
                    lineHeight: '20px',
                    whiteSpace: 'nowrap',
                  }}>
                    {tag}
                  </span>
                ))}
              </div>
            </div>

            {/* Right: activity cards */}
            <div style={{
              display: 'flex',
              flexDirection: 'column',
              gap: 16,
              flex: 1,
              minWidth: 0,
              alignItems: 'flex-start',
            }}>
              {/* Hotel card */}
              <motion.div
                initial={{ opacity: 0, x: 16 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ duration: 0.4, ease, delay: 0.15 }}
                style={recapCardStyle}
              >
                <div style={{
                  width: 64,
                  height: 64,
                  borderRadius: 12,
                  border: '1px solid rgba(12,14,28,0.05)',
                  overflow: 'hidden',
                  flexShrink: 0,
                }}>
                  <img src={ASSET_HOTEL} alt="hotel" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', justifyContent: 'space-between', height: '100%' }}>
                  <p style={{
                    fontFamily: "'Centra No2', -apple-system, sans-serif",
                    fontSize: 16,
                    fontWeight: 500,
                    color: '#0C0E1C',
                    margin: 0,
                    lineHeight: '20px',
                    fontFeatureSettings: '"ss02" 1',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap',
                    maxWidth: '100%',
                  }}>
                    Hard Rock Hotel Cancun - All Inclusive
                  </p>
                  <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginTop: 4 }}>
                    <span style={{
                      background: T.ratingBg,
                      borderRadius: 4,
                      width: 28,
                      height: 16,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontFamily: "'Centra No2', -apple-system, sans-serif",
                      fontSize: 12,
                      fontWeight: 500,
                      color: '#fff',
                      fontFeatureSettings: '"ss02" 1',
                      flexShrink: 0,
                    }}>9.2</span>
                    <span style={{
                      fontFamily: "'Centra No2', -apple-system, sans-serif",
                      fontSize: 12,
                      fontWeight: 400,
                      color: T.ratingText,
                      fontFeatureSettings: '"ss02" 1',
                    }}>Excellent</span>
                  </div>
                </div>
              </motion.div>

              {/* Flight card */}
              <motion.div
                initial={{ opacity: 0, x: 16 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ duration: 0.4, ease, delay: 0.22 }}
                style={recapCardStyle}
              >
                <div style={{
                  width: 64,
                  height: 64,
                  borderRadius: 12,
                  overflow: 'hidden',
                  flexShrink: 0,
                }}>
                  <img src={ASSET_FLIGHT} alt="flight" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                  <p style={{
                    fontFamily: "'Centra No2', -apple-system, sans-serif",
                    fontSize: 16,
                    fontWeight: 500,
                    color: '#0C0E1C',
                    margin: 0,
                    lineHeight: '20px',
                    fontFeatureSettings: '"ss02" 1',
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap',
                  }}>
                    HOUS → CUN
                  </p>
                  <p style={{
                    fontFamily: "'Centra No2', -apple-system, sans-serif",
                    fontSize: 16,
                    fontWeight: 400,
                    color: 'rgba(12,14,28,0.5)',
                    margin: 0,
                    lineHeight: '20px',
                    fontFeatureSettings: '"ss02" 1',
                  }}>
                    Conversation
                  </p>
                </div>
              </motion.div>
            </div>
          </div>
        </motion.div>

        {/* "Stay like a local" destinations */}
        <motion.div
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, ease, delay: 0.14 }}
        >
          <h2 style={{
            fontFamily: "'Centra No2', -apple-system, sans-serif",
            fontSize: 22,
            fontWeight: 700,
            color: '#0C0E1C',
            letterSpacing: '-0.025em',
            margin: '0 0 16px',
          }}>
            Stay like a local in Paris
          </h2>

          <div style={{
            display: 'flex',
            gap: 14,
            overflowX: 'auto',
            paddingBottom: 4,
            scrollbarWidth: 'none',
          }}>
            {DESTINATIONS.map((dest, i) => (
              <motion.div
                key={dest.label}
                initial={{ opacity: 0, scale: 0.94 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.38, ease, delay: 0.2 + i * 0.05 }}
                onClick={() => submitQuery(`Stay in ${dest.label}`)}
                whileHover={{ scale: 1.025, transition: { duration: 0.12 } }}
                whileTap={{ scale: 0.97 }}
                style={{
                  flexShrink: 0,
                  width: 180,
                  borderRadius: 16,
                  overflow: 'hidden',
                  cursor: 'pointer',
                  background: '#fff',
                  boxShadow: '0 1px 8px rgba(12,14,28,0.08)',
                }}
              >
                <div style={{ height: 120, overflow: 'hidden' }}>
                  <img
                    src={dest.img}
                    alt={dest.label}
                    style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
                    loading="eager"
                  />
                </div>
                <div style={{ padding: '8px 12px 10px' }}>
                  <p style={{
                    fontFamily: "'Centra No2', -apple-system, sans-serif",
                    fontSize: 13,
                    fontWeight: 700,
                    color: '#0C0E1C',
                    margin: 0,
                    letterSpacing: '-0.01em',
                  }}>
                    {dest.label}
                  </p>
                </div>
              </motion.div>
            ))}
          </div>
        </motion.div>
      </div>
      </div>
    </div>
  );
};

// ─── Left sidebar (92px column) ──────────────────────────────────────────────
const ASSET_ONEKEY = 'https://www.figma.com/api/mcp/asset/d617af3a-aa1b-4e75-a9b5-85d5158f483a';
const ASSET_IC_HISTORY  = 'https://www.figma.com/api/mcp/asset/16be5bd4-cc1d-411e-adcc-98c4d34757a6';
const ASSET_IC_TRIPS    = 'https://www.figma.com/api/mcp/asset/c14d4506-f488-41af-9be4-a9d4ac5cde99';
const ASSET_IC_HEADSET  = 'https://www.figma.com/api/mcp/asset/966d2582-93bc-4458-9df3-f3d3b5fd608a';

const sidebarBtnStyle: React.CSSProperties = {
  width: 44,
  height: 44,
  borderRadius: 999,
  border: '1px solid #fff',
  backgroundImage: 'linear-gradient(179.9deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.5) 95.923%), linear-gradient(90deg, #F6F5F4 0%, #F6F5F4 100%)',
  boxShadow: '0px 12px 16px rgba(12,14,28,0.08)',
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'center',
  cursor: 'pointer',
  flexShrink: 0,
};

// Account circle SVG (inline since no asset URL available)
const AccountCircle = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
    <circle cx="12" cy="8" r="3.5" stroke="#0C0E1C" strokeWidth="1.8"/>
    <path d="M4 20c0-4.418 3.582-8 8-8s8 3.582 8 8" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round"/>
  </svg>
);

const LeftSidebar: React.FC = () => (
  <motion.div
    initial={{ opacity: 0, x: -12 }}
    animate={{ opacity: 1, x: 0 }}
    transition={{ duration: 0.45, ease: [0.42, 0.1, 0.24, 1] }}
    style={{
      width: 92,
      flexShrink: 0,
      background: T.sidebarBg,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      padding: 24,
      gap: 24,
    }}
  >
    {/* OneKey brand logo */}
    <img src={ASSET_ONEKEY} alt="OneKey" style={{ width: 44, height: 23, objectFit: 'contain' }} />

    {/* History */}
    <button style={sidebarBtnStyle} title="History">
      <img src={ASSET_IC_HISTORY} alt="History" style={{ width: 20, height: 20, objectFit: 'contain' }} />
    </button>

    {/* Trips */}
    <button style={sidebarBtnStyle} title="Trips">
      <img src={ASSET_IC_TRIPS} alt="Trips" style={{ width: 20, height: 20, objectFit: 'contain' }} />
    </button>

    {/* Support */}
    <button style={sidebarBtnStyle} title="Support">
      <img src={ASSET_IC_HEADSET} alt="Support" style={{ width: 20, height: 20, objectFit: 'contain' }} />
    </button>

    {/* Account */}
    <button style={sidebarBtnStyle} title="Account">
      <AccountCircle />
    </button>
  </motion.div>
);

// ─── Shared style objects ─────────────────────────────────────────────────────
const chipBtnStyle: React.CSSProperties = {
  display: 'flex',
  alignItems: 'center',
  gap: 8,
  height: 48,
  padding: '16px 20px',
  borderRadius: 100,
  background: 'rgba(12,14,28,0.05)',
  border: 'none',
  cursor: 'pointer',
  flexShrink: 0,
  fontFamily: "'Centra No2', -apple-system, sans-serif",
};

const chipLabelStyle: React.CSSProperties = {
  fontFamily: "'Centra No2', -apple-system, sans-serif",
  fontSize: 14,
  fontWeight: 500,
  color: '#0C0E1C',
  lineHeight: '18px',
  whiteSpace: 'nowrap',
};

const recapCardStyle: React.CSSProperties = {
  background: '#fff',
  borderRadius: 16,
  padding: '12px 16px',
  display: 'flex',
  alignItems: 'center',
  gap: 20,
  width: '100%',
  boxSizing: 'border-box',
  cursor: 'pointer',
};

export default EmptySearchView;
