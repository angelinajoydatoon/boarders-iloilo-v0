export const PROPERTY_NAMES: Record<string, string> = {
  '1': 'Luna House',
  '2': 'The Study Nook',
  '3': 'Amber Residences',
  '4': 'Casa Verde Boarding',
  'wvsu-ladies-boarding-house': 'WVSU Ladies Boarding House',
}

export function propertyNameFor(id: string | null | undefined) {
  return id ? PROPERTY_NAMES[id] ?? 'Unlisted property' : 'General report'
}
