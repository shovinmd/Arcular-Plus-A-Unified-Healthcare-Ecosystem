## Screens ↔ Backend Map (Overview)

Base API URL: `https://arcular-plus-backend.onrender.com`

Backend mounts (Node): `/api/users`, `/api/appointments`, `/api/orders`, `/api/hospitals`, `/api/pharmacies`, `/api/sos`, plus others (doctors, lab, nurse, reminders, ratings, chat).

This document links Flutter screens to the services, endpoints, controllers, and Mongo models they use. Expand sections as needed.

### Common Foundations
- Flutter services: `lib/services/api_service.dart`, `auth_service.dart`, `registration_service.dart`
- Backend: `node_backend/server.js`, `middleware/auth.js` or `firebaseAuthMiddleware`
- Models (key): `User`, `Doctor`, `Hospital`, `Pharmacy`, `Appointment`, `Order`, `LabReport`, `Medicine`, `SOSRequest`

---

## Auth (All Roles)

- Screens
  - `lib/screens/auth/login_screen.dart`
  - Registration screens per role: patient/doctor/hospital/lab/pharmacy

- Flutter services
  - `AuthService` (Firebase auth, Google sign-in)
  - `RegistrationService` (role registrations, docs upload)

- Backend
  - Routes: `/api/users/*`, plus role-specific (`/api/hospitals/register`, doctors, labs, pharmacy)
  - Controllers: `userController`, `hospitalController`, etc.
  - Models: `User`, `Doctor`, `Hospital`, `Lab`, `Pharmacy`

- Typical flow
  1) Login → Firebase ID token
  2) Registration → `registerOrSyncUser` (creates/updates Mongo `User`), role-specific registration

---

## Patient

### Appointments
- Screens
  - `lib/screens/user/appointment_booking_screen.dart`
  - `lib/screens/user/appointment_booking_new_screen.dart`
  - `lib/screens/user/user_appointments_screen.dart`

- Flutter services
  - `ApiService.createAppointment(appointmentData)` → tries routes in order: `/api/hospitals/:hospitalId/appointments`, `/api/appointments/create`, `/api/appointments`, `/api/appointments/book`
  - `ApiService.getUserAppointments({status,page,limit})` → `GET /api/appointments/user` with filters
  - `ApiService.updateAppointmentStatus(appointmentId, status)` → `PUT /api/appointments/:id/status`
  - Other reads used by screens: doctor profile `GET /api/doctors/:id/profile`, hospital info lookup

- Backend
  - Routes: `/api/appointments`, `/api/hospitals/:id/appointments` (hospital-scoped)
  - Controllers: `appointmentController.createAppointment`, `hospitalController.createAppointment`
  - Models: `Appointment`, plus lookups `Doctor`, `Hospital`, `User`

### Orders (Pharmacy)
- Screens
  - User order placement/history under `lib/screens/user/` and pharmacy UIs

- Flutter services
  - `ApiService.placeOrder(userId, items, userAddress, deliveryMethod, paymentMethod, userNotes)` → `POST /api/orders/place`
  - `ApiService.getOrdersByUser(userId)` → `GET /api/orders/user/:userId`
  - Hospital-created pharmacy order: `ApiService.createPharmacyOrder(orderData)` → `POST /api/orders/hospital-order`

- Backend
  - Routes: `/api/orders/*`
  - Controller: `orderController.placeOrder`
  - Models: `Order`, `Pharmacy`, `User`

### Emergency SOS
- Screen
  - `lib/screens/user/emergency_sos_screen.dart`

- Flutter services
  - `ApiService.createSOSRequest(sosData)` → POST `/api/sos/create`
  - `ApiService.getSOSRequestStatus(id)` → GET status
  - `ApiService.cancelSOSRequest(id)` → POST cancel
  - Realtime: `RealtimeSOSService` callbacks (accepted/admitted/status)

- Backend
  - Routes: `/api/sos/*`, `/api/hospitals` (for lists/nearby)
  - Controller: `sosController`
  - Models: `SOSRequest`, `Hospital`, `User`
  
 - Screen connections
   - `EmergencySOSScreen` → loads user via `ApiService.getUserInfo(uid)`; lists hospitals via `ApiService.getNearbyHospitals` (fallback `GET /api/hospitals`)
   - Activates SOS → sets `_activeSosId`, monitors status → shows acceptance/admission/timeouts

---

## Doctor

- Screens
  - `lib/screens/doctor/dashboard_doctor.dart`, `doctor_appointments_screen.dart`, `create_prescription_screen.dart`

- Flutter services
  - Appointments (doctor view): `ApiService.getDoctorAppointments(doctorId, {status})` → `GET /api/appointments/doctor/:doctorId`
  - Complete/cancel/reschedule (hospital/doctor flows): `PUT /api/appointments/:id/status`, specialized endpoints in `appointmentRoutes`
  - Prescriptions: create/list endpoints `POST /api/prescriptions`, `GET /api/prescriptions/doctor/:id`
  - Schedule: `GET/POST /api/doctor-schedule/*` (time slots, availability)

- Backend
  - Routes: `doctorRoutes`, `doctorScheduleRoutes`, `appointmentRoutes`, `prescriptionRoutes`
  - Models: `Doctor`, `Appointment`, `Prescription`, `DoctorSchedule`
  
 - Connections
   - Doctor dashboard pulls upcoming appointments, patient info via `User`
   - Creating prescription ties to `Appointment` and stores `Prescription`

