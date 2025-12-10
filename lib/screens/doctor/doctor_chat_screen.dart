import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';

class DoctorChatScreen extends StatefulWidget {
  final String senderRole; // 'doctor' or 'nurse'
  const DoctorChatScreen({super.key, this.senderRole = 'doctor'});

  @override
  _DoctorChatScreenState createState() => _DoctorChatScreenState();
}

class _DoctorChatScreenState extends State<DoctorChatScreen> {
  final _messageController = TextEditingController();
  final _patientController = TextEditingController();
  final _priorityController = TextEditingController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  final List<String> _priorities = ['Low', 'Medium', 'High', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  void dispose() {
    _messageController.dispose();
    _patientController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    final arcId = _patientController.text.trim();
    if (arcId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final messages = await ApiService.getChatsByArcId(arcId);
      setState(() => _messages = messages);
    } catch (e) {
      print('Error loading chat history: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty ||
        _patientController.text.trim().isEmpty ||
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
        arcId: _patientController.text.trim(),
        message: _messageController.text.trim(),
        priority: _priorityController.text.trim(),
        senderRole: widget.senderRole,
      );

      if (success) {
        // Clear form
        _messageController.clear();
        _priorityController.clear();

        // Reload messages
        _loadChatHistory();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.senderRole == 'doctor'
                ? 'Message sent to assigned nurses'
                : 'Message sent to assigned doctors'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.senderRole == 'doctor' ? 'Doctor Chat' : 'Nurse Chat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: widget.senderRole == 'doctor'
            ? const Color(0xFF17B18A)
            : const Color(0xFF8E24AA),
        foregroundColor: Colors.white,
      ),
      body: Column(
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
                    widget.senderRole == 'doctor'
                        ? 'Send Message to Nurse'
                        : 'Send Message to Doctor',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _patientController,
                          decoration: InputDecoration(
                            labelText: 'Patient ARC ID',
                            border: OutlineInputBorder(),
                          ),
                          onFieldSubmitted: (_) => _loadChatHistory(),
                        ),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _loadChatHistory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.senderRole == 'doctor'
                              ? const Color(0xFF17B18A)
                              : const Color(0xFF8E24AA),
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Load'),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _priorityController.text.isEmpty
                        ? null
                        : _priorityController.text,
                    decoration: InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
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
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                      hintText:
                          'Provide instructions, ask questions, or share updates...',
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.senderRole == 'doctor'
                            ? const Color(0xFF17B18A)
                            : const Color(0xFF8E24AA),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: widget.senderRole == 'doctor'
                            ? const Color(0xFF17B18A).withOpacity(0.4)
                            : const Color(0xFF8E24AA).withOpacity(0.4),
                        disabledForegroundColor: Colors.white.withOpacity(0.8),
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(widget.senderRole == 'doctor'
                              ? 'Send to Nurse'
                              : 'Send to Doctor'),
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
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No messages sent',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
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
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
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
            SizedBox(height: 8),
            Text(
              'Patient: ${message['patientId']?['fullName'] ?? 'Unknown'}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            Text(
              'From: ${message['senderRole'] == 'doctor' ? 'Doctor' : 'Nurse'}',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            SizedBox(height: 8),
            Text(
              message['message'] ?? '',
              style: GoogleFonts.poppins(),
            ),
            SizedBox(height: 8),
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
