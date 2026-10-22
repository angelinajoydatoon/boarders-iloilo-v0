export const UNIVERSITIES = [
  'All universities',
  'Iloilo Science and Technology University (ISATU)',
  'West Visayas State University (WVSU)',
  'University of Iloilo (UI) – PHINMA',
  'University of San Agustin (USA)',
  'Central Philippine University (CPU)',
  'University of the Philippines Visayas (UPV)',
  'Iloilo State University of Fisheries Science and Technology (ISUFST)',
  'St. Paul University Iloilo (SPUI)',
  'John B. Lacson Foundation Maritime University (JBLFMU)',
  'Western Institute of Technology (WIT)',
  'Other / not listed',
] as const

export const QUICK_LINK_UNIVERSITIES = UNIVERSITIES.slice(1, 5)
export const UNIVERSITY_DEFAULT = UNIVERSITIES[0]
export type University = (typeof UNIVERSITIES)[number]
