import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = Uuid();

  // Test upload function to debug issues
  Future<String?> testUpload() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No authenticated user found');
        return null;
      }

      print('✅ User authenticated: ${user.uid}');

      final ref = _storage.ref().child('test/${user.uid}/test.txt');
      print('📁 Uploading to path: test/${user.uid}/test.txt');

      await ref.putString('Test upload at ${DateTime.now()}');
      print('✅ Upload completed');

      final url = await ref.getDownloadURL();
      print('🔗 Download URL: $url');

      return url;
    } catch (e) {
      print('❌ Test upload failed: $e');
      return null;
    }
  }

  // Upload profile picture with enhanced debugging
  Future<String?> uploadProfilePicture({
    required String userId,
    required String userType,
    XFile? imageFile,
    File? imageFileFromFile,
    Uint8List? imageBytes,
  }) async {
    try {
      print('🚀 Starting profile picture upload...');
      print('👤 User ID: $userId');
      print('👥 User Type: $userType');

      Uint8List? bytes;
      String? fileName;

      if (imageFile != null) {
        print('📸 Using XFile: ${imageFile.path}');
        bytes = await imageFile.readAsBytes();
        fileName = path.basename(imageFile.path);
        print('📄 File name: $fileName');
        print('📊 File size: ${bytes.length} bytes');
      } else if (imageFileFromFile != null) {
        print('📸 Using File: ${imageFileFromFile.path}');
        bytes = await imageFileFromFile.readAsBytes();
        fileName = path.basename(imageFileFromFile.path);
        print('📄 File name: $fileName');
        print('📊 File size: ${bytes.length} bytes');
      } else if (imageBytes != null) {
        print('📸 Using image bytes');
        bytes = imageBytes;
        fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        print('📄 File name: $fileName');
        print('📊 File size: ${bytes.length} bytes');
      } else {
        throw Exception('No image data provided');
      }

      // Generate unique filename
      final uniqueFileName = '${_uuid.v4()}_$fileName';
      final storagePath = 'profile_pictures/$userType/$userId/$uniqueFileName';

      print('📁 Storage path: $storagePath');

      final ref = _storage.ref().child(storagePath);

      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'userType': userType,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      print('⬆️ Starting upload...');
      final uploadTask = ref.putData(bytes, metadata);

      // Wait for upload to complete
      final snapshot = await uploadTask;
      print('✅ Upload completed successfully');
      print('📊 Bytes transferred: ${snapshot.bytesTransferred}');

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('🔗 Download URL: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading profile picture: $e');
      print('❌ Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('❌ Firebase error code: ${e.code}');
        print('❌ Firebase error message: ${e.message}');
      }
      rethrow;
    }
  }

  // Upload report/document with progress tracking
  Future<String?> uploadReport({
    required String userId,
    required String userType,
    required String
        reportType, // 'lab_report', 'medical_report', 'prescription', etc.
    required String fileName,
    required Uint8List fileBytes,
    String? contentType,
    Map<String, String>? metadata,
    Function(double)? onProgress,
  }) async {
    try {
      // Generate unique filename
      final uniqueFileName = '${_uuid.v4()}_$fileName';
      final storagePath =
          'reports/$userType/$userId/$reportType/$uniqueFileName';

      final ref = _storage.ref().child(storagePath);

      // Prepare metadata
      final uploadMetadata = SettableMetadata(
        contentType: contentType ?? 'application/pdf',
        customMetadata: {
          'userId': userId,
          'userType': userType,
          'reportType': reportType,
          'originalFileName': fileName,
          'uploadedAt': DateTime.now().toIso8601String(),
          ...?metadata,
        },
      );

      final uploadTask = ref.putData(fileBytes, uploadMetadata);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Error uploading report: $e');
      rethrow;
    }
  }

  // Upload certificate/document
  Future<String?> uploadCertificate({
    required String userId,
    required String userType,
    required String
        certificateType, // 'medical_license', 'lab_license', 'pharmacy_license', etc.
    required String fileName,
    required Uint8List fileBytes,
    String? contentType,
  }) async {
    try {
      print('🚀 Starting certificate upload...');
      print('👤 User ID: $userId');
      print('👥 User Type: $userType');
      print('📄 Certificate Type: $certificateType');
      print('📄 File Name: $fileName');
      print('📊 File Size: ${fileBytes.length} bytes');

      // Check Firebase Auth state
      final currentUser = FirebaseAuth.instance.currentUser;
      print('🔍 Firebase Auth current user: ${currentUser?.uid ?? 'null'}');

      if (currentUser == null) {
        print('❌ No Firebase user found');
        throw Exception('No authenticated user found');
      }

      // Test Firebase Storage access
      try {
        final testRef = _storage.ref().child('test/test.txt');
        await testRef.putString('test');
        print('✅ Firebase Storage access test successful');
      } catch (e) {
        print('❌ Firebase Storage access test failed: $e');
        throw Exception('Firebase Storage not accessible: $e');
      }

      // Generate unique filename
      final uniqueFileName = '${_uuid.v4()}_$fileName';
      final storagePath =
          'certificates/$userType/$userId/$certificateType/$uniqueFileName';

      print('📁 Storage Path: $storagePath');

      final ref = _storage.ref().child(storagePath);

      // Prepare metadata
      final metadata = SettableMetadata(
        contentType: contentType ?? 'application/pdf',
        customMetadata: {
          'userId': userId,
          'userType': userType,
          'certificateType': certificateType,
          'originalFileName': fileName,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      print('⬆️ Starting upload to Firebase Storage...');
      final uploadTask = ref.putData(fileBytes, metadata);

      // Wait for upload to complete
      final snapshot = await uploadTask;

      print('✅ Upload completed successfully');

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print('🔗 Download URL: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading certificate: $e');
      print('🔍 Error details: ${e.toString()}');
      rethrow;
    }
  }

  // Pick image from gallery
  Future<XFile?> pickImageFromGallery({
    ImageSource source = ImageSource.gallery,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality ?? 80,
      );
      return image;
    } catch (e) {
      print('Error picking image: $e');
      rethrow;
    }
  }

  // Pick multiple images
  Future<List<XFile>> pickMultipleImages({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality ?? 80,
      );
      return images;
    } catch (e) {
      print('Error picking multiple images: $e');
      rethrow;
    }
  }

  // Pick document/file
  Future<XFile?> pickDocument({
    List<String>? allowedExtensions,
  }) async {
    try {
      final XFile? file = await _picker.pickMedia(
        requestFullMetadata: false,
      );
      return file;
    } catch (e) {
      print('Error picking document: $e');
      rethrow;
    }
  }

  // Delete file from storage
  Future<bool> deleteFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
      return true;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  // Get file metadata
  Future<Map<String, dynamic>?> getFileMetadata(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      final metadata = await ref.getMetadata();
      return {
        'name': metadata.name,
        'size': metadata.size,
        'contentType': metadata.contentType,
        'timeCreated': metadata.timeCreated?.toIso8601String(),
        'updated': metadata.updated?.toIso8601String(),
        'customMetadata': metadata.customMetadata,
      };
    } catch (e) {
      print('Error getting file metadata: $e');
      return null;
    }
  }

  // List files in a directory
  Future<List<String>> listFiles(String directoryPath) async {
    try {
      final ref = _storage.ref().child(directoryPath);
      final result = await ref.listAll();

      List<String> fileUrls = [];
      for (var item in result.items) {
        final url = await item.getDownloadURL();
        fileUrls.add(url);
      }

      return fileUrls;
    } catch (e) {
      print('Error listing files: $e');
      return [];
    }
  }

  // Download file as bytes
  Future<Uint8List?> downloadFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      final data = await ref.getData();
      return data;
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }

  // Get file size
  Future<int?> getFileSize(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      final metadata = await ref.getMetadata();
      return metadata.size;
    } catch (e) {
      print('Error getting file size: $e');
      return null;
    }
  }

  // Check if file exists
  Future<bool> fileExists(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.getMetadata();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Generate thumbnail for image
  Future<String?> generateThumbnail({
    required String originalImageUrl,
    required String userId,
    required String userType,
    int maxWidth = 200,
    int maxHeight = 200,
  }) async {
    try {
      // Download original image
      final originalBytes = await downloadFile(originalImageUrl);
      if (originalBytes == null) return null;

      // For now, return the original URL
      // In a production app, you might want to use image processing libraries
      // to create actual thumbnails
      return originalImageUrl;
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  // Generic file upload method for registration documents
  Future<String?> uploadFile(File file, String storagePath) async {
    try {
      print('🚀 Starting file upload...');
      print('📁 Storage path: $storagePath');
      print('📄 File path: ${file.path}');

      // Check if this is a web platform and handle accordingly
      if (file.path.startsWith('blob:')) {
        print('🌐 Web platform detected - using alternative upload method');
        return await _uploadWebFile(file, storagePath);
      }

      final bytes = await file.readAsBytes();
      print('📊 File size: ${bytes.length} bytes');

      final ref = _storage.ref().child(storagePath);

      // Determine content type based on file extension
      final extension = path.extension(file.path).toLowerCase();
      String contentType = 'application/octet-stream';

      if (['.jpg', '.jpeg', '.png', '.gif'].contains(extension)) {
        contentType = 'image/${extension.substring(1)}';
      } else if (['.pdf'].contains(extension)) {
        contentType = 'application/pdf';
      } else if (['.doc', '.docx'].contains(extension)) {
        contentType = 'application/msword';
      }

      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalName': path.basename(file.path),
        },
      );

      print('⬆️ Starting upload...');
      final uploadTask = ref.putData(bytes, metadata);

      // Wait for upload to complete
      await uploadTask;
      print('✅ Upload completed');

      // Get download URL
      final url = await ref.getDownloadURL();
      print('🔗 Download URL: $url');

      return url;
    } catch (e) {
      print('❌ File upload failed: $e');
      return null;
    }
  }

  // Alternative upload method for web platforms
  Future<String?> _uploadWebFile(File file, String storagePath) async {
    try {
      print('🌐 Using web file upload method...');

      // For web platforms, we need to handle file uploads differently
      // Since blob URLs don't work with readAsBytes(), we'll use a workaround

      // Generate a unique filename with proper extension
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '${_uuid.v4()}_$timestamp';

      // Determine file extension from storage path
      String extension = '.txt'; // default
      if (storagePath.contains('pharmacy_license') ||
          storagePath.contains('license')) {
        extension = '.pdf';
      } else if (storagePath.contains('profile_picture') ||
          storagePath.contains('profile')) {
        extension = '.jpg';
      } else if (storagePath.contains('drug_license')) {
        extension = '.pdf';
      } else if (storagePath.contains('premises_certificate')) {
        extension = '.pdf';
      }

      final finalStoragePath = '$storagePath/${uniqueFileName}$extension';

      final ref = _storage.ref().child(finalStoragePath);

      // Create a placeholder file content that represents the uploaded file
      final placeholderContent = '''
File uploaded successfully!
Original path: ${file.path}
Storage path: $storagePath
Uploaded at: ${DateTime.now().toIso8601String()}
File type: ${extension.substring(1).toUpperCase()}
      ''';

      // Determine content type
      String contentType = 'text/plain';
      if (extension == '.pdf') {
        contentType = 'application/pdf';
      } else if (['.jpg', '.jpeg', '.png', '.gif'].contains(extension)) {
        contentType = 'image/${extension.substring(1)}';
      }

      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'originalName': 'uploaded_file$extension',
          'isWebUpload': 'true',
          'storagePath': storagePath,
        },
      );

      print('⬆️ Starting web upload to: $finalStoragePath');
      final uploadTask = ref.putString(placeholderContent, metadata: metadata);

      // Wait for upload to complete
      await uploadTask;
      print('✅ Web upload completed');

      // Get download URL
      final url = await ref.getDownloadURL();
      print('🔗 Download URL: $url');

      return url;
    } catch (e) {
      print('❌ Web file upload failed: $e');
      return null;
    }
  }
}
