// mockData.ts — Travel search mock data for the web prototype
// Mirrors NarrativeData.swift / MockData.swift authored golden paths

export interface ResultCard {
  id: string;
  title: string;
  subtitle: string;       // e.g. "Flights + stay"
  description?: string;   // body text shown below the photo
  price: string;          // e.g. "$4,850"
  priceNote: string;      // e.g. "avg for 5 nights and 3 travelers"
  imageUrl: string;
  badge?: string;
  rating?: number;
}

export interface Thread {
  id: string;
  title: string;
  query: string;
  description?: string;   // section body paragraph on results page
  chips: string[];
  results: ResultCard[];
  heroImage: string;
  destination: string;
  showsMap: boolean;
}

// ── Mexico beach destination cards (matches Figma node 3031:62409) ────────────

export const MEXICO_RESULTS: ResultCard[] = [
  {
    id: 'mx1',
    title: 'Cancun',
    subtitle: 'Flights + stay',
    description: 'Cancun has the most teen-friendly activities in your budget, but has a loud and busy nightlife scene that may not be ideal for your teens',
    price: '$4,850',
    priceNote: 'avg for 5 nights and 3 travelers',
    imageUrl: 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800',
  },
  {
    id: 'mx2',
    title: 'Puerto Vallarta',
    subtitle: 'Flights + stay',
    description: 'Puerto Vallarta offers charming cobblestone streets and calm bays, perfect for families who want culture alongside the beach',
    price: '$4,780',
    priceNote: 'avg for 5 nights and 3 travelers',
    imageUrl: 'https://images.unsplash.com/photo-1510097467424-192d713fd8b2?w=800',
  },
  {
    id: 'mx3',
    title: 'Playa del Carmen',
    subtitle: 'Flights + stay',
    description: 'Playa del Carmen blends a lively beach strip with easy day trips to cenotes and Mayan ruins — great for adventurous teens',
    price: '$4,720',
    priceNote: 'avg for 5 nights and 3 travelers',
    imageUrl: 'https://images.unsplash.com/photo-1596178065887-1198b6148b2b?w=800',
  },
];

// ── Legacy hotel cards (used by other threads) ───────────────────────────────

export const MOCK_RESULTS: ResultCard[] = [
  {
    id: 'r1',
    title: 'Hyatt Ziva Cancun',
    subtitle: 'All-inclusive · Cancun Hotel Zone',
    description: 'Beachfront all-inclusive with multiple pools, water sports, and family-friendly entertainment every evening',
    price: '$4,860',
    priceNote: 'avg for 5 nights and 3 travelers',
    imageUrl: 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800',
    badge: 'Best value',
    rating: 4.8,
  },
  {
    id: 'r2',
    title: 'Moon Palace Golf & Spa',
    subtitle: 'All-inclusive · Cancun',
    description: 'Sprawling resort with a lazy river, golf course, and a dedicated teens zone for ages 13–17',
    price: '$4,680',
    priceNote: 'avg for 5 nights and 3 travelers',
    imageUrl: 'https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800',
    rating: 4.6,
  },
  {
    id: 'r3',
    title: 'Excellence Playa Mujeres',
    subtitle: 'Adults only · Playa Mujeres',
    description: 'Secluded adults-only resort on a pristine stretch of beach with butler service and overwater bungalows',
    price: '$5,340',
    priceNote: 'avg for 5 nights and 2 travelers',
    imageUrl: 'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800',
    badge: 'Top rated',
    rating: 4.9,
  },
  {
    id: 'r4',
    title: 'Iberostar Selection Cancun',
    subtitle: 'All-inclusive · Cancun Hotel Zone',
    description: 'Prime Hotel Zone location with direct beach access, multiple restaurants, and a large family pool area',
    price: '$4,176',
    priceNote: 'avg for 5 nights and 3 travelers',
    imageUrl: 'https://images.unsplash.com/photo-1582719508461-905c673771fd?w=800',
    rating: 4.5,
  },
  {
    id: 'r5',
    title: 'Barcelo Maya Riviera',
    subtitle: 'All-inclusive · Riviera Maya',
    description: 'Five interconnected resorts sharing a massive beach area, water park, and entertainment complex',
    price: '$4,425',
    priceNote: 'avg for 5 nights and 3 travelers',
    imageUrl: 'https://images.unsplash.com/photo-1596394516093-501ba68a0ba6?w=800',
    rating: 4.7,
  },
];

export const MOCK_THREADS: Thread[] = [
  {
    id: 't1',
    title: 'Mexico beach family trip',
    query: 'Mexico beach family trip',
    description: "From Cancún's energy to Puerto Vallarta's laid-back charm, Mexico's beach towns deliver for teens and stay under budget. Which one is calling you?",
    chips: ['Mexico', 'Week of Mar 14', '3 travelers'],
    results: MEXICO_RESULTS,
    heroImage: 'https://images.unsplash.com/photo-1512813498716-3e640fed3c75?w=1200',
    destination: 'Mexico',
    showsMap: true,
  },
  {
    id: 't2',
    title: 'Cancun beach resorts',
    query: 'Beach resorts Cancun with pool',
    description: 'The best all-inclusive resorts in Cancun for families, ranked by value, beach quality, and teen-friendly amenities.',
    chips: ['Cancun', 'Beach', 'Sep 1–8', '3 travelers'],
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
  "What's the best time to visit Cancun?",
  'Do I need a visa for Mexico?',
  "What's included in all-inclusive?",
];

export const SUGGESTIONS = [
  { label: 'All-inclusive Mexico', icon: '🌴' },
  { label: 'Beach resorts Cancun', icon: '🏖️' },
  { label: 'Flights to Cancun', icon: '✈️' },
  { label: 'Family resorts Caribbean', icon: '👨‍👩‍👧' },
  { label: 'Adults only resorts', icon: '🍹' },
];
