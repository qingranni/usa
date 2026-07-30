// mockData.ts — Travel search mock data for the web prototype
// Mirrors NarrativeData.swift / MockData.swift authored golden paths

export interface ResultCard {
  id: string;
  title: string;
  subtitle: string;
  price: string;
  priceNote: string;
  imageUrl: string;
  badge?: string;
  rating?: number;
}

export interface Thread {
  id: string;
  title: string;
  query: string;
  chips: string[];
  results: ResultCard[];
  heroImage: string;
  destination: string;
  showsMap: boolean;
}

export const MOCK_RESULTS: ResultCard[] = [
  {
    id: 'r1',
    title: 'Hyatt Ziva Cancun',
    subtitle: 'All-inclusive · Cancun Hotel Zone',
    price: '$389',
    priceNote: '/night · Includes taxes and fees',
    imageUrl: 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800',
    badge: 'Best value',
    rating: 4.8,
  },
  {
    id: 'r2',
    title: 'Moon Palace Golf & Spa',
    subtitle: 'All-inclusive · Cancun',
    price: '$312',
    priceNote: '/night · Includes taxes and fees',
    imageUrl: 'https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800',
    rating: 4.6,
  },
  {
    id: 'r3',
    title: 'Excellence Playa Mujeres',
    subtitle: 'Adults only · Playa Mujeres',
    price: '$445',
    priceNote: '/night · Includes taxes and fees',
    imageUrl: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800',
    badge: 'Top rated',
    rating: 4.9,
  },
  {
    id: 'r4',
    title: 'Iberostar Selection Cancun',
    subtitle: 'All-inclusive · Cancun Hotel Zone',
    price: '$278',
    priceNote: '/night · Includes taxes and fees',
    imageUrl: 'https://images.unsplash.com/photo-1582719508461-905c673771fd?w=800',
    rating: 4.5,
  },
  {
    id: 'r5',
    title: 'Barcelo Maya Riviera',
    subtitle: 'All-inclusive · Riviera Maya',
    price: '$295',
    priceNote: '/night · Includes taxes and fees',
    imageUrl: 'https://images.unsplash.com/photo-1596394516093-501ba68a0ba6?w=800',
    rating: 4.7,
  },
];

export const MOCK_THREADS: Thread[] = [
  {
    id: 't1',
    title: 'Mexico all-inclusive for 2',
    query: 'All-inclusive resorts in Mexico',
    chips: ['Mexico', 'All-inclusive', '2 adults', 'Aug 10–17'],
    results: MOCK_RESULTS,
    heroImage: 'https://images.unsplash.com/photo-1512813498716-3e640fed3c75?w=1200',
    destination: 'Mexico',
    showsMap: true,
  },
  {
    id: 't2',
    title: 'Cancun beach resorts',
    query: 'Beach resorts Cancun with pool',
    chips: ['Cancun', 'Beach', 'Pool', 'Sep 1–8'],
    results: MOCK_RESULTS.slice(0, 3),
    heroImage: 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=1200',
    destination: 'Cancun',
    showsMap: true,
  },
  {
    id: 't3',
    title: 'Flights to Cancun',
    query: 'Nonstop flights New York to Cancun',
    chips: ['New York', 'Cancun', 'Nonstop', 'Aug 10'],
    results: [],
    heroImage: 'https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=1200',
    destination: 'Cancun',
    showsMap: false,
  },
];

export const QUICK_ANSWERS = [
  'What\'s the best time to visit Cancun?',
  'Do I need a visa for Mexico?',
  'What\'s included in all-inclusive?',
];

export const SUGGESTIONS = [
  { label: 'All-inclusive Mexico', icon: '🌴' },
  { label: 'Beach resorts Cancun', icon: '🏖️' },
  { label: 'Flights to Cancun', icon: '✈️' },
  { label: 'Family resorts Caribbean', icon: '👨‍👩‍👧' },
  { label: 'Adults only resorts', icon: '🍹' },
];
