## PIN → City/State Fetch (Google Geocoding)

This feature lets users tap a button beside the PIN (pincode) field to fetch City and State via Google Geocoding, without auto-overwriting manual input.

### Where implemented

- File: `lib/screens/auth/patient_registration_screen.dart`
- Function: `_fetchCityStateFromGoogle()`
- Trigger: PIN field suffix icon (download icon)

### How it works (flow)

1. Reads the PIN from the input field.
2. Calls Google Geocoding API with a postal-code focused query:
   - `https://maps.googleapis.com/maps/api/geocode/json?components=postal_code:<PIN>|country:IN&region=in&key=<API_KEY>`
3. Parses `address_components` for:
   - City: `locality`, `postal_town`, `administrative_area_level_2`, `sublocality`, `sublocality_level_1`
   - State: `administrative_area_level_1`
4. Fills the City/State fields if found.
5. If no results or an API error occurs, shows a friendly message and lets the user enter values manually.

### API key configuration

Preferred (via dart-define at build/run time):

```
--dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```

Fallback (already wired for dev):
- Uses a provided key in code if the env var is missing.

Make sure in Google Cloud:
- Geocoding API is enabled
- Billing is enabled
- API key restrictions allow your platform (Web/Android/iOS) and the Geocoding API

### Error handling & logging

- Console logs include HTTP status/body, Google `status` and `error_message`, and zero‑result cases.
- User sees a clean message: “Could not fetch address. Please enter city and state manually.”

### UX notes

- No auto-fill: users stay in control; fetch is on-demand.
- City/State inputs remain editable after fetch.

### Extending to other registrations

The same pattern will be added to other provider registration screens (hospital, doctor, nurse, lab, pharmacy):

1. Add a suffix icon to the PIN field.
2. Reuse `_fetchCityStateFromGoogle()` (move to a shared utility, e.g., `lib/services/location_service.dart`).
3. Fill that screen’s City/State controllers on success.

### Optional fallback (Nominatim)

If needed, a fallback to OpenStreetMap Nominatim can be added for zero‑result or denied Google requests. This is currently not enabled by default; ask to enable if desired.


