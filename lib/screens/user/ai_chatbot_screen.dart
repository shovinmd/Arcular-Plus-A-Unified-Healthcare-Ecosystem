import 'package:flutter/material.dart';
import 'package:arcular_plus/services/gemini_ai_service.dart';
import 'package:arcular_plus/services/archat_memory_service.dart';
import 'package:google_fonts/google_fonts.dart';

class AIChatbotScreen extends StatefulWidget {
  final String userType;

  const AIChatbotScreen({
    super.key,
    this.userType = 'user',
  });

  @override
  State<AIChatbotScreen> createState() => _AIChatbotScreenState();
}

class _AIChatbotScreenState extends State<AIChatbotScreen> {
  // Chat state
  final List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // Conversation management
  static const int _maxMessages = 20; // Maximum messages to keep in memory
  static const int _maxMessageLength =
      800; // Increased from 500 to 800 characters

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    // Save conversation to memory when chat is closed
    _saveChatHistory();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    await _loadChatHistory();
    _addBotMessage(_getWelcomeMessage());
  }

  Future<void> _loadChatHistory() async {
    try {
      // Load conversation messages from memory service
      final conversationMessages =
          await ArcChatMemoryService.getConversationMessages(widget.userType);

      _messages.clear();
      for (var msg in conversationMessages) {
        _messages.add(ChatMessage(
          text: msg['text'],
          isUser: msg['isUser'],
          timestamp: DateTime.parse(msg['timestamp']),
        ));
      }

      print(
          '✅ Loaded ${_messages.length} conversation messages for ${widget.userType}');
    } catch (e) {
      print('❌ Error loading chat history: $e');
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      // Save all messages to conversation memory
      for (final message in _messages) {
        await ArcChatMemoryService.saveConversationMessage(
          userType: widget.userType,
          text: message.text,
          isUser: message.isUser,
          metadata: {
            'messageLength': message.text.length,
            'sessionId': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );
      }

      print('✅ Saved ${_messages.length} messages to conversation memory');
    } catch (e) {
      print('❌ Error saving chat history: $e');
    }
  }

  String _getWelcomeMessage() {
    switch (widget.userType.toLowerCase()) {
      case 'doctor':
        return 'Hello! I\'m your medical AI assistant powered by Gemini. I can help you with patient care, medical reports, treatment protocols, and clinical decision support. How can I assist you today?';
      case 'pharmacy':
        return 'Hello! I\'m your pharmacy AI assistant powered by Gemini. I can help you with medication information, drug interactions, dosage guidance, and prescription support. How can I assist you today?';
      case 'lab':
      case 'lab_technician':
        return 'Hello! I\'m your lab AI assistant powered by Gemini. I can help you with test interpretations, lab procedures, quality control, and report analysis. How can I assist you today?';
      case 'hospital':
      case 'nurse':
        return 'Hello! I\'m your hospital AI assistant powered by Gemini. I can help you with patient care protocols, medical procedures, emergency protocols, and care coordination. How can I assist you today?';
      default:
        return 'Hello! Arc here. I\'m your AI health assistant powered by Gemini. I can help you with general health information, medication questions, pregnancy tracking, and wellness advice. How can I assist you today?';
    }
  }

  String _getAppBarTitle() {
    switch (widget.userType.toLowerCase()) {
      case 'doctor':
        return 'ChatArc - Medical AI Assistant';
      case 'pharmacy':
        return 'ChatArc - Pharmacy AI Assistant';
      case 'lab':
      case 'lab_technician':
        return 'ChatArc - Lab AI Assistant';
      case 'hospital':
      case 'nurse':
        return 'ChatArc - Hospital AI Assistant';
      default:
        return 'ChatArc - AI Health Assistant';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
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
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2)
              ], // Original indigo gradient
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.memory, color: Colors.white),
            onPressed: _showMemoryStats,
            tooltip: 'Memory Stats',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all, color: Colors.white),
            onPressed: _clearChat,
            tooltip: 'Clear Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat Messages
          Expanded(
            child: Column(
              children: [
                // Conversation Status
                if (_messages.length > 1) _buildConversationStatus(),
                // Messages List
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessage(_messages[index]);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Typing Indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF667eea), // Indigo
                    child: const Icon(Icons.smart_toy, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTypingDot(0),
                        _buildTypingDot(1),
                        _buildTypingDot(2),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                // Text Input
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: _getInputHint(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),

                // Send Button
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInputHint() {
    switch (widget.userType.toLowerCase()) {
      case 'doctor':
        return 'Ask about patient care, medical reports...';
      case 'pharmacy':
        return 'Ask about medications, drug interactions...';
      case 'lab':
      case 'lab_technician':
        return 'Ask about lab tests, results interpretation...';
      case 'hospital':
      case 'nurse':
        return 'Ask about patient care, medical procedures...';
      default:
        return 'Type your health question...';
    }
  }

  Widget _buildMessage(ChatMessage message) {
    final isUser = message.isUser;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: Colors.white,
              radius: 24,
              child: ClipOval(
                child: Image.asset(
                  'assets/images/ChatArc.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [
                              Color(0xFF667eea),
                              Color(0xFF764ba2)
                            ], // Indigo gradient
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: isUser ? null : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _shortenBotMessage(message.text, isUser),
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: const Color(0xFF667eea), // Indigo
              child: const Icon(Icons.person, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 600 + (index * 200)),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.grey[600],
        shape: BoxShape.circle,
      ),
    );
  }

  void _addBotMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _manageMessageLimit();
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    // Truncate message if too long
    final truncatedText = text.length > _maxMessageLength
        ? '${text.substring(0, _maxMessageLength)}... (truncated)'
        : text;

    setState(() {
      _messages.add(ChatMessage(
        text: truncatedText,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _manageMessageLimit();
    });
    _saveChatHistory();
    _scrollToBottom();
  }

  void _manageMessageLimit() {
    if (_messages.length > _maxMessages) {
      // Keep the welcome message and recent messages
      final welcomeMessage = _messages.first;
      final recentMessages =
          _messages.sublist(_messages.length - _maxMessages + 1);
      _messages.clear();
      _messages.add(welcomeMessage);
      _messages.addAll(recentMessages);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _messageController.clear();
    _addUserMessage(message);

    // Save user message to memory
    await ArcChatMemoryService.saveConversationMessage(
      userType: widget.userType,
      text: message,
      isUser: true,
      metadata: {
        'messageLength': message.length,
        'sessionId': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    setState(() {
      _isLoading = true;
    });

    try {
      // Get enhanced conversation context from memory service
      final memoryContext =
          await ArcChatMemoryService.getConversationContext(widget.userType);

      // Build conversation context for better continuity
      String conversationContext = '';
      if (_messages.length > 1) {
        // Include last few messages for context (excluding welcome message)
        final recentMessages = _messages.sublist(1).take(5);
        conversationContext = recentMessages
                .map((msg) =>
                    '${msg.isUser ? "User" : "Assistant"}: ${msg.text}')
                .join('\n') +
            '\n\n';
      }

      // Combine memory context with current conversation
      final fullContext = memoryContext.isNotEmpty
          ? '$memoryContext\n$conversationContext'
          : conversationContext;

      // Use Gemini AI service with enhanced conversation context
      final response = await GeminiAIService.getHealthcareResponse(
        message,
        widget.userType,
        conversationContext: fullContext.isNotEmpty ? fullContext : null,
      );

      setState(() {
        _isLoading = false;
      });

      _addBotMessage(response);

      // Save bot response to memory
      await ArcChatMemoryService.saveConversationMessage(
        userType: widget.userType,
        text: response,
        isUser: false,
        metadata: {
          'messageLength': response.length,
          'sessionId': DateTime.now().millisecondsSinceEpoch.toString(),
          'responseType': 'ai_response',
        },
      );

      // Save important Q&A pairs to memory for future reference
      if (message.length > 10 && response.length > 20) {
        await ArcChatMemoryService.saveMemoryItem(
          userType: widget.userType,
          message: message,
          response: response,
          context: {
            'messageLength': message.length,
            'responseLength': response.length,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      // Speak the response using TTS
      // await _speak(response); // Removed TTS
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _addBotMessage(
          'Sorry, I encountered an error. Please try again. If the issue persists, try asking a shorter question.');
    }
  }

  String _shortenBotMessage(String message, bool isUser) {
    if (isUser) return message;

    // Clean up any markdown formatting that might slip through
    String cleanedMessage = message
        .replaceAll(
            RegExp(r'\*\*(.*?)\*\*'), r'$1') // Remove **bold** formatting
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1') // Remove *italic* formatting
        .replaceAll(RegExp(r'##\s*'), '') // Remove ## headers
        .replaceAll(RegExp(r'#\s*'), '') // Remove # headers
        .replaceAll(RegExp(r'`(.*?)`'), r'$1') // Remove `code` formatting
        .replaceAll(RegExp(r'\[(.*?)\]\(.*?\)'),
            r'$1'); // Remove [link](url) formatting

    // Don't truncate messages - let them be full length
    return cleanedMessage;
  }

  Future<void> _clearChat() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
            'Are you sure you want to clear the current conversation? This will save the conversation to memory but clear the current chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Clear current conversation using memory service
      await ArcChatMemoryService.clearConversation(widget.userType);

      // Clear local messages
      setState(() {
        _messages.clear();
      });

      // Add welcome message back
      _addBotMessage(_getWelcomeMessage());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat cleared. Conversation saved to memory.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showMemoryStats() async {
    try {
      final stats = await ArcChatMemoryService.getMemoryStats(widget.userType);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Memory Statistics'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User Type: ${widget.userType.toUpperCase()}'),
              const SizedBox(height: 8),
              Text('Memory Items: ${stats['memoryItems']}'),
              Text('Conversation Messages: ${stats['conversationMessages']}'),
              Text('Total Interactions: ${stats['totalInteractions']}'),
              const SizedBox(height: 16),
              const Text(
                'Memory stores important Q&A pairs and conversation context to help with follow-up questions.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _clearAllMemories();
              },
              child: const Text('Clear All Memories'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading memory stats: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _clearAllMemories() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Memories'),
        content: const Text(
            'Are you sure you want to clear all memories? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ArcChatMemoryService.clearAllMemories(widget.userType);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All memories cleared.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  String _getConversationStatus() {
    if (_messages.length >= _maxMessages) {
      return 'Conversation limit reached. Recent messages will be preserved.';
    }
    return '${_messages.length - 1} messages in conversation';
  }

  Widget _buildConversationStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getConversationStatus(),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.blue[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
