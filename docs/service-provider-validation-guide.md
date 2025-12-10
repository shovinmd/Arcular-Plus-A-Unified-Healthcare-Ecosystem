# Service Provider Registration - Field Validation Guide

## Overview
This document provides comprehensive validation rules for all service provider registration screens in the Arcular Plus application. Each field is categorized as Required or Optional with specific validation criteria.

---

## 1. DOCTOR REGISTRATION SCREEN

### **Step 1: Basic Information**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Full Name** | ✅ Required | - Min 2 characters<br>- Max 50 characters<br>- Only letters, spaces, hyphens<br>- No numbers or special chars | "Please enter your full legal name"<br>"Name must be 2-50 characters"<br>"Name can only contain letters" |
| **Email** | ✅ Required | - Valid email format<br>- Must be unique<br>- Max 100 characters | "Please enter a valid email"<br>"Email already exists"<br>"Email too long" |
| **Mobile Number** | ✅ Required | - Exactly 10 digits<br>- Indian mobile format<br>- Must be unique | "Please enter 10-digit mobile number"<br>"Mobile number already exists"<br>"Invalid mobile format" |
| **Alternate Mobile** | ❌ Optional | - Exactly 10 digits if provided<br>- Different from primary mobile | "Invalid alternate mobile format"<br>"Cannot be same as primary mobile" |
| **Gender** | ✅ Required | - Must select from dropdown<br>- Options: Male, Female, Other | "Please select gender" |
| **Date of Birth** | ✅ Required | - Must be valid date<br>- Age between 18-80 years<br>- Cannot be future date | "Please select date of birth"<br>"Age must be 18-80 years"<br>"Cannot be future date" |
| **Blood Group** | ✅ Required | - Must select from dropdown<br>- Valid blood group format | "Please select blood group" |
| **Address** | ✅ Required | - Min 10 characters<br>- Max 200 characters<br>- Must contain street/area | "Please enter complete address"<br>"Address too short/long" |
| **City** | ✅ Required | - Min 2 characters<br>- Max 50 characters<br>- Only letters and spaces | "Please enter city name"<br>"Invalid city format" |
| **State** | ✅ Required | - Min 2 characters<br>- Max 50 characters<br>- Only letters and spaces | "Please enter state name"<br>"Invalid state format" |
| **Pincode** | ✅ Required | - Exactly 6 digits<br>- Valid Indian pincode format | "Please enter 6-digit pincode"<br>"Invalid pincode format" |
| **Location Coordinates** | ❌ Optional | - Latitude: -90 to 90<br>- Longitude: -180 to 180<br>- Decimal format | "Invalid coordinates"<br>"Latitude must be -90 to 90"<br>"Longitude must be -180 to 180" |

### **Step 2: Professional Details**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Medical Registration Number** | ✅ Required | - Min 5 characters<br>- Max 20 characters<br>- Alphanumeric format<br>- Must be unique | "Please enter medical registration number"<br>"Registration number already exists"<br>"Invalid format" |
| **License Number** | ✅ Required | - Min 5 characters<br>- Max 20 characters<br>- Alphanumeric format<br>- Must be unique | "Please enter license number"<br>"License number already exists"<br>"Invalid format" |
| **Primary Specialization** | ✅ Required | - Must select from dropdown<br>- Cannot be empty | "Please select primary specialization" |
| **Specializations** | ✅ Required | - Must select at least 1<br>- Max 5 specializations<br>- Cannot duplicate primary | "Please select at least one specialization"<br>"Maximum 5 specializations allowed"<br>"Cannot duplicate primary specialization" |
| **Years of Experience** | ✅ Required | - Must be number<br>- Range: 0-50 years<br>- Cannot be negative | "Please enter years of experience"<br>"Experience must be 0-50 years"<br>"Must be a valid number" |
| **Consultation Fee** | ✅ Required | - Must be number<br>- Range: ₹100-₹10000<br>- Cannot be negative | "Please enter consultation fee"<br>"Fee must be ₹100-₹10000"<br>"Must be a valid amount" |
| **Qualifications** | ✅ Required | - Must select at least 1<br>- Max 5 qualifications<br>- Cannot be empty | "Please select at least one qualification"<br>"Maximum 5 qualifications allowed" |
| **Hospital Affiliations** | ❌ Optional | - Max 10 hospitals<br>- Must be valid hospital IDs | "Maximum 10 hospitals allowed"<br>"Invalid hospital selection" |

