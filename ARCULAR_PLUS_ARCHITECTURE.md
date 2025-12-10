# Arcular+ Complete Architecture & Implementation Guide

## Project Overview

Arcular+ is a comprehensive healthcare management application with separate interfaces for patients, hospitals, doctors, nurses, labs, pharmacies, admins, and arc staff. Built using Flutter for the frontend and Node.js for the backend, with Firebase handling authentication and storage.

## 🏗️ Complete System Architecture

### Frontend (Flutter) - Multi-Platform
- **Mobile App**: Android & iOS support
- **Web App**: Progressive Web App (PWA)
- **Cross-Platform**: Single codebase for all platforms

### Backend (Node.js + Express + MongoDB)
- **API Server**: RESTful API with comprehensive endpoints
- **Database**: MongoDB with Mongoose ODM
- **Authentication**: Firebase Admin SDK + JWT
- **File Storage**: Firebase Storage + Local uploads
- **Deployment**: Render.com (Production)

### Authentication & Security
- **Firebase Auth**: Email/password, Google Sign-In
- **JWT Tokens**: API authentication
- **Role-based Access**: 8 different user types
- **Middleware**: Token verification, role validation

## 📱 Frontend Architecture (Flutter)

### Core Structure
```
lib/
├── main.dart                 # App entry point
├── app.dart                  # Main app configuration
├── main_web.dart            # Web-specific entry
├── firebase_options.dart     # Firebase configuration
├── config/
│   ├── themes.dart          # UI theme configuration
│   └── gemini_config.dart   # AI service configuration
├── models/                  # Data models (5 models)
├── services/                # Business logic (5 services)
├── screens/                 # UI screens (50+ screens)
├── widgets/                 # Reusable components (4 widgets)
└── utils/                   # Utilities (4 utilities)
```

### Screen Organization by User Type

#### 🔐 Authentication Screens (22 screens)
- **Universal**: `select_user_type.dart`, `universal_signup_screen.dart`
- **Patient**: `signup_user.dart`, `patient_registration_screen.dart`
- **Hospital**: `hospital_signup_screen.dart`, `hospital_registration_screen.dart`
- **Doctor**: `doctor_signup_screen.dart`, `doctor_registration_screen.dart`
- **Nurse**: `nurse_signup_screen.dart`, `nurse_registration_screen.dart`
- **Lab**: `lab_signup_screen.dart`, `lab_registration_screen.dart`
- **Pharmacy**: `pharmacy_signup_screen.dart`, `pharmacy_registration_screen.dart`
- **Admin**: `admin_signup_screen.dart`, `admin_registration_screen.dart`
- **ArcStaff**: `login_arcstaff_screen.dart`
- **Login**: `login_screen.dart`, `login_admin_screen.dart`
- **Status**: `approval_pending_screen.dart`, `intro_screen.dart`

#### 👤 Patient Screens (20 screens)
- **Dashboard**: `dashboard_user.dart` (1,436 lines - comprehensive)
- **Profile**: `profile_screen.dart`, `update_profile_screen.dart`
- **Appointments**: `appointment_booking_screen.dart`
- **Health**: `bmi_calculator_screen.dart`, `health_history_screen.dart`
- **Pregnancy**: `pregnancy_tracking_screen.dart`, `pregnancy_blog_screen.dart`
- **Medication**: `medicine_user.dart`, `medicine_order_screen.dart`, `prescription_screen.dart`
- **Reports**: `lab_reports_screen.dart`, `report_user.dart`
- **Emergency**: `emergency_sos_screen.dart`
- **AI Chat**: `ai_chatbot_screen.dart`
- **Utilities**: `calendar_user.dart`, `notifications_screen.dart`, `user_settings_screen.dart`
- **Health Tracking**: `menstrual_cycle_screen.dart`

#### 🏥 Hospital Screens (12 screens)
- **Dashboard**: `dashboard_hospital.dart` (1,726 lines - comprehensive)
- **Profile**: `hospital_profile_screen.dart`, `hospital_profile_update_screen.dart`
- **Management**: `patient_management_screen.dart`, `patient_detail_screen.dart`
- **Appointments**: `appointment_scheduler_screen.dart`, `appointment_manage.dart`
- **Reports**: `report_upload_screen.dart`, `report_upload.dart`
- **Medication**: `medicine_assignment_screen.dart`, `medicine_hospital.dart`
- **Departments**: `departments_screen.dart`

