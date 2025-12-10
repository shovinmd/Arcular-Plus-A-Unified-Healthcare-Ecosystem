import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProviderRatingScreen extends StatefulWidget {
  final String appointmentId;
  final String providerType; // 'hospital' or 'doctor'
  final String providerId;
  final String providerName;

  const ProviderRatingScreen({
    super.key,
    required this.appointmentId,
    required this.providerType,
    required this.providerId,
    required this.providerName,
  });

  @override
  State<ProviderRatingScreen> createState() => _ProviderRatingScreenState();
}

class _ProviderRatingScreenState extends State<ProviderRatingScreen> {
  int _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await ApiService.submitProviderRating(
        appointmentId: widget.appointmentId,
        providerId: widget.providerId,
        providerType: widget.providerType,
        rating: _rating,
        review: _reviewController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('Already rated')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('You have already rated this ${widget.providerType}.'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit rating: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Visit'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF32CCBC), Color(0xFF90F7EC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.providerType == 'hospital'
                            ? Icons.local_hospital
                            : Icons.person,
                        color: const Color(0xFF32CCBC),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.providerName,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              widget.providerType == 'hospital'
                                  ? 'Hospital'
                                  : 'Doctor',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Rating Section
            Text(
              'How was your experience?',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Star Rating
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        index < _rating ? Icons.star : Icons.star_border,
                        color:
                            index < _rating ? Colors.amber : Colors.grey[400],
                        size: 40,
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 8),
            Center(
              child: Text(
                _rating == 0
                    ? 'Tap to rate'
                    : _rating == 1
                        ? 'Poor'
                        : _rating == 2
                            ? 'Fair'
                            : _rating == 3
                                ? 'Good'
                                : _rating == 4
                                    ? 'Very Good'
                                    : 'Excellent',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _rating == 0 ? Colors.grey[600] : Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Review Section
            Text(
              'Share your feedback (optional)',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _reviewController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Tell us about your experience...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[500],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF32CCBC),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Submit Rating',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // Info Text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue[600],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your feedback helps improve healthcare services and helps other patients make informed decisions.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
