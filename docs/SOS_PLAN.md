## SOS Feature Plan (Non-breaking)

Scope
- Implement end-to-end SOS between user → hospital (staff/admin), without disrupting existing backend or screens.
- Reuse existing auth, models, notification service when possible.

Non-breaking constraints
- Do not modify or remove existing endpoints or behavior.
- Add new model, routes, and minimal integrations behind new paths only.
- Guard with Firebase auth and hospital scoping.

Data Model: `SOS`
- Fields:
  - userId (String, required, Firebase UID)
  - hospitalId (String, required, Mongo ObjectId as string)
  - location: { lat: Number, lng: Number } (optional)
  - category: String (e.g., medical, security) (optional)
  - priority: String (Low|Medium|High|Critical) (default Medium)
  - description: String (optional)
  - status: String (open|acknowledged|assigned|resolved|cancelled) (default open)
  - assignedTo: String (staff UID or Mongo _id as string, optional)
  - notes: [{ by: String, text: String, at: Date }]
  - createdAt, updatedAt

Backend Endpoints (new)
- User-side
  - POST `/api/sos/create` → create SOS (auth required)
  - GET `/api/sos/my` → list my SOS
  - GET `/api/sos/:id` → SOS details (owner or hospital staff)
- Hospital-side (auth + hospital scope)
  - GET `/api/sos/hospital/:hospitalId` (query: status, from, to) → inbox
  - PATCH `/api/sos/:id/assign` { assignedTo } → assign responder
  - PATCH `/api/sos/:id/status` { status } → change status
  - PATCH `/api/sos/:id/notes` { text } → append operational note

Authorization
- All routes protected by Firebase token via existing middleware.
- Hospital routes require staff/admin linked to the hospital (use existing Nurse/Doctor/Hospital models to validate).

Notifications (reuse FCM service)
- On create: notify hospital admins/staff of the hospitalId.
- On assign/status change: notify SOS owner (user) and assigned staff.

Frontend Work
- User app
  - Add SOS Quick Action (capture short description, priority, location if allowed).
  - Submit to `/api/sos/create` and show success toast.
  - SOS History screen: list + status chips, detail view with notes timeline.
- Hospital dashboard
  - SOS Inbox tab: filters by status; show list with priority and relative time.
  - Detail drawer/modal: assign staff, update status, add notes.
  - Poll every 5–10s (can upgrade to socket later).

Telemetry & Logs
- Add concise server logs on create/assign/status change.
- Avoid verbose logs in production.

Validation
- Limit description length, validate priority and status enums.
- Enforce hospitalId is a valid ObjectId string.

Rate Limiting (basic)
- Throttle SOS create per user (e.g., 1 every 60s) to prevent abuse.

Phased Delivery (tomorrow)
1) Model + routes skeleton; unit-test create/list.
2) Hospital inbox GET + status/assign/notes.
3) User UI: Quick Action + History (read-only first), then create.
4) Hospital UI: Inbox + Detail actions.
5) Notifications wiring.

Rollout & Safety
- Feature flags not required; new endpoints are additive.
- Revert path: disable new routes via server config if needed.


