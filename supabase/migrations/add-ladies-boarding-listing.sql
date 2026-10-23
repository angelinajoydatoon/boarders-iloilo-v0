-- Add the code-backed listing required by viewing_requests.property_id.
-- Approval required before executing this migration.
insert into public.properties (id, title, details)
values (
  'wvsu-ladies-boarding-house',
  'WVSU Ladies Boarding House',
  jsonb_build_object(
    'area', 'Iloilo City',
    'university', 'West Visayas State University (WVSU)',
    'rent', 4000,
    'distance', '900 m from West Visayas State University',
    'room_type', 'Solo',
    'policy', 'Female-only',
    'curfew', 'Not specified',
    'availability', 'Available',
    'contract', '1 month deposit',
    'bathroom', 'Common bathroom with lockers for tenants',
    'cooking', 'Dirty kitchen and dining area available',
    'wifi_details', '₱200/month (free for a solo tenant)',
    'contract_details', '1 month deposit',
    'gate_distance', '900 m from West Visayas State University',
    'laundry', 'Laundry area available',
    'electricity', 'Monthly submeter reading',
    'water', '₱100 per head (free for a solo tenant)',
    'pets', 'Allowed (requires a responsible owner)',
    'security', 'Owner states: fire safety certified, with Certificate of Occupancy, DTI, BIR, and Business Permit',
    'nearby', 'Dorm restaurant on-site, Mission Hospital, Treeple Brew'
  )
)
on conflict (id) do nothing;
