// EmptySearchView.tsx — Desktop homepage matching Figma node 3031:55634
// Exact tokens from get_design_context: colors, shadows, radii, typography

import React, { useState, useCallback, useMemo, useEffect, useRef } from 'react';
import ReactDOM from 'react-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { useAppStore } from '../store/appStore';
import { spring, ease, glass } from '../theme/theme';

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
  cardShadow:   '0 4px 24px rgba(12,14,28,0.08), 0 1px 4px rgba(12,14,28,0.04)',
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

const LOB_TABS = [
  { label: 'Stays',        img: ASSET_STAYS  },
  { label: 'Flights',      img: ASSET_FLIGHTS },
  { label: 'Cars',         img: ASSET_CARS   },
  { label: 'Packages',     img: ASSET_PKG    },
  { label: 'Things to Do', img: ASSET_TTD    },
  { label: 'Cruises',      img: ASSET_CRUISE },
];

const DESTINATIONS = [
  { label: 'Paris',         img: 'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?w=400&auto=format&fit=crop' },
  { label: 'Cancun',        img: 'https://images.unsplash.com/photo-1590523277543-a94d2e4eb00b?w=400&auto=format&fit=crop' },
  { label: 'Tokyo',         img: 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=400&auto=format&fit=crop' },
  { label: 'New York',      img: 'https://images.unsplash.com/photo-1485871981521-5b1fd3805eee?w=400&auto=format&fit=crop' },
  { label: 'Rome',          img: 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=400&auto=format&fit=crop' },
  { label: 'Bali',          img: 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=400&auto=format&fit=crop' },
  { label: 'London',        img: 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=400&auto=format&fit=crop' },
  { label: 'Barcelona',     img: 'https://images.unsplash.com/photo-1583422409516-2895a77efded?w=400&auto=format&fit=crop' },
  { label: 'Mexico City',   img: 'https://images.unsplash.com/photo-1518105779142-d975f22f1b0a?w=400&auto=format&fit=crop' },
  { label: 'Maldives',      img: 'https://images.unsplash.com/photo-1514282401047-d79a71a590e8?w=400&auto=format&fit=crop' },
  { label: 'Sydney',        img: 'https://images.unsplash.com/photo-1506973035872-a4ec16b8e8d9?w=400&auto=format&fit=crop' },
  { label: 'Dubai',         img: 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=400&auto=format&fit=crop' },
  { label: 'Santorini',     img: 'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?w=400&auto=format&fit=crop' },
  { label: 'Seattle',       img: 'https://images.unsplash.com/photo-1438401171849-74ac270044ee?w=400&auto=format&fit=crop' },
  { label: 'Miami',         img: 'https://images.unsplash.com/photo-1506966953602-c20cc11f75e3?w=400&auto=format&fit=crop' },
  { label: 'Los Angeles',   img: 'https://images.unsplash.com/photo-1580655653885-65763b2597d0?w=400&auto=format&fit=crop' },
  { label: 'Chicago',       img: 'https://images.unsplash.com/photo-1494522855154-9297ac14b55f?w=400&auto=format&fit=crop' },
  { label: 'San Francisco', img: 'https://images.unsplash.com/photo-1521747116042-5a810fda9664?w=400&auto=format&fit=crop' },
  { label: 'Las Vegas',     img: 'https://images.unsplash.com/photo-1605833556294-ea5c7a74f57d?w=400&auto=format&fit=crop' },
  { label: 'Honolulu',      img: 'https://images.unsplash.com/photo-1507876466758-e54d7c383db7?w=400&auto=format&fit=crop' },
  { label: 'Amsterdam',     img: 'https://images.unsplash.com/photo-1534351590666-13e3e96b5017?w=400&auto=format&fit=crop' },
  { label: 'Prague',        img: 'https://images.unsplash.com/photo-1519677100203-a0e668c92439?w=400&auto=format&fit=crop' },
  { label: 'Lisbon',        img: 'https://images.unsplash.com/photo-1585208798174-6cedd86e019a?w=400&auto=format&fit=crop' },
  { label: 'Bangkok',       img: 'https://images.unsplash.com/photo-1508009603885-50cf7c579365?w=400&auto=format&fit=crop' },
  { label: 'Singapore',     img: 'https://images.unsplash.com/photo-1525625293386-3f8f99389edd?w=400&auto=format&fit=crop' },
  { label: 'Phuket',        img: 'https://images.unsplash.com/photo-1589394815804-964ed0be2eb5?w=400&auto=format&fit=crop' },
  { label: 'Cape Town',     img: 'https://images.unsplash.com/photo-1580060839134-75a5edca2e99?w=400&auto=format&fit=crop' },
  { label: 'Buenos Aires',  img: 'https://images.unsplash.com/photo-1589909202802-8f4aadce1849?w=400&auto=format&fit=crop' },
  { label: 'Rio de Janeiro',img: 'https://images.unsplash.com/photo-1483729558449-99ef09a8c325?w=400&auto=format&fit=crop' },
  { label: 'Vienna',        img: 'https://images.unsplash.com/photo-1516550893923-42d28e5677af?w=400&auto=format&fit=crop' },
  { label: 'Kyoto',         img: 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=400&auto=format&fit=crop' },
  { label: 'Maui',          img: 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?w=400&auto=format&fit=crop' },
  { label: 'Tulum',         img: 'https://images.unsplash.com/photo-1552074284-5e88ef1aef18?w=400&auto=format&fit=crop' },
];

const DEST_TAGLINES: Record<string, string> = {
  'Paris':         'World-class art, food, and the most romantic streets on earth',
  'Cancun':        'Crystal-clear waters, all-inclusive resorts, and vibrant nightlife',
  'Tokyo':         'Futuristic city meets ancient temples — a truly unique contrast',
  'New York':      'The city that never sleeps — culture, food, and energy everywhere',
  'Rome':          'Every cobblestone has a story — 3,000 years of living history',
  'Bali':          'Spiritual retreats, lush rice terraces, and world-class surf',
  'London':        'Royal history meets cutting-edge creativity in one iconic city',
  'Barcelona':     'Gaudí\'s dreamlike architecture, beaches, and tapas culture',
  'Mexico City':   'Vibrant street art, incredible cuisine, and rich Aztec heritage',
  'Maldives':      'Overwater bungalows, coral reefs, and absolute serenity',
  'Sydney':        'Iconic harbour, golden beaches, and a relaxed cosmopolitan vibe',
  'Dubai':         'Record-breaking skyline, desert adventures, and luxury shopping',
  'Santorini':     'Volcanic caldera views, white-washed villages, and sunset magic',
  'Seattle':       'Coffee culture, Pike Place Market, and stunning mountain views',
  'Miami':         'Art Deco beaches, Latin flair, and endless sunshine',
  'Los Angeles':   'Hollywood glamour, year-round sun, and world-famous beaches',
  'Chicago':       'Deep-dish pizza, jazz, and a breathtaking lakefront skyline',
  'San Francisco': 'Golden Gate views, sourdough, and foggy Victorian charm',
  'Las Vegas':     'Non-stop entertainment, world-class dining, and desert nightlife',
  'Honolulu':      'Pristine beaches, surf culture, and the spirit of aloha',
  'Amsterdam':     'Canal-side cafés, cycling culture, and world-class museums',
  'Prague':        'Fairy-tale spires, cobblestone streets, and Czech beer culture',
  'Lisbon':        'Fado music, tiled facades, and Atlantic sunset views',
  'Bangkok':       'Street food paradise, ornate temples, and buzzing night markets',
  'Singapore':     'Futuristic gardens, hawker centers, and seamless cosmopolitan life',
  'Phuket':        'Emerald waters, limestone cliffs, and vibrant beach parties',
  'Cape Town':     'Table Mountain, Cape winelands, and rugged Atlantic coastline',
  'Buenos Aires':  'Tango, steak, and European elegance in South America',
  'Rio de Janeiro':'Carnival energy, Copacabana beaches, and Christ the Redeemer',
  'Vienna':        'Imperial palaces, coffee houses, and world-class classical music',
  'Kyoto':         'Ancient temples, geisha districts, and cherry blossom season',
  'Maui':          'Road to Hana, volcanic craters, and the best sunsets in Hawaii',
  'Tulum':         'Cenotes, Mayan ruins on the cliffs, and boho-chic beach vibes',
};

const TRENDING_DESTS = new Set(['Paris', 'Tokyo', 'Bali', 'Santorini', 'Tulum', 'Kyoto']);

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
  <svg width="16" height="16" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M1.82812 6.62532C1.82813 4.20047 3.79384 2.23474 6.21868 2.23474H10.2434V3.69827H6.21868C4.60212 3.69827 3.29164 5.00875 3.29164 6.62532V10.6107H1.82812V6.62532Z" fill="#191E3B"/>
    <path d="M11.0238 2.31939C11.3809 2.67659 11.3809 3.25578 11.0238 3.61298L8.70442 5.93234L7.66956 4.89747L9.60083 2.96619L7.66956 1.0349L8.70442 3.45809e-05L11.0238 2.31939Z" fill="#191E3B"/>
    <path d="M16.1719 10.7281C16.1719 13.1529 14.2062 15.1187 11.7813 15.1187L7.75664 15.1187L7.75664 13.6551L11.7813 13.6551C13.3979 13.6551 14.7084 12.3446 14.7084 10.7281L14.7084 6.77484L16.1719 6.77484L16.1719 10.7281Z" fill="#191E3B"/>
    <path d="M6.92545 15.0329C6.56833 14.6757 6.56833 14.0965 6.92545 13.7393L9.2448 11.42L10.2797 12.4548L8.34839 14.3861L10.2797 16.3174L9.2448 17.3523L6.92545 15.0329Z" fill="#191E3B"/>
    <path d="M3.6588 14.2724C3.6588 13.6661 3.16737 13.1747 2.56116 13.1747C1.95495 13.1747 1.46352 13.6661 1.46352 14.2724C1.46352 14.8786 1.95495 15.37 2.56116 15.37V16.8335C1.14667 16.8335 0 15.6868 0 14.2724C0 12.8579 1.14667 11.7112 2.56116 11.7112C3.97565 11.7112 5.12232 12.8579 5.12232 14.2724C5.12232 15.6868 3.97565 16.8335 2.56116 16.8335V15.37C3.16737 15.37 3.6588 14.8786 3.6588 14.2724Z" fill="#191E3B"/>
    <path d="M16.5377 3.07936C16.5377 2.47315 16.0463 1.98171 15.4401 1.98171C14.8339 1.98171 14.3424 2.47315 14.3424 3.07936C14.3424 3.68557 14.8339 4.177 15.4401 4.177V5.64053C14.0256 5.64053 12.8789 4.49385 12.8789 3.07936C12.8789 1.66486 14.0256 0.518188 15.4401 0.518188C16.8546 0.518188 18.0012 1.66486 18.0012 3.07936C18.0012 4.49385 16.8546 5.64053 15.4401 5.64053V4.177C16.0463 4.177 16.5377 3.68557 16.5377 3.07936Z" fill="#191E3B"/>
  </svg>
);
const IconOneWay = () => (
  <svg width="16" height="16" viewBox="0 0 20 13" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M3.51305 10.1192C3.51305 9.53718 3.04119 9.06533 2.45913 9.06533C1.87707 9.06533 1.40522 9.53718 1.40522 10.1192C1.40522 10.7013 1.87707 11.1732 2.45913 11.1732V12.5784C1.10099 12.5784 0 11.4774 0 10.1192C0 8.7611 1.10099 7.66011 2.45913 7.66011C3.81727 7.66011 4.91826 8.7611 4.91826 10.1192C4.91826 11.4774 3.81727 12.5784 2.45913 12.5784V11.1732C3.04119 11.1732 3.51305 10.7013 3.51305 10.1192Z" fill="#191E3B"/>
    <path d="M18.5951 10.1192C18.5951 9.53718 18.1232 9.06533 17.5412 9.06533C16.9591 9.06533 16.4872 9.53718 16.4872 10.1192C16.4872 10.7013 16.9591 11.1732 17.5412 11.1732V12.5784C16.183 12.5784 15.082 11.4774 15.082 10.1192C15.082 8.7611 16.183 7.66011 17.5412 7.66011C18.8993 7.66011 20.0003 8.7611 20.0003 10.1192C20.0003 11.4774 18.8993 12.5784 17.5412 12.5784V11.1732C18.1232 11.1732 18.5951 10.7013 18.5951 10.1192Z" fill="#191E3B"/>
    <path d="M17.587 6.22597C17.4614 6.69441 16.9798 6.97247 16.5114 6.847L13.4693 6.03188L13.833 4.67454L16.3661 5.35328L17.0448 2.8202L18.4021 3.1839L17.587 6.22597Z" fill="#191E3B"/>
    <path d="M9.68694 0C14.2113 0 16.7714 3.46134 17.0685 6.32485L15.6701 6.46963C15.4357 4.21225 13.3857 1.40522 9.68694 1.40522C6.03637 1.40539 4.14099 4.32583 3.69418 6.53619L2.31641 6.2583C2.83815 3.6768 5.11469 0.000169163 9.68694 0Z" fill="#191E3B"/>
  </svg>
);
const IconMultiCity = () => (
  <svg width="16" height="16" viewBox="0 0 19 14" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M3.33739 11.3272C3.33739 10.7743 2.88913 10.326 2.33617 10.326C1.78322 10.326 1.33496 10.7743 1.33496 11.3272C1.33496 11.8802 1.78322 12.3284 2.33617 12.3284V13.6634C1.04594 13.6634 0 12.6175 0 11.3272C0 10.037 1.04594 8.99104 2.33617 8.99104C3.62641 8.99104 4.67235 10.037 4.67235 11.3272C4.67235 12.6175 3.62641 13.6634 2.33617 13.6634V12.3284C2.88913 12.3284 3.33739 11.8802 3.33739 11.3272Z" fill="#191E3B"/>
    <path d="M10.2085 2.33617C10.2085 1.78322 9.76023 1.33496 9.20727 1.33496C8.65431 1.33496 8.20605 1.78322 8.20605 2.33617C8.20605 2.88913 8.65431 3.33739 9.20727 3.33739V4.67235C7.91703 4.67235 6.87109 3.62641 6.87109 2.33617C6.87109 1.04594 7.91703 0 9.20727 0C10.4975 0 11.5434 1.04594 11.5434 2.33617C11.5434 3.62641 10.4975 4.67235 9.20727 4.67235V3.33739C9.76023 3.33739 10.2085 2.88913 10.2085 2.33617Z" fill="#191E3B"/>
    <path d="M17.6655 11.3272C17.6655 10.7743 17.2173 10.326 16.6643 10.326C16.1113 10.326 15.6631 10.7743 15.6631 11.3272C15.6631 11.8802 16.1113 12.3284 16.6643 12.3284V13.6634C15.3741 13.6634 14.3281 12.6175 14.3281 11.3272C14.3281 10.037 15.3741 8.99104 16.6643 8.99104C17.9545 8.99104 19.0005 10.037 19.0005 11.3272C19.0005 12.6175 17.9545 13.6634 16.6643 13.6634V12.3284C17.2173 12.3284 17.6655 11.8802 17.6655 11.3272Z" fill="#191E3B"/>
    <path d="M16.7067 7.62859C16.5874 8.07361 16.1299 8.33776 15.6848 8.21856L12.7948 7.4442L13.1404 6.15473L15.5468 6.79953L16.1916 4.39311L17.481 4.73862L16.7067 7.62859Z" fill="#191E3B"/>
    <path d="M9.20513 1.71393C13.5033 1.71393 15.9353 5.0022 16.2176 7.72254L14.8891 7.86008C14.6665 5.71556 12.719 3.04889 9.20513 3.04889C5.73709 3.04905 3.93648 5.82347 3.51201 7.9233L2.20312 7.65931C2.69878 5.20689 4.86149 1.71409 9.20513 1.71393Z" fill="#191E3B"/>
    <circle cx="9.20706" cy="2.33618" r="1.03128" fill="#F5F2F1"/>
  </svg>
);
const IconSeat = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
    {/* EGDS airline_seat — side-profile seat silhouette */}
    <path d="M7 5a2 2 0 0 1 2-2h1a2 2 0 0 1 2 2v7h3a2 2 0 0 1 2 2v1H7V5Z" fill="#191E3B" opacity="0.85"/>
    <rect x="5" y="17" width="14" height="2.5" rx="1.25" fill="#191E3B" opacity="0.85"/>
    <path d="M10 19.5V22" stroke="#191E3B" strokeWidth="1.6" strokeLinecap="round" opacity="0.85"/>
    <path d="M15 19.5V22" stroke="#191E3B" strokeWidth="1.6" strokeLinecap="round" opacity="0.85"/>
  </svg>
);
const IconSeatPremiumEco = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
    {/* Same upright seat + legrest extension for extra legroom */}
    <path d="M7 5a2 2 0 0 1 2-2h1a2 2 0 0 1 2 2v7h3a2 2 0 0 1 2 2v1H7V5Z" fill="#191E3B" opacity="0.85"/>
    <rect x="5" y="17" width="14" height="2.5" rx="1.25" fill="#191E3B" opacity="0.85"/>
    <rect x="14.5" y="13" width="5" height="2" rx="1" fill="#191E3B" opacity="0.7"/>
    <path d="M10 19.5V22" stroke="#191E3B" strokeWidth="1.6" strokeLinecap="round" opacity="0.85"/>
    <path d="M15 19.5V22" stroke="#191E3B" strokeWidth="1.6" strokeLinecap="round" opacity="0.85"/>
  </svg>
);
const IconSeatBusiness = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
    {/* Backrest angled ~40° off vertical = clearly reclined */}
    <path d="M7 12L10 12L6 3L3 3Z" fill="#191E3B" opacity="0.85"/>
    {/* Seat cushion */}
    <rect x="10" y="12" width="6" height="3" rx="1.25" fill="#191E3B" opacity="0.85"/>
    {/* Legrest extending forward */}
    <rect x="15.5" y="12" width="5" height="2.5" rx="1.25" fill="#191E3B" opacity="0.75"/>
    {/* Base platform */}
    <rect x="7" y="17" width="12" height="2.5" rx="1.25" fill="#191E3B" opacity="0.85"/>
    <path d="M10 19.5V22" stroke="#191E3B" strokeWidth="1.6" strokeLinecap="round" opacity="0.85"/>
    <path d="M16.5 19.5V22" stroke="#191E3B" strokeWidth="1.6" strokeLinecap="round" opacity="0.85"/>
  </svg>
);
const IconSeatFirst = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
    {/* Fully flat bed surface */}
    <rect x="3" y="11" width="18" height="3.5" rx="1.75" fill="#191E3B" opacity="0.85"/>
    {/* Pillow / headrest at head end */}
    <rect x="3" y="6" width="5.5" height="5.5" rx="2" fill="#191E3B" opacity="0.75"/>
    <path d="M6 14.5V18" stroke="#191E3B" strokeWidth="1.6" strokeLinecap="round" opacity="0.85"/>
    <path d="M19 14.5V18" stroke="#191E3B" strokeWidth="1.6" strokeLinecap="round" opacity="0.85"/>
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
    // Relative: next/this week|weekend|month, in N days/weeks, tomorrow, etc.
    // Named seasons/holidays, month names (full + abbrev), durations
    regex: /\b(next\s+(?:week|weekend|month|monday|tuesday|wednesday|thursday|friday|saturday|sunday|january|february|march|april|may|june|july|august|september|october|november|december)|this\s+(?:week|weekend|month|summer|winter|fall|spring)|in\s+\d+\s+(?:days?|weeks?|months?)|a\s+(?:week|month)\s+from\s+now|tomorrow|tonight|spring\s+break|summer|winter|fall|autumn|christmas|thanksgiving|new\s+year(?:'?s)?|easter|labor\s+day|memorial\s+day|fourth\s+of\s+july|july\s+4th|january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec|\d+\s+nights?|\d+\s+weeks?|\d+\s+days?|(?:a\s+)?(?:long\s+)?weekend)\b/gi,
  },
  {
    entityType: 'place',
    // US cities, international cities, countries, regions, and vibe words
    regex: /\b(seattle|portland|san\s+francisco|sf|los\s+angeles|la|san\s+diego|las\s+vegas|phoenix|denver|salt\s+lake\s+city|austin|dallas|houston|chicago|minneapolis|st\.?\s+louis|nashville|atlanta|charlotte|washington\s+d\.?c\.?|dc|new\s+york|nyc|boston|philadelphia|new\s+orleans|miami|tampa|fort\s+lauderdale|toronto|vancouver|montreal|london|amsterdam|berlin|prague|vienna|zurich|lisbon|madrid|rome|paris|barcelona|milan|florence|athens|istanbul|dubai|abu\s+dhabi|doha|tel\s+aviv|cape\s+town|nairobi|tokyo|osaka|kyoto|seoul|taipei|hong\s+kong|singapore|bangkok|bali|sydney|melbourne|auckland|cancun|mexico\s+city|havana|san\s+jose|bogota|lima|rio\s+de\s+janeiro|buenos\s+aires|new\s+york|hawaii|maldives|caribbean|europe|asia|pacific\s+northwest|east\s+coast|west\s+coast|southeast\s+asia|mediterranean|scandinavia|beach|mountains?|ski\s+resort|tropical|island|countryside|city\s+break|costa\s+rica|thailand|greece|portugal|france|italy|spain|japan|mexico|iceland|morocco|egypt|peru|chile|brazil|new\s+zealand|australia|ireland|scotland|croatia|turkey)\b/gi,
  },
  {
    entityType: 'people',
    // Numbered: "for two", word numbers, digit counts
    // Party types: solo, couple, family, group
    regex: /\b(for\s+(?:one|two|three|four|five|six|seven|eight|nine|ten|\d+)|just\s+(?:me|us|the\s+two\s+of\s+us)|solo|alone|by\s+myself|couple|two\s+of\s+us|the\s+(?:two|three|four)\s+of\s+us|with\s+(?:my\s+)?(?:partner|spouse|wife|husband|girlfriend|boyfriend|family|kids?|children)|with\s+\d+\s+(?:kids?|children|friends?)|group\s+of\s+\d+|party\s+of\s+\d+|family\s+of\s+\d+|\d+\s+adults?\s+and\s+\d+\s+(?:kids?|children|teenagers?|teens?)|\d+\s+adults?|\d+\s+(?:people|travelers?|passengers?|guests?|friends?))\b/gi,
  },
  {
    entityType: 'budget',
    regex: /\b(under\s+\$[\d,]+|over\s+\$[\d,]+|around\s+\$[\d,]+|up\s+to\s+\$[\d,]+|\$[\d,]+(?:\s+budget)?|budget(?:\s+trip|\s+travel)?|cheap(?:\s+flights?)?|affordable|economy(?:\s+class)?|mid.?range|moderate|splurge|luxury|luxurious|high.?end|five.?star|5.?star|first\s+class|business\s+class)\b/gi,
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
type ContextChipIconType = 'calendar' | 'destination' | 'people' | 'star' | 'map' | 'tag' | 'waves' | 'fork' | 'walk' | 'moon' | 'ticket' | 'hotel' | 'sparkle';
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
      { id: 'all-inclusive', icon: 'sparkle', label: 'All inclusive' },
      { id: 'near-beaches',  icon: 'waves',   label: 'Near beaches'  },
      { id: 'water-sports',  icon: 'waves',   label: 'Water sports'  },
    );
  } else if (culture.some(kw => fullText.includes(kw))) {
    chips.push(
      { id: 'best-museums',     icon: 'star', label: 'Best museums'     },
      { id: 'local-food-tours', icon: 'fork', label: 'Local food tours' },
      { id: 'city-walks',       icon: 'walk', label: 'City walks'       },
    );
  } else if (asia.some(kw => fullText.includes(kw))) {
    chips.push(
      { id: 'local-experiences', icon: 'star', label: 'Local experiences' },
      { id: 'street-food',       icon: 'fork', label: 'Street food'       },
      { id: 'temple-tours',      icon: 'walk', label: 'Temple tours'      },
    );
  } else if (fullText.includes('las vegas')) {
    chips.push(
      { id: 'shows-events',  icon: 'ticket', label: 'Shows & events' },
      { id: 'casino-resorts', icon: 'star', label: 'Casino resorts' },
      { id: 'nightlife',     icon: 'moon',  label: 'Nightlife'      },
    );
  } else if (fullText.includes('orlando')) {
    chips.push(
      { id: 'theme-parks',      icon: 'star',   label: 'Theme parks'      },
      { id: 'family-resorts',   icon: 'hotel',  label: 'Family resorts'   },
      { id: 'discount-tickets', icon: 'ticket', label: 'Discount tickets' },
    );
  }

  if (fullText.includes('spring break')) {
    chips.push(
      { id: 'spring-break-pkgs', icon: 'sparkle', label: 'Spring break packages' },
      { id: 'beach-clubs',       icon: 'waves',   label: 'Beach clubs'            },
    );
  } else if (fullText.includes('summer')) {
    chips.push(
      { id: 'peak-season', icon: 'calendar', label: 'Peak season tips' },
      { id: 'early-bird',  icon: 'star',    label: 'Early bird deals' },
    );
  } else if (
    fullText.includes('christmas') ||
    fullText.includes('thanksgiving') ||
    fullText.includes('holiday')
  ) {
    chips.push(
      { id: 'holiday-pkgs',      icon: 'sparkle', label: 'Holiday packages'  },
      { id: 'family-gatherings', icon: 'people',  label: 'Family gatherings' },
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
    case 'waves':       return (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
        <path d="M2 12c1.5-2 3-2 4.5 0s3 2 4.5 0 3-2 4.5 0 3 2 4.5 0" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round"/>
        <path d="M2 17c1.5-2 3-2 4.5 0s3 2 4.5 0 3-2 4.5 0 3 2 4.5 0" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round"/>
        <path d="M2 7c1.5-2 3-2 4.5 0s3 2 4.5 0 3-2 4.5 0 3 2 4.5 0" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round"/>
      </svg>
    );
    case 'fork':        return (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
        <path d="M8 2v4a3 3 0 0 0 3 3v11" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round"/>
        <path d="M6 2v4M10 2v4" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round"/>
        <path d="M16 2c0 0 2 2 2 5s-2 3-2 3v10" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round"/>
      </svg>
    );
    case 'walk':        return (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
        <circle cx="13" cy="4" r="2" stroke="#0C0E1C" strokeWidth="1.8"/>
        <path d="M9 8.5l2 2.5v4l-2 5" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
        <path d="M11 11l3 1 2-3" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
        <path d="M13 12v4l2 4" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round"/>
      </svg>
    );
    case 'moon':        return (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
        <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
    );
    case 'ticket':      return (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
        <path d="M2 9a2 2 0 0 1 0-4V3h20v2a2 2 0 0 1 0 4v2a2 2 0 0 1 0 4v2H2v-2a2 2 0 0 1 0-4V9z" stroke="#0C0E1C" strokeWidth="1.8" strokeLinejoin="round"/>
        <path d="M15 3v18" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round" strokeDasharray="2 2"/>
      </svg>
    );
    case 'hotel':       return (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
        <rect x="2" y="3" width="20" height="18" rx="1" stroke="#0C0E1C" strokeWidth="1.8"/>
        <path d="M2 9h20" stroke="#0C0E1C" strokeWidth="1.8"/>
        <rect x="6" y="13" width="3" height="3" rx="0.5" stroke="#0C0E1C" strokeWidth="1.5"/>
        <rect x="10.5" y="13" width="3" height="3" rx="0.5" stroke="#0C0E1C" strokeWidth="1.5"/>
        <rect x="15" y="13" width="3" height="3" rx="0.5" stroke="#0C0E1C" strokeWidth="1.5"/>
        <rect x="6" y="5" width="3" height="2.5" rx="0.5" stroke="#0C0E1C" strokeWidth="1.5"/>
        <rect x="10.5" y="5" width="3" height="2.5" rx="0.5" stroke="#0C0E1C" strokeWidth="1.5"/>
        <rect x="15" y="5" width="3" height="2.5" rx="0.5" stroke="#0C0E1C" strokeWidth="1.5"/>
        <path d="M10 21v-4h4v4" stroke="#0C0E1C" strokeWidth="1.8" strokeLinecap="round"/>
      </svg>
    );
    case 'sparkle':     return (
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
        <path d="M12 3l1.8 5.4 5.4 1.6-5.4 1.6L12 17l-1.8-5.4L4.8 10l5.4-1.6z" stroke="#0C0E1C" strokeWidth="1.8" strokeLinejoin="round"/>
        <path d="M19 3l.7 2 2 .7-2 .7-.7 2-.7-2-2-.7 2-.7z" stroke="#0C0E1C" strokeWidth="1.4" strokeLinejoin="round"/>
        <path d="M5 17l.5 1.5 1.5.5-1.5.5L5 21l-.5-1.5L3 19l1.5-.5z" stroke="#0C0E1C" strokeWidth="1.3" strokeLinejoin="round"/>
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
      initial={{ opacity: 0, y: -8, scale: 0.96}}
      animate={{ opacity: 1, y: 0, scale: 1}}
      exit={{ opacity: 0, y: -6, scale: 0.97, filter: 'blur(4px)', transition: { duration: 0.12 } }}
      transition={spring.snap}
      style={{
        position: 'fixed',
        top: position.top,
        left: position.left,
        background: glass.elevated.background,
        backdropFilter: glass.elevated.backdropFilter,
        WebkitBackdropFilter: glass.elevated.WebkitBackdropFilter,
        border: glass.elevated.border,
        boxShadow: glass.elevated.boxShadow,
        borderRadius: 24,
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
  <span className="nlp-cursor" style={{ userSelect: 'none', marginLeft: -1, lineHeight: '20px', verticalAlign: 'middle', alignSelf: 'center' }}>|</span>
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

// ─── Flight NLP ghost text ────────────────────────────────────────────────────
const FLIGHT_GHOSTS = [
  "From Seattle to Tokyo, during next weekend",
  "From New York to Miami, during this Friday",
  "From Los Angeles to London, during Dec 20–27",
  "From Chicago to Paris, during spring break",
  "From San Francisco to Cancun, for a couple",
  "From Boston to Barcelona, during August 10–17",
  "From Dallas to Rome, during next month",
];

// ─── Flight NLP parser ────────────────────────────────────────────────────────
const CITY_MAP: Record<string, string> = {
  'seattle': 'Seattle (SEA)', 'new york': 'New York (JFK)', 'los angeles': 'Los Angeles (LAX)',
  'chicago': 'Chicago (ORD)', 'san francisco': 'San Francisco (SFO)', 'boston': 'Boston (BOS)',
  'dallas': 'Dallas (DFW)', 'miami': 'Miami (MIA)', 'tokyo': 'Tokyo (NRT)',
  'london': 'London (LHR)', 'paris': 'Paris (CDG)', 'cancun': 'Cancún (CUN)',
  'rome': 'Rome (FCO)', 'barcelona': 'Barcelona (BCN)', 'los cabos': 'Los Cabos (SJD)',
  'las vegas': 'Las Vegas (LAS)', 'orlando': 'Orlando (MCO)', 'denver': 'Denver (DEN)',
  'atlanta': 'Atlanta (ATL)', 'houston': 'Houston (IAH)', 'phoenix': 'Phoenix (PHX)',
};

function parseFlightInput(text: string): {
  origin?: string;
  destination?: string;
  departDate?: string;
  returnDate?: string;
  adults?: number;
} {
  const result: ReturnType<typeof parseFlightInput> = {};
  const lower = text.toLowerCase();

  // Origin → Destination
  const routeMatch = lower.match(/^(.+?)\s+to\s+(.+?)(?:,|$)/i);
  if (routeMatch) {
    const rawOrigin = routeMatch[1].trim();
    const rawDest   = routeMatch[2].trim();
    const originKey = Object.keys(CITY_MAP).find(k => rawOrigin.includes(k));
    const destKey   = Object.keys(CITY_MAP).find(k => rawDest.includes(k));
    if (originKey) result.origin = CITY_MAP[originKey];
    if (destKey)   result.destination = CITY_MAP[destKey];
  }

  // Dates
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const iso = (d: Date) => d.toISOString().slice(0, 10);
  const nextWeekday = (target: number) => {
    const d = new Date(today);
    const diff = (target - d.getDay() + 7) % 7 || 7;
    d.setDate(d.getDate() + diff);
    return d;
  };

  if (/next weekend/i.test(text)) {
    const sat = nextWeekday(6);
    const sun = new Date(sat); sun.setDate(sat.getDate() + 1);
    result.departDate = iso(sat);
    result.returnDate = iso(sun);
  } else if (/this (monday|tuesday|wednesday|thursday|friday|saturday|sunday)/i.test(text)) {
    const dayNames = ['sunday','monday','tuesday','wednesday','thursday','friday','saturday'];
    const m = text.match(/this (monday|tuesday|wednesday|thursday|friday|saturday|sunday)/i);
    if (m) {
      const idx = dayNames.indexOf(m[1].toLowerCase());
      result.departDate = iso(nextWeekday(idx));
    }
  } else if (/tomorrow/i.test(text)) {
    const d = new Date(today); d.setDate(d.getDate() + 1);
    result.departDate = iso(d);
  } else {
    const rangeMatch = text.match(/\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{1,2})[–\-](\d{1,2})/i);
    if (rangeMatch) {
      const monthNames: Record<string, number> = {
        jan:0,feb:1,mar:2,apr:3,may:4,jun:5,jul:6,aug:7,sep:8,oct:9,nov:10,dec:11
      };
      const monthIdx = monthNames[rangeMatch[1].toLowerCase()];
      const year = today.getMonth() > monthIdx ? today.getFullYear() + 1 : today.getFullYear();
      const dep = new Date(year, monthIdx, parseInt(rangeMatch[2]));
      const ret = new Date(year, monthIdx, parseInt(rangeMatch[3]));
      result.departDate = iso(dep);
      result.returnDate = iso(ret);
    } else {
      const nightsMatch = text.match(/(\d+)\s+nights?/i);
      if (nightsMatch) {
        const nights = parseInt(nightsMatch[1]);
        const dep = new Date(today); dep.setDate(dep.getDate() + 7);
        const ret = new Date(dep); ret.setDate(dep.getDate() + nights);
        result.departDate = iso(dep);
        result.returnDate = iso(ret);
      }
    }
  }

  // Travelers
  const familyMatch = text.match(/family\s+of\s+(\d+)/i);
  const adultsMatch = text.match(/(\d+)\s+(?:adults?|travelers?|people)/i);
  const forNMatch   = text.match(/\bfor\s+(\d+)\b/i);
  if (familyMatch) {
    const n = parseInt(familyMatch[1]);
    result.adults = Math.min(n <= 2 ? n : 2, 9);
  } else if (/\bcouple\b/i.test(text)) {
    result.adults = 2;
  } else if (/\bsolo\b/i.test(text)) {
    result.adults = 1;
  } else if (adultsMatch) {
    result.adults = Math.min(parseInt(adultsMatch[1]), 9);
  } else if (forNMatch) {
    result.adults = Math.min(parseInt(forNMatch[1]), 9);
  }

  return result;
}

// ─── Component ───────────────────────────────────────────────────────────────
const EmptySearchView: React.FC = () => {
  const { submitQuery } = useAppStore();
  const [activeTab, setActiveTab] = useState(-1);
  const [selectedLob, setSelectedLob] = useState<string>('');
  const DEFAULT_TRIP = 'Roundtrip';
  const [flightTrip, setFlightTrip] = useState<string>(DEFAULT_TRIP);
  const DEFAULT_CLASS = 'Economy';
  const [flightClass, setFlightClass] = useState<string>(DEFAULT_CLASS);
  const [openFlightDropdown, setOpenFlightDropdown] = useState<'trip' | 'class' | null>(null);
  const [activeFlightField, setActiveFlightField] = useState<string | null>(null);
  const [leavingFrom, setLeavingFrom] = useState('');
  const DEFAULT_ORIGIN = 'Houston (HOU)';
  const [selectedOrigin, setSelectedOrigin] = useState(DEFAULT_ORIGIN);
  const [goingTo, setGoingTo] = useState('');
  const [flightChipPopover, setFlightChipPopover] = useState<{
    chipId: string;
    pos: { top: number; left: number; width: number };
  } | null>(null);
  const [originSearch, setOriginSearch] = useState('');
  const [destinationSearch, setDestinationSearch] = useState('');
  const [travelersAdults, setTravelersAdults] = useState(1);
  const [travelersChildren, setTravelersChildren] = useState(0);
  const [travelersChildAges, setTravelersChildAges] = useState<number[]>([]);
  const [travelersInfantsSeat, setTravelersInfantsSeat] = useState(0);
  const [travelersInfantsLap, setTravelersInfantsLap] = useState(0);
  const [travelersInfantAges, setTravelersInfantAges] = useState<number[]>([]);
  const [flightDates, setFlightDates] = useState<{ depart: string; return: string }>({ depart: '', return: '' });
  const [calViewYear, setCalViewYear] = useState(() => new Date().getFullYear());
  const [calViewMonth, setCalViewMonth] = useState(() => new Date().getMonth());
  const [flexDelta, setFlexDelta] = useState<0 | 1 | 2>(0);
  const flightChipBtnRefs = useRef<Record<string, HTMLButtonElement | null>>({});
  const nlpChipBtnRefs = useRef<Record<string, HTMLButtonElement | null>>({});
  const nlpChipsScrollRef = useRef<HTMLDivElement>(null);
  const [nlpChipPopover, setNlpChipPopover] = useState<{
    chipId: string;
    pos: { top: number; left: number; width: number };
  } | null>(null);
  const tripBtnRef = useRef<HTMLButtonElement | null>(null);
  const classBtnRef = useRef<HTMLButtonElement | null>(null);
  const [flightDropdownPos, setFlightDropdownPos] = useState<{ top: number; left: number; width: number } | null>(null);
  const [segments, setSegments] = useState<Segment[]>([]);
  const [liveText, setLiveText] = useState('');
  const [isFocused, setIsFocused] = useState(false);
  const [ghostIndex, setGhostIndex] = useState(0);
  const [flightGhostIndex, setFlightGhostIndex] = useState(0);
  const inputRef = React.useRef<HTMLInputElement>(null);
  const cardRef = React.useRef<HTMLDivElement>(null);
  const [selectedChipId, setSelectedChipId] = useState<string | null>(null);
  const [popoverPosition, setPopoverPosition] = useState<{ top: number; left: number } | null>(null);
  const [destPopoverAnchor, setDestPopoverAnchor] = useState<{ top: number; left: number; width: number } | null>(null);
  const [destSearch, setDestSearch] = useState('');
  const destSearchRef = useRef<HTMLInputElement>(null);
  const [lobFlash, setLobFlash] = useState(false);
  const [voiceListening, setVoiceListening] = useState(false);
  const [voiceTranscript, setVoiceTranscript] = useState('');
  const [voiceReceiving, setVoiceReceiving] = useState(false);
  const [voiceSupported] = useState(() => !!(
    (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition
  ));
  const [voiceTarget, setVoiceTarget] = useState<'nlp' | 'flights'>('nlp');
  const recognitionRef = useRef<any>(null);
  useEffect(() => {
    if (selectedLob !== '') {
      setLobFlash(true);
      const id = setTimeout(() => setLobFlash(false), 600);
      return () => clearTimeout(id);
    }
  }, [selectedLob]);
  // Rotate ghost text every 3 s when idle (not focused, no input)
  useEffect(() => {
    if (isFocused || liveText || segments.length > 0) return;
    const id = setInterval(() => {
      setGhostIndex(i => (i + 1) % GHOST_EXAMPLES.length);
    }, 3000);
    return () => clearInterval(id);
  }, [isFocused, liveText, segments.length]);

  // Rotate flight ghost text every 3500ms when leaving-from is empty
  useEffect(() => {
    if (leavingFrom !== '') return;
    const id = setInterval(() => {
      setFlightGhostIndex(i => (i + 1) % FLIGHT_GHOSTS.length);
    }, 3500);
    return () => clearInterval(id);
  }, [leavingFrom]);

  // ── Voice recognition helpers ─────────────────────────────────────────────
  const startVoice = useCallback((target: 'nlp' | 'flights') => {
    setVoiceTarget(target);
    setVoiceTranscript('');
    setVoiceReceiving(false);
    setVoiceListening(true);

    if (!voiceSupported) return;

    const SR = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    const rec = new SR();
    rec.continuous = false;
    rec.interimResults = true;
    rec.lang = 'en-US';

    rec.onresult = (event: any) => {
      let transcript = '';
      for (let i = event.resultIndex; i < event.results.length; i++) {
        transcript += event.results[i][0].transcript;
      }
      setVoiceTranscript(transcript);
      setVoiceReceiving(true);
    };

    rec.onend = () => {
      setVoiceReceiving(false);
      // Keep modal open so user can confirm or discard
    };

    rec.onerror = () => {
      setVoiceReceiving(false);
      // Keep overlay open — user dismisses by clicking away or tapping ×
    };

    recognitionRef.current = rec;
    rec.start();
  }, [voiceSupported]);

  const stopVoice = useCallback((confirm: boolean) => {
    if (recognitionRef.current) {
      try { recognitionRef.current.stop(); } catch (_) { /* ignore */ }
      recognitionRef.current = null;
    }
    if (confirm && voiceTranscript) {
      if (voiceTarget === 'flights') {
        setLeavingFrom(voiceTranscript);
      } else {
        setLiveText(voiceTranscript);
      }
    }
    setVoiceListening(false);
    setVoiceTranscript('');
    setVoiceReceiving(false);
  }, [voiceTranscript, voiceTarget, setLeavingFrom, setLiveText]);

  // Escape key dismisses voice overlay
  useEffect(() => {
    if (!voiceListening) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') stopVoice(false);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [voiceListening, stopVoice]);

  // NLP auto-fill: parse leavingFrom and populate flight chips
  const applyFlightParse = useCallback((text: string) => {
    if (!text) return;
    const parsed = parseFlightInput(text);
    if (parsed.destination) setGoingTo(parsed.destination);
    if (parsed.departDate) setFlightDates(prev => ({ depart: parsed.departDate!, return: parsed.returnDate || prev.return }));
    if (parsed.adults) setTravelersAdults(parsed.adults);
    if (parsed.origin) setSelectedOrigin(parsed.origin);
  }, []);

  // Debounced auto-fill (600ms)
  useEffect(() => {
    const timer = setTimeout(() => applyFlightParse(leavingFrom), 600);
    return () => clearTimeout(timer);
  }, [leavingFrom, applyFlightParse]);

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

  // Close destination popover on outside mousedown
  useEffect(() => {
    if (!destPopoverAnchor) return;
    const handleMouseDown = (e: MouseEvent) => {
      const target = e.target as Element;
      if (target.closest?.('[data-dest-popover]')) return;
      setDestPopoverAnchor(null);
      setDestSearch('');
    };
    document.addEventListener('mousedown', handleMouseDown);
    return () => document.removeEventListener('mousedown', handleMouseDown);
  }, [destPopoverAnchor]);

  // Close destination popover when card collapses
  useEffect(() => {
    if (!isFocused) {
      setDestPopoverAnchor(null);
      setDestSearch('');
    }
  }, [isFocused]);


  // Collapse card on click outside; also close flight dropdowns and flight chip popovers
  useEffect(() => {
    if (!isFocused && openFlightDropdown === null && !flightChipPopover && !nlpChipPopover && !voiceListening) return;
    const handleMouseDown = (e: MouseEvent) => {
      const target = e.target as Element;
      if (target.closest?.('[data-flight-popover]')) return;
      if (target.closest?.('[data-flight-dropdown]')) return;
      if (target.closest?.('[data-nlp-popover]')) return;
      if (cardRef.current && !cardRef.current.contains(e.target as Node)) {
        setIsFocused(false);
        setSelectedChipId(null);
        setPopoverPosition(null);
        setOpenFlightDropdown(null);
        setFlightChipPopover(null);
        setNlpChipPopover(null);
        setActiveFlightField(null);
        setDestPopoverAnchor(null);
        if (voiceListening) stopVoice(false);
        inputRef.current?.blur();
      } else {
        setOpenFlightDropdown(null);
        setFlightChipPopover(null);
        setNlpChipPopover(null);
        setActiveFlightField(null);
      }
    };
    document.addEventListener('mousedown', handleMouseDown);
    return () => document.removeEventListener('mousedown', handleMouseDown);
  }, [isFocused, openFlightDropdown, flightChipPopover, nlpChipPopover]);

  // Re-anchor fixed popovers when the page scrolls
  useEffect(() => {
    const handleScroll = () => {
      if (flightChipPopover) {
        const btn = flightChipBtnRefs.current[flightChipPopover.chipId];
        if (btn) {
          const rect = btn.getBoundingClientRect();
          const minWidth = (flightChipPopover.chipId === 'origin' || flightChipPopover.chipId === 'destination') ? 340 : flightChipPopover.chipId === 'dates' ? 700 : 260;
          const popWidth = Math.max(rect.width, minWidth);
          const rawLeft = flightChipPopover.chipId === 'dates' ? rect.left - Math.max(0, rect.left + popWidth - (window.innerWidth - 16)) : rect.left;
          setFlightChipPopover({ chipId: flightChipPopover.chipId, pos: { top: rect.bottom + 8, left: Math.max(8, rawLeft), width: popWidth } });
        }
      }
    };
    window.addEventListener('scroll', handleScroll, { passive: true, capture: true });
    return () => window.removeEventListener('scroll', handleScroll, { capture: true });
  }, [flightChipPopover]);

  const displayTokens = useMemo((): DisplayToken[] => {
    const committed: DisplayToken[] = segments.map(s => ({ ...s }));
    const tentative: DisplayToken[] = parseTokens(liveText).map((t, i) =>
      t.type === 'chip'
        ? { id: `tentative-${t.entityType}-${t.value}`, type: 'chip', value: t.value, entityType: t.entityType }
        : { id: `live-${i}`, type: 'text', value: t.value }
    );
    return [...committed, ...tentative];
  }, [segments, liveText]);


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

    // Chips already passed (text continues after them)
    const committableChips = liveParsed.filter(
      (t): t is Extract<Token, { type: 'chip' }> =>
        t.type === 'chip' && t.end < newText.length
    );

    // Chip sitting exactly at the end of input — auto-commit + auto-space
    const terminalChip = liveParsed.find(
      (t): t is Extract<Token, { type: 'chip' }> =>
        t.type === 'chip' && t.end === newText.length
    ) ?? null;

    const commitUpTo = (
      tokens: typeof liveParsed,
      upToIdx: number,
      remaining: string,
    ) => {
      const newSegs: Segment[] = [...segments];
      for (let i = 0; i <= upToIdx; i++) {
        const token = tokens[i];
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
      setSegments(newSegs);
      setLiveText(remaining);
    };

    if (committableChips.length > 0) {
      const lastChip = committableChips[committableChips.length - 1];
      commitUpTo(liveParsed, liveParsed.indexOf(lastChip), newText.slice(lastChip.end));
    } else if (terminalChip) {
      // Auto-commit: chip fully typed → lock it in, leave cursor with a space
      commitUpTo(liveParsed, liveParsed.indexOf(terminalChip), ' ');
    } else {
      setLiveText(newText);
    }
  }, [segments]);

  const handleSubmit = useCallback(() => {
    const committed = segments.map(s => s.value).join(' ');
    const full = (committed + ' ' + liveText).trim();
    if (full) submitQuery(full);
    // else: do nothing (no composer)
  }, [segments, liveText, submitQuery]);

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
    // Backspace on empty liveText → delete last committed segment
    if (e.key === 'Backspace' && liveText === '' && segments.length > 0) {
      e.preventDefault();
      const last = segments[segments.length - 1];
      setSegments(prev => prev.slice(0, -1));
      // Restore the deleted segment's text back into the live input
      if (last.type === 'text') setLiveText(last.value);
    }
    // Cmd/Ctrl+A → select all (clear chips, put all text back into input)
    if ((e.metaKey || e.ctrlKey) && e.key === 'a') {
      e.preventDefault();
      const allText = [...segments.map(s => s.value), liveText].filter(Boolean).join(' ');
      setSegments([]);
      setLiveText(allText);
      setTimeout(() => {
        if (inputRef.current) inputRef.current.select();
      }, 0);
    }
  }, [handleSubmit, selectedChipId, liveText, segments]);

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
      background: '#ffffff',
      overflowY: 'auto',
      overflowX: 'auto',
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
            opacity: { duration: 0.5, ease: ease.inOut },
            y: { duration: 0.5, ease: ease.inOut },
          }}
          style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 20,
            background: T.cardBg,
            padding: '56px 24px',
            borderRadius: 24,
            boxShadow: 'none',
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
          <div style={{ display: 'flex', alignItems: 'center', gap: 0, overflowX: 'auto', scrollbarWidth: 'none', WebkitOverflowScrolling: 'touch' as never, paddingBlock: 8, marginBlock: -8 }}>
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
                        background: glass.pill.background,
                        backdropFilter: glass.pill.backdropFilter,
                        WebkitBackdropFilter: glass.pill.WebkitBackdropFilter,
                        border: glass.pill.border,
                        boxShadow: glass.pill.boxShadow,
                        zIndex: -1,
                      }}
                      initial={{ opacity: 0, scale: 0.78 }}
                      animate={{ opacity: 1, scale: 1 }}
                      exit={{ opacity: 0, scale: 0.84 }}
                      transition={spring.snap}
                    />
                  )}
                  <img src={tab.img} alt={tab.label} style={{ width: 22, height: 22, objectFit: 'cover', position: 'relative', zIndex: 1 }} />
                  <motion.span
                    animate={{ scale: isActive ? 1.02 : 1 }}
                    transition={spring.snap}
                    style={{ position: 'relative', zIndex: 1, fontWeight: isActive ? 600 : 500 }}
                  >{tab.label}</motion.span>
                </motion.button>
              );
            })}
          </div>

          {/* NLP input card wrapper — provides positioning context for the gradient ring */}
          <motion.div
            layout
          animate={{ maxWidth: (isFocused || (selectedLob !== '' && selectedLob !== 'Stays')) ? 960 : 680 }}
          transition={spring.std}
            style={{ position: 'relative', width: '100%' }}
          >

          {/* Gemini-style rotating gradient border — sibling to card so it's never clipped */}
          {isFocused && <div key="gemini-ring" className="gemini-ring" />}

          {/* NLP input card — morphs between idle and typing states */}
          <motion.div
            ref={cardRef}
            layout
            className={lobFlash ? 'lob-flash' : undefined}
            onClick={() => { if (selectedLob === '') { setIsFocused(true); setTimeout(() => inputRef.current?.focus(), 0); } }}
            whileTap={(isFocused || selectedLob !== '') ? {} : { scale: 0.985 }}
            animate={{
              borderRadius: (isFocused || selectedLob !== '') ? 28 : 44,
              background: (isFocused || selectedLob !== '') ? 'rgba(255,255,255,0.92)' : glass.card.background,
              boxShadow: (isFocused || selectedLob !== '')
                ? '0 4px 40px rgba(12,14,28,0.10), 0 1px 6px rgba(12,14,28,0.06), inset 0 1px 0 rgba(255,255,255,0.95)'
                : '0 2.5px 25px rgba(0,0,0,0.08)',
              borderColor: (isFocused || selectedLob !== '') ? 'rgba(255,255,255,0.5)' : 'rgba(255,255,255,0)',
            }}
            transition={spring.std}
            style={{
              position: 'relative',
              width: '100%',
              backdropFilter: glass.card.backdropFilter,
              WebkitBackdropFilter: glass.card.WebkitBackdropFilter,
              border: '1px solid transparent',
              overflow: (isFocused || selectedLob !== '') ? 'hidden' : 'hidden',
              cursor: (isFocused || selectedLob !== '') ? 'default' : 'pointer',
              display: 'flex',
              flexDirection: 'column',
              gap: 0,
            }}
          >
            {/* AI scan-line shimmer — covers full card while typing */}
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
                    borderRadius: 'inherit',
                  }}
                >
                  <motion.div
                    animate={{ left: ['-40%', '120%'] }}
                    transition={{ duration: 2.2, ease: 'linear', repeat: Infinity, repeatDelay: 1.4 }}
                    style={{
                      position: 'absolute',
                      top: 0, bottom: 0,
                      width: '45%',
                      background: 'linear-gradient(90deg, transparent, rgba(99,102,241,0.055), rgba(99,102,241,0.03), transparent)',
                    }}
                  />
                </motion.div>
              )}
            </AnimatePresence>

            {/* ─ Inner content — animated per LOB ─ */}
            <AnimatePresence mode="popLayout" initial={false}>
                <motion.div
                key={selectedLob === '' ? '__nlp__' : selectedLob}
                initial={{ opacity: 0, y: 12, scale: 0.97 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                exit={{ opacity: 0, y: -6, scale: 0.99, transition: { duration: 0.08, ease: 'easeIn' } }}
                transition={spring.std}
                style={{ width: '100%', display: 'flex', flexDirection: 'column' }}
              >
                {selectedLob === '' ? (
                  <>
                    {/* ── Top zone ── */}
                    <motion.div
                      animate={{
                        paddingTop: isFocused ? 20 : 8,
                        paddingLeft: isFocused ? 20 : 24,
                        paddingRight: isFocused ? 20 : 12,
                        paddingBottom: isFocused ? 24 : 8,
                      }}
                      transition={spring.std}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        position: 'relative',
                        width: '100%',
                        boxSizing: 'border-box',
                        gap: 8,
                      }}
                    >

                      {/* Magnifying glass icon — idle state only */}
                      <AnimatePresence>
                        {!isFocused && (
                          <motion.div
                            key="search-icon"
                            initial={{ opacity: 0 }}
                            animate={{ opacity: 1 }}
                            exit={{ opacity: 0 }}
                            transition={{ duration: 0.1 }}
                            style={{ flexShrink: 0, display: 'flex', alignItems: 'center', marginRight: 4 }}
                          >
                            <IconSearch />
                          </motion.div>
                        )}
                      </AnimatePresence>

                      {/* Input or ghost text — takes remaining space */}
                      <div style={{ flex: 1, minWidth: 0, position: 'relative', height: 24 }}>
                        <AnimatePresence mode="wait" initial={false}>
                          {voiceListening && voiceTarget === 'nlp' ? (
                            /* ── Inline voice visualization ── */
                            <motion.div
                              key="voice-vis"
                              initial={{ opacity: 0, filter: 'blur(4px)' }}
                              animate={{ opacity: 1, filter: 'blur(0px)' }}
                              exit={{ opacity: 0, filter: 'blur(4px)', transition: { duration: 0.12 } }}
                              transition={{ type: 'spring', stiffness: 400, damping: 30 }}
                              style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', gap: 10 }}
                            >
                              {/* Pulse dot */}
                              <div style={{
                                width: 8, height: 8, borderRadius: 100,
                                background: 'rgba(99,102,241,0.7)',
                                animation: 'voicePulse 1.2s ease-in-out infinite',
                                flexShrink: 0,
                              }} />
                              {/* Listening text / transcript */}
                              <AnimatePresence mode="wait">
                                <motion.span
                                  key={voiceTranscript ? 'transcript' : 'listening'}
                                  initial={{ opacity: 0 }}
                                  animate={{ opacity: 1 }}
                                  exit={{ opacity: 0 }}
                                  transition={{ duration: 0.15 }}
                                  style={{
                                    fontSize: 16,
                                    fontWeight: 400,
                                    fontFamily: "'Centra No2', -apple-system, sans-serif",
                                    color: voiceTranscript ? '#191E3B' : 'rgba(12,14,28,0.4)',
                                    flex: 1,
                                    minWidth: 0,
                                    overflow: 'hidden',
                                    textOverflow: 'ellipsis',
                                    whiteSpace: 'nowrap',
                                  }}
                                >
                                  {voiceTranscript || 'Listening\u2026'}
                                </motion.span>
                              </AnimatePresence>
                              {/* Waveform bars */}
                              <div style={{ display: 'flex', alignItems: 'center', gap: 2, flexShrink: 0 }}>
                                {Array.from({ length: 9 }).map((_, i) => (
                                  <div key={i} style={{
                                    width: 3, height: 20, borderRadius: 99,
                                    background: voiceReceiving ? 'rgba(99,102,241,0.7)' : 'rgba(99,102,241,0.4)',
                                    transformOrigin: 'center',
                                    animation: `voiceBar ${0.8 + (i % 4) * 0.1}s ease-in-out infinite`,
                                    animationDelay: `${(i / 8) * 0.5}s`,
                                  }} />
                                ))}
                              </div>
                            </motion.div>
                          ) : isFocused ? (
                            <motion.div
                              key="input-zone"
                              initial={{ opacity: 1 }}
                              animate={{ opacity: 1 }}
                              exit={{ opacity: 0 }}
                              transition={{ duration: 0.08, ease: ease.inOut }}
                              style={{ position: 'absolute', inset: 0, width: '100%' }}
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
                                  color: 'transparent',
                                  caretColor: 'transparent',
                                  cursor: 'text',
                                  zIndex: 2,
                                  fontSize: 16,
                                  fontWeight: 400,
                                  fontFamily: "'Centra No2', -apple-system, sans-serif",
                                  padding: 0,
                                  margin: 0,
                                }}
                              />
                              {/* Visual overlay — token chips + text */}
                              <div
                                style={{
                                  pointerEvents: 'none',
                                  position: 'absolute',
                                  inset: 0,
                                  zIndex: 1,
                                  width: '100%',
                                  display: 'flex',
                                  flexWrap: 'wrap',
                                  alignItems: 'center',
                                  gap: 6,
                                  overflow: 'visible',
                                  fontFamily: "'Centra No2', -apple-system, sans-serif",
                                  fontSize: 16,
                                  fontWeight: 400,
                                  lineHeight: '20px',
                                }}
                              >
                                <AnimatePresence mode="popLayout">
                                  {displayTokens.length > 0 && displayTokens.map(token =>
                                      token.type === 'chip' ? (
                                        <motion.span
                                          key={`chip-${token.id}`}
                                          data-chip-id={token.id}
                                          initial={{ opacity: 0, scale: 0.75, y: 4}}
                                          animate={{
                                            opacity: 1,
                                            scale: 1,
                                            y: 0,
                                            filter: 'blur(0px)',
                                            background: selectedChipId === token.id
                                              ? 'rgba(255,255,255,0.94)'
                                              : glass.pill.background,
                                            boxShadow: selectedChipId === token.id
                                              ? '0 0 0 2px rgba(99,102,241,0.25), 0 2px 10px rgba(12,14,28,0.08)'
                                              : glass.pill.boxShadow,
                                          }}
                                          exit={{ opacity: 0, scale: 0.88}}
                                          transition={spring.snap}
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
                                            backdropFilter: glass.pill.backdropFilter,
                                            WebkitBackdropFilter: glass.pill.WebkitBackdropFilter,
                                            border: '1px solid rgba(255,255,255,0.6)',
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
                                  }
                                  <motion.span key="cursor" style={{ color: '#191E3B' }}>
                                    <BlinkingCursor />
                                  </motion.span>
                                </AnimatePresence>
                              </div>
                            </motion.div>
                          ) : (
                            <AnimatePresence mode="wait" initial={false}>
                              <motion.p
                                key={ghostIndex}
                                initial={{ opacity: 0, y: 8}}
                                animate={{ opacity: 1, y: 0}}
                                exit={{ opacity: 0, y: -6, filter: 'blur(3px)', transition: { duration: 0.18 } }}
                                transition={{ duration: 0.28, ease: ease.out }}
                                style={{
                                  position: 'absolute',
                                  inset: 0,
                                  display: 'flex',
                                  alignItems: 'center',
                                  fontFamily: "'Centra No2', -apple-system, sans-serif",
                                  fontSize: 16,
                                  fontWeight: 400,
                                  color: T.textVariant,
                                  margin: 0,
                                  lineHeight: 1,
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

                      {/* Voice + submit — idle state only */}
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
                            {/* Mic button → × cancel during voice */}
                            <motion.button
                              onClick={e => {
                                e.stopPropagation();
                                if (voiceListening && voiceTarget === 'nlp') stopVoice(false);
                                else startVoice('nlp');
                              }}
                              whileHover={{ scale: 1.08 }}
                              whileTap={{ scale: 0.92 }}
                              style={{
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                cursor: 'pointer',
                                flexShrink: 0,
                                background: voiceListening && voiceTarget === 'nlp' ? 'rgba(12,14,28,0.07)' : 'transparent',
                                border: 'none',
                                width: 36,
                                height: 36,
                                borderRadius: 100,
                                fontSize: 18,
                                color: '#191E3B',
                              }}
                            >
                              <AnimatePresence mode="wait">
                                {voiceListening && voiceTarget === 'nlp' ? (
                                  <motion.span
                                    key="cancel"
                                    initial={{ opacity: 0, scale: 0.7 }}
                                    animate={{ opacity: 1, scale: 1 }}
                                    exit={{ opacity: 0, scale: 0.7 }}
                                    transition={{ type: 'spring', stiffness: 400, damping: 30 }}
                                  >×</motion.span>
                                ) : (
                                  <motion.img
                                    key="mic"
                                    src={ASSET_VOICE}
                                    alt="voice"
                                    initial={{ opacity: 0, scale: 0.7 }}
                                    animate={{ opacity: 1, scale: 1 }}
                                    exit={{ opacity: 0, scale: 0.7 }}
                                    transition={{ type: 'spring', stiffness: 400, damping: 30 }}
                                    style={{ width: 15, height: 16.5, objectFit: 'contain' }}
                                  />
                                )}
                              </AnimatePresence>
                            </motion.button>
                            {/* Submit button → ✓ confirm during voice */}
                            <motion.button
                              onClick={e => {
                                e.stopPropagation();
                                if (voiceListening && voiceTarget === 'nlp') stopVoice(true);
                                else handleSubmit();
                              }}
                              animate={{
                                opacity: (voiceListening && voiceTarget === 'nlp') ? 1 : hasText ? 1 : 0.4,
                                scale: (voiceListening && voiceTarget === 'nlp') ? 1 : hasText ? 1 : 0.95,
                                background: T.submitBg,
                              }}
                              transition={spring.snap}
                              whileHover={{ scale: 1.08 }}
                              whileTap={{ scale: 0.92 }}
                              style={{
                                width: 48,
                                height: 48,
                                borderRadius: 100,
                                border: 'none',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                cursor: 'pointer',
                                flexShrink: 0,
                              }}
                            >
                              <AnimatePresence mode="wait">
                                {voiceListening && voiceTarget === 'nlp' ? (
                                  <motion.span
                                    key="confirm"
                                    initial={{ opacity: 0, scale: 0.7 }}
                                    animate={{ opacity: 1, scale: 1 }}
                                    exit={{ opacity: 0, scale: 0.7 }}
                                    transition={{ type: 'spring', stiffness: 400, damping: 30 }}
                                    style={{ fontSize: 18, color: '#0C0E1C' }}
                                  >✓</motion.span>
                                ) : (
                                  <motion.div
                                    key="arrow"
                                    initial={{ opacity: 0, scale: 0.7 }}
                                    animate={{ opacity: 1, scale: 1 }}
                                    exit={{ opacity: 0, scale: 0.7 }}
                                    transition={{ type: 'spring', stiffness: 400, damping: 30 }}
                                    style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                                  >
                                    <IconArrow color='#0C0E1C' />
                                  </motion.div>
                                )}
                              </AnimatePresence>
                            </motion.button>
                          </motion.div>
                        )}
                      </AnimatePresence>
                    </motion.div>

                    {/* ── Chips + actions row ── */}
                    {isFocused && (
                      <div
                        style={{
                          paddingTop: 16,
                          paddingLeft: 20,
                          paddingRight: 20,
                          paddingBottom: 16,
                          display: 'flex',
                          alignItems: 'center',
                          gap: 16,
                          alignSelf: 'stretch',
                        }}
                      >
                        <div
                          ref={nlpChipsScrollRef}
                          style={{ display: 'flex', flex: 1, gap: 8, alignItems: 'center', justifyContent: 'flex-start', overflowX: 'auto', scrollbarWidth: 'none', WebkitOverflowScrolling: 'touch' as never, minWidth: 0, paddingBlock: 16, marginBlock: -16, paddingRight: 12, WebkitMaskImage: 'linear-gradient(to right, black calc(100% - 48px), transparent 100%)', maskImage: 'linear-gradient(to right, black calc(100% - 48px), transparent 100%)' }}>
                          <motion.button
                            onClick={e => { e.stopPropagation(); inputRef.current?.focus(); }}
                            initial={{ opacity: 0, scale: 0.88, x: 6 }}
                            animate={{ opacity: 1, scale: 1, x: 0 }}
                            transition={spring.snap}
                            whileHover={{ scale: 1.04, boxShadow: '0 4px 16px rgba(12,14,28,0.10)' }}
                            whileTap={{ scale: 0.95 }}
                            style={{
                              width: 48,
                              height: 48,
                              borderRadius: 100,
                              background: 'rgba(12,14,28,0.07)',
                              backdropFilter: 'none',
                              WebkitBackdropFilter: 'none',
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
                                ref={(el) => { nlpChipBtnRefs.current[chip.id] = el as HTMLButtonElement | null; }}
                                initial={{ opacity: 0, scale: 0.88, x: 6 }}
                                animate={{ opacity: 1, scale: 1, x: 0 }}
                                exit={{ opacity: 0, scale: 0.82}}
                                transition={{ ...spring.snap, delay: i * 0.025 }}
                                whileHover={{ scale: 1.04, boxShadow: '0 4px 16px rgba(12,14,28,0.10)' }}
                                whileTap={{ scale: 0.95 }}
                                onClick={e => {
                                  e.stopPropagation();
                                  if (chip.id === 'destination') {
                                    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
                                    const popWidth = 480;
                                    const rawLeft = rect.left - Math.max(0, rect.left + popWidth - (window.innerWidth - 16));
                                    setDestPopoverAnchor({ top: rect.bottom + 8, left: Math.max(8, rawLeft), width: popWidth });
                                    setTimeout(() => destSearchRef.current?.focus(), 80);
                                  } else if (chip.id === 'dates' || chip.id === 'travelers') {
                                    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
                                    const minWidth = chip.id === 'dates' ? 700 : 320;
                                    const popWidth = Math.max(rect.width, minWidth);
                                    const rawLeft = chip.id === 'dates'
                                      ? rect.left - Math.max(0, rect.left + popWidth - (window.innerWidth - 16))
                                      : rect.left;
                                    setNlpChipPopover({ chipId: chip.id, pos: { top: rect.bottom + 8, left: Math.max(8, rawLeft), width: popWidth } });
                                  } else {
                                    inputRef.current?.focus();
                                  }
                                }}
                                style={chipBtnStyle}
                              >
                                <ContextChipIcon icon={chip.icon} />
                                <span style={chipLabelStyle}>{chip.label}</span>
                              </motion.button>
                            ))}
                          </AnimatePresence>
                        </div>

                        <motion.button
                          onClick={e => {
                            e.stopPropagation();
                            if (voiceListening && voiceTarget === 'nlp') stopVoice(false);
                            else startVoice('nlp');
                          }}
                          initial={{ opacity: 1, scale: 0.88 }}
                          animate={{ opacity: 1, x: 0, scale: 1 }}
                          transition={spring.snap}
                          whileHover={{ scale: 1.08, background: 'rgba(12,14,28,0.10)' }}
                          whileTap={{ scale: 0.93 }}
                          style={{
                            width: 48, height: 48, borderRadius: 40000,
                            background: T.voiceBg, border: 'none',
                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                            cursor: 'pointer', flexShrink: 0,
                          }}
                        >
                          <AnimatePresence mode="wait">
                            {voiceListening && voiceTarget === 'nlp' ? (
                              <motion.span key="x" initial={{ opacity: 0, scale: 0.7 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.7 }} transition={{ type: 'spring', stiffness: 400, damping: 30 }} style={{ fontSize: 18, color: '#191E3B', lineHeight: 1 }}>×</motion.span>
                            ) : (
                              <motion.img key="mic" src={ASSET_VOICE} alt="voice" initial={{ opacity: 0, scale: 0.7 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.7 }} transition={{ type: 'spring', stiffness: 400, damping: 30 }} style={{ width: 15, height: 16.5, objectFit: 'contain' }} />
                            )}
                          </AnimatePresence>
                        </motion.button>

                        <motion.button
                          onClick={e => {
                            e.stopPropagation();
                            if (voiceListening && voiceTarget === 'nlp') stopVoice(true);
                            else handleSubmit();
                          }}
                          initial={{ opacity: 1, scale: 0.88 }}
                          animate={{
                            opacity: (voiceListening && voiceTarget === 'nlp') ? 1 : hasText ? 1 : 0.4,
                            x: 0,
                            scale: (voiceListening && voiceTarget === 'nlp') ? 1 : hasText ? 1 : 0.95,
                            background: T.submitBg,
                            boxShadow: hasText ? T.submitShadow : 'none',
                            borderColor: T.submitBorder,
                          }}
                          transition={spring.snap}
                          whileHover={{ scale: 1.08 }}
                          whileTap={{ scale: 0.92 }}
                          style={{
                            width: 48, height: 48, borderRadius: 100,
                            borderWidth: 1, borderStyle: 'solid',
                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                            cursor: 'pointer', flexShrink: 0,
                          }}
                        >
                          <AnimatePresence mode="wait">
                            {voiceListening && voiceTarget === 'nlp' ? (
                              <motion.span key="check" initial={{ opacity: 0, scale: 0.7 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.7 }} transition={{ type: 'spring', stiffness: 400, damping: 30 }} style={{ fontSize: 18, color: '#0C0E1C', lineHeight: 1 }}>✓</motion.span>
                            ) : (
                              <motion.div key="arrow" initial={{ opacity: 0, scale: 0.7 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.7 }} transition={{ type: 'spring', stiffness: 400, damping: 30 }} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}><IconArrow color='#0C0E1C' /></motion.div>
                            )}
                          </AnimatePresence>
                        </motion.button>
                      </div>
                    )}
                  </>
                ) : selectedLob === 'Flights' ? (
                  <>
                    {/* ── Flights structured form ── */}

                    {/* Row 1: Input row — ghost text + input + voice + submit */}
                    <motion.div
                      initial={{ opacity: 0, y: 6 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ type: 'spring', stiffness: 500, damping: 34, delay: 0.0 }}
                      style={{
                        background: 'white',
                        height: 84,
                        padding: 24,
                        display: 'flex',
                        alignItems: 'center',
                        gap: 12,
                      }}
                    >
                      {/* Playback display + leavingFrom input */}
                      {(() => {
                        const fmt = (d: string) => new Date(d + 'T00:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
                        const totalTravelers = travelersAdults + travelersChildren + travelersInfantsSeat + travelersInfantsLap;
                        const hasAnyFill = !!(goingTo || flightDates.depart);
                        let playbackText = '';
                        if (selectedOrigin && goingTo) {
                          playbackText = `From ${selectedOrigin} to ${goingTo}`;
                        } else if (selectedOrigin) {
                          playbackText = `From ${selectedOrigin}`;
                        } else if (goingTo) {
                          playbackText = `To ${goingTo}`;
                        }
                        if (flightDates.depart) {
                          const dateStr = flightDates.return
                            ? `${fmt(flightDates.depart)} – ${fmt(flightDates.return)}`
                            : fmt(flightDates.depart);
                          playbackText += playbackText ? `, during ${dateStr}` : `During ${dateStr}`;
                        }
                        if (totalTravelers > 1 || travelersChildren > 0) {
                          const tStr = `for ${totalTravelers} traveler${totalTravelers !== 1 ? 's' : ''}`;
                          playbackText += playbackText ? `, ${tStr}` : tStr;
                        }
                        return (
                          <div style={{ flex: 1, position: 'relative', minWidth: 0, height: 36, display: 'flex', alignItems: 'center' }}>
                            {/* Ghost text — shown when nothing filled */}
                            <AnimatePresence mode="wait" initial={false}>
                              {!hasAnyFill && leavingFrom === '' && (
                                <motion.span
                                  key={flightGhostIndex}
                                  initial={{ opacity: 0, y: 6 }}
                                  animate={{ opacity: 1, y: 0 }}
                                  exit={{ opacity: 0, y: -5, transition: { duration: 0.18 } }}
                                  transition={{ duration: 0.26, ease: ease.out }}
                                  style={{
                                    position: 'absolute',
                                    inset: 0,
                                    display: 'flex',
                                    alignItems: 'center',
                                    fontFamily: "'Centra No2', -apple-system, sans-serif",
                                    fontSize: 14,
                                    fontWeight: 400,
                                    color: '#676A7D',
                                    pointerEvents: 'none',
                                    userSelect: 'none',
                                    whiteSpace: 'nowrap',
                                    overflow: 'hidden',
                                  }}
                                >
                                  {FLIGHT_GHOSTS[flightGhostIndex]}
                                </motion.span>
                              )}
                            </AnimatePresence>

                            {/* Playback text — shown as chips are filled */}
                            <AnimatePresence initial={false}>
                              {hasAnyFill && (
                                <motion.span
                                  key={playbackText}
                                  initial={{ opacity: 0, y: 4 }}
                                  animate={{ opacity: 1, y: 0 }}
                                  exit={{ opacity: 0, y: -4 }}
                                  transition={{ duration: 0.2, ease: ease.out }}
                                  style={{
                                    position: 'absolute',
                                    inset: 0,
                                    display: 'flex',
                                    alignItems: 'center',
                                    fontFamily: "'Centra No2', -apple-system, sans-serif",
                                    fontSize: 14,
                                    fontWeight: 500,
                                    color: '#0C0E1C',
                                    pointerEvents: 'none',
                                    userSelect: 'none',
                                    whiteSpace: 'nowrap',
                                    overflow: 'hidden',
                                  }}
                                >
                                  {playbackText}
                                </motion.span>
                              )}
                            </AnimatePresence>

                            {/* Actual input — transparent text, visible caret */}
                            <input
                              value={leavingFrom}
                              onChange={e => setLeavingFrom(e.target.value)}
                              onKeyDown={e => {
                                if (e.key === 'Escape') (e.target as HTMLInputElement).blur();
                                if (e.key === 'Enter') {
                                  applyFlightParse(leavingFrom);
                                  setTimeout(() => {
                                    const parsed = parseFlightInput(leavingFrom);
                                    const nextChip = !parsed.origin ? 'origin'
                                      : !parsed.destination ? 'destination'
                                      : !parsed.departDate ? 'dates'
                                      : !parsed.adults ? 'travelers'
                                      : null;
                                    if (nextChip) {
                                      const btn = flightChipBtnRefs.current[nextChip];
                                      if (btn) {
                                        const r = btn.getBoundingClientRect();
                                        setFlightChipPopover({ chipId: nextChip, pos: { top: r.bottom + 8, left: r.left, width: r.width } });
                                      }
                                    }
                                  }, 50);
                                }
                              }}
                              style={{
                                position: 'absolute', inset: 0,
                                border: 'none', outline: 'none', background: 'transparent',
                                fontSize: 14, fontWeight: 400,
                                color: hasAnyFill ? 'transparent' : '#0C0E1C',
                                caretColor: '#0C0E1C',
                                width: '100%', padding: 0, margin: 0,
                                fontFamily: "'Centra No2', -apple-system, sans-serif",
                              }}
                            />
                          </div>
                        );
                      })()}

                    </motion.div>

                    {/* Row 2: Chip row + CTAs on the left */}
                    <motion.div
                      initial={{ opacity: 0, y: 8 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ type: 'spring', stiffness: 500, damping: 34, delay: 0.04 }}
                      style={{ position: 'relative', background: 'rgba(247,244,243,0.55)' }}
                    >
                      <div style={{
                        display: 'flex',
                        alignItems: 'center',
                        padding: 16,
                        gap: 0,
                      }}>
                        {/* Scrollable chips — flex 1, with right gradient peek */}
                        <div style={{ flex: 1, minWidth: 0, position: 'relative' }}>
                        <div style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: 8,
                          overflowX: 'auto',
                          scrollbarWidth: 'none',
                          msOverflowStyle: 'none',
                          flexWrap: 'nowrap',
                          paddingTop: 8,
                          paddingBottom: 8,
                          marginTop: -8,
                          marginBottom: -8,
                          paddingRight: 40,
                        }}>
                        {/* Roundtrip chip — frosted glass */}
                        <div style={{ position: 'relative', flexShrink: 0 }}>
                          <motion.button
                            ref={tripBtnRef}
                            whileHover={{ scale: 1.02 }}
                            whileTap={{ scale: 0.97 }}
                            onClick={e => {
                              e.stopPropagation();
                              if (openFlightDropdown === 'trip') { setOpenFlightDropdown(null); return; }
                              const rect = tripBtnRef.current?.getBoundingClientRect();
                              if (rect) setFlightDropdownPos({ top: rect.bottom + 6, left: rect.left, width: Math.max(rect.width, 180) });
                              setOpenFlightDropdown('trip');
                            }}
                            style={{
                              display: 'flex', alignItems: 'center', gap: 6,
                              height: 48, padding: 16, borderRadius: 999,
                              ...(flightTrip !== DEFAULT_TRIP ? {
                                background: 'linear-gradient(180deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.8) 96%), linear-gradient(90deg, rgba(247,244,243,0.25) 0%, rgba(247,244,243,0.25) 100%)',
                                backdropFilter: 'blur(15px)',
                                WebkitBackdropFilter: 'blur(15px)',
                                border: '1px solid white',
                                boxShadow: '0px 12px 32px rgba(12,14,28,0.08)',
                              } : {
                                background: 'rgba(103,106,125,0.08)',
                                backdropFilter: 'none',
                                WebkitBackdropFilter: 'none',
                                border: 'none',
                                boxShadow: 'none',
                              }),
                              fontSize: 14, fontWeight: 500, color: flightTrip !== DEFAULT_TRIP ? '#0c0e1c' : 'rgba(25,30,59,0.75)', cursor: 'pointer',
                              fontFamily: "'Centra No2', -apple-system, sans-serif",
                              whiteSpace: 'nowrap',
                            }}
                          >
                            {flightTrip === 'One-way' ? <IconOneWay /> : flightTrip === 'Multi-city' ? <IconMultiCity /> : <IconRouteTrip />}
                            {flightTrip}
                            <IconChevronDown />
                          </motion.button>
                        </div>

                        {/* Origin, Destination, Dates, Travelers chips */}
                        {([
                          { id: 'origin',      label: 'Where from',  Icon: IconPlane    },
                          { id: 'destination', label: 'Where to',    Icon: IconPin      },
                          { id: 'dates',       label: 'When',        Icon: IconCalendar },
                          { id: 'travelers',   label: 'Who',         Icon: IconPeople   },
                        ]).map((chip) => {
                          const isActiveChip = activeFlightField === chip.id;
                          const isFilled = chip.id === 'origin' ? (!!selectedOrigin && selectedOrigin !== DEFAULT_ORIGIN)
                            : chip.id === 'destination' ? !!goingTo
                            : chip.id === 'dates' ? !!flightDates.depart
                            : (travelersAdults > 1 || travelersChildren > 0 || travelersInfantsSeat > 0 || travelersInfantsLap > 0);
                          const useFrosted = isFilled;
                          return (
                            <motion.button
                              key={chip.id}
                              ref={el => { flightChipBtnRefs.current[chip.id] = el; }}
                              whileHover={{ scale: 1.04 }}
                              whileTap={{ scale: 0.95 }}
                              onClick={e => {
                                e.stopPropagation();
                                setActiveFlightField(chip.id);
                                const btn = flightChipBtnRefs.current[chip.id];
                                if (btn) {
                                  const rect = btn.getBoundingClientRect();
                                  const minWidth = (chip.id === 'origin' || chip.id === 'destination') ? 340 : chip.id === 'dates' ? 700 : 260;
                                  const popWidth = Math.max(rect.width, minWidth);
                                  const rawLeft = chip.id === 'dates' ? rect.left - Math.max(0, rect.left + popWidth - (window.innerWidth - 16)) : rect.left;
                                  setFlightChipPopover({ chipId: chip.id, pos: { top: rect.bottom + 8, left: Math.max(8, rawLeft), width: popWidth } });
                                }
                              }}
                              style={{
                                display: 'flex', alignItems: 'center', gap: 8,
                                height: 48, padding: 16, borderRadius: 999,
                                flexShrink: 0,
                                ...(useFrosted ? {
                                  background: 'linear-gradient(180deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.8) 96%), linear-gradient(90deg, rgba(247,244,243,0.25) 0%, rgba(247,244,243,0.25) 100%)',
                                  backdropFilter: 'blur(15px)',
                                  WebkitBackdropFilter: 'blur(15px)',
                                  border: '1px solid white',
                                  boxShadow: '0px 12px 32px rgba(12,14,28,0.08)',
                                } : {
                                  background: 'rgba(103,106,125,0.08)',
                                  backdropFilter: 'none',
                                  WebkitBackdropFilter: 'none',
                                  border: 'none',
                                  boxShadow: 'none',
                                }),
                                cursor: 'pointer',
                                fontFamily: "'Centra No2', -apple-system, sans-serif",
                              }}
                            >
                              {isFilled ? <IconCheck /> : <chip.Icon />}
                              <span style={{
                                fontFamily: "'Centra No2', -apple-system, sans-serif",
                                fontSize: 14, fontWeight: 500, lineHeight: '18px',
                                color: useFrosted ? '#0c0e1c' : 'rgba(25,30,59,0.75)',
                                whiteSpace: 'nowrap',
                              }}>{chip.label}</span>
                            </motion.button>
                          );
                        })}

                        {/* Economy chip — grey with seat icon */}
                        <div style={{ position: 'relative', flexShrink: 0 }}>
                          <motion.button
                            ref={classBtnRef}
                            whileHover={{ scale: 1.02 }}
                            whileTap={{ scale: 0.97 }}
                            onClick={e => {
                              e.stopPropagation();
                              if (openFlightDropdown === 'class') { setOpenFlightDropdown(null); return; }
                              const rect = classBtnRef.current?.getBoundingClientRect();
                              if (rect) setFlightDropdownPos({ top: rect.bottom + 6, left: rect.left, width: Math.max(rect.width, 210) });
                              setOpenFlightDropdown('class');
                            }}
                            style={{
                              display: 'flex', alignItems: 'center', gap: 6,
                              height: 48, padding: 16, borderRadius: 100,
                              background: 'rgba(103,106,125,0.08)',
                              border: 'none',
                              fontSize: 14, fontWeight: 500, color: 'rgba(25,30,59,0.75)', cursor: 'pointer',
                              fontFamily: "'Centra No2', -apple-system, sans-serif",
                              whiteSpace: 'nowrap',
                            }}
                          >
                            <IconSeat />
                            {flightClass}
                          </motion.button>
                        </div>
                        </div>
                        {/* Gradient fade — peek indicator */}
                        <div style={{
                          position: 'absolute', top: 0, right: 0, bottom: 0, width: 56,
                          background: 'linear-gradient(to right, transparent, rgba(247,244,243,0.98))',
                          pointerEvents: 'none',
                        }} />
                        </div>

                        {/* Voice button */}
                        <motion.button
                          onClick={e => {
                            e.stopPropagation();
                            if (voiceListening && voiceTarget === 'flights') stopVoice(false);
                            else startVoice('flights');
                          }}
                          whileHover={{ scale: 1.08 }}
                          whileTap={{ scale: 0.93 }}
                          style={{
                            width: 48, height: 48, borderRadius: 40000,
                            background: '#e9ebef', border: 'none',
                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                            cursor: 'pointer', flexShrink: 0,
                          }}
                        >
                          <AnimatePresence mode="wait">
                            {voiceListening && voiceTarget === 'flights' ? (
                              <motion.span key="cancel-f" initial={{ opacity: 0, scale: 0.7 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.7 }} transition={{ type: 'spring', stiffness: 400, damping: 30 }}>×</motion.span>
                            ) : (
                              <motion.img key="mic-f" src={ASSET_VOICE} alt="voice" initial={{ opacity: 0, scale: 0.7 }} animate={{ opacity: 1, scale: 1 }} exit={{ opacity: 0, scale: 0.7 }} transition={{ type: 'spring', stiffness: 400, damping: 30 }} style={{ width: 15, height: 16.5, objectFit: 'contain' }} />
                            )}
                          </AnimatePresence>
                        </motion.button>

                        {/* Submit button */}
                        {(() => {
                          const flightsReady = !!(selectedOrigin && goingTo && flightDates.depart);
                          const isDisabled = activeFlightField || !flightsReady;
                          return (
                            <motion.button
                              onClick={e => {
                                e.stopPropagation();
                                if (voiceListening && voiceTarget === 'flights') stopVoice(true);
                                else if (flightsReady) handleSubmit();
                              }}
                              animate={{ background: flightsReady ? T.submitBg : 'rgba(253,219,50,0.35)', boxShadow: 'none', borderColor: 'transparent' }}
                              transition={spring.snap}
                              whileHover={flightsReady && !activeFlightField ? { scale: 1.08 } : {}}
                              whileTap={flightsReady && !activeFlightField ? { scale: 0.92 } : {}}
                              style={{
                                width: 48, height: 48, borderRadius: 100,
                                borderWidth: 1, borderStyle: 'solid',
                                display: 'flex', alignItems: 'center', justifyContent: 'center',
                                cursor: isDisabled ? 'default' : 'pointer', flexShrink: 0,
                                marginLeft: 8,
                                opacity: activeFlightField ? 0.5 : 1,
                                transition: 'opacity 0.2s ease',
                                pointerEvents: activeFlightField ? 'none' : 'all',
                              }}
                            >
                              <IconArrow color='#0C0E1C' />
                            </motion.button>
                          );
                        })()}
                      </div>
                    </motion.div>

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

          {/* Destination popover — portal so it escapes card overflow:hidden */}
          {ReactDOM.createPortal(
            <AnimatePresence>
              {destPopoverAnchor && (
                <motion.div
                  key="dest-popover"
                  data-dest-popover="true"
                  initial={{ opacity: 0, y: -8, scale: 0.96 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: -6, scale: 0.97, transition: { duration: 0.12 } }}
                  transition={spring.snap}
                  style={{
                    position: 'fixed',
                    top: destPopoverAnchor.top,
                    left: destPopoverAnchor.left,
                    width: 480,
                    borderRadius: 24,
                    padding: 0,
                    background: 'rgba(255,255,255,0.96)',
                    backdropFilter: 'blur(24px) saturate(1.8)',
                    WebkitBackdropFilter: 'blur(24px) saturate(1.8)',
                    boxShadow: '0 24px 64px rgba(12,14,28,0.14), 0 4px 16px rgba(12,14,28,0.08), 0 1px 0 rgba(255,255,255,0.8) inset',
                    border: '1px solid rgba(255,255,255,0.8)',
                    overflow: 'hidden',
                    zIndex: 9998,
                  }}
                >
                  {/* Header */}
                  <div style={{ padding: '16px 20px 12px' }}>
                    {/* AI label */}
                    <div style={{ marginBottom: 10 }}>
                      <span style={{
                        display: 'inline-flex', alignItems: 'center', gap: 4,
                        fontSize: 11, fontWeight: 600,
                        color: 'rgba(99,102,241,0.85)',
                        background: 'rgba(99,102,241,0.08)',
                        borderRadius: 999, padding: '3px 10px',
                        fontFamily: "'Centra No2', -apple-system, sans-serif",
                        letterSpacing: '0.01em',
                      }}>
                        ✦ Suggested for you
                      </span>
                    </div>
                    {/* Search input */}
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, background: 'rgba(12,14,28,0.05)', borderRadius: 14, padding: '8px 12px' }}>
                      <IconSearch />
                      <input
                        ref={destSearchRef}
                        value={destSearch}
                        onChange={e => setDestSearch(e.target.value)}
                        placeholder="Search destinations"
                        style={{ border: 'none', outline: 'none', background: 'transparent', fontSize: 14, color: '#191E3B', width: '100%', fontFamily: "'Centra No2', -apple-system, sans-serif" }}
                      />
                    </div>
                  </div>

                  {/* Destination rows */}
                  <div>
                    {(() => {
                      const filtered = DESTINATIONS.filter(d =>
                        d.label.toLowerCase().includes(destSearch.toLowerCase())
                      ).slice(0, 8);
                      if (filtered.length === 0) {
                        return (
                          <div style={{ padding: '16px 20px', textAlign: 'center', fontSize: 14, color: 'rgba(12,14,28,0.4)', fontFamily: "'Centra No2', -apple-system, sans-serif" }}>
                            No destinations found
                          </div>
                        );
                      }
                      return filtered.map((dest, idx) => (
                        <React.Fragment key={dest.label}>
                          <button
                            onMouseDown={e => {
                              e.preventDefault();
                              setLiveText(prev => prev ? `${prev} ${dest.label}` : dest.label);
                              setDestSearch('');
                              setDestPopoverAnchor(null);
                            }}
                            style={{
                              display: 'flex', alignItems: 'center', gap: 12,
                              width: '100%', padding: '12px 20px',
                              border: 'none', background: 'transparent', cursor: 'pointer', textAlign: 'left',
                              fontFamily: "'Centra No2', -apple-system, sans-serif",
                            }}
                            onMouseEnter={e => (e.currentTarget.style.background = 'rgba(99,102,241,0.04)')}
                            onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                          >
                            <img src={dest.img} alt={dest.label} style={{ width: 48, height: 48, borderRadius: 12, objectFit: 'cover', flexShrink: 0 }} />
                            <div style={{ flex: 1, minWidth: 0 }}>
                              <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 3 }}>
                                <span style={{ fontSize: 15, fontWeight: 600, color: '#0C0E1C', lineHeight: 1.2 }}>{dest.label}</span>
                                {TRENDING_DESTS.has(dest.label) && (
                                  <span style={{
                                    fontSize: 10, fontWeight: 600,
                                    background: 'rgba(234,88,12,0.1)',
                                    color: 'rgb(234,88,12)',
                                    borderRadius: 999, padding: '2px 7px',
                                    flexShrink: 0,
                                  }}>
                                    {dest.label === 'Paris' || dest.label === 'Tokyo' ? '🔥 Trending' : '⭐ Top pick'}
                                  </span>
                                )}
                              </div>
                              <span style={{ fontSize: 12, color: 'rgba(12,14,28,0.5)', fontStyle: 'italic', lineHeight: 1.4, display: 'block' }}>
                                {DEST_TAGLINES[dest.label] ?? ''}
                              </span>
                            </div>
                          </button>
                          {idx < filtered.length - 1 && (
                            <div style={{ height: 1, background: 'rgba(12,14,28,0.05)', margin: '0 20px 0 72px' }} />
                          )}
                        </React.Fragment>
                      ));
                    })()}
                  </div>

                  {/* Footer */}
                  <div style={{ padding: '10px 20px', borderTop: '1px solid rgba(12,14,28,0.05)', background: 'rgba(12,14,28,0.02)' }}>
                    <span style={{ fontSize: 11, color: 'rgba(12,14,28,0.35)', fontFamily: "'Centra No2', -apple-system, sans-serif" }}>Personalized based on your search</span>
                  </div>
                </motion.div>
              )}
            </AnimatePresence>,
            document.body
          )}

          {ReactDOM.createPortal(
            <AnimatePresence>
              {openFlightDropdown && flightDropdownPos && (
                <motion.div
                  key={openFlightDropdown}
                  initial={{ opacity: 0, y: -8, scale: 0.96 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: -6, scale: 0.97, transition: { duration: 0.1 } }}
                  transition={spring.snap}
                  data-flight-dropdown="true"
                  style={{
                    position: 'fixed',
                    top: flightDropdownPos.top,
                    left: flightDropdownPos.left,
                    minWidth: flightDropdownPos.width,
                    background: glass.elevated.background,
                    backdropFilter: glass.elevated.backdropFilter,
                    WebkitBackdropFilter: glass.elevated.WebkitBackdropFilter,
                    border: glass.elevated.border,
                    boxShadow: glass.elevated.boxShadow,
                    borderRadius: 16,
                    overflow: 'hidden',
                    zIndex: 9999,
                    padding: '6px',
                  }}
                >
                  {openFlightDropdown === 'trip' && ([
                    { value: 'Roundtrip', Icon: IconRouteTrip },
                    { value: 'One-way',   Icon: IconOneWay    },
                    { value: 'Multi-city',Icon: IconMultiCity },
                  ]).map(opt => (
                    <button
                      key={opt.value}
                      onMouseDown={e => e.preventDefault()}
                      onClick={e => { e.stopPropagation(); setFlightTrip(opt.value); setOpenFlightDropdown(null); }}
                      style={{
                        display: 'flex', alignItems: 'center', gap: 10,
                        width: '100%', textAlign: 'left',
                        padding: '9px 12px', border: 'none', cursor: 'pointer',
                        borderRadius: 10,
                        background: flightTrip === opt.value ? 'rgba(12,14,28,0.06)' : 'transparent',
                        fontFamily: "'Centra No2', -apple-system, sans-serif",
                        fontSize: 14, fontWeight: flightTrip === opt.value ? 600 : 500, color: '#191E3B',
                      }}
                    >
                      <span style={{ flexShrink: 0, width: 20, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                        <opt.Icon />
                      </span>
                      {opt.value}
                      {flightTrip === opt.value && <span style={{ marginLeft: 'auto', color: '#6366F1', fontSize: 12 }}>✓</span>}
                    </button>
                  ))}
                  {openFlightDropdown === 'class' && ([
                    { value: 'Economy',         icon: <IconSeat />,            desc: 'Standard seating' },
                    { value: 'Premium Economy', icon: <IconSeatPremiumEco />,  desc: 'Extra legroom'    },
                    { value: 'Business class',  icon: <IconSeatBusiness />,    desc: 'Lie-flat beds'    },
                    { value: 'First class',     icon: <IconSeatFirst />,       desc: 'Private suite'    },
                  ]).map(opt => {
                    const isSelected = flightClass === opt.value;
                    return (
                      <button
                        key={opt.value}
                        onMouseDown={e => e.preventDefault()}
                        onClick={e => { e.stopPropagation(); setFlightClass(opt.value); setOpenFlightDropdown(null); }}
                        style={{
                          display: 'flex', alignItems: 'center', gap: 10,
                          width: '100%', textAlign: 'left',
                          padding: '9px 12px', border: 'none', cursor: 'pointer',
                          borderRadius: 10,
                          background: isSelected ? 'rgba(12,14,28,0.06)' : 'transparent',
                          fontFamily: "'Centra No2', -apple-system, sans-serif",
                        }}
                      >
                        <span style={{ flexShrink: 0, width: 20, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{opt.icon}</span>
                        <span style={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                          <span style={{ fontSize: 14, fontWeight: isSelected ? 600 : 500, color: '#191E3B', lineHeight: '18px' }}>{opt.value}</span>
                          <span style={{ fontSize: 11, fontWeight: 400, color: 'rgba(25,30,59,0.45)', lineHeight: '14px' }}>{opt.desc}</span>
                        </span>
                        {isSelected && <span style={{ marginLeft: 'auto', color: '#6366F1', fontSize: 14 }}>✓</span>}
                      </button>
                    );
                  })}
                </motion.div>
              )}
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
                  background: glass.elevated.background,
                  backdropFilter: glass.elevated.backdropFilter,
                  WebkitBackdropFilter: glass.elevated.WebkitBackdropFilter,
                  border: glass.elevated.border,
                  boxShadow: glass.elevated.boxShadow,
                  borderRadius: 20,
                  zIndex: 9999,
                  overflow: 'hidden',
                };

                if (chipId === 'origin' || chipId === 'destination') {
                  const search = chipId === 'origin' ? originSearch : destinationSearch;
                  const setSearch = chipId === 'origin' ? setOriginSearch : setDestinationSearch;
                  const matches = (chipId === 'origin' ? originMatches : destinationMatches).slice(0, 5);
                  const airportPopoverStyle: React.CSSProperties = {
                    ...sharedPopoverStyle,
                    borderRadius: 24,
                    padding: '24px 0',
                    boxShadow: '0 6px 36px rgba(12,14,28,0.12), 0 2px 8px rgba(12,14,28,0.06)',
                    border: '1px solid rgba(255,255,255,0.7)',
                    background: 'rgba(255,255,255,0.96)',
                    backdropFilter: 'blur(20px)',
                    WebkitBackdropFilter: 'blur(20px)',
                    overflow: 'hidden',
                  };
                  const iconContainerStyle: React.CSSProperties = {
                    width: 48, height: 48, borderRadius: 12,
                    background: '#F4F1F0',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    flexShrink: 0,
                  };
                  const sectionLabelStyle: React.CSSProperties = {
                    fontSize: 13, fontWeight: 400, color: '#707480',
                    marginBottom: 4,
                    fontFamily: "'Centra No2', -apple-system, sans-serif",
                    padding: '0 24px',
                  };
                  const rowStyle: React.CSSProperties = {
                    display: 'flex', gap: 16, alignItems: 'center',
                    padding: '8px 24px',
                    border: 'none', background: 'transparent',
                    cursor: 'pointer', textAlign: 'left',
                    borderRadius: 8, width: '100%',
                    boxSizing: 'border-box',
                    fontFamily: "'Centra No2', -apple-system, sans-serif",
                  };
                  return (
                    <motion.div
                      key={chipId}
                      data-flight-popover="true"
                      initial={{ opacity: 0, y: -8, scale: 0.96}}
                      animate={{ opacity: 1, y: 0, scale: 1}}
                      exit={{ opacity: 0, y: -6, scale: 0.97, filter: 'blur(4px)', transition: { duration: 0.12 } }}
                      transition={spring.snap}
                      style={airportPopoverStyle}
                    >
                      {/* Search input */}
                      <input
                        autoFocus
                        placeholder="Search airports or cities"
                        value={search}
                        onChange={e => setSearch(e.target.value)}
                        style={{
                          display: 'block', width: '100%', border: 'none',
                          padding: '0 24px', fontSize: 16, marginBottom: 16,
                          fontFamily: "'Centra No2', -apple-system, sans-serif",
                          outline: 'none', boxSizing: 'border-box', color: '#191E3B',
                          background: 'transparent',
                        }}
                      />

                      {/* My current location section */}
                      <div style={{ marginBottom: 8 }}>
                        <div style={sectionLabelStyle}>My current location</div>
                        <div style={{ paddingBlock: 8 }}>
                          <button
                            style={rowStyle}
                            onMouseEnter={e => (e.currentTarget.style.background = 'rgba(12,14,28,0.03)')}
                            onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                            onMouseDown={e => {
                              e.preventDefault();
                              const value = 'San Antonio (SAT)';
                              if (chipId === 'origin') {
                                setSelectedOrigin(value);
                                setOriginSearch('');
                                setTimeout(() => {
                                  const destBtn = flightChipBtnRefs.current['destination'];
                                  if (destBtn) {
                                    const rect = destBtn.getBoundingClientRect();
                                    setActiveFlightField('destination');
                                    setFlightChipPopover({ chipId: 'destination', pos: { top: rect.bottom + 8, left: rect.left, width: Math.max(rect.width, 340) } });
                                  }
                                }, 120);
                              } else {
                                setGoingTo(value);
                                setDestinationSearch('');
                                // Auto-advance to dates after destination chosen
                                setTimeout(() => {
                                  const datesBtn = flightChipBtnRefs.current['dates'];
                                  if (datesBtn) {
                                    const rect = datesBtn.getBoundingClientRect();
                                    const popWidth = Math.max(rect.width, 700);
                                    const rawLeft = rect.left - Math.max(0, rect.left + popWidth - (window.innerWidth - 16));
                                    setActiveFlightField('dates');
                                    setFlightChipPopover({ chipId: 'dates', pos: { top: rect.bottom + 8, left: Math.max(8, rawLeft), width: popWidth } });
                                  }
                                }, 120);
                              }
                            }}
                          >
                            <div style={iconContainerStyle}>
                              <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                                <circle cx="12" cy="12" r="3" fill="#191E3B"/>
                                <path d="M12 2v3M12 19v3M2 12h3M19 12h3" stroke="#191E3B" strokeWidth="1.8" strokeLinecap="round"/>
                                <circle cx="12" cy="12" r="7" stroke="#191E3B" strokeWidth="1.8"/>
                              </svg>
                            </div>
                            <div style={{ flex: 1, minWidth: 0 }}>
                              <div style={{ fontSize: 14, fontWeight: 500, color: '#191E3B', lineHeight: '20px' }}>San Antonio (SAT)</div>
                              <div style={{ fontSize: 14, fontWeight: 400, color: '#676A7D', lineHeight: '20px' }}>Airport in Texas, US</div>
                            </div>
                          </button>
                        </div>
                      </div>

                      {/* Suggested section */}
                      {matches.length > 0 && (
                        <div>
                          <div style={sectionLabelStyle}>Suggested</div>
                          <div style={{ paddingBlock: 8 }}>
                            {matches.map(airport => (
                              <button
                                key={airport.code}
                                style={rowStyle}
                                onMouseEnter={e => (e.currentTarget.style.background = 'rgba(12,14,28,0.03)')}
                                onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
                                onMouseDown={e => {
                                  e.preventDefault();
                                  if (chipId === 'origin') {
                                    setSelectedOrigin(`${airport.city} (${airport.code})`);
                                    setOriginSearch('');
                                    setTimeout(() => {
                                      const destBtn = flightChipBtnRefs.current['destination'];
                                      if (destBtn) {
                                        const rect = destBtn.getBoundingClientRect();
                                        setActiveFlightField('destination');
                                        setFlightChipPopover({ chipId: 'destination', pos: { top: rect.bottom + 8, left: rect.left, width: Math.max(rect.width, 340) } });
                                      }
                                    }, 120);
                                  } else {
                                    setGoingTo(`${airport.city} (${airport.code})`);
                                    setDestinationSearch('');
                                    // Auto-advance to dates after destination chosen
                                    setTimeout(() => {
                                      const datesBtn = flightChipBtnRefs.current['dates'];
                                      if (datesBtn) {
                                        const rect = datesBtn.getBoundingClientRect();
                                        const popWidth = Math.max(rect.width, 700);
                                        const rawLeft = rect.left - Math.max(0, rect.left + popWidth - (window.innerWidth - 16));
                                        setActiveFlightField('dates');
                                        setFlightChipPopover({ chipId: 'dates', pos: { top: rect.bottom + 8, left: Math.max(8, rawLeft), width: popWidth } });
                                      }
                                    }, 120);
                                  }
                                }}
                              >
                                <div style={iconContainerStyle}>
                                  <IconPlane />
                                </div>
                                <div style={{ flex: 1, minWidth: 0 }}>
                                  <div style={{ fontSize: 14, fontWeight: 500, color: '#191E3B', lineHeight: '20px' }}>{airport.city} ({airport.code})</div>
                                  <div style={{ fontSize: 14, fontWeight: 400, color: '#676A7D', lineHeight: '20px' }}>{airport.name}</div>
                                </div>
                              </button>
                            ))}
                          </div>
                        </div>
                      )}
                    </motion.div>
                  );
                }

                if (chipId === 'dates') {
                  const calDeparture = flightDates.depart ? new Date(flightDates.depart + 'T00:00:00') : null;
                  const calReturn = flightDates.return ? new Date(flightDates.return + 'T00:00:00') : null;
                  const calToday = new Date(); calToday.setHours(0, 0, 0, 0);

                  const handleDayTap = (date: Date) => {
                    const ds = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
                    if (calDeparture && !calReturn) {
                      if (date < calDeparture) {
                        setFlightDates({ depart: ds, return: flightDates.depart });
                      } else {
                        setFlightDates({ ...flightDates, return: ds });
                        // Auto-close calendar then open travelers
                        setTimeout(() => {
                          setFlightChipPopover(null);
                          setActiveFlightField(null);
                          setTimeout(() => {
                            const travelersBtn = flightChipBtnRefs.current['travelers'];
                            if (travelersBtn) {
                              const rect = travelersBtn.getBoundingClientRect();
                              const popWidth = Math.max(rect.width, 260);
                              setActiveFlightField('travelers');
                              setFlightChipPopover({ chipId: 'travelers', pos: { top: rect.bottom + 8, left: Math.max(8, rect.left), width: popWidth } });
                            }
                          }, 80);
                        }, 220);
                      }
                    } else {
                      setFlightDates({ depart: ds, return: '' });
                    }
                  };

                  const calNavBtnStyle: React.CSSProperties = {
                    width: 36, height: 36, borderRadius: '50%', border: 'none',
                    background: 'rgba(12,14,28,0.07)', cursor: 'pointer',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    flexShrink: 0,
                  };

                  const mockFlightPrice = (date: Date): string | null => {
                    if (date < calToday) return null;
                    const seed = date.getFullYear() * 10000 + (date.getMonth() + 1) * 100 + date.getDate();
                    const base = 89 + (seed % 7) * 40 + (seed % 3) * 15;
                    return `$${base}`;
                  };

                  const renderCalMonth = (year: number, month: number) => {
                    const daysInMonth = new Date(year, month + 1, 0).getDate();
                    const firstDow = new Date(year, month, 1).getDay();

                    // Find cheapest available day in this month for bold highlight
                    let cheapestPrice = Infinity;
                    let cheapestDay = -1;
                    for (let day = 1; day <= daysInMonth; day++) {
                      const d = new Date(year, month, day);
                      const p = mockFlightPrice(d);
                      if (p !== null) {
                        const num = parseInt(p.replace('$', ''), 10);
                        if (num < cheapestPrice) { cheapestPrice = num; cheapestDay = day; }
                      }
                    }

                    const cells: React.ReactElement[] = [];
                    for (let i = 0; i < firstDow; i++) {
                      cells.push(<div key={`e${i}`} style={{ height: 48 }} />);
                    }
                    for (let day = 1; day <= daysInMonth; day++) {
                      const d = new Date(year, month, day);
                      const isPast = d < calToday;
                      void (d.getTime() === calToday.getTime()); // reserved
                      const isDep = !!calDeparture && d.getTime() === calDeparture.getTime();
                      const isRet = !!calReturn && d.getTime() === calReturn.getTime();
                      const isSelected = isDep || isRet;
                      const hasRange = !!calDeparture && !!calReturn;
                      const isInRange = hasRange && d > calDeparture! && d < calReturn!;
                      const isRangeStart = isDep && hasRange;
                      const isRangeEnd = isRet && hasRange;
                      const price = mockFlightPrice(d);
                      const isCheapest = day === cheapestDay && price !== null;
                      // Price color: white when selected endpoint, green otherwise
                      const priceColor = isSelected ? '#fff' : '#22C55E';
                      cells.push(
                        <div key={day} style={{ position: 'relative', height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', pointerEvents: isPast ? 'none' : 'auto' }}>
                          {/* Range band — 40px tall, centered in 48px cell */}
                          {isInRange && (
                            <div style={{ position: 'absolute', top: 4, bottom: 4, left: 0, right: 0, background: 'rgba(12,14,28,0.06)' }} />
                          )}
                          {isRangeStart && (
                            <div style={{ position: 'absolute', top: 10, bottom: 10, left: '50%', right: 0, background: 'rgba(12,14,28,0.06)' }} />
                          )}
                          {isRangeEnd && (
                            <div style={{ position: 'absolute', top: 10, bottom: 10, left: 0, right: '50%', background: 'rgba(12,14,28,0.06)' }} />
                          )}
                          <button
                            disabled={isPast}
                            onClick={() => !isPast && handleDayTap(d)}
                            style={{
                              position: 'relative', zIndex: 1,
                              width: 40, height: 40, borderRadius: '50%',
                              border: 'none',
                              background: isSelected ? '#191E3B' : 'transparent',
                              color: isSelected ? '#fff' : isPast ? 'rgba(12,14,28,0.25)' : '#191E3B',
                              cursor: isPast ? 'default' : 'pointer',
                              display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
                              gap: 1,
                              fontFamily: "'Centra No2', -apple-system, sans-serif",
                              opacity: isPast ? 0.25 : 1,
                              padding: 0,
                            }}
                          >
                            <span style={{ fontSize: 13, fontWeight: 400, lineHeight: 1 }}>{day}</span>
                            {price !== null && (
                              <span style={{
                                fontSize: 10,
                                fontWeight: isCheapest ? 600 : 400,
                                color: priceColor,
                                lineHeight: 1,
                              }}>{price}</span>
                            )}
                          </button>
                        </div>
                      );
                    }
                    return (
                      <div key={`${year}-${month}`} style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', marginBottom: 4 }}>
                          {['Sun','Mon','Tue','Wed','Thu','Fri','Sat'].map((lbl, i) => (
                            <div key={i} style={{ textAlign: 'center', fontSize: 13, color: '#9CA3AF', padding: '4px 0' }}>{lbl}</div>
                          ))}
                        </div>
                        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)' }}>
                          {cells}
                        </div>
                      </div>
                    );
                  };

                  // Left = current calViewMonth, Right = calViewMonth+1
                  const leftDate = new Date(calViewYear, calViewMonth, 1);
                  const rightDate = new Date(calViewYear, calViewMonth + 1, 1);
                  const leftGrid = renderCalMonth(leftDate.getFullYear(), leftDate.getMonth());
                  const rightGrid = renderCalMonth(rightDate.getFullYear(), rightDate.getMonth());

                  // Disable left-arrow if both visible months are <= today's month
                  const todayYear = new Date().getFullYear();
                  const todayMonth = new Date().getMonth();
                  const isPrevDisabled = (calViewYear < todayYear) || (calViewYear === todayYear && calViewMonth <= todayMonth);

                  const prevMonth = () => {
                    if (isPrevDisabled) return;
                    const d = new Date(calViewYear, calViewMonth - 1, 1);
                    setCalViewYear(d.getFullYear()); setCalViewMonth(d.getMonth());
                  };
                  const nextMonth = () => {
                    const d = new Date(calViewYear, calViewMonth + 1, 1);
                    setCalViewYear(d.getFullYear()); setCalViewMonth(d.getMonth());
                  };

                  const flexChips: { label: string; value: 0 | 1 | 2 }[] = [
                    { label: 'Exact dates', value: 0 },
                    { label: '± 1 day',     value: 1 },
                    { label: '± 2 days',    value: 2 },
                  ]; void flexChips; void setFlexDelta;

                  return (
                    <motion.div
                      key="dates"
                      data-flight-popover="true"
                      initial={{ opacity: 0, y: -8, scale: 0.96 }}
                      animate={{ opacity: 1, y: 0, scale: 1 }}
                      exit={{ opacity: 0, y: -6, scale: 0.97, filter: 'blur(4px)', transition: { duration: 0.12 } }}
                      transition={spring.snap}
                      style={{
                        ...sharedPopoverStyle,
                        borderRadius: 24,
                        padding: 24,
                        width: 700,
                        background: '#fff',
                        border: '1px solid rgba(255,255,255,0.7)',
                        boxShadow: '0 6px 36px rgba(12,14,28,0.12), 0 2px 8px rgba(12,14,28,0.06)',
                        backdropFilter: 'blur(20px)',
                        WebkitBackdropFilter: 'blur(20px)',
                        overflow: 'hidden',
                      }}
                    >
                      {/* ── Header: [<] [Left Month] | [Right Month] [>] ── */}
                      <div style={{ display: 'flex', alignItems: 'center', marginBottom: 20 }}>
                        <button
                          onClick={prevMonth}
                          disabled={isPrevDisabled}
                          style={{
                            ...calNavBtnStyle,
                            opacity: isPrevDisabled ? 0.3 : 1,
                            cursor: isPrevDisabled ? 'default' : 'pointer',
                            flexShrink: 0,
                          }}
                        >
                          <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                            <path d="M10 12L6 8l4-4" stroke="#191E3B" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
                          </svg>
                        </button>
                        <div style={{ flex: 1, textAlign: 'center', fontSize: 16, fontWeight: 700, color: '#191E3B', fontFamily: "'Centra No2', -apple-system, sans-serif" }}>
                          {new Date(leftDate.getFullYear(), leftDate.getMonth(), 1).toLocaleDateString('en-US', { month: 'short', year: 'numeric' })}
                        </div>
                        <div style={{ flex: 1, textAlign: 'center', fontSize: 16, fontWeight: 700, color: '#191E3B', fontFamily: "'Centra No2', -apple-system, sans-serif" }}>
                          {new Date(rightDate.getFullYear(), rightDate.getMonth(), 1).toLocaleDateString('en-US', { month: 'short', year: 'numeric' })}
                        </div>
                        <button
                          onClick={nextMonth}
                          style={{ ...calNavBtnStyle, cursor: 'pointer', flexShrink: 0 }}
                        >
                          <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                            <path d="M6 4l4 4-4 4" stroke="#191E3B" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
                          </svg>
                        </button>
                      </div>

                      {/* ── Two month grids side by side ── */}
                      <div style={{ display: 'flex', gap: 32 }}>
                        {leftGrid}
                        {rightGrid}
                      </div>

                    </motion.div>
                  );
                }

                if (chipId === 'travelers') {
                  const tBtnStyle = (disabled: boolean): React.CSSProperties => ({
                    width: 36, height: 36, borderRadius: 100, border: 'none',
                    background: disabled ? 'rgba(12,14,28,0.04)' : 'rgba(12,14,28,0.08)',
                    cursor: disabled ? 'default' : 'pointer',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                    color: disabled ? 'rgba(25,30,59,0.25)' : '#191E3B',
                    fontSize: 18, lineHeight: 1,
                  });
                  const AgePill = ({ value, onChange, maxAge }: { value: number; onChange: (v: number) => void; maxAge: number }) => (
                    <div style={{ position: 'relative', width: 120 }}>
                      <select
                        value={value}
                        onChange={e => onChange(Number(e.target.value))}
                        style={{
                          appearance: 'none', WebkitAppearance: 'none',
                          width: '100%', height: 36, borderRadius: 100, border: 'none',
                          background: 'rgba(12,14,28,0.06)', paddingLeft: 16, paddingRight: 36,
                          fontSize: 14, color: '#191E3B', cursor: 'pointer',
                          fontFamily: "'Centra No2', -apple-system, sans-serif",
                          outline: 'none',
                        }}
                      >
                        {Array.from({ length: maxAge + 1 }, (_, i) => (
                          <option key={i} value={i}>{i} yr{i !== 1 ? 's' : ''}</option>
                        ))}
                      </select>
                      <svg style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none' }} width="12" height="12" viewBox="0 0 12 12" fill="none">
                        <path d="M2 4l4 4 4-4" stroke="#191E3B" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                      </svg>
                    </div>
                  );
                  const TRow = ({ label, sub, val, onDec, onInc, atMin, atMax, ages, onAgeChange, maxAge, first }: {
                    label: string; sub?: string; val: number; first?: boolean;
                    onDec: () => void; onInc: () => void; atMin: boolean; atMax: boolean;
                    ages?: number[]; onAgeChange?: (i: number, v: number) => void; maxAge?: number;
                  }) => (
                    <div>
                      {!first && <div style={{ height: 1, background: 'rgba(12,14,28,0.07)', margin: '0 20px' }} />}
                      <div style={{ height: 60, padding: '0 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <div>
                          <div style={{ fontSize: 15, fontWeight: 500, color: '#191E3B' }}>{label}</div>
                          {sub && <div style={{ fontSize: 12, fontWeight: 400, color: 'rgba(12,14,28,0.45)' }}>{sub}</div>}
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                          <button disabled={atMin} onClick={onDec} style={tBtnStyle(atMin)}>−</button>
                          <span style={{ width: 32, textAlign: 'center', fontSize: 15, fontWeight: 400, color: '#191E3B' }}>{val}</span>
                          <button disabled={atMax} onClick={onInc} style={tBtnStyle(atMax)}>+</button>
                        </div>
                      </div>
                      {ages && ages.length > 0 && onAgeChange && maxAge !== undefined && (
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, padding: '0 20px 12px' }}>
                          {ages.map((age, i) => (
                            <AgePill key={i} value={age} onChange={v => onAgeChange(i, v)} maxAge={maxAge} />
                          ))}
                        </div>
                      )}
                    </div>
                  );
                  void (['Economy', 'Premium Economy', 'Business class', 'First class']); // cabin options reserved
                  return (
                    <motion.div
                      key="travelers"
                      data-flight-popover="true"
                      initial={{ opacity: 0, y: -8, scale: 0.96 }}
                      animate={{ opacity: 1, y: 0, scale: 1 }}
                      exit={{ opacity: 0, y: -6, scale: 0.97, transition: { duration: 0.12 } }}
                      transition={spring.snap}
                      style={{ ...sharedPopoverStyle, width: 300, padding: '8px 0 0', borderRadius: 20, overflow: 'hidden' }}
                    >
                      <TRow
                        label="Adults" val={travelersAdults}
                        onDec={() => setTravelersAdults(v => Math.max(1, v - 1))}
                        onInc={() => setTravelersAdults(v => Math.min(9, v + 1))}
                        atMin={travelersAdults <= 1} atMax={travelersAdults >= 9}
                        first
                      />
                      <TRow
                        label="Children" sub="Ages 2 to 17" val={travelersChildren}
                        onDec={() => { const n = Math.max(0, travelersChildren - 1); setTravelersChildren(n); setTravelersChildAges(p => p.slice(0, n)); }}
                        onInc={() => { setTravelersChildren(v => v + 1); setTravelersChildAges(p => [...p, 2]); }}
                        atMin={travelersChildren <= 0} atMax={travelersChildren >= 9}
                        ages={travelersChildAges}
                        onAgeChange={(i, v) => setTravelersChildAges(p => p.map((a, idx) => idx === i ? v : a))}
                        maxAge={17}
                      />
                      <TRow
                        label="Infants in seat" sub="Younger than 2" val={travelersInfantsSeat}
                        onDec={() => { const n = Math.max(0, travelersInfantsSeat - 1); setTravelersInfantsSeat(n); setTravelersInfantAges(p => [...p.slice(0, n), ...p.slice(travelersInfantsSeat)]); }}
                        onInc={() => { setTravelersInfantsSeat(v => v + 1); setTravelersInfantAges(p => [...p.slice(0, travelersInfantsSeat), 0, ...p.slice(travelersInfantsSeat)]); }}
                        atMin={travelersInfantsSeat <= 0} atMax={travelersInfantsSeat >= 9}
                        ages={travelersInfantAges.slice(0, travelersInfantsSeat)}
                        onAgeChange={(i, v) => setTravelersInfantAges(p => p.map((a, idx) => idx === i ? v : a))}
                        maxAge={1}
                      />
                      <TRow
                        label="Infants on lap" sub="Younger than 2" val={travelersInfantsLap}
                        onDec={() => { const n = Math.max(0, travelersInfantsLap - 1); setTravelersInfantsLap(n); setTravelersInfantAges(p => [...p.slice(0, travelersInfantsSeat), ...p.slice(travelersInfantsSeat, travelersInfantsSeat + n)]); }}
                        onInc={() => { setTravelersInfantsLap(v => v + 1); setTravelersInfantAges(p => [...p, 0]); }}
                        atMin={travelersInfantsLap <= 0} atMax={travelersInfantsLap >= 9}
                        ages={travelersInfantAges.slice(travelersInfantsSeat)}
                        onAgeChange={(i, v) => setTravelersInfantAges(p => p.map((a, idx) => idx === travelersInfantsSeat + i ? v : a))}
                        maxAge={1}
                      />
                      <div style={{ height: 8 }} />
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
              {nlpChipPopover && (() => {
                const { chipId, pos } = nlpChipPopover;
                const sharedPopoverStyle: React.CSSProperties = {
                  position: 'fixed',
                  top: pos.top,
                  left: pos.left,
                  width: pos.width,
                  background: '#fff',
                  border: '1px solid rgba(255,255,255,0.7)',
                  boxShadow: '0 6px 36px rgba(12,14,28,0.12), 0 2px 8px rgba(12,14,28,0.06)',
                  backdropFilter: 'blur(20px)',
                  WebkitBackdropFilter: 'blur(20px)',
                  borderRadius: 24,
                  zIndex: 9999,
                  overflow: 'hidden',
                };

                if (chipId === 'dates') {
                  const calDeparture = flightDates.depart ? new Date(flightDates.depart + 'T00:00:00') : null;
                  const calReturn = flightDates.return ? new Date(flightDates.return + 'T00:00:00') : null;
                  const calToday = new Date(); calToday.setHours(0, 0, 0, 0);

                  const handleDayTap = (date: Date) => {
                    const ds = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
                    if (calDeparture && !calReturn) {
                      if (date < calDeparture) {
                        setFlightDates({ depart: ds, return: flightDates.depart });
                      } else {
                        setFlightDates({ ...flightDates, return: ds });
                        // Auto-close calendar then open travelers
                        setTimeout(() => {
                          setNlpChipPopover(null);
                          setTimeout(() => {
                            const travelersBtn = nlpChipBtnRefs.current['travelers'];
                            if (travelersBtn) {
                              const rect = travelersBtn.getBoundingClientRect();
                              const popWidth = Math.max(rect.width, 320);
                              setNlpChipPopover({ chipId: 'travelers', pos: { top: rect.bottom + 8, left: Math.max(8, rect.left), width: popWidth } });
                            }
                          }, 80);
                        }, 220);
                      }
                    } else {
                      setFlightDates({ depart: ds, return: '' });
                    }
                  };

                  const calNavBtnStyle: React.CSSProperties = {
                    width: 36, height: 36, borderRadius: '50%', border: 'none',
                    background: 'rgba(12,14,28,0.07)', cursor: 'pointer',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    flexShrink: 0,
                  };

                  const mockFlightPrice = (date: Date): string | null => {
                    if (date < calToday) return null;
                    const seed = date.getFullYear() * 10000 + (date.getMonth() + 1) * 100 + date.getDate();
                    const base = 89 + (seed % 7) * 40 + (seed % 3) * 15;
                    return `$${base}`;
                  };

                  const renderCalMonth = (year: number, month: number) => {
                    const daysInMonth = new Date(year, month + 1, 0).getDate();
                    const firstDow = new Date(year, month, 1).getDay();

                    let cheapestPrice = Infinity;
                    let cheapestDay = -1;
                    for (let day = 1; day <= daysInMonth; day++) {
                      const d = new Date(year, month, day);
                      const p = mockFlightPrice(d);
                      if (p !== null) {
                        const num = parseInt(p.replace('$', ''), 10);
                        if (num < cheapestPrice) { cheapestPrice = num; cheapestDay = day; }
                      }
                    }

                    const cells: React.ReactElement[] = [];
                    for (let i = 0; i < firstDow; i++) {
                      cells.push(<div key={`e${i}`} style={{ height: 48 }} />);
                    }
                    for (let day = 1; day <= daysInMonth; day++) {
                      const d = new Date(year, month, day);
                      const isPast = d < calToday;
                      void (d.getTime() === calToday.getTime()); // reserved
                      const isDep = !!calDeparture && d.getTime() === calDeparture.getTime();
                      const isRet = !!calReturn && d.getTime() === calReturn.getTime();
                      const isSelected = isDep || isRet;
                      const hasRange = !!calDeparture && !!calReturn;
                      const isInRange = hasRange && d > calDeparture! && d < calReturn!;
                      const isRangeStart = isDep && hasRange;
                      const isRangeEnd = isRet && hasRange;
                      const price = mockFlightPrice(d);
                      const isCheapest = day === cheapestDay && price !== null;
                      const priceColor = isSelected ? '#fff' : '#22C55E';
                      cells.push(
                        <div key={day} style={{ position: 'relative', height: 48, display: 'flex', alignItems: 'center', justifyContent: 'center', pointerEvents: isPast ? 'none' : 'auto' }}>
                          {isInRange && (
                            <div style={{ position: 'absolute', top: 4, bottom: 4, left: 0, right: 0, background: 'rgba(12,14,28,0.06)' }} />
                          )}
                          {isRangeStart && (
                            <div style={{ position: 'absolute', top: 10, bottom: 10, left: '50%', right: 0, background: 'rgba(12,14,28,0.06)' }} />
                          )}
                          {isRangeEnd && (
                            <div style={{ position: 'absolute', top: 10, bottom: 10, left: 0, right: '50%', background: 'rgba(12,14,28,0.06)' }} />
                          )}
                          <button
                            disabled={isPast}
                            onClick={() => !isPast && handleDayTap(d)}
                            style={{
                              position: 'relative', zIndex: 1,
                              width: 40, height: 40, borderRadius: '50%',
                              border: 'none',
                              background: isSelected ? '#191E3B' : 'transparent',
                              color: isSelected ? '#fff' : isPast ? 'rgba(12,14,28,0.25)' : '#191E3B',
                              cursor: isPast ? 'default' : 'pointer',
                              display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
                              gap: 1,
                              fontFamily: "'Centra No2', -apple-system, sans-serif",
                              opacity: isPast ? 0.25 : 1,
                              padding: 0,
                            }}
                          >
                            <span style={{ fontSize: 13, fontWeight: 400, lineHeight: 1 }}>{day}</span>
                            {price !== null && (
                              <span style={{
                                fontSize: 10,
                                fontWeight: isCheapest ? 600 : 400,
                                color: priceColor,
                                lineHeight: 1,
                              }}>{price}</span>
                            )}
                          </button>
                        </div>
                      );
                    }
                    return (
                      <div key={`${year}-${month}`} style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', marginBottom: 4 }}>
                          {['Sun','Mon','Tue','Wed','Thu','Fri','Sat'].map((lbl, idx) => (
                            <div key={idx} style={{ textAlign: 'center', fontSize: 13, color: '#9CA3AF', padding: '4px 0' }}>{lbl}</div>
                          ))}
                        </div>
                        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)' }}>
                          {cells}
                        </div>
                      </div>
                    );
                  };

                  const leftDate = new Date(calViewYear, calViewMonth, 1);
                  const rightDate = new Date(calViewYear, calViewMonth + 1, 1);
                  const leftGrid = renderCalMonth(leftDate.getFullYear(), leftDate.getMonth());
                  const rightGrid = renderCalMonth(rightDate.getFullYear(), rightDate.getMonth());

                  const todayYear = new Date().getFullYear();
                  const todayMonth = new Date().getMonth();
                  const isPrevDisabled = (calViewYear < todayYear) || (calViewYear === todayYear && calViewMonth <= todayMonth);

                  const prevMonth = () => {
                    if (isPrevDisabled) return;
                    const d = new Date(calViewYear, calViewMonth - 1, 1);
                    setCalViewYear(d.getFullYear()); setCalViewMonth(d.getMonth());
                  };
                  const nextMonth = () => {
                    const d = new Date(calViewYear, calViewMonth + 1, 1);
                    setCalViewYear(d.getFullYear()); setCalViewMonth(d.getMonth());
                  };

                  return (
                    <motion.div
                      key="nlp-dates"
                      data-nlp-popover="true"
                      initial={{ opacity: 0, y: -8, scale: 0.96 }}
                      animate={{ opacity: 1, y: 0, scale: 1 }}
                      exit={{ opacity: 0, y: -6, scale: 0.97, filter: 'blur(4px)', transition: { duration: 0.12 } }}
                      transition={spring.snap}
                      style={{ ...sharedPopoverStyle, padding: 24, width: 700, overflow: 'hidden' }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', marginBottom: 20 }}>
                        <button
                          onClick={prevMonth}
                          disabled={isPrevDisabled}
                          style={{
                            ...calNavBtnStyle,
                            opacity: isPrevDisabled ? 0.3 : 1,
                            cursor: isPrevDisabled ? 'default' : 'pointer',
                            flexShrink: 0,
                          }}
                        >
                          <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                            <path d="M10 12L6 8l4-4" stroke="#191E3B" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
                          </svg>
                        </button>
                        <div style={{ flex: 1, textAlign: 'center', fontSize: 16, fontWeight: 700, color: '#191E3B', fontFamily: "'Centra No2', -apple-system, sans-serif" }}>
                          {new Date(leftDate.getFullYear(), leftDate.getMonth(), 1).toLocaleDateString('en-US', { month: 'short', year: 'numeric' })}
                        </div>
                        <div style={{ flex: 1, textAlign: 'center', fontSize: 16, fontWeight: 700, color: '#191E3B', fontFamily: "'Centra No2', -apple-system, sans-serif" }}>
                          {new Date(rightDate.getFullYear(), rightDate.getMonth(), 1).toLocaleDateString('en-US', { month: 'short', year: 'numeric' })}
                        </div>
                        <button
                          onClick={nextMonth}
                          style={{ ...calNavBtnStyle, cursor: 'pointer', flexShrink: 0 }}
                        >
                          <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
                            <path d="M6 4l4 4-4 4" stroke="#191E3B" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
                          </svg>
                        </button>
                      </div>
                      <div style={{ display: 'flex', gap: 32 }}>
                        {leftGrid}
                        {rightGrid}
                      </div>
                    </motion.div>
                  );
                }

                if (chipId === 'travelers') {
                  const tBtnStyle2 = (disabled: boolean): React.CSSProperties => ({
                    width: 36, height: 36, borderRadius: 100, border: 'none',
                    background: disabled ? 'rgba(12,14,28,0.04)' : 'rgba(12,14,28,0.08)',
                    cursor: disabled ? 'default' : 'pointer',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
                    color: disabled ? 'rgba(25,30,59,0.25)' : '#191E3B',
                    fontSize: 18, lineHeight: 1,
                  });
                  const AgePill2 = ({ value, onChange, maxAge }: { value: number; onChange: (v: number) => void; maxAge: number }) => (
                    <div style={{ position: 'relative', width: 120 }}>
                      <select
                        value={value}
                        onChange={e => onChange(Number(e.target.value))}
                        style={{
                          appearance: 'none', WebkitAppearance: 'none',
                          width: '100%', height: 36, borderRadius: 100, border: 'none',
                          background: 'rgba(12,14,28,0.06)', paddingLeft: 16, paddingRight: 36,
                          fontSize: 14, color: '#191E3B', cursor: 'pointer',
                          fontFamily: "'Centra No2', -apple-system, sans-serif",
                          outline: 'none',
                        }}
                      >
                        {Array.from({ length: maxAge + 1 }, (_, i) => (
                          <option key={i} value={i}>{i} yr{i !== 1 ? 's' : ''}</option>
                        ))}
                      </select>
                      <svg style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none' }} width="12" height="12" viewBox="0 0 12 12" fill="none">
                        <path d="M2 4l4 4 4-4" stroke="#191E3B" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/>
                      </svg>
                    </div>
                  );
                  const TRow2 = ({ label, sub, val, onDec, onInc, atMin, atMax, ages, onAgeChange, maxAge, first }: {
                    label: string; sub?: string; val: number; first?: boolean;
                    onDec: () => void; onInc: () => void; atMin: boolean; atMax: boolean;
                    ages?: number[]; onAgeChange?: (i: number, v: number) => void; maxAge?: number;
                  }) => (
                    <div>
                      {!first && <div style={{ height: 1, background: 'rgba(12,14,28,0.07)', margin: '0 20px' }} />}
                      <div style={{ height: 60, padding: '0 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <div>
                          <div style={{ fontSize: 15, fontWeight: 500, color: '#191E3B' }}>{label}</div>
                          {sub && <div style={{ fontSize: 12, fontWeight: 400, color: 'rgba(12,14,28,0.45)' }}>{sub}</div>}
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                          <button disabled={atMin} onClick={onDec} style={tBtnStyle2(atMin)}>−</button>
                          <span style={{ width: 32, textAlign: 'center', fontSize: 15, fontWeight: 400, color: '#191E3B' }}>{val}</span>
                          <button disabled={atMax} onClick={onInc} style={tBtnStyle2(atMax)}>+</button>
                        </div>
                      </div>
                      {ages && ages.length > 0 && onAgeChange && maxAge !== undefined && (
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, padding: '0 20px 12px' }}>
                          {ages.map((age, i) => (
                            <AgePill2 key={i} value={age} onChange={v => onAgeChange(i, v)} maxAge={maxAge} />
                          ))}
                        </div>
                      )}
                    </div>
                  );
                  void (['Economy', 'Premium Economy', 'Business class', 'First class']); // cabin options reserved (NLP)
                  return (
                    <motion.div
                      key="nlp-travelers"
                      data-nlp-popover="true"
                      initial={{ opacity: 0, y: -8, scale: 0.96 }}
                      animate={{ opacity: 1, y: 0, scale: 1 }}
                      exit={{ opacity: 0, y: -6, scale: 0.97, transition: { duration: 0.12 } }}
                      transition={spring.snap}
                      style={{ ...sharedPopoverStyle, width: 300, padding: '8px 0 0', borderRadius: 20, overflow: 'hidden' }}
                    >
                      <TRow2
                        label="Adults" val={travelersAdults}
                        onDec={() => setTravelersAdults(v => Math.max(1, v - 1))}
                        onInc={() => setTravelersAdults(v => Math.min(9, v + 1))}
                        atMin={travelersAdults <= 1} atMax={travelersAdults >= 9}
                        first
                      />
                      <TRow2
                        label="Children" sub="Ages 2 to 17" val={travelersChildren}
                        onDec={() => { const n = Math.max(0, travelersChildren - 1); setTravelersChildren(n); setTravelersChildAges(p => p.slice(0, n)); }}
                        onInc={() => { setTravelersChildren(v => v + 1); setTravelersChildAges(p => [...p, 2]); }}
                        atMin={travelersChildren <= 0} atMax={travelersChildren >= 9}
                        ages={travelersChildAges}
                        onAgeChange={(i, v) => setTravelersChildAges(p => p.map((a, idx) => idx === i ? v : a))}
                        maxAge={17}
                      />
                      <TRow2
                        label="Infants in seat" sub="Younger than 2" val={travelersInfantsSeat}
                        onDec={() => { const n = Math.max(0, travelersInfantsSeat - 1); setTravelersInfantsSeat(n); setTravelersInfantAges(p => [...p.slice(0, n), ...p.slice(travelersInfantsSeat)]); }}
                        onInc={() => { setTravelersInfantsSeat(v => v + 1); setTravelersInfantAges(p => [...p.slice(0, travelersInfantsSeat), 0, ...p.slice(travelersInfantsSeat)]); }}
                        atMin={travelersInfantsSeat <= 0} atMax={travelersInfantsSeat >= 9}
                        ages={travelersInfantAges.slice(0, travelersInfantsSeat)}
                        onAgeChange={(i, v) => setTravelersInfantAges(p => p.map((a, idx) => idx === i ? v : a))}
                        maxAge={1}
                      />
                      <TRow2
                        label="Infants on lap" sub="Younger than 2" val={travelersInfantsLap}
                        onDec={() => { const n = Math.max(0, travelersInfantsLap - 1); setTravelersInfantsLap(n); setTravelersInfantAges(p => [...p.slice(0, travelersInfantsSeat), ...p.slice(travelersInfantsSeat, travelersInfantsSeat + n)]); }}
                        onInc={() => { setTravelersInfantsLap(v => v + 1); setTravelersInfantAges(p => [...p, 0]); }}
                        atMin={travelersInfantsLap <= 0} atMax={travelersInfantsLap >= 9}
                        ages={travelersInfantAges.slice(travelersInfantsSeat)}
                        onAgeChange={(i, v) => setTravelersInfantAges(p => p.map((a, idx) => idx === travelersInfantsSeat + i ? v : a))}
                        maxAge={1}
                      />
                      <div style={{ height: 8 }} />
                    </motion.div>
                  );
                }

                return null;
              })()}
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
          transition={{ duration: 0.5, ease: ease.inOut, delay: 0.07 }}
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
                transition={{ duration: 0.4, ease: ease.inOut, delay: 0.15 }}
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
                transition={{ duration: 0.4, ease: ease.inOut, delay: 0.22 }}
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
          transition={{ duration: 0.5, ease: ease.inOut, delay: 0.14 }}
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
                transition={{ duration: 0.38, ease: ease.inOut, delay: 0.2 + i * 0.05 }}
                onClick={() => submitQuery(`Stay in ${dest.label}`)}
                whileHover={{ y: -3, boxShadow: '0 8px 32px rgba(12,14,28,0.12)', transition: spring.snap }}
                whileTap={{ scale: 0.97 }}
                style={{
                  flexShrink: 0,
                  width: 180,
                  borderRadius: 16,
                  overflow: 'hidden',
                  cursor: 'pointer',
                  background: glass.card.background,
                  backdropFilter: glass.card.backdropFilter,
                  WebkitBackdropFilter: glass.card.WebkitBackdropFilter,
                  border: glass.card.border,
                  boxShadow: glass.card.boxShadow,
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
      <img src={ASSET_IC_HISTORY} alt="History" style={{ width: 17, height: 17, objectFit: 'contain' }} />
    </button>

    {/* Trips */}
    <button style={sidebarBtnStyle} title="Trips">
      <IconTrips />
    </button>

    {/* Support */}
    <button style={sidebarBtnStyle} title="Support">
      <img src={ASSET_IC_HEADSET} alt="Support" style={{ width: 17, height: 17, objectFit: 'contain' }} />
    </button>

    {/* Account */}
    <button style={sidebarBtnStyle} title="Account">
      <IconAccount />
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
  background: 'rgba(12,14,28,0.07)',
  backdropFilter: 'none',
  WebkitBackdropFilter: 'none',
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
