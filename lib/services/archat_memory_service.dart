import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ArcChatMemoryService {
  static const String _memoryKeyPrefix = 'archat_memory_';
  static const String _conversationKeyPrefix = 'archat_conversation_';
  static const int _maxMemoryItems = 1000;
  static const int _maxConversationMessages = 1500;

  // Memory item structure
  static Map<String, dynamic> _createMemoryItem({
    required String userType,
    required String message,
    required String response,
    required DateTime timestamp,
    Map<String, dynamic>? context,
  }) {
    return {
      'userType': userType,
      'message': message,
      'response': response,
      'timestamp': timestamp.toIso8601String(),
      'context': context ?? {},
      'id': '${timestamp.millisecondsSinceEpoch}_${userType}',
    };
  }

  // Conversation message structure
  static Map<String, dynamic> _createConversationMessage({
    required String text,
    required bool isUser,
    required DateTime timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return {
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata ?? {},
    };
  }

  // Save memory item
  static Future<void> saveMemoryItem({
    required String userType,
    required String message,
    required String response,
    Map<String, dynamic>? context,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memoryKey = '${_memoryKeyPrefix}$userType';

      // Get existing memories
      final existingMemoriesJson = prefs.getString(memoryKey);
      List<Map<String, dynamic>> memories = [];

      if (existingMemoriesJson != null) {
        final List<dynamic> decoded = json.decode(existingMemoriesJson);
        memories = decoded.cast<Map<String, dynamic>>();
      }

      // Add new memory item
      final newMemory = _createMemoryItem(
        userType: userType,
        message: message,
        response: response,
        timestamp: DateTime.now(),
        context: context,
      );

      memories.insert(0, newMemory); // Add to beginning

      // Keep only the most recent memories
      if (memories.length > _maxMemoryItems) {
        memories = memories.take(_maxMemoryItems).toList();
      }

      // Save back to preferences
      await prefs.setString(memoryKey, json.encode(memories));

      print('✅ Memory item saved for $userType');
    } catch (e) {
      print('❌ Error saving memory item: $e');
    }
  }

  // Get memory items for a user type
  static Future<List<Map<String, dynamic>>> getMemoryItems(
      String userType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memoryKey = '${_memoryKeyPrefix}$userType';

      final memoriesJson = prefs.getString(memoryKey);
      if (memoriesJson != null) {
        final List<dynamic> decoded = json.decode(memoriesJson);
        return decoded.cast<Map<String, dynamic>>();
      }

      return [];
    } catch (e) {
      print('❌ Error getting memory items: $e');
      return [];
    }
  }

  // Save conversation message
  static Future<void> saveConversationMessage({
    required String userType,
    required String text,
    required bool isUser,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationKey = '${_conversationKeyPrefix}$userType';

      // Get existing conversation
      final existingConversationJson = prefs.getString(conversationKey);
      List<Map<String, dynamic>> conversation = [];

      if (existingConversationJson != null) {
        final List<dynamic> decoded = json.decode(existingConversationJson);
        conversation = decoded.cast<Map<String, dynamic>>();
      }

      // Add new message
      final newMessage = _createConversationMessage(
        text: text,
        isUser: isUser,
        timestamp: DateTime.now(),
        metadata: metadata,
      );

      conversation.add(newMessage);

      // Keep only the most recent messages
      if (conversation.length > _maxConversationMessages) {
        conversation = conversation
            .skip(conversation.length - _maxConversationMessages)
            .toList();
      }

      // Save back to preferences
      await prefs.setString(conversationKey, json.encode(conversation));
    } catch (e) {
      print('❌ Error saving conversation message: $e');
    }
  }

  // Get conversation messages for a user type
  static Future<List<Map<String, dynamic>>> getConversationMessages(
      String userType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationKey = '${_conversationKeyPrefix}$userType';

      final conversationJson = prefs.getString(conversationKey);
      if (conversationJson != null) {
        final List<dynamic> decoded = json.decode(conversationJson);
        return decoded.cast<Map<String, dynamic>>();
      }

      return [];
    } catch (e) {
      print('❌ Error getting conversation messages: $e');
      return [];
    }
  }

  // Get conversation context for AI (last 10 messages)
  static Future<String> getConversationContext(String userType) async {
    try {
      final messages = await getConversationMessages(userType);
      final memories = await getMemoryItems(userType);

      String context = '';

      // Add recent memories context (last 5)
      if (memories.isNotEmpty) {
        context += 'Recent conversation context:\n';
        for (final memory in memories.take(5)) {
          context += 'Q: ${memory['message']}\nA: ${memory['response']}\n\n';
        }
      }

      // Add recent conversation context (last 10 messages)
      if (messages.isNotEmpty) {
        context += 'Current conversation:\n';
        final recentMessages = messages.length > 10
            ? messages.skip(messages.length - 10).toList()
            : messages;

        for (final message in recentMessages) {
          final role = message['isUser'] ? 'User' : 'Assistant';
          context += '$role: ${message['text']}\n';
        }
      }

      return context;
    } catch (e) {
      print('❌ Error getting conversation context: $e');
      return '';
    }
  }

  // Clear conversation for a user type (when chat is closed)
  static Future<void> clearConversation(String userType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conversationKey = '${_conversationKeyPrefix}$userType';

      // Save current conversation to memory before clearing
      final messages = await getConversationMessages(userType);
      if (messages.isNotEmpty) {
        // Save the entire conversation as a memory item
        final conversationText = messages
            .map((msg) =>
                '${msg['isUser'] ? 'User' : 'Assistant'}: ${msg['text']}')
            .join('\n');

        await saveMemoryItem(
          userType: userType,
          message: 'Conversation Summary',
          response: conversationText,
          context: {
            'messageCount': messages.length,
            'duration': messages.isNotEmpty
                ? DateTime.now()
                    .difference(DateTime.parse(messages.first['timestamp']))
                    .inMinutes
                : 0,
          },
        );
      }

      // Clear the conversation
      await prefs.remove(conversationKey);

      print('✅ Conversation cleared for $userType');
    } catch (e) {
      print('❌ Error clearing conversation: $e');
    }
  }

  // Clear all memories for a user type
  static Future<void> clearAllMemories(String userType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final memoryKey = '${_memoryKeyPrefix}$userType';
      final conversationKey = '${_conversationKeyPrefix}$userType';

      await prefs.remove(memoryKey);
      await prefs.remove(conversationKey);

      print('✅ All memories cleared for $userType');
    } catch (e) {
      print('❌ Error clearing all memories: $e');
    }
  }

  // Get memory statistics
  static Future<Map<String, int>> getMemoryStats(String userType) async {
    try {
      final memories = await getMemoryItems(userType);
      final messages = await getConversationMessages(userType);

      return {
        'memoryItems': memories.length,
        'conversationMessages': messages.length,
        'totalInteractions': memories.length + messages.length,
      };
    } catch (e) {
      print('❌ Error getting memory stats: $e');
      return {
        'memoryItems': 0,
        'conversationMessages': 0,
        'totalInteractions': 0,
      };
    }
  }

  // Search memories by keyword
  static Future<List<Map<String, dynamic>>> searchMemories(
    String userType,
    String keyword,
  ) async {
    try {
      final memories = await getMemoryItems(userType);
      final keywordLower = keyword.toLowerCase();

      return memories.where((memory) {
        final message = memory['message']?.toString().toLowerCase() ?? '';
        final response = memory['response']?.toString().toLowerCase() ?? '';
        return message.contains(keywordLower) ||
            response.contains(keywordLower);
      }).toList();
    } catch (e) {
      print('❌ Error searching memories: $e');
      return [];
    }
  }
}