#### 👨‍⚕️ Doctor Screens (3 screens)
- **Dashboard**: `dashboard_doctor.dart` (1,054 lines - comprehensive)
- **Profile**: `doctor_profile_screen.dart`, `update_doctor_profile_screen.dart`

#### 👩‍⚕️ Nurse Screens (11 screens)
- **Dashboard**: `dashboard_nurse.dart`
- **Patient Care**: `assigned_patients_tab.dart`, `patient_detail_screen.dart`, `patient_history_screen.dart`
- **Monitoring**: `vitals_monitoring_screen.dart`, `medication_log_screen.dart`
- **Care**: `care_reminders_screen.dart`, `patient_notes_screen.dart`
- **Communication**: `chat_feedback_screen.dart`
- **Schedule**: `shift_schedule_screen.dart`
- **QR**: `qr_scan_screen.dart`

#### 💊 Pharmacy Screens (7 screens)
- **Dashboard**: `dashboard_pharmacy.dart`
- **Inventory**: `inventory_management.dart`, `stock_alerts.dart`
- **Dispensing**: `medicine_dispensing.dart`, `prescription_scanner.dart`
- **AI**: `ai_medicine_suggestions.dart`, `enhanced_ai_chat.dart`

#### 🔬 Lab Screens (1 screen)
- **Dashboard**: `dashboard_lab.dart` (1,739 lines - comprehensive)

#### 👨‍💼 Admin Screens (2 screens)
- **Dashboard**: `admin_dashboard_screen.dart`
- **Approvals**: `hospital_approval_dashboard.dart`

#### 🏢 ArcStaff Screens (1 screen)
- **Dashboard**: `arcstaff_dashboard_screen.dart`

#### 👑 SuperAdmin Screens (1 screen)
- **Dashboard**: `superadmin_dashboard_screen.dart`

#### 📱 Scanner Screens (3 screens)
- **Mobile**: `scanner_mobile.dart`
- **Web**: `scanner_web.dart`
- **Universal**: `scanner_screen.dart`

### Services Layer (5 services)
- **ApiService**: HTTP client for backend communication (2,668 lines)
- **AuthService**: Authentication management
- **StorageService**: File upload/download
- **GeminiAIService**: AI chatbot integration
- **ApprovalStatusService**: User approval tracking

### Models (5 models)
- **UserModel**: Comprehensive user data (750 lines)
- **AppointmentModel**: Appointment management
- **DoctorModel**: Doctor-specific data
- **ReportModel**: Medical reports
- **MedicineModel**: Medication data

## 🔧 Backend Architecture (Node.js)

### Core Structure
```
node_backend/
├── server.js                 # Main server file
├── firebase.js              # Firebase Admin configuration
├── package.json             # Dependencies
├── models/                  # MongoDB schemas (15 models)
├── controllers/             # Request handlers (18 controllers)
├── routes/                  # API endpoints (18 route files)
├── middleware/              # Authentication & validation (2 files)
└── uploads/                 # File storage
```

### Database Models (15 models)

#### Core Models
- **User.js**: Patient data with comprehensive health information
- **Hospital.js**: Hospital registration and management
- **Doctor.js**: Doctor profiles and specializations
- **Nurse.js**: Nurse profiles and assignments
- **Lab.js**: Laboratory information and tests
- **Pharmacy.js**: Pharmacy details and inventory
- **ArcStaff.js**: ARC staff management
- **Staff.js**: General staff model

#### Functional Models
- **Appointment.js**: Appointment scheduling and management
- **Medication.js**: Medication prescriptions and tracking
- **Report.js**: Medical reports and documents
- **LabReport.js**: Laboratory test results
- **Notification.js**: System notifications
- **SOS.js**: Emergency alerts
- **PregnancyTracking.js**: Pregnancy monitoring
- **MenstrualCycle.js**: Cycle tracking