### **Step 3: Document Upload**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Medical Degree Certificate** | ✅ Required | - File size: Max 10MB<br>- Formats: JPG, PNG, PDF<br>- Must be clear and readable | "Please upload medical degree certificate"<br>"File too large (max 10MB)"<br>"Invalid file format" |
| **Medical License Certificate** | ✅ Required | - File size: Max 10MB<br>- Formats: JPG, PNG, PDF<br>- Must be clear and readable | "Please upload license certificate"<br>"File too large (max 10MB)"<br>"Invalid file format" |
| **Identity Proof** | ✅ Required | - File size: Max 10MB<br>- Formats: JPG, PNG, PDF<br>- Must be clear and readable | "Please upload identity proof"<br>"File too large (max 10MB)"<br>"Invalid file format" |

---

## 2. PHARMACY REGISTRATION SCREEN

### **Step 1: Basic Information**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Pharmacy Name** | ✅ Required | - Min 3 characters<br>- Max 100 characters<br>- Business name format<br>- Must be unique | "Please enter pharmacy name"<br>"Pharmacy name already exists"<br>"Invalid business name format" |
| **Email** | ✅ Required | - Valid email format<br>- Must be unique<br>- Max 100 characters | "Please enter a valid email"<br>"Email already exists"<br>"Email too long" |
| **Phone Number** | ✅ Required | - Exactly 10 digits<br>- Indian mobile format<br>- Must be unique | "Please enter 10-digit phone number"<br>"Phone number already exists"<br>"Invalid phone format" |
| **Alternate Phone** | ❌ Optional | - Exactly 10 digits if provided<br>- Different from primary phone | "Invalid alternate phone format"<br>"Cannot be same as primary phone" |
| **Gender** | ✅ Required | - Must select from dropdown<br>- Options: Male, Female, Other | "Please select gender" |
| **Date of Birth** | ✅ Required | - Must be valid date<br>- Age between 18-80 years<br>- Cannot be future date | "Please select date of birth"<br>"Age must be 18-80 years"<br>"Cannot be future date" |

### **Step 2: Location Details**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Address** | ✅ Required | - Min 10 characters<br>- Max 200 characters<br>- Must contain street/area | "Please enter complete pharmacy address"<br>"Address too short/long" |
| **City** | ✅ Required | - Min 2 characters<br>- Max 50 characters<br>- Only letters and spaces | "Please enter city name"<br>"Invalid city format" |
| **State** | ✅ Required | - Min 2 characters<br>- Max 50 characters<br>- Only letters and spaces | "Please enter state name"<br>"Invalid state format" |
| **Pincode** | ✅ Required | - Exactly 6 digits<br>- Valid Indian pincode format | "Please enter 6-digit pincode"<br>"Invalid pincode format" |
| **Location Coordinates** | ❌ Optional | - Latitude: -90 to 90<br>- Longitude: -180 to 180<br>- Decimal format | "Invalid coordinates"<br>"Latitude must be -90 to 90"<br>"Longitude must be -180 to 180" |

### **Step 3: Operational Details**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Pharmacy License Number** | ✅ Required | - Min 5 characters<br>- Max 20 characters<br>- Alphanumeric format<br>- Must be unique | "Please enter pharmacy license number"<br>"License number already exists"<br>"Invalid format" |
| **Owner Name** | ✅ Required | - Min 2 characters<br>- Max 50 characters<br>- Only letters and spaces | "Please enter owner name"<br>"Invalid name format" |
| **Pharmacist Name** | ✅ Required | - Min 2 characters<br>- Max 50 characters<br>- Only letters and spaces | "Please enter pharmacist name"<br>"Invalid name format" |
| **Pharmacist License Number** | ✅ Required | - Min 5 characters<br>- Max 20 characters<br>- Alphanumeric format<br>- Must be unique | "Please enter pharmacist license number"<br>"License number already exists"<br>"Invalid format" |
| **Pharmacist Qualification** | ✅ Required | - Must select from dropdown<br>- Valid qualification | "Please select pharmacist qualification" |
| **Years of Experience** | ✅ Required | - Must be number<br>- Range: 0-50 years<br>- Cannot be negative | "Please enter years of experience"<br>"Experience must be 0-50 years"<br>"Must be a valid number" |
| **Hospital Affiliations** | ❌ Optional | - Max 10 hospitals<br>- Must be valid hospital IDs | "Maximum 10 hospitals allowed"<br>"Invalid hospital selection" |
| **Home Delivery** | ❌ Optional | - Boolean value<br>- Default: false | - |

