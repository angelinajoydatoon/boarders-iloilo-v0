'use client'

export function BoardersFooter() {
  return (
    <footer className="bg-[#102b4e] px-4 py-8 text-blue-100 sm:px-6 sm:py-9" aria-label="Boarders Iloilo footer">
      <div className="mx-auto flex max-w-7xl flex-col gap-5 sm:flex-row sm:items-center sm:justify-between lg:px-3">
        <div className="min-w-0">
          <p className="text-lg font-bold tracking-tight text-white">
            Boarders <span className="text-amber-300">Iloilo</span>
          </p>
          <p className="mt-1 text-sm text-blue-100">Your place in the city.</p>
        </div>
        <p className="max-w-full text-sm text-blue-200/75 sm:text-right">Student housing in Iloilo City</p>
      </div>
    </footer>
  )
}
