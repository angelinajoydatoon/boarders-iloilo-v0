export type GuideRow = {
  id: string
  full_name: string
  email: string
  school: string
  service_area: string
  availability: string
  status: string
  created_at: string
  decided_by?: string | null
  decided_by_email?: string | null
  decided_at?: string | null
  decision_reason?: string | null
}

export const GUIDE_BASE_COLUMNS = 'id, full_name, email, school, service_area, availability, status, created_at'
export const GUIDE_DECISION_COLUMNS = `${GUIDE_BASE_COLUMNS}, decided_by, decided_by_email, decided_at, decision_reason`

export function isPendingGuide(status: string) {
  return status.trim().toLowerCase() === 'pending review'
}

export function guideStatusTone(status: string): 'pending' | 'approved' | 'rejected' {
  const normalized = status.trim().toLowerCase()
  if (normalized.startsWith('approved') || normalized === 'active student guide') return 'approved'
  if (normalized === 'rejected' || normalized === 'declined') return 'rejected'
  return 'pending'
}

export function formatDecisionDate(value: string | null | undefined) {
  if (!value) return 'a previous date'
  return new Date(value).toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' })
}