### **Step 4: Business Information**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Opening Time** | ✅ Required | - Must select from dropdown<br>- Valid time format<br>- Cannot be same as closing time | "Please select opening time"<br>"Cannot be same as closing time" |
| **Closing Time** | ✅ Required | - Must select from dropdown<br>- Valid time format<br>- Must be after opening time | "Please select closing time"<br>"Must be after opening time" |
| **Working Days** | ✅ Required | - Must select at least 1 day<br>- Max 7 days<br>- Cannot be empty | "Please select at least one working day"<br>"Maximum 7 days allowed" |
| **Services Provided** | ✅ Required | - Must select at least 1 service<br>- Max 10 services<br>- Cannot be empty | "Please select at least one service"<br>"Maximum 10 services allowed" |
| **Types of Drugs Available** | ✅ Required | - Must select at least 1 type<br>- Max 10 types<br>- Cannot be empty | "Please select at least one drug type"<br>"Maximum 10 types allowed" |

### **Step 5: Document Upload**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Pharmacy License Certificate** | ✅ Required | - File size: Max 10MB<br>- Formats: JPG, PNG, PDF<br>- Must be clear and readable | "Please upload pharmacy license certificate"<br>"File too large (max 10MB)"<br>"Invalid file format" |
| **Drug License Document** | ✅ Required | - File size: Max 10MB<br>- Formats: JPG, PNG, PDF<br>- Must be clear and readable | "Please upload drug license document"<br>"File too large (max 10MB)"<br>"Invalid file format" |
| **Premises Certificate** | ✅ Required | - File size: Max 10MB<br>- Formats: JPG, PNG, PDF<br>- Must be clear and readable | "Please upload premises certificate"<br>"File too large (max 10MB)"<br>"Invalid file format" |
| **Profile Picture** | ✅ Required | - File size: Max 5MB<br>- Formats: JPG, PNG only<br>- Must be clear image | "Please upload profile picture"<br>"File too large (max 5MB)"<br>"Invalid image format" |

---

## 3. LAB REGISTRATION SCREEN

### **Step 1: Basic Information**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Lab Name** | ✅ Required | - Min 3 characters<br>- Max 100 characters<br>- Business name format<br>- Must be unique | "Please enter lab name"<br>"Lab name already exists"<br>"Invalid business name format" |
| **Email** | ✅ Required | - Valid email format<br>- Must be unique<br>- Max 100 characters | "Please enter a valid email"<br>"Email already exists"<br>"Email too long" |
| **Phone Number** | ✅ Required | - Exactly 10 digits<br>- Indian mobile format<br>- Must be unique | "Please enter 10-digit phone number"<br>"Phone number already exists"<br>"Invalid phone format" |
| **Alternate Phone** | ❌ Optional | - Exactly 10 digits if provided<br>- Different from primary phone | "Invalid alternate phone format"<br>"Cannot be same as primary phone" |

### **Step 2: Location Details**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Address** | ✅ Required | - Min 10 characters<br>- Max 200 characters<br>- Must contain street/area | "Please enter complete lab address"<br>"Address too short/long" |
| **City** | ✅ Required | - Min 2 characters<br>- Max 50 characters<br>- Only letters and spaces | "Please enter city name"<br>"Invalid city format" |
| **State** | ✅ Required | - Min 2 characters<br>- Max 50 characters<br>- Only letters and spaces | "Please enter state name"<br>"Invalid state format" |
| **Pincode** | ✅ Required | - Exactly 6 digits<br>- Valid Indian pincode format | "Please enter 6-digit pincode"<br>"Invalid pincode format" |
| **Location Coordinates** | ❌ Optional | - Latitude: -90 to 90<br>- Longitude: -180 to 180<br>- Decimal format | "Invalid coordinates"<br>"Latitude must be -90 to 90"<br>"Longitude must be -180 to 180" |

