## Use Case Diagram (All Roles)

Open in a Markdown preview that supports Mermaid to view the diagram.

```mermaid
usecaseDiagram
title Arcular Plus – Use Case Diagram (All Roles)

actor User as "User (Patient)"
actor Doctor
actor Hospital
actor Pharmacy
actor Lab
actor Nurse
actor Admin as "Admin"

rectangle "Arcular Plus App" {
  (Login) as UC_Login
  (Register) as UC_Register
  (Manage Profile) as UC_Profile
  (Book Appointment) as UC_BookApt
  (View/Manage Appointments) as UC_UserApts
  (Emergency SOS) as UC_SOS
  (Place Pharmacy Order) as UC_Order
  (View Orders) as UC_ViewOrders
  (View Lab Reports) as UC_LabReports
  (Chat/Message) as UC_Chat
  (Receive Notifications) as UC_Notify

  (Select Doctor/Hospital) as UC_SelectProvider
  (Browse Medicines) as UC_BrowseMeds
  (Notify Nearby Hospitals) as UC_NotifyHosp

  UC_BookApt --> UC_SelectProvider : <<include>>
  UC_Order --> UC_BrowseMeds : <<include>>
  UC_SOS --> UC_NotifyHosp : <<include>>
}

User --> UC_Login
User --> UC_Register
User --> UC_Profile
User --> UC_BookApt
User --> UC_UserApts
User --> UC_SOS
User --> UC_Order
User --> UC_ViewOrders
User --> UC_LabReports
User --> UC_Chat
User --> UC_Notify

Doctor <-- UC_UserApts : "confirm/complete"
Doctor <-- UC_Chat : "consult messages"
Doctor <-- UC_LabReports : "order/interpret"

Hospital <-- UC_BookApt : "schedule/slots"
Hospital <-- UC_UserApts : "reschedule/cancel"
Hospital <-- UC_SOS : "accept/admit"

Pharmacy <-- UC_Order : "fulfill"
Pharmacy <-- UC_ViewOrders : "status updates"

Lab <-- UC_LabReports : "publish"
Lab <-- UC_UserApts : "test appointments"

Nurse <-- UC_UserApts : "vitals during visit"
Nurse <-- UC_SOS : "triage"

Admin <-- UC_Register : "provider approvals"
Admin <-- UC_Profile : "profile change approvals"
```


