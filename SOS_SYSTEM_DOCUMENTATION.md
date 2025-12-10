# 🚨 SOS Emergency System Documentation

## Overview
The SOS Emergency System is a comprehensive emergency response system that connects patients in distress with nearby hospitals through real-time notifications, automatic escalation, and emergency contact systems.

## 🏗️ System Architecture

### Frontend (Flutter)
- **User App**: Emergency SOS activation and monitoring
- **Hospital App**: SOS request management and patient care
- **Real-time Communication**: WebSocket-like polling system

### Backend (Node.js + MongoDB)
- **API Endpoints**: RESTful SOS management
- **Database**: MongoDB with geospatial indexing
- **Authentication**: Firebase Authentication
- **Real-time Updates**: Polling-based status monitoring

---

## 📱 User Side (Patient) - Emergency SOS Screen

### 1. SOS Activation Process

#### Step 1: Location Detection
```dart
// Get current GPS coordinates
Position? _currentPosition = await Geolocator.getCurrentPosition();
String _currentAddress = await _getAddressFromCoordinates();
```

#### Step 2: Emergency Details Selection
- **Emergency Type**: Medical, Accident, Fire, Other
- **Severity Level**: High, Medium, Low
- **Description**: Optional details about the emergency

#### Step 3: SOS Request Creation
```dart
final sosRequestData = {
  'patientId': firebaseUid,
  'patientName': user.fullName,
  'patientPhone': user.mobileNumber,
  'location': {
    'longitude': _currentPosition.longitude,
    'latitude': _currentPosition.latitude
  },
  'address': _currentAddress,
  'city': city,
  'emergencyType': selectedType,
  'severity': selectedSeverity
};
```

#### Step 4: Backend Processing
```javascript
// POST /api/sos/create
const sosRequest = new SOSRequest(sosRequestData);
await sosRequest.save();

// Find nearby hospitals
await ensureHospitalSOSForRequest(sosRequest, location, address, city, state, pincode);
```

### 2. Hospital Search Algorithm

#### Primary Search (25km radius)
```javascript
// MongoDB geospatial query
nearbyHospitals = await Hospital.find({
  status: 'active',
  isApproved: true,
  location: {
    $near: {
      $geometry: {
        type: 'Point',
        coordinates: [longitude, latitude]
      },
      $maxDistance: 25000 // 25km
    }
  }
});
```

#### Fallback Search (50km radius)
```javascript
// Haversine distance calculation
nearbyHospitals = candidates
  .map(h => {
    const distance = calculateDistance([lon, lat], [hLon, hLat]);
    return { ...h, _distanceKm: distance };
  })
  .filter(h => h._distanceKm <= 50000) // 50km
  .sort((a, b) => a._distanceKm - b._distanceKm);
```

#### City/Pincode Search (Last Resort)
```javascript
// Search hospitals in same city and pincode
const cityHospitals = await Hospital.find({
  isApproved: true,
  status: 'active',
  $or: [
    { city: city },
    { hospitalCity: city },
    { pincode: pincode }
  ]
});
```

### 3. Real-Time Monitoring

#### SOS Status Monitoring
```dart
// Monitor every 5 seconds
Timer.periodic(const Duration(seconds: 5), (timer) async {
  final sosStatus = await ApiService.getSOSRequestById(_activeSosId!);
  // Update UI based on status changes
});
```

#### Escalation Monitoring
```dart
// Monitor escalation every 30 seconds
Timer.periodic(const Duration(seconds: 30), (timer) async {
  final escalationResponse = await ApiService.handleSOSEscalation(_activeSosId!);
  // Handle emergency calls and retries
});
```

### 4. SOS Escalation System

#### 2-Minute Timeout
```javascript
if (timeSinceCreation >= twoMinutes) {
  // Trigger emergency calls
  emergencyCalls = [
    {
      number: '123',
      type: 'emergency_services',
      reason: 'No hospital response within 2 minutes'
    }
  ];
  
  // Add emergency contact call
  if (sosRequest.emergencyContact?.phone) {
    emergencyCalls.push({
      number: sosRequest.emergencyContact.phone,
      type: 'emergency_contact',
      reason: 'Emergency contact notification'
    });
  }
}
```

