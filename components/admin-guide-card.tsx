'use client'

import { useState } from 'react'
import { Check, Loader2, X } from 'lucide-react'
import { formatDecisionDate, guideStatusTone, isPendingGuide, type GuideRow } from '@/lib/guide-applications'

const toneClass = {
  pending: 'bg-amber-100 text-amber-800',
  approved: 'bg-emerald-100 text-emerald-800',
  rejected: 'bg-red-100 text-red-800',
}

export function GuideStatusBadge({ status }: { status: string }) {
  return <span className={`inline-flex h-fit shrink-0 items-center self-start whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-bold leading-5 ${toneClass[guideStatusTone(status)]}`}>{status}</span>
}

export function AdminGuideCard({ item, busy, leaving, error, onDecide }: {
  item: GuideRow
  busy: boolean
  leaving: boolean
  error: string | undefined
  onDecide: (id: string, decision: 'approved' | 'rejected', reason?: string) => Promise<boolean>
}) {
  const [rejecting, setRejecting] = useState(false)
  const [reason, setReason] = useState('')
  const pending = isPendingGuide(item.status)
  const tone = guideStatusTone(item.status)

  async function confirmReject() {
    const saved = await onDecide(item.id, 'rejected', reason)
    if (saved) setRejecting(false)
  }

  return (
    <article aria-busy={busy} className={`rounded-3xl border border-slate-200 bg-white p-5 shadow-sm transition-opacity duration-500 motion-reduce:transition-none ${leaving ? 'pointer-events-none opacity-0' : 'opacity-100'}`}>
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-xs font-bold uppercase tracking-wide text-slate-400">Application {item.id.slice(0, 8)}</p>
          <h2 className="mt-1 font-bold">{item.full_name}</h2>
          <p className="mt-1 break-words text-sm text-slate-500">{item.email} · {item.school}</p>
        </div>
        <GuideStatusBadge status={item.status} />
      </div>
      <div className="mt-4 grid gap-2 text-sm sm:grid-cols-2">
        <p><strong>Service area:</strong> {item.service_area}</p>
        <p><strong>Availability:</strong> {item.availability}</p>
        <p><strong>Submitted:</strong> {new Date(item.created_at).toLocaleDateString('en-PH')}</p>
      </div>

      {pending && !rejecting && (
        <div className="mt-5 flex flex-wrap gap-2">
          <button type="button" disabled={busy} onClick={() => void onDecide(item.id, 'approved')} className="inline-flex min-h-10 items-center gap-2 rounded-full bg-emerald-700 px-4 text-sm font-bold text-white disabled:cursor-not-allowed disabled:opacity-60">
            {busy ? <Loader2 className="size-4 animate-spin" aria-hidden="true" /> : <Check className="size-4" aria-hidden="true" />}
            {busy ? 'Approving…' : 'Approve'}
          </button>
          <button type="button" disabled={busy} onClick={() => setRejecting(true)} className="inline-flex min-h-10 items-center gap-2 rounded-full bg-red-700 px-4 text-sm font-bold text-white disabled:cursor-not-allowed disabled:opacity-60">
            <X className="size-4" aria-hidden="true" />Reject
          </button>
        </div>
      )}

      {pending && rejecting && (
        <div className="mt-5 rounded-2xl border border-red-200 bg-red-50 p-4">
          <label htmlFor={`reject-${item.id}`} className="text-sm font-bold text-red-900">Reason for rejection (required)</label>
          <textarea id={`reject-${item.id}`} value={reason} onChange={(event) => setReason(event.target.value)} maxLength={1000} rows={3} disabled={busy} className="mt-2 w-full rounded-xl border border-red-200 bg-white px-3 py-2 text-sm outline-none focus:border-red-400 focus:ring-2 focus:ring-red-100 disabled:opacity-60" placeholder="The student will see this reason." />
          <div className="mt-3 flex flex-wrap gap-2">
            <button type="button" disabled={busy || !reason.trim()} onClick={() => void confirmReject()} className="inline-flex min-h-10 items-center gap-2 rounded-full bg-red-700 px-4 text-sm font-bold text-white disabled:cursor-not-allowed disabled:opacity-60">
              {busy ? <Loader2 className="size-4 animate-spin" aria-hidden="true" /> : <X className="size-4" aria-hidden="true" />}
              {busy ? 'Rejecting…' : 'Confirm rejection'}
            </button>
            <button type="button" disabled={busy} onClick={() => { setRejecting(false); setReason('') }} className="inline-flex min-h-10 items-center rounded-full border border-slate-300 bg-white px-4 text-sm font-bold text-slate-700 disabled:opacity-60">Cancel</button>
          </div>
        </div>
      )}

      {!pending && (
        <div className="mt-5 w-full text-sm font-semibold text-slate-600">
          {tone === 'rejected' ? 'Rejected' : 'Approved'} by {item.decided_by_email ?? item.decided_by ?? 'an administrator'} on {formatDecisionDate(item.decided_at)}
          {tone === 'rejected' && item.decision_reason ? ` · Reason: ${item.decision_reason}` : ''}
        </div>
      )}

      {error && <p role="alert" className="mt-4 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-semibold text-red-800">{error}</p>}
    </article>
  )
}
