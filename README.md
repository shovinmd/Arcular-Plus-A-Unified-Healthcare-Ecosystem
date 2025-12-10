# Arcular Plus: A Unified Healthcare Ecosystem

<div align="center">
  <img src="assets/images/Icon.png" alt="Arcular Plus Logo" width="200" height="200">
  
  **A comprehensive healthcare management platform connecting patients, healthcare providers, and medical facilities**
  
  [![Flutter](https://img.shields.io/badge/Flutter-3.1.3+-blue.svg)](https://flutter.dev/)
  [![Node.js](https://img.shields.io/badge/Node.js-Latest-green.svg)](https://nodejs.org/)
  [![Firebase](https://img.shields.io/badge/Firebase-Latest-orange.svg)](https://firebase.google.com/)
  [![MongoDB](https://img.shields.io/badge/MongoDB-Latest-green.svg)](https://mongodb.com/)
  [![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
</div>

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [User Roles](#user-roles)
- [Technology Stack](#technology-stack)
- [Installation](#installation)
- [API Documentation](#api-documentation)
- [Screenshots](#screenshots)
- [Contributing](#contributing)
- [License](#license)
- [Author](#author)

---

## 🏥 Overview

**Arcular Plus** is a revolutionary healthcare management ecosystem that seamlessly connects patients, healthcare providers, hospitals, pharmacies, laboratories, and administrative staff through a unified platform. Built with Flutter for cross-platform compatibility and Node.js for robust backend services, it provides comprehensive healthcare solutions for modern medical practices.

### Key Highlights

- **Multi-Platform Support**: Android, iOS, and Web applications
- **8 User Roles**: Patients, Doctors, Nurses, Hospitals, Pharmacies, Labs, Admins, and Arc Staff
- **50+ Screens**: Comprehensive UI covering all healthcare workflows
- **AI Integration**: ChatArc AI chatbot powered by Google Gemini
- **Real-time Features**: SOS alerts, notifications, and live updates
- **Production Ready**: Deployed on Render.com with MongoDB Atlas

---

## ✨ Features

### 👤 Patient Features
- **Profile Management**: Comprehensive health data and medical history
- **Appointment Booking**: Schedule appointments with doctors and hospitals
- **Medication Tracking**: Prescription management and medication reminders
- **Lab Reports**: Upload and view medical reports and test results
- **Emergency SOS**: Location-based emergency alerts to nearby hospitals
- **AI Chatbot**: ChatArc AI assistant for health queries
- **Health Tracking**: BMI calculator, pregnancy tracking, menstrual cycle monitoring
- **QR Code Health ID**: Digital health identification system

### 🏥 Hospital Features
- **Hospital Registration**: Complete hospital profile and department management
- **Doctor Management**: Add and manage medical staff
- **Patient Management**: Comprehensive patient care system
- **Appointment Scheduling**: Advanced scheduling and calendar management
- **Report Management**: Upload and manage medical reports
- **Analytics Dashboard**: Patient statistics and hospital performance metrics

### 👨‍⚕️ Doctor Features
- **Doctor Profile**: Professional profile with specializations
- **Patient Management**: Access to assigned patients and their medical history
- **Appointment Handling**: Manage patient appointments and consultations
- **Prescription Writing**: Digital prescription management
- **Report Review**: Access and review patient lab reports
- **QR Code Scanning**: Quick patient identification

### 👩‍⚕️ Nurse Features
- **Patient Assignment**: Manage assigned patients
- **Vitals Monitoring**: Track and record patient vital signs
- **Medication Administration**: Log medication administration
- **Care Reminders**: Set and manage patient care reminders
- **Patient Notes**: Document patient care activities
- **Shift Scheduling**: Manage work schedules

### 💊 Pharmacy Features
- **Inventory Management**: Complete medicine inventory system
- **Medicine Dispensing**: Process and fulfill prescriptions
- **Prescription Scanning**: QR code-based prescription processing
- **AI Medicine Suggestions**: AI-powered medicine recommendations
- **Stock Alerts**: Automated inventory alerts

### 🔬 Laboratory Features
- **Lab Registration**: Laboratory profile and test management
- **Test Request Management**: Process and manage test requests
- **Report Upload**: Upload and manage test results
- **Patient Data Access**: Access patient information for tests
- **Analytics Dashboard**: Lab performance and statistics

### 👨‍💼 Admin Features
- **User Approval System**: Approve/reject healthcare provider registrations
- **Hospital Approval Dashboard**: Manage hospital approvals
- **System Management**: Overall system administration
- **User Analytics**: Comprehensive user statistics

---

## 🏗️ Architecture

### Frontend Architecture (Flutter)
```
lib/
├── main.dart                 # App entry point
├── app.dart                  # Main app configuration
├── config/                   # Configuration files
├── models/                   # Data models (5 models)
├── services/                 # Business logic (5 services)
├── screens/                  # UI screens (50+ screens)
├── widgets/                  # Reusable components
└── utils/                    # Utility functions
```

### Backend Architecture (Node.js)
```
node_backend/
├── server.js                 # Main server file
├── models/                   # MongoDB schemas (15 models)
├── controllers/              # Request handlers (18 controllers)
├── routes/                   # API endpoints (18 route files)
├── middleware/               # Authentication & validation
└── uploads/                  # File storage
```

### Database Collections
- **Users**: Patient, Doctor, Hospital, Nurse, Lab, Pharmacy, Admin, ArcStaff
- **Appointments**: Scheduling and management
- **Medications**: Prescriptions and tracking
- **Reports**: Medical documents
- **Notifications**: System alerts
- **SOS**: Emergency data

---

## 👥 User Roles

| Role | Description | Key Features |
|------|-------------|--------------|
| **Patient** | End users seeking healthcare services | Profile management, appointment booking, medication tracking, emergency SOS |
| **Doctor** | Medical professionals providing care | Patient management, prescription writing, appointment handling |
| **Nurse** | Healthcare staff providing patient care | Vitals monitoring, medication administration, care reminders |
| **Hospital** | Medical facilities managing operations | Doctor management, patient care, appointment scheduling |
| **Pharmacy** | Medicine dispensing and inventory | Inventory management, prescription processing, AI suggestions |
| **Lab** | Laboratory services and testing | Test management, report upload, patient data access |
| **Admin** | System administrators | User approvals, system management, analytics |
| **Arc Staff** | ARC staff managing operations | Staff management, user approval/rejection |

---

## 🛠️ Technology Stack

### Frontend
- **Flutter 3.1.3+**: Cross-platform mobile and web development
- **Firebase**: Authentication, Storage, Firestore
- **Google Generative AI**: ChatArc AI chatbot
- **Google Maps**: Location services and mapping
- **QR Flutter**: QR code generation and scanning
- **Glassmorphism**: Modern UI effects
- **Flutter Animate**: Smooth animations

### Backend
- **Node.js**: Runtime environment
- **Express.js**: Web framework
- **MongoDB**: Database with Mongoose ODM
- **Firebase Admin SDK**: Authentication and authorization
- **JWT**: Token-based authentication
- **Multer**: File upload handling
- **Nodemailer**: Email notifications
- **Helmet**: Security middleware

### Deployment
- **Render.com**: Backend hosting (Production)
- **MongoDB Atlas**: Cloud database
- **Firebase Storage**: File storage
- **GitHub**: Version control and CI/CD

---

## 🚀 Installation

### Prerequisites
- Flutter SDK 3.1.3 or higher
- Node.js 16.x or higher
- MongoDB Atlas account
- Firebase project
- Git

### Frontend Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/shovinmd/Arcular-Plus.git
   cd Arcular-Plus
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Update `firebase_options.dart` with your Firebase configuration

4. **Run the application**
   ```bash
   # For mobile
   flutter run
   
   # For web
   flutter run -d chrome
   ```

### Backend Setup

1. **Navigate to backend directory**
   ```bash
   cd node_backend
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Configure environment variables**
   ```bash
   # Create .env file
   MONGODB_URI=your_mongodb_atlas_uri
   FIREBASE_PROJECT_ID=your_firebase_project_id
   FIREBASE_PRIVATE_KEY=your_firebase_private_key
   FIREBASE_CLIENT_EMAIL=your_firebase_client_email
   ```

4. **Start the server**
   ```bash
   npm start
   ```

### Build Scripts

- **Mobile Build**: `./build_mobile.sh`
- **Web Build**: `./build_web.sh`

---

## 📚 API Documentation

### Base URL
```
https://arcular-plus-backend.onrender.com
```

### Authentication
All API endpoints require Firebase authentication token in the header:
```
Authorization: Bearer <firebase_id_token>
```

### Key Endpoints

#### User Management
- `POST /api/users/register` - User registration
- `GET /api/users/profile` - Get user profile
- `PUT /api/users/profile` - Update user profile

#### Appointments
- `POST /api/appointments` - Create appointment
- `GET /api/appointments` - Get appointments
- `PUT /api/appointments/:id` - Update appointment

#### Medications
- `POST /api/medications` - Add medication
- `GET /api/medications` - Get medications
- `PUT /api/medications/:id` - Update medication

#### Reports
- `POST /api/reports/upload` - Upload report
- `GET /api/reports` - Get reports

#### Emergency SOS
- `POST /api/sos` - Send emergency alert
- `GET /api/sos` - Get SOS alerts

---

## 📱 Screenshots

<div align="center">
  <img src="assets/images/intro.gif" alt="App Introduction" width="300">
  <p><em>App Introduction Screen</em></p>
</div>

### Key Screens
- **Dashboard**: Comprehensive overview for each user role
- **Profile Management**: Detailed user profiles with health data
- **Appointment Booking**: Easy appointment scheduling
- **Emergency SOS**: Location-based emergency alerts
- **AI Chatbot**: ChatArc AI assistant
- **QR Scanner**: Quick patient identification

---

## 🤝 Contributing

We welcome contributions to Arcular Plus! Please follow these steps:

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Commit your changes**
   ```bash
   git commit -m 'Add some amazing feature'
   ```
4. **Push to the branch**
   ```bash
   git push origin feature/amazing-feature
   ```
5. **Open a Pull Request**

### Development Guidelines
- Follow Flutter and Dart style guidelines
- Write comprehensive tests for new features
- Update documentation for API changes
- Ensure cross-platform compatibility

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author

**Shovin Michel David**

- **GitHub**: [@shovinmd](https://github.com/shovinmd)
- **Repository**: [Arcular-Plus](https://github.com/shovinmd/Arcular-Plus)
- **Email**: [Contact via GitHub](https://github.com/shovinmd)

---

## 🙏 Acknowledgments

- **Flutter Team** for the amazing cross-platform framework
- **Firebase** for authentication and storage services
- **Google** for Gemini AI integration
- **MongoDB** for robust database solutions
- **Render** for reliable hosting services
- **Open Source Community** for inspiration and support

---

<div align="center">
  <p><strong>Arcular Plus</strong> - Revolutionizing Healthcare Management</p>
  <p>Made with ❤️ by Shovin Michel David</p>
</div>
"# Arcular-Plus-A-Unified-Healthcare-Ecosystem" 
"# Arcular-Plus-A-Unified-Healthcare-Ecosystem" 