#### 5-Minute Retry System
```javascript
if (timeSinceLastRetry >= fiveMinutes && !acceptedHospital) {
  // Reset timeout and re-notify hospitals
  sosRequest.timeoutAt = new Date(now.getTime() + 2 * 60 * 1000);
  sosRequest.retryCount = (sosRequest.retryCount || 0) + 1;
  
  // Re-notify hospitals
  await ensureHospitalSOSForRequest(sosRequest, ...);
}
```

#### Stop Conditions
- ✅ **Hospital accepts** SOS request
- ✅ **Hospital reaches** patient location (only call emergency contact, not 123)
- ✅ **Hospital admits** patient
- ✅ **User cancels** SOS request

#### Emergency Coordination System
When emergency services (123) are already on the way but a hospital accepts the SOS request during a retry, the system automatically detects this coordination conflict and provides options:

**Coordination Detection:**
```javascript
// Check if emergency services (123) were already called
const emergencyServicesCalled = sosRequest.emergencyCallsTriggered?.some(call => 
  call.number === '123' && call.type === 'emergency_services'
) || false;

if (emergencyServicesCalled && acceptedHospital) {
  // Update SOS request with coordination info
  sosRequest.coordinationRequired = true;
  sosRequest.coordinationReason = 'Hospital accepted after emergency services called';
  sosRequest.coordinationStatus = 'pending';
}
```

**Coordination Options:**
1. **Hospital Will Manage**: Hospital handles the case, inform emergency services (123) when they arrive
2. **Emergency Services Will Handle**: Hospital cancels response, emergency services (123) continue
3. **Coordinate When They Arrive**: Both services coordinate when emergency services arrive

**Important Note**: Emergency services (123) are real responders who cannot be cancelled through the app. The coordination is about managing the response when they arrive at the scene.

**Coordination API:**
```javascript
// Handle coordination
POST /api/sos/coordinate/:sosRequestId
Body: {
  coordinationAction: 'emergency_services_cancelled' | 'hospital_cancelled' | 'both_responding',
  coordinationDetails: { reason, timestamp }
}

// Get coordination status
GET /api/sos/coordination-status/:sosRequestId
```

**Coordination Actions Explained:**
- `emergency_services_cancelled`: Hospital will manage the case, inform emergency services (123) when they arrive
- `hospital_cancelled`: Hospital cancels response, emergency services (123) continue handling
- `both_responding`: Both services coordinate when emergency services arrive at the scene

### 5. User Interface Features

#### Active SOS Card
```dart
// Only shows when hospital accepts
if (_activeSosId != null && _activeSosStatus == 'accepted')
  Card(
    child: Column(
      children: [
        Text('SOS Accepted'),
        Text('ID: $_activeSosId'),
        Text('Status: $_activeSosStatus'),
        
        // Escalation status
        if (_escalationTriggered)
          Container(
            decoration: BoxDecoration(color: Colors.red[50]),
            child: Column(
              children: [
                Text('Emergency Escalation Active'),
                Text('Retry Attempt: $_retryCount'),
                Text('Emergency Calls: ${_emergencyCallsTriggered.length}'),
              ],
            ),
          ),
        
        // Action buttons
        ElevatedButton(
          onPressed: _showHospitalReachedDialog,
          child: Text('Hospital Reached'),
        ),
        ElevatedButton(
          onPressed: _showCancelSOSDialog,
          child: Text('Cancel SOS'),
        ),
      ],
    ),
  )
```

#### Activity Log
```dart
// Real-time activity tracking
final List<String> _sosActivityLog = [];

void _logSos(String event) {
  final timestamp = DateTime.now().toIso8601String();
  _sosActivityLog.add('$timestamp: $event');
}
```

---

## 🏥 Hospital Side - Dashboard Hospital

### 1. SOS Request Management

