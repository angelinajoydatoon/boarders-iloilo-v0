'use client'

import { useMemo, useState } from 'react'
import Link from 'next/link'
import { ArrowLeft, Clock3, MapPin, Search, Utensils, X } from 'lucide-react'

type NearbyPlace = {
  id: string
  name: string
  category: string
  description: string
  distance: string
  walk: string
  hours: string
  open: boolean
  offerings: string[]
  prices: string[]
  image: string
}

const places: NearbyPlace[] = [
  {
    id: 'treeple-brew',
    name: 'Treeple Brew Cafe',
    category: 'Cafés',
    description: 'A relaxed study-friendly café near WVSU for coffee, merienda, and quick catch-ups.',
    distance: '350 m from WVSU',
    walk: '5 min walk',
    hours: '7:00 AM – 9:00 PM',
    open: true,
    offerings: ['Iced coffee', 'Hot coffee', 'Pastries', 'Wi-Fi-friendly seating'],
    prices: ['Brewed coffee · ₱85', 'Iced latte · ₱120', 'Croissant · ₱95'],
    image: '/nearby/treeple-brew.png',
  },
  {
    id: 'alma-carinderia',
    name: 'Alma Carinderia',
    category: 'Carinderias',
    description: 'Everyday Filipino rice meals and silog plates for a filling student budget lunch.',
    distance: '280 m from WVSU',
    walk: '4 min walk',
    hours: '6:00 AM – 8:00 PM',
    open: true,
    offerings: ['Rice meals', 'Silog plates', 'Vegetable dishes', 'Takeaway meals'],
    prices: ['Chicken meal · ₱95', 'Porksilog · ₱110', 'Vegetable dish · ₱55'],
    image: '/nearby/alma-carinderia.png',
  },
  {
    id: 'corner-sari-sari',
    name: 'Corner Sari-Sari',
    category: 'Convenience Stores',
    description: 'A neighborhood stop for snacks, drinks, toiletries, and small everyday essentials.',
    distance: '420 m from WVSU',
    walk: '5 min walk',
    hours: '6:00 AM – 10:00 PM',
    open: true,
    offerings: ['Groceries', 'Toiletries', 'Cold drinks', 'Load and essentials'],
    prices: ['Bottled water · ₱25', 'Shampoo sachet · ₱12', 'Instant noodles · ₱18'],
    image: '/nearby/sari-sari.png',
  },
  {
    id: 'joes-bbq',
    name: "Joe's BBQ & Snacks",
    category: 'Food Stalls',
    description: 'An easy evening stop for grilled snacks, banana cue, and cold drinks on the way home.',
    distance: '500 m from WVSU',
    walk: '6 min walk',
    hours: '4:00 PM – 10:00 PM',
    open: false,
    offerings: ['Barbecue skewers', 'Banana cue', 'Fish balls', 'Takeaway drinks'],
    prices: ['BBQ stick · ₱25', 'Banana cue · ₱35', 'Iced tea · ₱30'],
    image: '/nearby/joes-bbq.png',
  },
]

const categories = ['All', ...Array.from(new Set(places.map((place) => place.category)))]

