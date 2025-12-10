import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/gemini_config.dart';

class GeminiAIService {
  static const String _apiKey = GeminiConfig.apiKey;
  static late final GenerativeModel _model;
  static bool _initialized = false;

  static void initialize() {
    if (!_initialized) {
      _model = GenerativeModel(
        model: GeminiConfig.model,
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: GeminiConfig.temperature,
          maxOutputTokens: GeminiConfig.maxTokens,
        ),
      );
      _initialized = true;
    }
  }

  static Future<String> getHealthcareResponse(String query, String userType,
      {String? conversationContext}) async {
    try {
      initialize();

      String systemPrompt = _getSystemPrompt(userType);

      String fullPrompt = systemPrompt;
      if (conversationContext != null && conversationContext.isNotEmpty) {
        fullPrompt +=
            '\n\nConversation Context:\n$conversationContext\n\nCurrent Query: $query';
      } else {
        fullPrompt += '\n\nUser Query: $query';
      }

      // Add user type context to the prompt
      fullPrompt +=
          '\n\nRemember: You are responding as a ${userType.toUpperCase()} AI assistant. Provide relevant, professional responses appropriate for this user type.';

      final content = [
        Content.text(fullPrompt),
      ];

      final response = await _model.generateContent(content);
      String responseText = response.text ??
          'Sorry, I could not generate a response at this time.';

      // Additional cleanup for any remaining formatting issues
      responseText = responseText
          .replaceAll(
              RegExp(r'\*\*(.*?)\*\*'), r'$1') // Remove **bold** formatting
          .replaceAll(RegExp(r'\*(.*?)\*'), r'$1') // Remove *italic* formatting
          .replaceAll(RegExp(r'##\s*'), '') // Remove ## headers
          .replaceAll(RegExp(r'#\s*'), '') // Remove # headers
          .replaceAll(RegExp(r'`(.*?)`'), r'$1') // Remove `code` formatting
          .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'),
              r'$1'); // Remove [link](url) formatting

      return responseText;
    } catch (e) {
      return 'Error: $e. Please check your internet connection and try again.';
    }
  }

  static String _getSystemPrompt(String userType) {
    switch (userType.toLowerCase()) {
      case 'patient':
      case 'user':
        return '''
You are a helpful healthcare AI assistant for patients. You can:
- Answer general health questions
- Explain medical terms in simple language
- Provide basic health advice
- Explain pregnancy and baby growth stages
- Suggest when to see a doctor
- Help with medication understanding
- Explain lab test results
- Provide wellness tips

IMPORTANT GUIDELINES:
1. Always remind users to consult healthcare professionals for medical advice
2. Keep responses clear, empathetic, and easy to understand
3. NEVER use markdown formatting like ** or ## in responses
4. Provide plain text responses only
5. After answering, ask 1-2 relevant follow-up questions to help the user
6. Keep responses conversational and helpful

Example follow-up questions:
- "Do you have any other symptoms?"
- "How long have you been experiencing this?"
- "Have you consulted a doctor about this?"
- "Would you like to know more about treatment options?"
''';

      case 'doctor':
        return '''
You are a medical AI assistant for doctors. You can:
- Help analyze medical reports and lab results
- Suggest differential diagnoses
- Provide medical literature references
- Help with treatment protocols
- Explain complex medical procedures
- Assist with patient education materials
- Help interpret diagnostic tests
- Suggest follow-up care plans

IMPORTANT GUIDELINES:
1. This is for educational purposes only. Always use clinical judgment
2. NEVER use markdown formatting like ** or ## in responses
3. Provide plain text responses only
4. After answering, ask 1-2 relevant follow-up questions
5. Keep responses professional and evidence-based

Example follow-up questions:
- "What other symptoms is the patient experiencing?"
- "Have you considered additional diagnostic tests?"
- "What's the patient's medical history?"
''';

      case 'pharmacy':
        return '''
You are a pharmacy AI assistant. You can:
- Suggest medicine names and dosages based on symptoms
- Explain medication side effects and interactions
- Provide drug information
- Help with prescription understanding
- Suggest over-the-counter alternatives
- Explain pregnancy-safe medications
- Help with medication storage and administration
- Provide drug interaction warnings

IMPORTANT GUIDELINES:
1. Always recommend consulting a doctor for proper diagnosis and prescription
2. NEVER use markdown formatting like ** or ## in responses
3. Provide plain text responses only
4. After answering, ask 1-2 relevant follow-up questions
5. Keep responses helpful and safety-focused

Example follow-up questions:
- "Are you taking any other medications?"
- "Do you have any allergies?"
- "What's your age and weight for dosage?"
''';

      case 'lab':
      case 'lab_technician':
        return '''
You are a laboratory AI assistant for lab technicians and medical professionals. You can:
- Help interpret lab test results and normal ranges
- Explain medical tests and procedures
- Suggest follow-up tests based on results
- Help understand test preparation requirements
- Assist with report analysis and quality control
- Explain test methodologies and protocols
- Help with equipment troubleshooting
- Provide guidance on sample handling

IMPORTANT GUIDELINES:
1. This is for educational purposes only. Always use clinical judgment
2. NEVER use markdown formatting like ** or ## in responses
3. Provide plain text responses only
4. After answering, ask 1-2 relevant follow-up questions
5. Keep responses professional and evidence-based
6. Always recommend consulting healthcare professionals for proper interpretation

Example follow-up questions:
- "What other tests would you like to run?"
- "Are there any specific concerns about these results?"
- "Would you like me to explain the normal ranges?"
- "Do you need help with test preparation procedures?"
''';

      case 'hospital':
      case 'nurse':
        return '''
You are a hospital AI assistant for nurses and healthcare staff. You can:
- Help with patient care protocols and procedures
- Assist with medical procedures and nursing interventions
- Provide medication administration guidance
- Help with patient monitoring and vital signs
- Explain hospital procedures and policies
- Assist with emergency protocols and triage
- Help with patient education and discharge planning
- Provide care coordination support

IMPORTANT GUIDELINES:
1. This is for educational purposes only. Always follow hospital protocols
2. NEVER use markdown formatting like ** or ## in responses
3. Provide plain text responses only
4. After answering, ask 1-2 relevant follow-up questions
5. Keep responses professional and protocol-focused
6. Always recommend consulting with medical staff for complex cases

Example follow-up questions:
- "What's the patient's current condition?"
- "Are there any specific protocols you need help with?"
- "Would you like guidance on documentation?"
- "Do you need help with patient education materials?"
''';

      default:
        return '''
You are a general healthcare AI assistant. You can:
- Answer health-related questions
- Provide basic medical information
- Explain pregnancy and baby development
- Suggest when to seek medical attention
- Help with general wellness advice
- Explain medical procedures
- Provide health education

IMPORTANT GUIDELINES:
1. Always recommend consulting healthcare professionals for medical advice
2. NEVER use markdown formatting like ** or ## in responses
3. Provide plain text responses only
4. After answering, ask 1-2 relevant follow-up questions
5. Keep responses clear, empathetic, and easy to understand

Example follow-up questions:
- "Do you have any other symptoms?"
- "How long have you been experiencing this?"
- "Have you consulted a doctor about this?"
- "Would you like to know more about treatment options?"
''';
    }
  }

  // Specialized methods for different use cases
  static Future<String> analyzeMedicalReport(String reportText) async {
    try {
      initialize();

      final content = [
        Content.text('''
Analyze this medical report and provide insights:

$reportText

Please provide:
1. Key findings
2. Normal vs abnormal values
3. Potential implications
4. Recommended follow-up actions
'''),
      ];

      final response = await _model.generateContent(content);
      return response.text ?? 'Unable to analyze the report at this time.';
    } catch (e) {
      return 'Error analyzing report: $e';
    }
  }

  static Future<String> suggestMedicine(
      String symptoms, String age, String conditions) async {
    try {
      initialize();

      final content = [
        Content.text('''
Based on these symptoms, suggest appropriate medicines:

Symptoms: $symptoms
Age: $age
Medical Conditions: $conditions

Please provide:
1. Suggested medicines (generic and brand names)
2. Recommended dosages
3. Precautions and side effects
4. When to see a doctor
5. Alternative remedies

IMPORTANT: Always recommend consulting a healthcare professional for proper diagnosis.
'''),
      ];

      final response = await _model.generateContent(content);
      return response.text ?? 'Unable to suggest medicines at this time.';
    } catch (e) {
      return 'Error suggesting medicines: $e';
    }
  }

  static Future<String> explainPregnancyStage(int weeks) async {
    try {
      initialize();

      final content = [
        Content.text('''
Explain pregnancy development at week $weeks:

Please provide:
1. Baby's development milestones
2. Physical changes in the mother
3. Important care tips
4. What to expect in the coming weeks
5. When to contact healthcare provider
6. Nutritional recommendations

Make it informative yet easy to understand for expecting parents.
'''),
      ];

      final response = await _model.generateContent(content);
      return response.text ??
          'Unable to provide pregnancy information at this time.';
    } catch (e) {
      return 'Error explaining pregnancy stage: $e';
    }
  }

  static Future<String> explainBabyGrowth(int months) async {
    try {
      initialize();

      final content = [
        Content.text('''
Explain baby development at $months months:

Please provide:
1. Physical development milestones
2. Cognitive development
3. Social and emotional development
4. Feeding and nutrition
5. Sleep patterns
6. Safety considerations
7. When to be concerned

Make it helpful for new parents.
'''),
      ];

      final response = await _model.generateContent(content);
      return response.text ??
          'Unable to provide baby growth information at this time.';
    } catch (e) {
      return 'Error explaining baby growth: $e';
    }
  }

  static Future<String> getDrugInformation(String drugName) async {
    try {
      initialize();

      final content = [
        Content.text('''
Provide information about $drugName:

Please include:
1. What it's used for
2. How to take it
3. Common side effects
4. Drug interactions
5. Precautions
6. Storage instructions
7. What to do if you miss a dose

Keep it clear and comprehensive for patients.
'''),
      ];

      final response = await _model.generateContent(content);
      return response.text ??
          'Unable to provide drug information at this time.';
    } catch (e) {
      return 'Error getting drug information: $e';
    }
  }

  static Future<String> interpretLabResults(String labResults) async {
    try {
      initialize();

      final content = [
        Content.text('''
Interpret these lab test results:

$labResults

Please provide:
1. What each test measures
2. Normal ranges
3. What abnormal values might indicate
4. When to follow up with a doctor
5. Any lifestyle recommendations

Keep it easy to understand for patients.
'''),
      ];

      final response = await _model.generateContent(content);
      return response.text ?? 'Unable to interpret lab results at this time.';
    } catch (e) {
      return 'Error interpreting lab results: $e';
    }
  }

  static Future<String> getEmergencyGuidance(String emergencyType) async {
    try {
      initialize();

      final content = [
        Content.text('''
Provide emergency guidance for: $emergencyType

Please provide:
1. Immediate steps to take
2. When to call emergency services
3. What to do while waiting for help
4. Prevention tips
5. Warning signs to watch for

IMPORTANT: Always call emergency services for serious situations.
'''),
      ];

      final response = await _model.generateContent(content);
      return response.text ??
          'Unable to provide emergency guidance at this time.';
    } catch (e) {
      return 'Error providing emergency guidance: $e';
    }
  }
}
