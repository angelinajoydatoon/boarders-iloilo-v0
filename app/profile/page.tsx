import { Suspense } from 'react'
import { BoardersApp } from '@/components/boarders-app'

export default function ProfilePage() {
  return <Suspense><BoardersApp view="user" /></Suspense>
}
