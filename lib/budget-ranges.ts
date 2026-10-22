export const BUDGET_RANGES = [
  { label: 'Any budget', min: null, max: null },
  { label: 'Under ₱2,000', min: 0, max: 2000 },
  { label: '₱2,000 to ₱3,000', min: 2000, max: 3000 },
  { label: '₱3,000 to ₱4,000', min: 3000, max: 4000 },
  { label: '₱4,000 to ₱6,000', min: 4000, max: 6000 },
  { label: 'Over ₱6,000', min: 6000, max: null },
] as const

export const DEFAULT_BUDGET = BUDGET_RANGES[0].label

const LEGACY_BUDGET_LABELS: Record<string, string> = {
  'Under ₱4,000': '₱3,000 to ₱4,000',
  '₱4,000–₱6,000': '₱4,000 to ₱6,000',
}

export function getBudgetRange(label: string) {
  const normalizedLabel = LEGACY_BUDGET_LABELS[label] ?? label
  return BUDGET_RANGES.find((range) => range.label === normalizedLabel) ?? BUDGET_RANGES[0]
}

export function matchesBudget(rent: number, label: string) {
  const range = getBudgetRange(label)
  return (range.min === null || rent >= range.min) && (range.max === null || rent < range.max)
}
