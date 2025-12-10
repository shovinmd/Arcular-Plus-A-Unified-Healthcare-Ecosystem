import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/api_service.dart';

class ChatTab extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String patientArcId;
  const ChatTab(
      {super.key,
      required this.patientId,
      required this.patientName,
      required this.patientArcId});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final _messageController = TextEditingController();
  final _priorityController = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  final List<String> _priorities = ['Low', 'Medium', 'High', 'Urgent'];
  List<String> _nurses = [];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    setState(() => _isLoading = true);

    try {
      // Load chat messages for this patient
      final messages = await ApiService.getChatsByArcId(widget.patientArcId);
      setState(() => _messages = messages);

      // Load assigned nurses for this patient
      final assignments = await ApiService.getNurseAssignments();
      final byArc = assignments
          .where((a) => (a['patientArcId'] ?? '') == widget.patientArcId)
          .toList();

      final nurseNames = <String>{};
      for (final assignment in byArc) {
        final name = (assignment['nurseName'] ??
                (assignment['nurseId'] is Map
                    ? assignment['nurseId']['fullName']
                    : null))
            ?.toString();
        if (name != null && name.isNotEmpty) nurseNames.add(name);
      }

      setState(() => _nurses = nurseNames.toList());
    } catch (e) {
      print('Error loading chat history: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load chat history: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty ||
        _priorityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ApiService.sendChatMessage(
        arcId: widget.patientArcId,
        message: _messageController.text.trim(),
        priority: _priorityController.text.trim(),
        senderRole: 'doctor',
      );

      if (success) {
        _messageController.clear();
        _priorityController.clear();

        // Reload messages to get the latest
        await _loadChatHistory();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow[700]!;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Send Message Form
        Card(
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send Message to Nurse for ${widget.patientName}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _priorityController.text.isEmpty
                            ? null
                            : _priorityController.text,
                        decoration: InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _priorities.map((priority) {
                          return DropdownMenuItem(
                            value: priority,
                            child: Text(priority),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _priorityController.text = value ?? '';
                          });
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: null,
                        decoration: InputDecoration(
                          labelText: 'Send To',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _nurses.map((nurse) {
                          return DropdownMenuItem(
                            value: nurse,
                            child: Text(nurse),
                          );
                        }).toList(),
                        onChanged: (value) {
                          // Handle nurse selection
                        },
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                    hintText: 'Provide instructions or ask questions...',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Send to Nurse'),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Messages List
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat,
                        size: 48,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No messages for ${widget.patientName}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildMessageCard(message);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(message['priority'] ?? 'Low')
                        .withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message['priority'] ?? 'Low',
                    style: TextStyle(
                      color: _getPriorityColor(message['priority'] ?? 'Low'),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Spacer(),
                Text(
                  _getTimeAgo(DateTime.parse(message['createdAt'] ??
                      DateTime.now().toIso8601String())),
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text(
              'From: ${message['senderRole'] ?? 'Unknown'}',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            SizedBox(height: 6),
            Text(
              message['message'] ?? '',
              style: GoogleFonts.poppins(),
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  message['status'] == 'read' ? Icons.done_all : Icons.done,
                  color:
                      message['status'] == 'read' ? Colors.blue : Colors.grey,
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  message['status'] == 'read' ? 'Delivered' : 'Sent',
                  style: GoogleFonts.poppins(
                    color:
                        message['status'] == 'read' ? Colors.blue : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
