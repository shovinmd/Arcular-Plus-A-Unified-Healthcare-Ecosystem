## Combined User Sequence Diagram

Open in a Markdown preview that supports Mermaid to view the diagram.

```mermaid
sequenceDiagram
  autonumber
  actor U as User (Patient)
  participant A as App (Flutter)
  participant S as ApiService
  participant B as Backend (Express)
  participant F as Firebase Auth
  participant M as MongoDB (Models)
  participant H as Hospital
  participant P as Pharmacy

  rect rgb(245,245,245)
  note over U,A: Login / Registration
  U->>A: Open app
  A->>F: Check session
  alt Not authenticated
    U->>A: Login (Email/Google) or Register
    A->>F: Sign-in / Create user
    F-->>A: ID Token
    A->>S: getUserInfo(uid)
    S->>B: GET /api/users/:uid (Bearer ID Token)
    B->>M: Find User by uid
    M-->>B: User
    B-->>S: 200 User
    S-->>A: UserModel
  else Authenticated
    A->>S: getUserInfo(uid)
    S->>B: GET /api/users/:uid
    B->>M: Find User by uid
    M-->>B: User
    B-->>S: 200 User
    S-->>A: UserModel
  end
  A-->>U: Show Dashboard
  end

  rect rgb(245,255,245)
  note over U,A: Book Appointment
  U->>A: Select doctor, hospital, slot
  A->>S: createAppointment(data)
  alt Hospital-scoped route
    S->>B: POST /api/hospitals/:id/appointments
  else Generic route
    S->>B: POST /api/appointments
  end
  B->>M: Validate user/doctor/hospital, check slot
  M-->>B: OK / Conflict
  alt Created
    B-->>S: 201 Appointment
    S-->>A: success
    A-->>U: Success + refresh My Appointments
  else Slot conflict
    B-->>S: 400 Conflict
    S-->>A: error
    A-->>U: Pick another slot
  end
  end

  rect rgb(245,245,255)
  note over U,A: Place Pharmacy Order
  U->>A: Add medicines, address, payment
  A->>S: placeOrder(userId, items, ...)
  S->>B: POST /api/orders/place (Bearer)
  B->>M: Fetch User, Pharmacy, compute totals
  M-->>B: OK
  alt Accepted
    B-->>S: 201 Order
    S-->>A: success
    A-->>U: Show confirmation & tracking
  else Failed
    B-->>S: 4xx/5xx
    S-->>A: error
    A-->>U: Adjust cart / retry
  end
  end

  rect rgb(255,245,245)
  note over U,A: Emergency SOS
  U->>A: Open SOS, select type/severity
  A->>S: createSOSRequest(payload)
  S->>B: POST /api/sos/create (Bearer)
  B->>M: Persist SOSRequest, locate nearby hospitals
  M-->>B: Saved + candidates
  B-->>S: 201 {sosRequestId, status, timeoutAt}
  S-->>A: success
  A-->>U: SOS active; send SMS; start polling
  loop Poll status
    A->>S: getSOSRequestStatus(id)
    S->>B: GET /api/sos/:id/status
    B->>M: Read SOSRequest
    M-->>B: status
    B-->>S: 200 status
    S-->>A: status
  end
  alt accepted
    A-->>U: Hospital accepted
  else admitted
    A-->>U: Admitted; clear active SOS
  else timeout
    A-->>U: Timeout; suggest call
  else cancelled
    A-->>U: Cancelled
  end
  end
```


---

## Doctor Sequence (Confirm Appointment, Create Prescription)

```mermaid
sequenceDiagram
  autonumber
  actor D as Doctor
  participant A as App (Flutter)
  participant S as ApiService
  participant B as Backend
  participant M as MongoDB

  D->>A: Open Doctor Dashboard
  A->>S: getDoctorAppointments(doctorId)
  S->>B: GET /api/appointments/doctor/:doctorId
  B->>M: Find appointments by doctor
  M-->>B: List
  B-->>S: 200 List
  S-->>A: Appointments

  D->>A: Confirm/Complete appointment
  A->>S: updateAppointmentStatus(id, status)
  S->>B: PUT /api/appointments/:id/status
  B->>M: Update appointment status
  M-->>B: OK
  B-->>S: 200
  S-->>A: success

  D->>A: Create prescription
  A->>S: POST prescription (appointmentId, meds)
  S->>B: POST /api/prescriptions
  B->>M: Save Prescription
  M-->>B: Saved
  B-->>S: 201 Prescription
  S-->>A: success
```

