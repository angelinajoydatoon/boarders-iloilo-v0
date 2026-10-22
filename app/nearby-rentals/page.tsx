import { Suspense } from 'react'
import { BoardersApp } from '@/components/boarders-app'

export default function NearbyRentalsPage() {
  return <Suspense><BoardersApp view="explore" /></Suspense>
}
