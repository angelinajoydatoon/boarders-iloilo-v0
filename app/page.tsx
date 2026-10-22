import { Suspense } from 'react'
import { BoardersApp } from '@/components/boarders-app'

export default function HomePage() {
  return <Suspense><BoardersApp view="home" /></Suspense>
}
