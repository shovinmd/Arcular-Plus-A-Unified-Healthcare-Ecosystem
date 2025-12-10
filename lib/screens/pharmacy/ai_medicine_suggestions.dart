import 'package:flutter/material.dart';
import '../../utils/user_type_enum.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/input_field.dart';
import '../../widgets/chatarc_floating_button.dart';

class AIMedicineSuggestions extends StatefulWidget {
  const AIMedicineSuggestions({Key? key}) : super(key: key);

  @override
  State<AIMedicineSuggestions> createState() => _AIMedicineSuggestionsState();
}

class _AIMedicineSuggestionsState extends State<AIMedicineSuggestions> {
  final _symptomController = TextEditingController();
  final _ageController = TextEditingController();
  final _conditionController = TextEditingController();

  List<Map<String, dynamic>> suggestions = [];
  bool isLoading = false;
  String selectedCategory = 'All';

  final List<String> categories = [
    'All',
    'Pain Relief',
    'Fever',
    'Cough & Cold',
    'Allergy',
    'Gastric',
    'Vitamins',
    'Antibiotics',
  ];

  @override
  void dispose() {
    _symptomController.dispose();
    _ageController.dispose();
    _conditionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Medicine Suggestions'),
        backgroundColor: UserType.pharmacy.color,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildInputSection(),
              _buildCategoryFilter(),
              Expanded(
                child: _buildSuggestionsList(),
              ),
            ],
          ),
          const ChatArcFloatingButton(userType: 'pharmacy'),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: UserType.pharmacy.color,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'AI Medicine Recommendations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InputField(
              controller: _symptomController,
              labelText: 'Symptoms',
              hintText: 'e.g., fever, headache, cough',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InputField(
                    controller: _ageController,
                    labelText: 'Age',
                    hintText: 'Enter age',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InputField(
                    controller: _conditionController,
                    labelText: 'Medical Condition',
                    hintText: 'e.g., diabetes, hypertension',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: isLoading ? 'Analyzing...' : 'Get AI Suggestions',
              onPressed: isLoading ? () {} : _getAISuggestions,
              color: UserType.pharmacy.color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;

          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  selectedCategory = category;
                  _filterSuggestions();
                });
              },
              selectedColor: UserType.pharmacy.color.withOpacity(0.2),
              checkmarkColor: UserType.pharmacy.color,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuggestionsList() {
    if (suggestions.isEmpty && !isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Enter symptoms to get AI recommendations',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                SizedBox(height: 16),
                Text(
                  'Analyzing symptoms and generating recommendations...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          _getConfidenceColor(suggestion['confidence'])
                              .withOpacity(0.2),
                      child: Icon(
                        Icons.medication,
                        color: _getConfidenceColor(suggestion['confidence']),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion['medicine'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            suggestion['category'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getConfidenceColor(suggestion['confidence'])
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${suggestion['confidence']}%',
                        style: TextStyle(
                          color: _getConfidenceColor(suggestion['confidence']),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  suggestion['description'],
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dosage: ${suggestion['dosage']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Price: \$${suggestion['price']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Add to Cart',
                        onPressed: () => _addToCart(suggestion),
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomButton(
                        text: 'View Details',
                        onPressed: () => _showMedicineDetails(suggestion),
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getConfidenceColor(int confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.orange;
    return Colors.red;
  }

  void _getAISuggestions() {
    if (_symptomController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter symptoms to get recommendations'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    // Simulate AI processing
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        isLoading = false;
        suggestions = _generateMockSuggestions();
      });
    });
  }

  List<Map<String, dynamic>> _generateMockSuggestions() {
    final symptoms = _symptomController.text.toLowerCase();
    final age = int.tryParse(_ageController.text) ?? 30;

    List<Map<String, dynamic>> mockSuggestions = [];

    if (symptoms.contains('fever') || symptoms.contains('headache')) {
      mockSuggestions.addAll([
        {
          'medicine': 'Paracetamol 500mg',
          'category': 'Pain Relief',
          'description': 'Effective for fever and mild to moderate pain relief',
          'dosage': '1 tablet every 4-6 hours',
          'price': 5.0,
          'confidence': 95,
        },
        {
          'medicine': 'Ibuprofen 400mg',
          'category': 'Pain Relief',
          'description': 'Anti-inflammatory medication for fever and pain',
          'dosage': '1 tablet every 6-8 hours',
          'price': 7.5,
          'confidence': 85,
        },
      ]);
    }

    if (symptoms.contains('cough') || symptoms.contains('cold')) {
      mockSuggestions.addAll([
        {
          'medicine': 'Cetirizine 10mg',
          'category': 'Allergy',
          'description': 'Antihistamine for allergy symptoms and cold',
          'dosage': '1 tablet daily',
          'price': 6.0,
          'confidence': 90,
        },
        {
          'medicine': 'Vitamin C 500mg',
          'category': 'Vitamins',
          'description': 'Boosts immunity and helps with cold recovery',
          'dosage': '1 tablet daily',
          'price': 3.5,
          'confidence': 75,
        },
      ]);
    }

    if (symptoms.contains('stomach') || symptoms.contains('acid')) {
      mockSuggestions.addAll([
        {
          'medicine': 'Omeprazole 20mg',
          'category': 'Gastric',
          'description': 'Proton pump inhibitor for acid reflux',
          'dosage': '1 tablet daily before breakfast',
          'price': 8.5,
          'confidence': 88,
        },
      ]);
    }

    // Add general recommendations
    if (mockSuggestions.isEmpty) {
      mockSuggestions.addAll([
        {
          'medicine': 'Multivitamin',
          'category': 'Vitamins',
          'description': 'General health supplement for overall wellness',
          'dosage': '1 tablet daily',
          'price': 4.0,
          'confidence': 70,
        },
        {
          'medicine': 'Paracetamol 500mg',
          'category': 'Pain Relief',
          'description': 'Safe pain reliever for general use',
          'dosage': '1 tablet every 4-6 hours as needed',
          'price': 5.0,
          'confidence': 65,
        },
      ]);
    }

    return mockSuggestions;
  }

  void _filterSuggestions() {
    if (selectedCategory == 'All') {
      setState(() {
        suggestions = _generateMockSuggestions();
      });
    } else {
      setState(() {
        suggestions = _generateMockSuggestions()
            .where((suggestion) => suggestion['category'] == selectedCategory)
            .toList();
      });
    }
  }

  void _addToCart(Map<String, dynamic> suggestion) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${suggestion['medicine']} added to cart!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showMedicineDetails(Map<String, dynamic> suggestion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(suggestion['medicine']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${suggestion['category']}'),
            const SizedBox(height: 8),
            Text('Description: ${suggestion['description']}'),
            const SizedBox(height: 8),
            Text('Dosage: ${suggestion['dosage']}'),
            const SizedBox(height: 8),
            Text('Price: \$${suggestion['price']}'),
            const SizedBox(height: 8),
            Text('AI Confidence: ${suggestion['confidence']}%'),
            const SizedBox(height: 16),
            const Text(
              '⚠️ Always consult with a healthcare professional before taking any medication.',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addToCart(suggestion);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add to Cart'),
          ),
        ],
      ),
    );
  }
}
