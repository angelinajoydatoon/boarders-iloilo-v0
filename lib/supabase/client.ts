import { createBrowserClient } from '@supabase/ssr'

let browserClient: ReturnType<typeof createBrowserClient> | undefined

export function createClient() {
  if (!browserClient) {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
    const supabaseKey =
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

    if (!supabaseUrl || !supabaseKey) {
      throw new Error('Supabase client configuration is unavailable in this preview.')
    }

    browserClient = createBrowserClient(supabaseUrl, supabaseKey, {
      cookieOptions: { secure: process.env.NODE_ENV === 'production' },
    })
  }

  return browserClient
}
