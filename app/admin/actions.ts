'use server'

import { createClient } from '@/lib/supabase/server'

export type GuideDecisionResult =
  | { ok: true; status: string; decidedAt: string; decidedByEmail: string | null }
  | { ok: false; error: string }

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const MAX_REASON_LENGTH = 1000

const ERROR_MESSAGES: Record<string, string> = {
  '28000': 'Your session has expired. Sign in again and retry.',
  '42501': 'Administrator access is required to decide applications.',
  '55000': 'This application has already been decided. Refresh to see its current status.',
  P0002: 'This application no longer exists. Refresh and try again.',
  '22023': 'The decision was not valid. A reason is required when rejecting.',
  '23502': 'This application has no linked student account, so it cannot be decided.',
}

export async function decideGuideApplication(
  applicationId: string,
  decision: 'approved' | 'rejected',
  reason?: string,
): Promise<GuideDecisionResult> {
  if (!UUID_PATTERN.test(applicationId)) return { ok: false, error: 'Invalid application.' }
  if (decision !== 'approved' && decision !== 'rejected') return { ok: false, error: 'Invalid decision.' }

  const trimmedReason = (reason ?? '').trim()
  if (decision === 'rejected' && !trimmedReason) return { ok: false, error: 'Enter a reason before rejecting.' }
  if (trimmedReason.length > MAX_REASON_LENGTH) return { ok: false, error: `Keep the reason under ${MAX_REASON_LENGTH} characters.` }

  const supabase = await createClient()
  const { data: userData } = await supabase.auth.getUser()
  if (!userData.user) return { ok: false, error: ERROR_MESSAGES['28000'] }

  const { data, error } = await supabase.rpc('admin_decide_guide_application', {
    p_application_id: applicationId,
    p_decision: decision,
    p_reason: decision === 'rejected' ? trimmedReason : null,
  })

  if (error) {
    if (error.code === 'PGRST202' || error.code === '42883') {
      return { ok: false, error: 'The guide decision function is not installed yet. Run supabase/migrations/guide-applications-workflow.sql in the Supabase SQL Editor.' }
    }
    return { ok: false, error: ERROR_MESSAGES[error.code] ?? 'The decision was not saved. The application remains pending.' }
  }

  const result = (data ?? {}) as { status?: string; decided_at?: string; decided_by_email?: string | null }
  return {
    ok: true,
    status: result.status ?? (decision === 'approved' ? 'Agreement Required' : 'Rejected'),
    decidedAt: result.decided_at ?? new Date().toISOString(),
    decidedByEmail: result.decided_by_email ?? userData.user.email ?? null,
  }
}
