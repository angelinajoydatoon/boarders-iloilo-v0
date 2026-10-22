'use client'

import { FormEvent, useEffect, useMemo, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

const siteUrl = () => (process.env.NEXT_PUBLIC_SITE_URL?.replace(/\/$/, '') || window.location.origin)

export function ForgotPasswordForm() {
  const supabase = useMemo(() => createClient(), [])
  const [email, setEmail] = useState('')
  const [status, setStatus] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError(''); setStatus('')
    if (!/^\S+@\S+\.\S+$/.test(email)) return setError('Enter a valid email address.')
    setLoading(true)
    const { error: resetError } = await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo: `${siteUrl()}/auth/callback?next=/reset-password` })
    setLoading(false)
    if (resetError) return setError('We could not send the reset email. Please try again shortly.')
    setStatus('If an account matches that email, you will receive a password reset link shortly.')
  }

  return <main className="min-h-[70vh] bg-[#f7f8fa] px-4 py-12 text-[#11243d] sm:px-6 lg:py-20"><div className="mx-auto max-w-lg rounded-3xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8"><p className="text-sm font-bold uppercase tracking-[.18em] text-amber-600">Account recovery</p><h1 className="mt-2 text-3xl font-bold">Forgot your password?</h1><p className="mt-3 text-slate-500">Enter your email and we&apos;ll send a secure link to reset your password.</p><form onSubmit={submit} className="mt-7 space-y-5"><label className="block text-sm font-bold">Email address<input type="email" autoComplete="email" value={email} onChange={(event) => setEmail(event.target.value)} className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 font-normal outline-none focus:border-amber-400 focus:ring-2 focus:ring-amber-100" /></label><button disabled={loading} className="w-full rounded-xl bg-[#102b4e] px-4 py-3 font-bold text-white disabled:opacity-50">{loading ? 'Sending…' : 'Send reset link'}</button></form>{status && <p role="status" className="mt-5 rounded-2xl bg-emerald-50 px-4 py-3 text-sm font-semibold text-emerald-700">{status}</p>}{error && <p role="alert" className="mt-5 rounded-2xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">{error}</p>}<a href="/profile" className="mt-6 inline-block text-sm font-bold text-[#102b4e] underline underline-offset-4">Back to login</a></div></main>
}

export function ResetPasswordForm() {
  const supabase = useMemo(() => createClient(), [])
  const router = useRouter()
  const [password, setPassword] = useState('')
  const [confirmation, setConfirmation] = useState('')
  const [status, setStatus] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (new URLSearchParams(window.location.search).get('auth') === 'error') setError('This recovery link is invalid or has expired. Request a new one.')
  }, [])

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError(''); setStatus('')
    if (password.length < 8) return setError('Use at least 8 characters for your password.')
    if (password !== confirmation) return setError('Passwords do not match.')
    setLoading(true)
    const { data } = await supabase.auth.getSession()
    if (!data.session) { setLoading(false); return setError('This recovery link is invalid or has expired. Request a new one.') }
    const { error: updateError } = await supabase.auth.updateUser({ password })
    setLoading(false)
    if (updateError) return setError('We could not update your password. Request a new link and try again.')
    setStatus('Your password has been reset. You can now log in with your new password.')
    setTimeout(() => router.push('/profile'), 900)
  }

  return <main className="min-h-[70vh] bg-[#f7f8fa] px-4 py-12 text-[#11243d] sm:px-6 lg:py-20"><div className="mx-auto max-w-lg rounded-3xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8"><p className="text-sm font-bold uppercase tracking-[.18em] text-amber-600">Account recovery</p><h1 className="mt-2 text-3xl font-bold">Choose a new password</h1><p className="mt-3 text-slate-500">Use at least 8 characters. Your previous password will stop working after this update.</p><form onSubmit={submit} className="mt-7 space-y-5"><label className="block text-sm font-bold">New password<input type="password" autoComplete="new-password" value={password} onChange={(event) => setPassword(event.target.value)} className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 font-normal outline-none focus:border-amber-400 focus:ring-2 focus:ring-amber-100" /></label><label className="block text-sm font-bold">Confirm new password<input type="password" autoComplete="new-password" value={confirmation} onChange={(event) => setConfirmation(event.target.value)} className="mt-2 w-full rounded-xl border border-slate-200 px-4 py-3 font-normal outline-none focus:border-amber-400 focus:ring-2 focus:ring-amber-100" /></label><button disabled={loading} className="w-full rounded-xl bg-[#102b4e] px-4 py-3 font-bold text-white disabled:opacity-50">{loading ? 'Updating…' : 'Reset password'}</button></form>{status && <p role="status" className="mt-5 rounded-2xl bg-emerald-50 px-4 py-3 text-sm font-semibold text-emerald-700">{status}</p>}{error && <p role="alert" className="mt-5 rounded-2xl bg-red-50 px-4 py-3 text-sm font-semibold text-red-700">{error}</p>}</div></main>
}
