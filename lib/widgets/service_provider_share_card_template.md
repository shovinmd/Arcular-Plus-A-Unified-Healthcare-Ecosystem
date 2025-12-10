# Service Provider Share Card Template

This document shows how to use the `ServiceProviderShareCard` widget for all service providers to maintain consistent layout and branding.

## Usage for Each Service Provider

### 🏥 Hospital
```dart
ServiceProviderShareCard(
  name: hospital.hospitalName ?? 'Hospital Name',
  email: hospital.hospitalEmail ?? hospital.email ?? '',
  phone: hospital.hospitalPhone ?? hospital.mobileNumber ?? '',
  altPhone: hospital.alternateMobile ?? hospital.altPhoneNumber ?? '',
  address: hospital.address ?? '',
  city: hospital.city ?? '',
  state: hospital.state ?? '',
  pincode: hospital.pincode ?? '',
  arcId: hospital.healthQrId ?? hospital.arcId ?? hospital.uid,
  providerType: hospital.hospitalType ?? 'Hospital',
  registrationNumber: hospital.registrationNumber ?? 'N/A',
  profileImageUrl: profileImageUrl,
  qrDataString: qrDataString,
  maxWidth: screenWidth - 24,
  primaryColor: kHospitalGreen, // Color(0xFF4CAF50)
  secondaryColor: Color(0xFF66BB6A),
  providerIcon: Icons.local_hospital,
)
```

### 💊 Pharmacy
```dart
ServiceProviderShareCard(
  name: pharmacy.pharmacyName ?? pharmacy.fullName ?? 'Pharmacy Name',
  email: pharmacy.email ?? '',
  phone: pharmacy.mobileNumber ?? '',
  altPhone: pharmacy.alternateMobile ?? '',
  address: pharmacy.address ?? '',
  city: pharmacy.city ?? '',
  state: pharmacy.state ?? '',
  pincode: pharmacy.pincode ?? '',
  arcId: pharmacy.healthQrId ?? pharmacy.arcId ?? pharmacy.uid,
  providerType: 'Pharmaceutical Store',
  registrationNumber: pharmacy.registrationNumber ?? 'N/A',
  profileImageUrl: profileImageUrl,
  qrDataString: qrDataString,
  maxWidth: screenWidth - 24,
  primaryColor: kPharmacyYellow, // Color(0xFFFFD700)
  secondaryColor: Color(0xFFFFA500),
  providerIcon: Icons.local_pharmacy,
)
```

### 👨‍⚕️ Doctor
```dart
ServiceProviderShareCard(
  name: doctor.fullName ?? 'Doctor Name',
  email: doctor.email ?? '',
  phone: doctor.mobileNumber ?? '',
  altPhone: doctor.alternateMobile ?? '',
  address: doctor.address ?? '',
  city: doctor.city ?? '',
  state: doctor.state ?? '',
  pincode: doctor.pincode ?? '',
  arcId: doctor.healthQrId ?? doctor.arcId ?? doctor.uid,
  providerType: 'Medical Doctor',
  registrationNumber: doctor.medicalLicenseNumber ?? 'N/A',
  profileImageUrl: profileImageUrl,
  qrDataString: qrDataString,
  maxWidth: screenWidth - 24,
  primaryColor: kDoctorBlue, // Color(0xFF2196F3)
  secondaryColor: Color(0xFF1976D2),
  providerIcon: Icons.medical_services,
)
```

### 🧪 Lab
```dart
ServiceProviderShareCard(
  name: lab.labName ?? lab.fullName ?? 'Lab Name',
  email: lab.email ?? '',
  phone: lab.mobileNumber ?? '',
  altPhone: lab.alternateMobile ?? '',
  address: lab.address ?? '',
  city: lab.city ?? '',
  state: lab.state ?? '',
  pincode: lab.pincode ?? '',
  arcId: lab.healthQrId ?? lab.arcId ?? lab.uid,
  providerType: 'Diagnostic Laboratory',
  registrationNumber: lab.labLicenseNumber ?? 'N/A',
  profileImageUrl: profileImageUrl,
  qrDataString: qrDataString,
  maxWidth: screenWidth - 24,
  primaryColor: kLabPurple, // Color(0xFF9C27B0)
  secondaryColor: Color(0xFF7B1FA2),
  providerIcon: Icons.science,
)
```

### 👩‍⚕️ Nurse
```dart
ServiceProviderShareCard(
  name: nurse.fullName ?? 'Nurse Name',
  email: nurse.email ?? '',
  phone: nurse.mobileNumber ?? '',
  altPhone: nurse.alternateMobile ?? '',
  address: nurse.address ?? '',
  city: nurse.city ?? '',
  state: nurse.state ?? '',
  pincode: nurse.pincode ?? '',
  arcId: nurse.healthQrId ?? nurse.arcId ?? nurse.uid,
  providerType: 'Registered Nurse',
  registrationNumber: nurse.nursingLicenseNumber ?? 'N/A',
  profileImageUrl: profileImageUrl,
  qrDataString: qrDataString,
  maxWidth: screenWidth - 24,
  primaryColor: kNursePink, // Color(0xFFE91E63)
  secondaryColor: Color(0xFFC2185B),
  providerIcon: Icons.health_and_safety,
)
```

## Color Constants

Make sure to define these color constants in each service provider's profile screen:

```dart
// Hospital
const Color kHospitalGreen = Color(0xFF4CAF50);

// Pharmacy
const Color kPharmacyYellow = Color(0xFFFFD700);

// Doctor
const Color kDoctorBlue = Color(0xFF2196F3);

// Lab
const Color kLabPurple = Color(0xFF9C27B0);

// Nurse
const Color kNursePink = Color(0xFFE91E63);
```

## Implementation Steps

1. **Import the shared widget:**
   ```dart
   import '../../widgets/service_provider_share_card.dart';
   ```

2. **Replace the existing `_buildShareIdCard` method** with the `ServiceProviderShareCard` widget

3. **Remove the old `_buildShareIdCard` method** and any related helper methods

4. **Update the `_shareQr()` method** to use the new widget

5. **Test the share functionality** to ensure the card displays correctly

## Benefits

- ✅ **Consistent Layout**: All service providers have the same professional layout
- ✅ **Brand Colors**: Each provider uses their specific color theme
- ✅ **Responsive Design**: Automatically adapts to different screen sizes
- ✅ **Maintainable**: Single widget to update for all providers
- ✅ **Professional Look**: Clean, modern design with proper spacing and typography