#### Real-Time SOS Monitoring
```dart
// Start monitoring for new SOS requests
RealtimeSOSService.instance.startRealtimeMonitoring(
  userType: 'hospital',
  onSOSReceived: (request) {
    // Trigger alarm system
    _alarmController.repeat(reverse: true);
    _playAlarmSound();
    _showEmergencyDialog(request);
  }
);
```

#### Alarm System
```dart
// Visual alarm
AnimatedBuilder(
  animation: _alarmAnimation,
  builder: (context, child) {
    return Transform.scale(
      scale: 1.0 + (_alarmAnimation.value * 0.3),
      child: Icon(Icons.emergency, color: Colors.red[600]),
    );
  },
);

// Audio alarm and vibration
void _playAlarmSound() {
  HapticFeedback.heavyImpact();
  // Continuous vibration pattern
  _startContinuousVibration();
}
```

### 2. SOS Request Tabs

#### Tab Structure
```dart
TabBar(
  tabs: [
    Tab(text: 'Pending (${_sosRequests.length})'),
    Tab(text: 'Accepted (${_acceptedRequests.length})'),
    Tab(text: 'Cancelled (${_cancelledRequests.length})'),
  ],
)
```

#### Request Status Flow
- **Pending**: New SOS requests waiting for response
- **Accepted**: Hospital has accepted the request
- **Cancelled**: User cancelled or timeout occurred

### 3. Emergency Dialog

#### Full-Screen Alert
```dart
void _showEmergencyDialog(Map<String, dynamic> request) {
  showDialog(
    context: context,
    barrierDismissible: false, // Cannot dismiss by tapping outside
    builder: (context) => WillPopScope(
      onWillPop: () async => false, // Prevent back button dismissal
      child: Dialog(
        child: Container(
          child: Column(
            children: [
              // Emergency icon with animation
              AnimatedBuilder(
                animation: _alarmAnimation,
                builder: (context, child) => Icon(Icons.emergency),
              ),
              
              // Patient information
              Text('Patient: ${request['patientInfo']['patientName']}'),
              Text('Phone: ${request['patientInfo']['patientPhone']}'),
              Text('Location: ${request['emergencyDetails']['location']['address']}'),
              Text('Coordinates: ${lat}, ${lng}'),
              
              // Google Maps link
              ElevatedButton(
                onPressed: () => _openGoogleMaps(request),
                child: Text('Open in Google Maps'),
              ),
              
              // Action buttons
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _tabController.animateTo(0);
                      _stopAlarm();
                    },
                    child: Text('VIEW REQUEST'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _stopAlarm();
                    },
                    child: Text('DISMISS'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

### 4. SOS Request Actions

#### Accept SOS Request
```dart
Future<void> _acceptSOSRequest(String sosRequestId) async {
  final response = await ApiService.acceptSOSRequest(widget.hospitalId, sosRequestId);
  
  if (response['success'] == true) {
    // Update UI
    setState(() {
      _sosRequests.removeWhere((req) => req['sosRequestId'] == sosRequestId);
      _acceptedRequests.add(response['data']);
    });
    
    // Stop alarm
    _stopAlarm();
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('SOS request accepted successfully')),
    );
  }
}
```

#### Mark Patient as Admitted
```dart
Future<void> _admitPatient(String sosRequestId) async {
  // Show ward/bed input dialog
  final wardNumber = await _showAdmissionDialog();
  final bedNumber = await _showAdmissionDialog();
  
  if (wardNumber != null && bedNumber != null) {
    final admissionData = {
      'wardNumber': wardNumber,
      'bedNumber': bedNumber,
      'admittedAt': DateTime.now().toIso8601String(),
    };
    
    final response = await ApiService.markPatientAdmitted(
      widget.hospitalId,
      sosRequestId,
      admissionData,
    );
    
    if (response['success'] == true) {
      // Update UI and notify other hospitals
      _loadSOSRequests();
    }
  }
}
```

---

## 🔄 Backend API Endpoints

### SOS Management
```javascript
// Create SOS request
POST /api/sos/create
Body: {
  patientId, patientName, patientPhone,
  location: { longitude, latitude },
  address, city, state, pincode,
  emergencyType, description, severity
}