### **Step 3: Operational Details**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Lab License Number** | ✅ Required | - Min 5 characters<br>- Max 20 characters<br>- Alphanumeric format<br>- Must be unique | "Please enter lab license number"<br>"License number already exists"<br>"Invalid format" |
| **Associated Hospital** | ❌ Optional | - Min 2 characters<br>- Max 100 characters<br>- Only letters and spaces | "Invalid hospital name format" |
| **Owner Name** | ✅ Required | - Min 2 characters<br>- Max 50 characters<br>- Only letters and spaces | "Please enter owner name"<br>"Invalid name format" |
| **Hospital Affiliations** | ❌ Optional | - Max 10 hospitals<br>- Must be valid hospital IDs | "Maximum 10 hospitals allowed"<br>"Invalid hospital selection" |
| **Available Tests** | ✅ Required | - Must select at least 1 test<br>- Max 15 tests<br>- Cannot be empty | "Please select at least one test"<br>"Maximum 15 tests allowed" |
| **Home Sample Collection** | ❌ Optional | - Boolean value<br>- Default: false | - |

### **Step 4: Document Upload**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Lab License Certificate** | ✅ Required | - File size: Max 10MB<br>- Formats: JPG, PNG, PDF<br>- Must be clear and readable | "Please upload lab license certificate"<br>"File too large (max 10MB)"<br>"Invalid file format" |
| **Profile Picture** | ✅ Required | - File size: Max 5MB<br>- Formats: JPG, PNG only<br>- Must be clear image | "Please upload profile picture"<br>"File too large (max 5MB)"<br>"Invalid image format" |

---

## 4. NURSE REGISTRATION SCREEN

### **Step 1: Basic Information**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Full Name** | ✅ Required | - Min 2 characters<br>- Max 50 characters<br>- Only letters, spaces, hyphens<br>- No numbers or special chars | "Please enter your full legal name"<br>"Name must be 2-50 characters"<br>"Name can only contain letters" |
| **Email** | ✅ Required | - Valid email format<br>- Must be unique<br>- Max 100 characters | "Please enter a valid email"<br>"Email already exists"<br>"Email too long" |
| **Phone Number** | ✅ Required | - Exactly 10 digits<br>- Indian mobile format<br>- Must be unique | "Please enter 10-digit phone number"<br>"Phone number already exists"<br>"Invalid phone format" |
| **Alternate Phone** | ❌ Optional | - Exactly 10 digits if provided<br>- Different from primary phone | "Invalid alternate phone format"<br>"Cannot be same as primary phone" |
| **Gender** | ✅ Required | - Must select from dropdown<br>- Options: Male, Female, Other | "Please select gender" |
| **Date of Birth** | ✅ Required | - Must be valid date<br>- Age between 18-65 years<br>- Cannot be future date | "Please select date of birth"<br>"Age must be 18-65 years"<br>"Cannot be future date" |
| **Address** | ✅ Required | - Min 10 characters<br>- Max 200 characters<br>- Must contain street/area | "Please enter complete address"<br>"Address too short/long" |
| **City** | ✅ Required | - Min 2 characters<br>- Max 50 characters<br>- Only letters and spaces | "Please enter city name"<br>"Invalid city format" |
| **State** | ✅ Required | - Min 2 characters<br>- Max 50 characters<br>- Only letters and spaces | "Please enter state name"<br>"Invalid state format" |
| **Pincode** | ✅ Required | - Exactly 6 digits<br>- Valid Indian pincode format | "Please enter 6-digit pincode"<br>"Invalid pincode format" |
| **Location Coordinates** | ❌ Optional | - Latitude: -90 to 90<br>- Longitude: -180 to 180<br>- Decimal format | "Invalid coordinates"<br>"Latitude must be -90 to 90"<br>"Longitude must be -180 to 180" |