---

## Hospital

- Screens
  - `lib/screens/hospital/*` (dashboard, staff, pharmacy, records)

- Flutter services
  - `ApiService.getHospitalInfo(uid)` → `GET /api/hospitals/uid/:uid`
  - Hospital-scoped appointment create: `POST /api/hospitals/:id/appointments`
  - Staff and records screens call corresponding records endpoints

- Backend
  - Routes: `hospitalRoutes` (profile/search/register/geo), hospital-scoped appointments
  - Models: `Hospital`, `Appointment`, `HospitalRecord`, `Staff`
  
 - Connections
   - Hospital dashboard shows pending approvals, staff, appointments, pharmacy orders
   - Location updates: `PUT /api/hospitals/:hospitalId/location`

---

## Pharmacy

- Screens
  - `lib/screens/pharmacy/*` and `lib/screens/hospital/manage_pharmacy_screen.dart`

- Flutter services
  - Inventory/medicine APIs: `GET/POST /api/medicine/*`, `GET/POST /api/pharmacy-inventory/*`
  - Orders: `ApiService.getHospitalOrders(hospitalId)` → `GET /api/orders/hospital/:hospitalId`, `createPharmacyOrder`

- Backend
  - Routes: `pharmacyRoutes`, `pharmacyInventoryRoutes`, `medicineRoutes`, `orderRoutes`
  - Models: `Pharmacy`, `Medicine`, `Order`
  
 - Connections
   - Inventory management ties `Medicine` to `Pharmacy`
   - Orders flow from `User` → `Order` → `Pharmacy`

---

## Lab

- Screens
  - `lib/screens/lab/*`

- Backend
  - Routes: `labRoutes`, `reportRoutes`, `testRequestRoutes`
  - Models: `Lab`, `LabReport`, `Report`, `TestRequest`
  
 - Connections
   - Test requests create `TestRequest`; results stored as `LabReport`/`Report`

---

## Nurse

- Screens
  - `lib/screens/nurse/*`

- Backend
  - Routes: `nurseRoutes`, `patientAssignmentRoutes`, `vitalsRoutes`, `nurseTalkRoutes`
  - Models: `Nurse`, `PatientAssignment`, `PatientVital`, `NurseTalk`, `ChatMessage`
  
 - Connections
   - Nurse dashboards read `PatientAssignment`; vitals recorded to `PatientVital` linked to `User`

---

## Notes
- All client requests include Firebase ID token; backend authenticates and populates `req.user`.
- Extend each section with exact screen widgets → service methods → route/controller → model fields as needed.

---

## Quick Index (Screens → Services → Endpoints → Models)

- Auth/Login
  - Screens: `auth/login_screen.dart`
  - Services: `AuthService`, `RegistrationService`
  - Endpoints: `/api/users/*`, role `/api/hospitals/register` etc.
  - Models: `User`, `Hospital`/`Doctor`/`Lab`/`Pharmacy`

- Patient Appointments
  - Screens: `user/appointment_booking_screen.dart`
  - Services: `ApiService.createAppointment`, `getUserAppointments`
  - Endpoints: `/api/appointments`, `/api/hospitals/:id/appointments`
  - Models: `Appointment`, `Doctor`, `Hospital`, `User`

- Patient Orders
  - Screens: user order screens
  - Services: `ApiService.placeOrder`, `getOrdersByUser`
  - Endpoints: `/api/orders/place`, `/api/orders/user/:id`
  - Models: `Order`, `Pharmacy`, `User`

- SOS
  - Screens: `user/emergency_sos_screen.dart`
  - Services: `ApiService.createSOSRequest`, `getSOSRequestStatus`, `cancelSOSRequest`
  - Endpoints: `/api/sos/create`, `/api/sos/:id/status`, `/api/sos/:id/cancel`
  - Models: `SOSRequest`, `Hospital`, `User`

- Doctor
  - Screens: `doctor/dashboard_doctor.dart`, `doctor_appointments_screen.dart`
  - Services: `getDoctorAppointments`, schedule APIs
  - Endpoints: `/api/appointments/doctor/:id`, `/api/doctor-schedule/*`
  - Models: `Doctor`, `Appointment`, `DoctorSchedule`

- Hospital
  - Screens: `hospital/*`
  - Services: `getHospitalInfo`, hospital appointments
  - Endpoints: `/api/hospitals/uid/:uid`, `/api/hospitals/:id/appointments`
  - Models: `Hospital`, `Appointment`

- Pharmacy
  - Screens: `pharmacy/*`, `hospital/manage_pharmacy_screen.dart`
  - Services: inventory, `getHospitalOrders`, `createPharmacyOrder`
  - Endpoints: `/api/medicine/*`, `/api/pharmacy-inventory/*`, `/api/orders/*`
  - Models: `Pharmacy`, `Medicine`, `Order`

- Lab
  - Screens: `lab/*`
  - Endpoints: `labRoutes`, `reportRoutes`, `testRequestRoutes`
  - Models: `Lab`, `LabReport`, `Report`, `TestRequest`

- Nurse
  - Screens: `nurse/*`
  - Endpoints: `nurseRoutes`, `patientAssignmentRoutes`, `vitalsRoutes`, `nurseTalkRoutes`
  - Models: `Nurse`, `PatientAssignment`, `PatientVital`, `NurseTalk`, `ChatMessage`