// Get hospital SOS requests
GET /api/sos/hospital/:hospitalId

// Accept SOS request
POST /api/sos/accept/:hospitalId
Body: { sosRequestId }

// Mark patient as admitted
POST /api/sos/admit/:hospitalId
Body: { sosRequestId, wardNumber, bedNumber }

// Confirm patient admission (user)
POST /api/sos/confirm-admission
Body: { sosRequestId, hospitalId }

// Confirm hospital reached (user)
POST /api/sos/confirm-hospital-reached
Body: { sosRequestId, hospitalId, doctorId? }

// Cancel SOS request
POST /api/sos/cancel/:sosRequestId
```

### SOS Escalation System
```javascript
// Handle SOS escalation
POST /api/sos/escalate/:sosRequestId

// Get escalation status
GET /api/sos/escalation-status/:sosRequestId
```

### Emergency Coordination System
```javascript
// Handle emergency coordination
POST /api/sos/coordinate/:sosRequestId
Body: {
  coordinationAction: 'emergency_services_cancelled' | 'hospital_cancelled' | 'both_responding',
  coordinationDetails: { reason, timestamp }
}

// Get coordination status
GET /api/sos/coordination-status/:sosRequestId
```

### Hospital Management
```javascript
// Get nearby hospitals
GET /api/hospitals/nearby?latitude=lat&longitude=lng&radius=25

// Get hospital profile
GET /api/hospitals/:hospitalId
```

---

## 📊 Database Schema

### SOSRequest Collection
```javascript
{
  _id: ObjectId,
  patientId: String, // Firebase UID
  patientName: String,
  patientPhone: String,
  patientEmail: String,
  patientAge: Number,
  patientGender: String,
  emergencyContact: {
    name: String,
    phone: String,
    relation: String
  },
  location: {
    type: 'Point',
    coordinates: [longitude, latitude]
  },
  address: String,
  city: String,
  state: String,
  pincode: String,
  emergencyType: String,
  description: String,
  severity: String,
  status: String, // pending, accepted, hospitalReached, admitted, cancelled
  timeoutAt: Date,
  retryCount: Number,
  lastRetryAt: Date,
  escalationTriggered: Boolean,
  escalationTriggeredAt: Date,
  emergencyCallsTriggered: Array,
  coordinationRequired: Boolean,
  coordinationReason: String,
  coordinationStatus: String, // pending, emergency_services_cancelled, hospital_cancelled, both_responding
  coordinationDetails: Object,
  createdAt: Date,
  updatedAt: Date
}
```

### HospitalSOS Collection
```javascript
{
  _id: ObjectId,
  sosRequestId: ObjectId,
  hospitalId: String, // Hospital UID
  hospitalStatus: String, // notified, accepted, hospitalReached, admitted, handledByOther
  patientInfo: Object,
  emergencyDetails: Object,
  acceptedBy: {
    hospitalName: String,
    acceptedByStaff: {
      name: String,
      phone: String,
      role: String
    },
    acceptedAt: Date
  },
  admissionDetails: {
    wardNumber: String,
    bedNumber: String,
    admittedAt: Date,
    admittedBy: String
  },
  createdAt: Date,
  updatedAt: Date
}
```

### Hospital Collection
```javascript
{
  _id: ObjectId,
  uid: String, // Firebase UID
  hospitalName: String,
  primaryPhone: String,
  email: String,
  address: String,
  city: String,
  hospitalCity: String,
  pincode: String,
  location: {
    type: 'Point',
    coordinates: [longitude, latitude]
  },
  geoCoordinates: {
    lat: Number,
    lng: Number
  },
  longitude: Number,
  latitude: Number,
  status: String, // active, inactive
  isApproved: Boolean,
  departments: Array,
  specialties: Array,
  createdAt: Date,
  updatedAt: Date
}
```

---

## 🔧 Configuration

### Environment Variables
```bash
# Backend (.env)
MONGODB_URI=mongodb://localhost:27017/arcular_plus
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_PRIVATE_KEY=your-private-key
FIREBASE_CLIENT_EMAIL=your-client-email
PORT=3000
```

### Firebase Configuration
```dart
// Frontend (firebase_options.dart)
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return FirebaseOptions(
      apiKey: 'your-api-key',
      appId: 'your-app-id',
      messagingSenderId: 'your-sender-id',
      projectId: 'your-project-id',
    );
  }
}
```

---

## 🚀 Deployment

### Backend Deployment (Render)
```bash
# Deploy to Render
git push origin main