## Hospital Sequence (Profile, Hospital-side Appointment, SOS Acceptance)

```mermaid
sequenceDiagram
  autonumber
  actor H as Hospital Staff
  participant A as App (Flutter)
  participant S as ApiService
  participant B as Backend
  participant M as MongoDB

  H->>A: Open Hospital Dashboard
  A->>S: getHospitalInfo(uid)
  S->>B: GET /api/hospitals/uid/:uid
  B->>M: Find Hospital by uid
  M-->>B: Hospital
  B-->>S: 200
  S-->>A: Hospital data

  H->>A: Create appointment for patient
  A->>S: createAppointment(hospital-scoped)
  S->>B: POST /api/hospitals/:id/appointments
  B->>M: Validate and save Appointment
  M-->>B: Saved
  B-->>S: 201
  S-->>A: success

  H->>A: Accept SOS
  A->>S: acceptSOS(sosId)
  S->>B: POST /api/sos/:id/accept
  B->>M: Update SOSRequest and HospitalSOS
  M-->>B: OK
  B-->>S: 200
  S-->>A: success
```

## Pharmacy Sequence (Fulfill Order)

```mermaid
sequenceDiagram
  autonumber
  actor P as Pharmacy Staff
  participant A as App (Flutter)
  participant S as ApiService
  participant B as Backend
  participant M as MongoDB

  P->>A: Open Orders
  A->>S: getHospitalOrders(hospitalId) / getOrdersByUser
  S->>B: GET /api/orders/hospital/:id or /api/orders/user/:id
  B->>M: Query Orders
  M-->>B: List
  B-->>S: 200
  S-->>A: Orders list

  P->>A: Update order status → Fulfilled
  A->>S: updateOrderStatus(orderId, status)
  S->>B: PUT /api/orders/:orderId/status
  B->>M: Update Order
  M-->>B: OK
  B-->>S: 200
  S-->>A: success
```

## Lab Sequence (Publish Lab Report)

```mermaid
sequenceDiagram
  autonumber
  actor L as Lab Staff
  participant A as App (Flutter)
  participant S as ApiService
  participant B as Backend
  participant M as MongoDB

  L->>A: Open Test Requests
  A->>S: getTestRequests()
  S->>B: GET /api/test-requests
  B->>M: Query TestRequest
  M-->>B: List
  B-->>S: 200
  S-->>A: List

  L->>A: Upload/Publish result
  A->>S: createLabReport(data)
  S->>B: POST /api/lab-reports
  B->>M: Save LabReport
  M-->>B: Saved
  B-->>S: 201
  S-->>A: success
```

## Nurse Sequence (Record Vitals)

```mermaid
sequenceDiagram
  autonumber
  actor N as Nurse
  participant A as App (Flutter)
  participant S as ApiService
  participant B as Backend
  participant M as MongoDB

  N->>A: Open Assignments
  A->>S: getAssignments()
  S->>B: GET /api/patient-assignments
  B->>M: Query PatientAssignment
  M-->>B: List
  B-->>S: 200
  S-->>A: List

  N->>A: Record vitals for patient
  A->>S: savePatientVital(vitals)
  S->>B: POST /api/vitals
  B->>M: Save PatientVital
  M-->>B: Saved
  B-->>S: 201
  S-->>A: success
```

## Admin Sequence (Approve Provider)

```mermaid
sequenceDiagram
  autonumber
  actor X as Admin
  participant A as Web Admin UI
  participant B as Backend
  participant M as MongoDB

  X->>A: Review provider registrations
  A->>B: GET /api/admin/providers/pending
  B->>M: Query pending providers
  M-->>B: List
  B-->>A: 200

  X->>A: Approve provider
  A->>B: POST /api/admin/providers/:id/approve
  B->>M: Update approval status
  M-->>B: OK
  B-->>A: 200
```

