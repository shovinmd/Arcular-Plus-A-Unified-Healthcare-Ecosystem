import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../services/api_service.dart';

class NurseTalkScreen extends StatefulWidget {
  const NurseTalkScreen({Key? key}) : super(key: key);

  @override
  State<NurseTalkScreen> createState() => _NurseTalkScreenState();
}

class _NurseTalkScreenState extends State<NurseTalkScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _nurses = [];
  List<Map<String, dynamic>> _handoverNotes = [];
  Map<String, dynamic>? _selectedNurse;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isChatLoading = false;
  // int _unreadCount = 0; // Unused for now

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _handoverController = TextEditingController();
  final ScrollController _messageScrollController = ScrollController();
  Timer? _typingDebounce;
  Timer? _typingPoller;
  Timer? _presencePinger;
  Timer? _messageRefresher;
  Timer? _lastSeenUpdater;
  bool _peerTyping = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      // Stop last seen updater when switching away from chat tab (index 1)
      if (_tabController.index != 1) {
        _stopLastSeenUpdater();
      } else if (_selectedNurse != null) {
        // Start last seen updater when switching to chat tab
        _startLastSeenUpdater();
      }
    });
    _loadData();
    _startPresencePing();
    // Immediate presence ping to show as online right away
    ApiService.pingNursePresence().then((_) {
      _loadData(); // Refresh nurses list to show updated presence
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _handoverController.dispose();
    _messageScrollController.dispose();
    _typingDebounce?.cancel();
    _typingPoller?.cancel();
    _presencePinger?.cancel();
    _messageRefresher?.cancel();
    _lastSeenUpdater?.cancel();
    super.dispose();
  }

  // Format last seen time
  String _formatLastSeen(String? lastSeen) {
    if (lastSeen == null) return 'Never seen';

    try {
      final lastSeenDate = DateTime.parse(lastSeen).toUtc();
      final now = DateTime.now().toUtc();
      final difference = now.difference(lastSeenDate);

      if (difference.inSeconds < 30) {
        return 'Online now';
      } else if (difference.inMinutes < 1) {
        return 'Last seen ${difference.inSeconds}s ago';
      } else if (difference.inMinutes < 60) {
        return 'Last seen ${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return 'Last seen ${difference.inHours}h ago';
      } else {
        return 'Last seen ${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  // Start last seen updater
  void _startLastSeenUpdater() {
    _lastSeenUpdater?.cancel();
    _lastSeenUpdater = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _selectedNurse != null) {
        setState(() {
          // Trigger rebuild to update last seen display
        });
      }
    });
  }

  // Stop last seen updater
  void _stopLastSeenUpdater() {
    _lastSeenUpdater?.cancel();
  }

  // Start periodic presence ping
  void _startPresencePing() {
    // Ping presence every 30 seconds
    _presencePinger = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        ApiService.pingNursePresence().then((_) {
          // Refresh nurses list after presence update to get updated lastSeen
          print('🔄 Refreshing nurses list after presence ping');
          _loadData();
        }).catchError((error) {
          print('❌ Presence ping failed: $error');
        });
      } else {
        timer.cancel();
      }
    });

    // Refresh messages every 5 seconds if a nurse is selected
    _messageRefresher = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _selectedNurse != null) {
        if (_isChatLoading) return; // avoid overlapping loads
        final String? receiverId = _selectedNurse?['userId'] ??
            _selectedNurse?['id'] ??
            _selectedNurse?['uid'] ??
            _selectedNurse?['_id'];
        if (receiverId != null && receiverId.isNotEmpty) {
          _loadMessages(receiverId);
        }
      } else if (!mounted) {
        timer.cancel();
      }
    });

    // Poll typing status every 2 seconds
    _typingPoller = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (mounted && _selectedNurse != null) {
        final String? receiverId = _selectedNurse?['userId'] ??
            _selectedNurse?['id'] ??
            _selectedNurse?['uid'] ??
            _selectedNurse?['_id'];
        if (receiverId != null && receiverId.isNotEmpty) {
          final typing = await ApiService.getNurseTyping(receiverId);
          if (mounted) setState(() => _peerTyping = typing);
        }
      } else if (!mounted) {
        timer.cancel();
      }
    });
  }

  Future<void> _loadData() async {
    print('🔄 _loadData() called - refreshing nurses list');
    setState(() => _isLoading = true);

    try {
      final nurses = await ApiService.getNurseTalkNurses();
      final handoverNotes = await ApiService.getHandoverNotes();
      // final unreadCount = await ApiService.getNurseUnreadCount();

      print('📱 Loaded ${nurses.length} nurses:');
      for (var nurse in nurses) {
        print(
            '  - ${nurse['name']}: isOnline=${nurse['isOnline']}, lastSeen=${nurse['lastSeen']}');
      }

      setState(() {
        _nurses = nurses;
        _handoverNotes = handoverNotes;
        // _unreadCount = unreadCount;
        _isLoading = false;
        // Auto-select first nurse if none selected
        if (_selectedNurse == null && _nurses.isNotEmpty) {
          _selectedNurse = _nurses.first;
        }
      });

      // Immediately load messages for the selected nurse (if any)
      if (_selectedNurse != null) {
        final String? receiverId = _selectedNurse?['userId'] ??
            _selectedNurse?['id'] ??
            _selectedNurse?['uid'] ??
            _selectedNurse?['_id'];
        if (receiverId != null && receiverId.isNotEmpty) {
          await _loadMessages(receiverId);
        }
      }
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMessages(String receiverId) async {
    try {
      if (mounted) setState(() => _isChatLoading = true);
      final messages = await ApiService.getNurseMessages(receiverId);
      if (mounted) {
        setState(() {
          _messages = messages;
          _isChatLoading = false;
        });
      }
      _scrollToBottom();
    } catch (e) {
      print('❌ Error loading messages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
        setState(() => _isChatLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messageScrollController.hasClients) {
        _messageScrollController.animateTo(
          _messageScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedNurse == null) {
      return;
    }

    final String? receiverId = _selectedNurse?['userId'] ??
        _selectedNurse?['id'] ??
        _selectedNurse?['uid'] ??
        _selectedNurse?['_id'];

    if (receiverId == null || receiverId.toString().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Unable to send: receiver not resolved')),
        );
      }
      return;
    }

    try {
      final success = await ApiService.sendNurseMessage(
        receiverId: receiverId,
        message: _messageController.text.trim(),
      );

      if (success) {
        _messageController.clear();
        await _loadMessages(receiverId);
        // Ping presence after sending message to stay online
        ApiService.pingNursePresence().then((_) {
          _loadData(); // Refresh nurses list to show updated presence
        });
        print('✅ Message sent successfully');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send message')),
          );
        }
        print('❌ Failed to send message');
      }
    } catch (e) {
      print('❌ Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  Future<void> _sendHandoverNote() async {
    if (_handoverController.text.trim().isEmpty) return;

    // Find a random nurse to send handover to (in real app, select specific nurse)
    if (_nurses.isNotEmpty) {
      final randomNurse = _nurses.first;
      final String? receiverId =
          randomNurse['userId'] ?? randomNurse['id'] ?? randomNurse['uid'];
      if (receiverId == null || receiverId.toString().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Select a valid nurse to send handover')),
          );
        }
        return;
      }
      final success = await ApiService.sendNurseMessage(
        receiverId: receiverId,
        message: _handoverController.text.trim(),
        messageType: 'handover',
      );

      if (success) {
        _handoverController.clear();
        await _loadData(); // Refresh handover notes
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Handover note sent successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('NurseTalk'),
        backgroundColor: const Color.fromARGB(255, 27, 148, 154),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              icon: const Icon(Icons.people),
              text: 'Nurses (${_nurses.length})',
            ),
            Tab(
              icon: const Icon(Icons.chat),
              text: _selectedNurse != null ? 'Chat' : 'Select Nurse',
            ),
            Tab(
              icon: const Icon(Icons.assignment),
              text: 'Handover (${_handoverNotes.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNursesTab(),
                _buildChatTab(),
                _buildHandoverTab(),
              ],
            ),
    );
  }

  Widget _buildNursesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _nurses.length,
        itemBuilder: (context, index) {
          final nurse = _nurses[index];
          // Handle both boolean and numeric isOnline values
          final dynamic isOnlineValue = nurse['isOnline'];
          final bool isOnline = isOnlineValue == true || isOnlineValue == 1;
          final dynamic selectedId = _selectedNurse?['userId'] ??
              _selectedNurse?['id'] ??
              _selectedNurse?['uid'];
          final dynamic nurseId =
              nurse['userId'] ?? nurse['id'] ?? nurse['uid'];
          final bool isSelected = selectedId != null &&
              nurseId != null &&
              selectedId.toString() == nurseId.toString();

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: isSelected ? 4 : 1,
            color: isSelected ? const Color(0xFFE8F5E8) : Colors.white,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isOnline ? Colors.green : Colors.grey,
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                ),
              ),
              title: Text(
                nurse['name'] ?? 'Unknown Nurse',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nurse['email'] ?? ''),
                  Text(
                    isOnline ? '🟢 Online' : '🔴 Offline',
                    style: TextStyle(
                      color: isOnline ? Colors.green : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              trailing: isOnline
                  ? const Icon(Icons.chat, color: Colors.green)
                  : const Icon(Icons.chat_bubble_outline, color: Colors.grey),
              onTap: () {
                // Try multiple ways to get receiver ID
                final String? receiverId = nurse['userId'] ??
                    nurse['id'] ??
                    nurse['uid'] ??
                    nurse['_id'];
                print('📱 Selected nurse data: $nurse');
                print(
                    '📱 Selected nurse: ${nurse['name']} with ID: $receiverId');
                print('📱 Current user should be excluded from this list');

                // Additional safety check - prevent self-selection
                if (receiverId == null || receiverId.isEmpty) {
                  print('❌ Invalid receiver ID');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid nurse selection')),
                  );
                  return;
                }

                // Check if this is the current user (prevent self-selection)
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser != null) {
                  final nurseEmail = nurse['email']?.toString().toLowerCase();
                  final currentEmail = currentUser.email?.toLowerCase();
                  if (nurseEmail == currentEmail) {
                    print('❌ Cannot select yourself!');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Cannot chat with yourself')),
                    );
                    return;
                  }
                }

                // Switch chat: clear current messages immediately to avoid flash
                setState(() {
                  _selectedNurse = nurse;
                  _messages = [];
                  _isChatLoading = true;
                });
                _tabController.animateTo(1);
                _loadMessages(receiverId);
                _startLastSeenUpdater(); // Start real-time last seen updates
                // Ping presence when selecting nurse to stay online
                ApiService.pingNursePresence().then((_) {
                  _loadData(); // Refresh nurses list to show updated presence
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatTab() {
    if (_selectedNurse == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Select a nurse to start chatting',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Chat header
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color.fromARGB(255, 27, 148, 154),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  _selectedNurse!['name']?.substring(0, 1).toUpperCase() ?? 'N',
                  style:
                      const TextStyle(color: Color.fromARGB(255, 27, 148, 154)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedNurse!['name'] ?? 'Unknown Nurse',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_peerTyping)
                      const Text(
                        'Typing…',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedNurse!['email'] ?? '',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            _formatLastSeen(_selectedNurse!['lastSeen']),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: _isChatLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Start a conversation!',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _messageScrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        // Get current user's ID from Firebase Auth
                        final currentUserId =
                            FirebaseAuth.instance.currentUser?.uid;
                        final sender = message['senderId'];
                        final senderUid = sender is Map
                            ? (sender['uid'] ?? sender['_id'] ?? sender)
                            : sender;
                        final isFromMe = senderUid == currentUserId ||
                            sender == currentUserId;

                        return Align(
                          alignment: isFromMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isFromMe
                                  ? const Color.fromARGB(255, 27, 148, 154)
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['message'] ?? '',
                                  style: TextStyle(
                                    color: isFromMe
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                if (message['patientArcId'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Patient: ${message['patientArcId']}',
                                    style: TextStyle(
                                      color: isFromMe
                                          ? Colors.white70
                                          : Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      DateFormat('HH:mm').format(
                                        DateTime.parse(message['createdAt'] ??
                                                DateTime.now()
                                                    .toIso8601String())
                                            .toLocal(),
                                      ),
                                      style: TextStyle(
                                        color: isFromMe
                                            ? Colors.white70
                                            : Colors.grey[600],
                                        fontSize: 10,
                                      ),
                                    ),
                                    if (isFromMe) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        message['status'] == 'read'
                                            ? Icons.done_all
                                            : Icons.done,
                                        color: message['status'] == 'read'
                                            ? Colors.blue
                                            : Colors.grey,
                                        size: 12,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        // Message input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (_) {
                    _typingDebounce?.cancel();
                    _typingDebounce =
                        Timer(const Duration(milliseconds: 800), () async {
                      final String? receiverId = _selectedNurse?['userId'] ??
                          _selectedNurse?['id'] ??
                          _selectedNurse?['uid'] ??
                          _selectedNurse?['_id'];
                      if (receiverId != null && receiverId.isNotEmpty) {
                        await ApiService.sendNurseTyping(receiverId);
                      }
                    });
                  },
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send,
                    color: Color.fromARGB(255, 27, 148, 154)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHandoverTab() {
    return Column(
      children: [
        // Send handover note
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Leave Handover Note',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _handoverController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'e.g., Patient X needs BP check at 10 AM...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sendHandoverNote,
                  icon: const Icon(Icons.send),
                  label: const Text('Send Handover Note'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 27, 148, 154),
                    foregroundColor: const Color.fromARGB(255, 255, 255, 255),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        // Handover notes list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: _handoverNotes.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No handover notes from your hospital',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Only notes from nurses in your hospital are shown',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _handoverNotes.length,
                    itemBuilder: (context, index) {
                      final note = _handoverNotes[index];
                      final isHandover = note['messageType'] == 'handover';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isHandover ? Icons.assignment : Icons.chat,
                                    color: isHandover
                                        ? Colors.orange
                                        : Colors.blue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      note['senderId']?['fullName'] ??
                                          'Unknown',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM dd, HH:mm').format(
                                      DateTime.parse(note['createdAt'] ??
                                          DateTime.now().toIso8601String()),
                                    ),
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(note['message'] ?? ''),
                              if (note['patientArcId'] != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Patient: ${note['patientArcId']}',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
