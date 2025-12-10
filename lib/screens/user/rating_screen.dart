import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

const Color kPrimaryColor = Color(0xFF2196F3);
const Color kPrimaryText = Color(0xFF212121);
const Color kSecondaryText = Color(0xFF757575);

class RatingScreen extends StatefulWidget {
  final String orderId;
  final List<Map<String, dynamic>> orderItems;
  final String pharmacyName;

  const RatingScreen({
    super.key,
    required this.orderId,
    required this.orderItems,
    required this.pharmacyName,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _overallRating = 0;
  final TextEditingController _reviewController = TextEditingController();
  List<Map<String, dynamic>> _medicineRatings = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeMedicineRatings();
  }

  void _initializeMedicineRatings() {
    _medicineRatings = widget.orderItems
        .map((item) => {
              'medicineId': item['medicineId'] ?? item['_id'],
              'medicineName': item['medicineName'] ?? item['name'],
              'rating': 0,
            })
        .toList();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_overallRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide an overall rating'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ApiService.submitRating(
        orderId: widget.orderId,
        rating: _overallRating,
        review: _reviewController.text.trim().isEmpty
            ? null
            : _reviewController.text.trim(),
        medicineRatings:
            _medicineRatings.where((rating) => rating['rating'] > 0).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your rating!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Rate Your Order',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${widget.orderId}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pharmacy: ${widget.pharmacyName}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: kSecondaryText,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Overall Rating Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Experience',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: kPrimaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'How was your overall experience with this order?',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: kSecondaryText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _overallRating = index + 1;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            index < _overallRating
                                ? Icons.star
                                : Icons.star_border,
                            color: index < _overallRating
                                ? Colors.amber
                                : Colors.grey[400],
                            size: 40,
                          ),
                        ),
                      );
                    }),
                  ),
                  if (_overallRating > 0) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        _getRatingText(_overallRating),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _getRatingColor(_overallRating),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Review Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Write a Review (Optional)',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: kPrimaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share your experience with others',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: kSecondaryText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reviewController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Tell us about your experience...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey[400],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: kPrimaryColor, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Medicine Ratings Section
            if (widget.orderItems.length > 1) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate Individual Medicines (Optional)',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rate each medicine you received',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: kSecondaryText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...widget.orderItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _buildMedicineRatingCard(index, item);
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Submit Rating',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineRatingCard(int index, Map<String, dynamic> item) {
    final medicineName =
        item['medicineName'] ?? item['name'] ?? 'Unknown Medicine';
    final currentRating = _medicineRatings[index]['rating'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            medicineName,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kPrimaryText,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (starIndex) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _medicineRatings[index]['rating'] = starIndex + 1;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  child: Icon(
                    starIndex < currentRating ? Icons.star : Icons.star_border,
                    color: starIndex < currentRating
                        ? Colors.amber
                        : Colors.grey[400],
                    size: 20,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow[700]!;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