### API Controllers (18 controllers)

#### User Management
- **userController.js**: Patient registration and management (259 lines)
- **adminController.js**: Admin operations (227 lines)
- **arcStaffController.js**: ARC staff management (451 lines)

#### Healthcare Providers
- **hospitalController.js**: Hospital operations (406 lines)
- **doctorController.js**: Doctor management (435 lines)
- **nurseController.js**: Nurse operations (334 lines)
- **labController.js**: Laboratory management (325 lines)
- **pharmacyController.js**: Pharmacy operations (323 lines)

#### Core Features
- **appointmentController.js**: Appointment management (234 lines)
- **medicationController.js**: Medication handling (269 lines)
- **reportController.js**: Report management (229 lines)
- **labReportController.js**: Lab report processing (54 lines)

#### Special Features
- **notificationController.js**: Notification system (48 lines)
- **qrController.js**: QR code generation (12 lines)
- **sosController.js**: Emergency alerts (21 lines)
- **pregnancyController.js**: Pregnancy tracking (32 lines)
- **menstrualController.js**: Cycle tracking (32 lines)
- **staffController.js**: Staff management (80 lines)

### API Routes (18 route files)
- **userRoutes.js**: Patient endpoints
- **hospitalRoutes.js**: Hospital endpoints
- **doctorRoutes.js**: Doctor endpoints
- **nurseRoutes.js**: Nurse endpoints
- **labRoutes.js**: Laboratory endpoints
- **pharmacyRoutes.js**: Pharmacy endpoints
- **adminRoutes.js**: Admin endpoints
- **arcStaffRoutes.js**: ARC staff endpoints
- **appointmentRoutes.js**: Appointment endpoints
- **medicationRoutes.js**: Medication endpoints
- **reportRoutes.js**: Report endpoints
- **labReportRoutes.js**: Lab report endpoints
- **notificationRoutes.js**: Notification endpoints
- **sosRoutes.js**: Emergency endpoints
- **qrRoutes.js**: QR code endpoints
- **pregnancyRoutes.js**: Pregnancy endpoints
- **menstrualRoutes.js**: Cycle endpoints

### Middleware (2 files)
- **auth.js**: Firebase token verification and role validation
- **firebaseAuthMiddleware.js**: Enhanced Firebase authentication

## 🔄 Data Flow Architecture

### Authentication Flow
1. **User Registration**: Firebase Auth → Backend API → MongoDB
2. **User Login**: Firebase Auth → JWT Token → API Access
3. **Role Validation**: Token → Middleware → Role Check → Access Control

### Data Operations Flow
1. **Frontend Request**: Flutter → HTTP → Node.js API
2. **Authentication**: Middleware → Token Verification
3. **Business Logic**: Controller → Model → Database
4. **Response**: Database → Model → Controller → Frontend

### File Upload Flow
1. **File Selection**: Flutter → Image Picker/File Picker
2. **Upload**: Flutter → Firebase Storage → URL
3. **Database**: URL → MongoDB → User Profile

## 🎯 Feature Matrix

### Patient Features ✅
- [x] Profile Management (Comprehensive health data)
- [x] Appointment Booking & Management
- [x] Medication Tracking & Reminders
- [x] Lab Report Upload & Viewing
- [x] Pregnancy Tracking & Blog
- [x] Emergency SOS with Location
- [x] AI Chatbot (ChatArc with Gemini)
- [x] Health QR Code Generation
- [x] BMI Calculator
- [x] Menstrual Cycle Tracking
- [x] Health History Management
- [x] Prescription Management

### Hospital Features ✅
- [x] Hospital Registration & Profile
- [x] Doctor Management
- [x] Patient Management
- [x] Appointment Scheduling
- [x] Department Management
- [x] Report Upload & Management
- [x] Medicine Assignment
- [x] Analytics Dashboard

### Doctor Features ✅
- [x] Doctor Registration & Profile
- [x] Patient Management
- [x] Appointment Handling
- [x] Prescription Writing
- [x] Report Review
- [x] QR Code Scanning