export function NearbyDirectory() {
  const [category, setCategory] = useState('All')
  const [query, setQuery] = useState('')
  const [selected, setSelected] = useState<NearbyPlace | null>(null)
  const filtered = useMemo(() => places.filter((place) => {
    const matchesCategory = category === 'All' || place.category === category
    const haystack = `${place.name} ${place.category} ${place.description} ${place.offerings.join(' ')}`.toLowerCase()
    return matchesCategory && haystack.includes(query.toLowerCase().trim())
  }), [category, query])

  return <main className="min-h-screen bg-[#f8f6f1] text-[#102b4e]">
    <header className="border-b border-[#102b4e]/10 bg-white/90 backdrop-blur">
      <div className="mx-auto flex max-w-7xl items-center justify-between gap-4 px-5 py-4 sm:px-8">
        <Link href="/nearby-rentals" className="inline-flex items-center gap-2 text-sm font-bold text-[#102b4e] transition hover:text-amber-600"><ArrowLeft className="size-4" /> Back to viewing form</Link>
        <span className="hidden rounded-full bg-amber-100 px-3 py-1.5 text-xs font-bold text-amber-800 sm:inline-flex">Sample neighborhood guide</span>
      </div>
    </header>
    <section className="mx-auto max-w-7xl px-5 pb-7 pt-10 sm:px-8 sm:pt-14">
      <div className="max-w-3xl"><p className="text-xs font-bold uppercase tracking-[0.22em] text-amber-600">Around your next home</p><h1 className="mt-3 text-4xl font-black tracking-tight sm:text-6xl">Nearby, within a short walk.</h1><p className="mt-4 max-w-2xl text-base leading-7 text-slate-600 sm:text-lg">Explore sample places near West Visayas State University before you submit a viewing request. Walking times, prices, hours, and images are estimates for planning only and are not verified business information.</p></div>
      <div className="mt-8 flex flex-col gap-3 rounded-3xl border border-[#102b4e]/10 bg-white p-3 shadow-sm sm:flex-row sm:items-center sm:p-4"><label className="flex min-h-12 flex-1 items-center gap-3 rounded-2xl bg-[#f8f6f1] px-4"><Search className="size-5 text-slate-400" /><span className="sr-only">Search nearby places</span><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search cafés, rice meals, toiletries..." className="w-full bg-transparent text-sm font-semibold outline-none placeholder:text-slate-400" /></label><div className="flex gap-2 overflow-x-auto pb-1" aria-label="Filter nearby places">{categories.map((item) => <button key={item} type="button" onClick={() => setCategory(item)} className={`whitespace-nowrap rounded-full px-4 py-2.5 text-sm font-bold transition ${category === item ? 'bg-[#102b4e] text-white' : 'bg-slate-100 text-slate-600 hover:bg-amber-100 hover:text-[#102b4e]'}`}>{item}</button>)}</div></div>
    </section>
    <section className="mx-auto max-w-7xl px-5 pb-16 sm:px-8" aria-live="polite"><div className="mb-5 flex items-center justify-between"><p className="text-sm font-bold text-slate-500">{filtered.length} places near WVSU</p><p className="hidden text-xs font-semibold text-slate-400 sm:block">Approximate 5-minute walking radius</p></div>{filtered.length ? <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">{filtered.map((place) => <article key={place.id} className="group overflow-hidden rounded-3xl border border-[#102b4e]/10 bg-white shadow-sm transition hover:-translate-y-1 hover:shadow-xl"><div className="relative aspect-[4/3] overflow-hidden"><img src={place.image} alt={`${place.name} sample image`} className="h-full w-full object-cover transition duration-500 group-hover:scale-105" /><span className={`absolute left-3 top-3 rounded-full px-2.5 py-1 text-[11px] font-black ${place.open ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-100 text-slate-600'}`}>{place.open ? 'Open · sample status' : 'Closed · sample status'}</span></div><div className="p-5"><div className="flex items-start justify-between gap-3"><div><p className="text-xs font-bold uppercase tracking-wider text-amber-600">{place.category}</p><h2 className="mt-1 text-xl font-black">{place.name}</h2></div><Utensils className="mt-1 size-5 shrink-0 text-amber-500" /></div><p className="mt-3 line-clamp-2 text-sm leading-6 text-slate-600">{place.description}</p><div className="mt-4 flex flex-wrap gap-2 text-xs font-bold text-slate-500"><span className="inline-flex items-center gap-1"><MapPin className="size-3.5" />{place.distance}</span><span className="inline-flex items-center gap-1"><Clock3 className="size-3.5" />{place.walk}</span></div><button type="button" onClick={() => setSelected(place)} className="mt-5 w-full rounded-2xl bg-[#102b4e] px-4 py-3 text-sm font-bold text-white transition hover:bg-[#173b67] focus:outline-none focus-visible:ring-4 focus-visible:ring-amber-200">View details</button></div></article>)}</div> : <div className="rounded-3xl border border-dashed border-slate-300 bg-white p-12 text-center"><p className="font-bold">No nearby places match that search.</p><button type="button" onClick={() => { setCategory('All'); setQuery('') }} className="mt-3 text-sm font-bold text-amber-700 underline">Clear filters</button></div>}</section>
    {selected && <div className="fixed inset-0 z-50 grid place-items-center bg-[#102b4e]/55 p-4" role="presentation" onClick={() => setSelected(null)}><article role="dialog" aria-modal="true" aria-labelledby="nearby-detail-title" onClick={(event) => event.stopPropagation()} className="max-h-[92vh] w-full max-w-2xl overflow-y-auto rounded-3xl bg-white shadow-2xl"><div className="relative"><img src={selected.image} alt={`${selected.name} sample image`} className="h-56 w-full object-cover sm:h-72" /><button type="button" onClick={() => setSelected(null)} aria-label="Close nearby place details" className="absolute right-4 top-4 grid size-10 place-items-center rounded-full bg-white/95 text-[#102b4e] shadow"><X className="size-5" /></button></div><div className="p-6 sm:p-8"><p className="text-xs font-bold uppercase tracking-wider text-amber-600">{selected.category} · {selected.walk}</p><h2 id="nearby-detail-title" className="mt-2 text-3xl font-black">{selected.name}</h2><p className="mt-3 leading-7 text-slate-600">{selected.description}</p><div className="mt-6 grid gap-4 sm:grid-cols-2"><div className="rounded-2xl bg-[#f8f6f1] p-4"><p className="text-xs font-black uppercase tracking-wider text-slate-400">Hours</p><p className="mt-2 font-bold">{selected.hours}</p><p className="mt-1 text-xs text-slate-500">Sample estimate; verify before visiting.</p></div><div className="rounded-2xl bg-[#f8f6f1] p-4"><p className="text-xs font-black uppercase tracking-wider text-slate-400">Location</p><p className="mt-2 font-bold">{selected.distance}</p><p className="mt-1 text-xs text-slate-500">Approximate walking distance.</p></div></div><div className="mt-6 grid gap-5 sm:grid-cols-2"><div><h3 className="font-black">Available here</h3><ul className="mt-3 space-y-2 text-sm text-slate-600">{selected.offerings.map((item) => <li key={item}>· {item}</li>)}</ul></div><div><h3 className="font-black">Sample prices</h3><ul className="mt-3 space-y-2 text-sm text-slate-600">{selected.prices.map((item) => <li key={item}>· {item}</li>)}</ul></div></div><p className="mt-7 rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-xs font-semibold leading-5 text-amber-900">Sample listing for planning only. Prices, availability, opening hours, walking time, and images are not verified facts.</p><Link href="/nearby-rentals" className="mt-6 inline-flex w-full items-center justify-center rounded-2xl border border-[#102b4e] px-4 py-3 text-sm font-bold text-[#102b4e]">Return to viewing form</Link></div></article></div>}
  </main>
}
