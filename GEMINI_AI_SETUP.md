# Gemini AI Integration Setup

## Overview
This app now includes Gemini AI integration for enhanced healthcare assistance across all user roles. The AI can help with:

- **Patients**: Health queries, pregnancy/baby growth explanations, medical term explanations
- **Doctors**: Report analysis, differential diagnoses, treatment protocols
- **Pharmacies**: Medicine suggestions, drug information, pregnancy-safe medications
- **Labs**: Report interpretation, test explanations, follow-up recommendations

## Setup Instructions

### 1. Get Gemini API Key
1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create a new API key
3. Copy the API key

### 2. Configure the App
1. Open `lib/config/gemini_config.dart`
2. Replace `YOUR_GEMINI_API_KEY_HERE` with your actual API key:
```dart
static const String apiKey = 'your_actual_api_key_here';
```

### 3. Install Dependencies
Run the following command to install the Gemini AI package:
```bash
flutter pub get
```

## Features Implemented

### Floating Chatbot
- Available on all dashboards
- Context-aware responses based on user type
- Real-time chat interface
- Copy and share functionality

### Enhanced AI Chat (Pharmacy)
- Specialized features for pharmacy staff
- Drug information lookup
- Medicine suggestions based on symptoms
- Pregnancy-safe medication guidance
- Side effects and drug interaction checking

### AI Capabilities by User Type

#### Patients
- Health question answering
- Medical term explanations
- Pregnancy and baby growth information
- Wellness advice
- Doctor consultation recommendations

#### Doctors
- Medical report analysis
- Differential diagnosis suggestions
- Treatment protocol assistance
- Medical literature references
- Patient education materials

#### Pharmacies
- Medicine suggestions based on symptoms
- Drug information and side effects
- Pregnancy-safe medication guidance
- Drug interaction checking
- Dosage recommendations
- Over-the-counter alternatives

#### Labs
- Lab test result interpretation
- Medical test explanations
- Follow-up test suggestions
- Normal range explanations
- Report analysis assistance

## Usage

### Basic Chat
1. Click the floating chat button on any dashboard
2. Type your question
3. Get AI-powered responses

### Enhanced Pharmacy Features
1. Go to Pharmacy Dashboard
2. Click "Enhanced AI Chat"
3. Select a specific feature:
   - Drug Information
   - Medicine Suggestions
   - Pregnancy Safe Meds
   - Side Effects
   - Drug Interactions

### Quick Actions
- Use the attachment button for quick common queries
- Copy responses to clipboard
- Share important information

## Safety and Disclaimers

- **Medical Disclaimer**: AI responses are for informational purposes only
- **Professional Consultation**: Always recommend consulting healthcare professionals
- **Accuracy**: AI responses should be verified with medical professionals
- **Privacy**: No patient data is stored in AI conversations

## Configuration Options

You can customize the AI behavior in `lib/config/gemini_config.dart`:

```dart
// Adjust response creativity (0.0 to 1.0)
static const double temperature = 0.7;

// Maximum response length
static const int maxTokens = 1000;

// API timeout
static const int timeoutSeconds = 30;
```

## Troubleshooting

### Common Issues
1. **API Key Error**: Ensure your API key is correctly set in `gemini_config.dart`
2. **Network Issues**: Check internet connection
3. **Timeout Errors**: Increase timeout in config if needed
4. **Package Issues**: Run `flutter clean` and `flutter pub get`

### Testing
1. Test with simple health questions first
2. Verify responses are appropriate for the user type
3. Check that disclaimers are included in responses

## Future Enhancements

- Voice input/output
- Image analysis for medical reports
- Multi-language support
- Offline mode with cached responses
- Integration with medical databases
- Real-time drug interaction checking

## Support

For issues with the Gemini AI integration:
1. Check the API key configuration
2. Verify network connectivity
3. Review the console logs for error messages
4. Test with simple queries first 