### Nurse Features ✅
- [x] Patient Assignment
- [x] Vitals Monitoring
- [x] Medication Administration Log
- [x] Care Reminders
- [x] Patient Notes
- [x] Shift Scheduling
- [x] QR Code Scanning

### Lab Features ✅
- [x] Lab Registration & Profile
- [x] Test Request Management
- [x] Report Upload & Processing
- [x] Patient Data Access
- [x] Analytics Dashboard

### Pharmacy Features ✅
- [x] Pharmacy Registration & Profile
- [x] Inventory Management
- [x] Medicine Dispensing
- [x] Prescription Scanning
- [x] AI Medicine Suggestions
- [x] Stock Alerts

### Admin Features ✅
- [x] User Approval System
- [x] Hospital Approval Dashboard
- [x] System Management
- [x] User Analytics

### ArcStaff Features ✅
- [x] Staff Management
- [x] User Approval/Rejection
- [x] System Oversight

## 🔧 Technical Stack

### Frontend Dependencies
- **Flutter**: 3.1.3+ (Cross-platform framework)
- **Firebase**: Auth, Storage, Firestore
- **HTTP**: API communication
- **Image Picker**: File selection
- **QR Flutter**: QR code generation
- **Google Generative AI**: ChatArc AI
- **Shared Preferences**: Local storage
- **Google Fonts**: Typography
- **Glassmorphism**: UI effects
- **Flutter Animate**: Animations

### Backend Dependencies
- **Node.js**: Runtime environment
- **Express.js**: Web framework
- **MongoDB**: Database
- **Mongoose**: ODM
- **Firebase Admin**: Authentication
- **JWT**: Token management
- **Multer**: File uploads
- **Nodemailer**: Email notifications
- **QRCode**: QR generation
- **Helmet**: Security
- **CORS**: Cross-origin requests

## 🚀 Deployment Architecture

### Backend Deployment
- **Platform**: Render.com
- **URL**: https://arcular-plus-backend.onrender.com
- **Environment**: Production
- **Database**: MongoDB Atlas
- **Storage**: Firebase Storage

### Frontend Deployment
- **Mobile**: Android APK, iOS IPA
- **Web**: Progressive Web App (PWA)
- **Build Script**: `build_mobile.sh`

## 📊 Project Metrics

### Code Statistics
- **Frontend**: 50+ screens, 5 services, 5 models
- **Backend**: 18 controllers, 18 routes, 15 models
- **Total Lines**: 15,000+ lines of code
- **User Types**: 8 different roles
- **Features**: 50+ core features

### Database Collections
- **Users**: Patient, Doctor, Hospital, Nurse, Lab, Pharmacy, Admin, ArcStaff
- **Appointments**: Scheduling and management
- **Medications**: Prescriptions and tracking
- **Reports**: Medical documents
- **Notifications**: System alerts
- **SOS**: Emergency data

## 🔮 Future Enhancements

### Planned Features
1. **Real-time Notifications**: Push notifications
2. **Video Consultations**: Telemedicine integration
3. **Health Analytics**: Advanced reporting
4. **Integration APIs**: Third-party health systems
5. **Mobile Payments**: Payment gateway integration
6. **Advanced AI**: Enhanced medical assistance

### Technical Improvements
1. **Performance**: Code optimization
2. **Security**: Enhanced authentication
3. **Scalability**: Microservices architecture
4. **Monitoring**: Application monitoring
5. **Testing**: Comprehensive test suite

## 🎯 Current Status

### ✅ Completed
- Complete multi-role architecture
- Comprehensive UI/UX design
- Full API implementation
- Database schema design
- Authentication system
- File upload system
- AI integration

### 🔄 In Progress
- Performance optimization
- Error handling improvements
- Dependency updates
- Security enhancements

### 📋 Next Steps
1. **Critical Fixes**: FCM, API responses, error handling
2. **Dependency Updates**: Latest stable versions
3. **Feature Enhancements**: Notifications, security
4. **Production Deployment**: Full deployment
5. **Monitoring Setup**: Performance monitoring

This architecture provides a solid foundation for a comprehensive healthcare management system with room for future expansion and improvements.

 