### **Step 2: Professional Details**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Nursing License Number** | ✅ Required | - Min 5 characters<br>- Max 20 characters<br>- Alphanumeric format<br>- Must be unique | "Please enter nursing license number"<br>"License number already exists"<br>"Invalid format" |
| **Qualification** | ✅ Required | - Must select from dropdown<br>- Valid nursing qualification | "Please select qualification" |
| **Years of Experience** | ✅ Required | - Must be number<br>- Range: 0-40 years<br>- Cannot be negative | "Please enter years of experience"<br>"Experience must be 0-40 years"<br>"Must be a valid number" |
| **Specialization** | ❌ Optional | - Must select from dropdown if provided<br>- Valid nursing specialization | "Invalid specialization" |
| **Current Hospital** | ✅ Required | - Min 2 characters<br>- Max 100 characters<br>- Only letters and spaces | "Please enter current hospital name"<br>"Invalid hospital name format" |
| **Hospital Affiliations** | ❌ Optional | - Max 5 hospitals<br>- Must be valid hospital IDs | "Maximum 5 hospitals allowed"<br>"Invalid hospital selection" |

### **Step 3: Document Upload**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Nursing License Certificate** | ✅ Required | - File size: Max 10MB<br>- Formats: JPG, PNG, PDF<br>- Must be clear and readable | "Please upload nursing license certificate"<br>"File too large (max 10MB)"<br>"Invalid file format" |
| **Profile Picture** | ✅ Required | - File size: Max 5MB<br>- Formats: JPG, PNG only<br>- Must be clear image | "Please upload profile picture"<br>"File too large (max 5MB)"<br>"Invalid image format" |
| **Nursing Degree Certificate** | ✅ Required | - File size: Max 10MB<br>- Formats: JPG, PNG, PDF<br>- Must be clear and readable | "Please upload nursing degree certificate"<br>"File too large (max 10MB)"<br>"Invalid file format" |
| **Identity Proof** | ✅ Required | - File size: Max 10MB<br>- Formats: JPG, PNG, PDF<br>- Must be clear and readable | "Please upload identity proof"<br>"File too large (max 10MB)"<br>"Invalid file format" |

---

## 5. HOSPITAL REGISTRATION SCREEN

### **Step 1: Basic Information**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Hospital Name** | ✅ Required | - Min 3 characters<br>- Max 100 characters<br>- Business name format<br>- Must be unique | "Please enter hospital name"<br>"Hospital name already exists"<br>"Invalid business name format" |
| **Hospital Owner Name** | ✅ Required | - Min 2 characters<br>- Max 50 characters<br>- Only letters and spaces | "Please enter owner name"<br>"Invalid name format" |
| **Email** | ✅ Required | - Valid email format<br>- Must be unique<br>- Max 100 characters | "Please enter a valid email"<br>"Email already exists"<br>"Email too long" |
| **Phone Number** | ✅ Required | - Exactly 10 digits<br>- Indian mobile format<br>- Must be unique | "Please enter 10-digit phone number"<br>"Phone number already exists"<br>"Invalid phone format" |
| **Alternate Phone** | ❌ Optional | - Exactly 10 digits if provided<br>- Different from primary phone | "Invalid alternate phone format"<br>"Cannot be same as primary phone" |

### **Step 2: Location Details**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Address** | ✅ Required | - Min 10 characters<br>- Max 200 characters<br>- Must contain street/area | "Please enter complete hospital address"<br>"Address too short/long" |
| **City** | ✅ Required | - Min 2 characters<br>- Max 50 characters<br>- Only letters and spaces | "Please enter city name"<br>"Invalid city format" |
| **State** | ✅ Required | - Min 2 characters<br>- Max 50 characters<br>- Only letters and spaces | "Please enter state name"<br>"Invalid state format" |
| **Pincode** | ✅ Required | - Exactly 6 digits<br>- Valid Indian pincode format | "Please enter 6-digit pincode"<br>"Invalid pincode format" |
| **Location Coordinates** | ❌ Optional | - Latitude: -90 to 90<br>- Longitude: -180 to 180<br>- Decimal format | "Invalid coordinates"<br>"Latitude must be -90 to 90"<br>"Longitude must be -180 to 180" |

