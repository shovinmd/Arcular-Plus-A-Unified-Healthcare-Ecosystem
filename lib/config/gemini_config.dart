class GeminiConfig {
  // Gemini API key
  static const String apiKey = 'AIzaSyBy8NERIqaFiQu84x8_Wc4Vqq1pztBLbhU';
  
  // Model configuration - using gemini-2.0-flash as per the API endpoint
  static const String model = 'gemini-2.0-flash';
  
  // API endpoint
  static const String apiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
  
  // Temperature for response creativity (0.0 to 1.0)
  static const double temperature = 0.7;
  
  // Maximum tokens for response
  static const int maxTokens = 1000;
  
  // Safety settings
  static const bool enableSafetySettings = true;
  
  // Timeout for API calls (in seconds)
  static const int timeoutSeconds = 30;
} 