# Environment variables in Render dashboard:
MONGODB_URI=mongodb+srv://...
FIREBASE_PROJECT_ID=...
FIREBASE_PRIVATE_KEY=...
FIREBASE_CLIENT_EMAIL=...
```

### Frontend Deployment
```bash
# Build for web
flutter build web

# Build for Android
flutter build apk --release

# Build for iOS
flutter build ios --release
```

---

## 📈 Performance Considerations

### Database Indexing
```javascript
// Geospatial index for hospital location queries
db.hospitals.createIndex({ "location": "2dsphere" })

// Compound indexes for efficient queries
db.sosrequests.createIndex({ "patientId": 1, "status": 1 })
db.hospitalsos.createIndex({ "sosRequestId": 1, "hospitalId": 1 })
```

### Caching Strategy
- **Hospital Data**: Cache nearby hospitals for 5 minutes
- **SOS Status**: Real-time polling every 5 seconds
- **Escalation Status**: Poll every 30 seconds

### Rate Limiting
- **SOS Creation**: 1 request per minute per user
- **Hospital Acceptance**: No rate limit (emergency response)
- **API Calls**: 100 requests per minute per user

---

## 🔒 Security Features

### Authentication
- **Firebase Authentication**: JWT token validation
- **Role-based Access**: User vs Hospital permissions
- **Token Expiry**: Automatic token refresh

### Data Validation
- **Input Sanitization**: All user inputs validated
- **Coordinate Validation**: GPS coordinates within valid ranges
- **Phone Number Validation**: International format support

### Privacy Protection
- **Location Data**: Only shared with nearby hospitals
- **Personal Information**: Minimal data exposure
- **Emergency Contacts**: Only called when necessary

---

## 🐛 Troubleshooting

### Common Issues

#### SOS Not Creating
```bash
# Check Firebase authentication
firebase auth:list

# Verify MongoDB connection
mongosh "mongodb://localhost:27017/arcular_plus"

# Check API logs
tail -f /var/log/arcular-plus-backend.log
```

#### Hospitals Not Receiving SOS
```bash
# Verify hospital search radius
db.hospitals.find({ "status": "active", "isApproved": true })

# Check geospatial index
db.hospitals.getIndexes()

# Test coordinate calculation
node test-coordinates.js
```

#### Real-time Updates Not Working
```bash
# Check polling frequency
# User: 5 seconds
# Hospital: 5 seconds  
# Escalation: 30 seconds

# Verify WebSocket connections
netstat -an | grep :3000
```

### Debug Mode
```dart
// Enable debug logging
void main() {
  debugPrint('SOS System Debug Mode Enabled');
  runApp(MyApp());
}
```

---

## 📞 Support

### Emergency Contacts
- **Technical Support**: support@arcular.com
- **Emergency Services**: 123 (India)
- **Fire Department**: 101
- **Police**: 100

### Documentation
- **API Documentation**: `/api/docs`
- **Database Schema**: `/docs/schema.md`
- **Deployment Guide**: `/docs/deployment.md`

---

## 🔄 Version History

### v1.0.0 (Current)
- ✅ Basic SOS creation and hospital notification
- ✅ Real-time status monitoring
- ✅ Hospital acceptance and admission flow
- ✅ Emergency escalation system
- ✅ Activity logging and persistent state

### v1.1.0 (Planned)
- 🔄 Push notifications
- 🔄 SMS integration
- 🔄 Voice calls
- 🔄 Multi-language support

---

*This documentation covers the complete SOS Emergency System implementation. For technical support or feature requests, please contact the development team.*
