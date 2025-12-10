import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BMICalculatorScreen extends StatefulWidget {
  const BMICalculatorScreen({super.key});

  @override
  State<BMICalculatorScreen> createState() => _BMICalculatorScreenState();
}

class _BMICalculatorScreenState extends State<BMICalculatorScreen> with TickerProviderStateMixin {
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  double? _bmi;
  String? _bmiCategory;
  String? _bmiColor;
  
  // Animation controllers
  late AnimationController _resultAnimationController;
  late AnimationController _pulseAnimationController;
  late AnimationController _slideAnimationController;
  late Animation<double> _resultScaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _resultAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Define animations
    _resultScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _resultAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.bounceOut,
    ));
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _resultAnimationController.dispose();
    _pulseAnimationController.dispose();
    _slideAnimationController.dispose();
    super.dispose();
  }

  void _calculateBMI() {
    final height = double.tryParse(_heightController.text);
    final weight = double.tryParse(_weightController.text);

    if (height != null && weight != null && height > 0) {
      final heightInMeters = height / 100; // Convert cm to meters
      final bmi = weight / (heightInMeters * heightInMeters);
      
      setState(() {
        _bmi = bmi;
        _bmiCategory = _getBMICategory(bmi);
        _bmiColor = _getBMIColor(bmi);
      });
      
      // Start animations
      _resultAnimationController.forward();
      _pulseAnimationController.repeat(reverse: true);
      _slideAnimationController.forward();
    }
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal Weight';
    if (bmi < 30) return 'Overweight';
    if (bmi < 35) return 'Obese Class I';
    if (bmi < 40) return 'Obese Class II';
    return 'Obese Class III';
  }

  String _getBMIColor(double bmi) {
    if (bmi < 18.5) return 'blue';
    if (bmi < 25) return 'green';
    if (bmi < 30) return 'orange';
    return 'red';
  }

  Color _getColorFromString(String colorString) {
    switch (colorString) {
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'BMI Calculator',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF32CCBC), Color(0xFF90F7EC)], // Patient teal gradient
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F6FA), Color(0xFFE8F5E8)], // Light gradient background
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF32CCBC), Color(0xFF90F7EC)], // Patient teal gradient
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF32CCBC).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.monitor_weight,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Body Mass Index Calculator',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Calculate your BMI to understand your body composition',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Input Fields
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter Your Details',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF32CCBC),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Height Input
                      TextFormField(
                        controller: _heightController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Height (cm)',
                          hintText: 'e.g., 170',
                          prefixIcon: const Icon(Icons.height, color: Color(0xFF32CCBC)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF32CCBC), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Weight Input
                      TextFormField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Weight (kg)',
                          hintText: 'e.g., 65',
                          prefixIcon: const Icon(Icons.monitor_weight, color: Color(0xFF32CCBC)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF32CCBC), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Calculate Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: ElevatedButton(
                            onPressed: _calculateBMI,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF32CCBC), Color(0xFF90F7EC)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calculate,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Calculate BMI',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // BMI Result
              if (_bmi != null) ...[
                ScaleTransition(
                  scale: _resultScaleAnimation,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getColorFromString(_bmiColor!).withOpacity(0.8),
                                _getColorFromString(_bmiColor!).withOpacity(0.6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: _getColorFromString(_bmiColor!).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Your BMI',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _bmi!.toStringAsFixed(1),
                                style: GoogleFonts.poppins(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _bmiCategory!,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // BMI Categories Info
                SlideTransition(
                  position: _slideAnimation,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'BMI Categories',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF32CCBC),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildBMICategory('Underweight', '< 18.5', Colors.blue),
                          _buildBMICategory('Normal Weight', '18.5 - 24.9', Colors.green),
                          _buildBMICategory('Overweight', '25.0 - 29.9', Colors.orange),
                          _buildBMICategory('Obese Class I', '30.0 - 34.9', Colors.red),
                          _buildBMICategory('Obese Class II', '35.0 - 39.9', Colors.red[700]!),
                          _buildBMICategory('Obese Class III', '≥ 40.0', Colors.red[900]!),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBMICategory(String category, String range, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            range,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
} 