### **Step 3: Operational Details**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **Hospital Type** | ✅ Required | - Must select from dropdown<br>- Valid hospital type | "Please select hospital type" |
| **Registration Number** | ✅ Required | - Min 5 characters<br>- Max 20 characters<br>- Alphanumeric format<br>- Must be unique | "Please enter registration number"<br>"Registration number already exists"<br>"Invalid format" |
| **Number of Beds** | ✅ Required | - Must be number<br>- Range: 1-5000 beds<br>- Cannot be negative or zero | "Please enter number of beds"<br>"Beds must be 1-5000"<br>"Must be a valid number" |
| **Departments** | ✅ Required | - Must select at least 1 department<br>- Max 20 departments<br>- Cannot be empty | "Please select at least one department"<br>"Maximum 20 departments allowed" |
| **Special Facilities** | ❌ Optional | - Max 15 facilities<br>- Must be valid facilities | "Maximum 15 facilities allowed"<br>"Invalid facility selection" |

### **Step 4: Document Upload**

| Field | Required | Validation Rules | Error Messages |
|-------|----------|------------------|----------------|
| **License Document** | ✅ Required | - File size: Max 10MB<br>- Formats: JPG, PNG, PDF<br>- Must be clear and readable | "Please upload license document"<br>"File too large (max 10MB)"<br>"Invalid file format" |
| **Registration Certificate** | ✅ Required | - File size: Max 10MB<br>- Formats: JPG, PNG, PDF<br>- Must be clear and readable | "Please upload registration certificate"<br>"File too large (max 10MB)"<br>"Invalid file format" |
| **Building Permit** | ✅ Required | - File size: Max 10MB<br>- Formats: JPG, PNG, PDF<br>- Must be clear and readable | "Please upload building permit"<br>"File too large (max 10MB)"<br>"Invalid file format" |

---

## **COMMON VALIDATION RULES**

### **Email Validation**
```dart
bool isValidEmail(String email) {
  return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
}
```

### **Mobile Number Validation**
```dart
bool isValidMobile(String mobile) {
  return RegExp(r'^[6-9]\d{9}$').hasMatch(mobile);
}
```

### **Pincode Validation**
```dart
bool isValidPincode(String pincode) {
  return RegExp(r'^[1-9][0-9]{5}$').hasMatch(pincode);
}
```

### **Name Validation**
```dart
bool isValidName(String name) {
  return RegExp(r'^[a-zA-Z\s\-\.]+$').hasMatch(name) && 
         name.length >= 2 && 
         name.length <= 50;
}
```

### **File Upload Validation**
```dart
bool isValidFile(File file, List<String> allowedExtensions, int maxSizeMB) {
  String extension = file.path.split('.').last.toLowerCase();
  int fileSizeMB = (await file.length()) ~/ (1024 * 1024);
  
  return allowedExtensions.contains(extension) && 
         fileSizeMB <= maxSizeMB;
}
```

---

## **IMPLEMENTATION NOTES**

1. **Real-time Validation**: Validate fields as user types for better UX
2. **Server-side Validation**: Always validate on backend for security
3. **Error Messages**: Use clear, user-friendly error messages
4. **Field Dependencies**: Some fields depend on others (e.g., closing time after opening time)
5. **File Upload**: Show progress indicators and validate file types/sizes
6. **Location Services**: Handle location permission gracefully
7. **Network Validation**: Check for duplicate entries via API calls
8. **Step Validation**: Ensure all required fields in current step are filled before proceeding

---

## **TESTING CHECKLIST**

- [ ] All required fields show validation errors when empty
- [ ] Email format validation works correctly
- [ ] Mobile number format validation works correctly
- [ ] File upload size and format validation works
- [ ] Duplicate email/mobile detection works
- [ ] Step progression validation works
- [ ] Location coordinate validation works
- [ ] Date validation works correctly
- [ ] Dropdown selections work properly
- [ ] Multi-select validations work correctly
- [ ] Error messages are clear and helpful
- [ ] Form submission works only when all validations pass
