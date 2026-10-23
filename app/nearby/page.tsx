import type { Metadata } from 'next'
import { NearbyDirectory } from '@/components/nearby-directory'

export const metadata: Metadata = {
  title: 'Nearby | Boarders Iloilo',
  description: 'Explore sample cafés, carinderias, convenience stores, and food stalls near WVSU.',
}

export default function NearbyPage() {
  return <NearbyDirectory />
}
