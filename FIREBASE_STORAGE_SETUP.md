# Firebase Storage Setup Guide

## 🔧 Current Issue
Your Firebase Storage rules are currently set to deny all operations, which is preventing image uploads.

## 📋 Steps to Fix

### 1. **Deploy Firebase Storage Rules**

#### Option A: Using Firebase Console (Recommended for beginners)
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `arcularplus-7e66c`
3. Navigate to **Storage** in the left sidebar
4. Click on **Rules** tab
5. Replace the current rules with one of the following:

#### For Testing (Quick Fix):
```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // Allow all authenticated users to read and write files
    // WARNING: This is for testing only - not recommended for production
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

#### For Production (Secure):
```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // Allow users to read and write their own profile pictures
    match /profile_pictures/{userType}/{userId}/{fileName} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Allow users to read and write their own reports
    match /reports/{userType}/{userId}/{reportType}/{fileName} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Allow users to read and write their own certificates
    match /certificates/{userType}/{userId}/{certificateType}/{fileName} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Deny all other access
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

6. Click **Publish** to deploy the rules

#### Option B: Using Firebase CLI
1. Install Firebase CLI if not already installed:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Initialize Firebase in your project (if not already done):
   ```bash
   firebase init storage
   ```

4. Deploy the rules:
   ```bash
   firebase deploy --only storage
   ```

### 2. **Verify Storage Bucket Configuration**

1. In Firebase Console, go to **Storage**
2. Make sure your storage bucket is created: `arcularplus-7e66c.appspot.com`
3. Check that the bucket is in the correct region

### 3. **Test the Upload**

After deploying the rules, test the profile picture upload:
1. Run your Flutter app
2. Navigate to the Profile Settings screen
3. Try uploading a profile picture
4. Check the console for any error messages

## 🔍 Troubleshooting

### Common Issues:

1. **"Permission denied" error**
   - Make sure you're signed in to Firebase Auth
   - Check that the rules are deployed correctly
   - Verify the user ID matches the authenticated user

2. **"Bucket not found" error**
   - Ensure the storage bucket is created in Firebase Console
   - Check the bucket name in your `firebase_options.dart`

3. **"Network error"**
   - Check your internet connection
   - Verify Firebase project configuration

### Debug Steps:

1. **Check Firebase Auth Status**:
   ```dart
   final user = FirebaseAuth.instance.currentUser;
   print('Current user: ${user?.uid}');
   ```

2. **Check Storage Service**:
   Add debug prints to your `StorageService`:
   ```dart
   print('Uploading to path: $storagePath');
   print('User ID: $userId');
   ```

3. **Test with Simple Upload**:
   ```dart
   try {
     final ref = FirebaseStorage.instance.ref().child('test/test.txt');
     await ref.putString('Hello World');
     print('Upload successful');
   } catch (e) {
     print('Upload failed: $e');
   }
   ```

## 🛡️ Security Best Practices

### For Production:
1. **Use specific rules** instead of allowing all authenticated users
2. **Validate file types** and sizes
3. **Implement user-specific paths**
4. **Add rate limiting** if needed
5. **Regular security audits**

### Example Secure Rules:
```javascript
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // Profile pictures - users can only access their own
    match /profile_pictures/{userType}/{userId}/{fileName} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId
        && request.resource.size < 5 * 1024 * 1024 // 5MB limit
        && request.resource.contentType.matches('image/.*');
    }
    
    // Reports - users can only access their own
    match /reports/{userType}/{userId}/{reportType}/{fileName} {
      allow read, write: if request.auth != null 
        && request.auth.uid == userId
        && request.resource.size < 10 * 1024 * 1024; // 10MB limit
    }
    
    // Deny all other access
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## 📱 Testing the Implementation

After deploying the rules, test with this simple code:

```dart
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> testUpload() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('User not authenticated');
      return;
    }
    
    final ref = FirebaseStorage.instance
        .ref()
        .child('profile_pictures/patient/${user.uid}/test.txt');
    
    await ref.putString('Test upload');
    final url = await ref.getDownloadURL();
    print('Upload successful: $url');
  } catch (e) {
    print('Upload failed: $e');
  }
}
```

## 🚀 Next Steps

1. **Deploy the test rules first** to verify uploads work
2. **Test with your app** to ensure profile picture uploads function
3. **Switch to production rules** once everything is working
4. **Monitor Firebase Console** for any errors or issues

Let me know if you encounter any issues after deploying these rules! 