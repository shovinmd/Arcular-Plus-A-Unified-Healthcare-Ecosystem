## Data Flow Diagrams

This file contains DFD Level 0 (context) and Level 1 (major processes) for the Arcular Plus system, using Mermaid.

### Level 0 – Context Diagram

```mermaid
flowchart LR
  %% External entities
  U[User (Patient)]
  D[Doctor]
  H[Hospital]
  P[Pharmacy]
  L[Lab]
  N[Nurse]
  A[Admin]

  %% System
  S((Arcular Plus System))

  %% Flows in/out
  U -- Auth, Appointments, Orders, SOS, Records --> S
  D -- Appointments, Prescriptions, Schedule --> S
  H -- Appointments, SOS Accept/Admit, Records --> S
  P -- Inventory, Orders Fulfillment --> S
  L -- Test Requests, Lab Reports --> S
  N -- Assignments, Vitals --> S
  A -- Approvals, Admin Ops --> S

  S -- Notifications, Confirmations, Results --> U
  S -- Schedules, Tasks --> D
  S -- Tasks, Admissions --> H
  S -- Orders, Inventory Updates --> P
  S -- Test Orders, Results --> L
  S -- Assignments, Alerts --> N
  S -- Reports, Dashboards --> A
```

### Level 1 – Major Processes

```mermaid
flowchart TB
  %% External Entities
  U[User]
  D[Doctor]
  H[Hospital]
  P[Pharmacy]
  L[Lab]

  %% Data Stores (logical)
  DSU[(User Store)]
  DSA[(Appointment Store)]
  DSO[(Order Store)]
  DSL[(Lab Store)]
  DSS[(SOS Store)]

  %% Processes
  P1((Auth & Registration))
  P2((Appointment Management))
  P3((Pharmacy Orders))
  P4((Lab & Reports))
  P5((Emergency SOS))

  %% Flows: Auth
  U -- login/register --> P1
  P1 -- user profile --> DSU
  P1 -- session/confirmation --> U

  %% Flows: Appointments
  U -- book/reschedule/cancel --> P2
  D -- confirm/complete --> P2
  H -- manage slots/hospital-side create --> P2
  P2 -- appointment data --> DSA
  P2 -- confirmations/status --> U

  %% Flows: Orders
  U -- cart/place order --> P3
  P -- fulfill/update status --> P3
  P3 -- order data --> DSO
  P3 -- confirmations/status --> U

  %% Flows: Lab
  D -- test requests --> P4
  L -- publish results --> P4
  U -- view reports --> P4
  P4 -- test requests/reports --> DSL

  %% Flows: SOS
  U -- activate/cancel --> P5
  H -- accept/admit --> P5
  P5 -- sos requests/status --> DSS
  P5 -- alerts/notifications --> U
```

Notes:
- Data stores are logical; actual persistence uses MongoDB models shown in the ER diagram.
- Add Level 2 diagrams per process on request (e.g., detailed booking flow).


