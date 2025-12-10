import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:arcular_plus/services/api_service.dart';
import 'package:arcular_plus/services/realtime_sos_service.dart';

class SOSAnalyticsScreen extends StatefulWidget {
  final String hospitalId;

  const SOSAnalyticsScreen({Key? key, required this.hospitalId})
      : super(key: key);

  @override
  State<SOSAnalyticsScreen> createState() => _SOSAnalyticsScreenState();
}

class _SOSAnalyticsScreenState extends State<SOSAnalyticsScreen> {
  Map<String, dynamic> _analytics = {};
  bool _loading = true;
  String _selectedPeriod = '7d'; // 7 days, 30 days, 90 days

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);

    try {
      // Get real-time SOS statistics
      final realtimeStats =
          await RealtimeSOSService.getRealtimeSOSStats(widget.hospitalId);

      // Get SOS requests for analytics
      final sosRequests =
          await ApiService.getHospitalSOSRequests(widget.hospitalId);

      // Calculate analytics
      final analytics = _calculateAnalytics(sosRequests, realtimeStats);

      setState(() {
        _analytics = analytics;
        _loading = false;
      });
    } catch (e) {
      print('❌ Error loading SOS analytics: $e');
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _calculateAnalytics(
      List<Map<String, dynamic>> sosRequests,
      Map<String, dynamic> realtimeStats) {
    final now = DateTime.now();
    final periodDays = _selectedPeriod == '7d'
        ? 7
        : _selectedPeriod == '30d'
            ? 30
            : 90;
    final startDate = now.subtract(Duration(days: periodDays));

    // Filter requests by period and extract SOS request data
    final filteredRequests = sosRequests.where((request) {
      // Handle populated SOS request data
      final sosRequest = request['sosRequestId'] ?? request;
      final createdAt = DateTime.tryParse(sosRequest['createdAt'] ?? '');
      return createdAt != null && createdAt.isAfter(startDate);
    }).toList();

    // Calculate metrics
    final totalRequests = filteredRequests.length;
    final acceptedRequests = filteredRequests
        .where((r) =>
            r['hospitalStatus'] == 'accepted' ||
            r['hospitalStatus'] == 'admitted' ||
            r['hospitalStatus'] == 'discharged')
        .length;
    final completedRequests = filteredRequests
        .where((r) => r['hospitalStatus'] == 'discharged')
        .length;
    final responseTime = _calculateAverageResponseTime(filteredRequests);
    final acceptanceRate =
        totalRequests > 0 ? (acceptedRequests / totalRequests * 100) : 0;

    // Emergency type distribution
    final emergencyTypes = <String, int>{};
    for (final request in filteredRequests) {
      final sosRequest = request['sosRequestId'] ?? request;
      final type = sosRequest['emergencyType'] ?? 'Unknown';
      emergencyTypes[type] = (emergencyTypes[type] ?? 0) + 1;
    }

    // Severity distribution
    final severityDistribution = <String, int>{};
    for (final request in filteredRequests) {
      final sosRequest = request['sosRequestId'] ?? request;
      final severity = sosRequest['severity'] ?? 'Unknown';
      severityDistribution[severity] =
          (severityDistribution[severity] ?? 0) + 1;
    }

    return {
      'totalRequests': totalRequests,
      'acceptedRequests': acceptedRequests,
      'completedRequests': completedRequests,
      'acceptanceRate': acceptanceRate,
      'averageResponseTime': responseTime,
      'emergencyTypes': emergencyTypes,
      'severityDistribution': severityDistribution,
      'recentRequests': filteredRequests.take(10).toList(),
      'period': _selectedPeriod,
      'lastUpdated': now.toIso8601String(),
    };
  }

  double _calculateAverageResponseTime(List<Map<String, dynamic>> requests) {
    final responseTimes = <int>[];

    for (final request in requests) {
      // Handle populated SOS request data
      final sosRequest = request['sosRequestId'] ?? request;

      if (sosRequest['responseDetails']?['responseTime'] != null) {
        responseTimes.add(sosRequest['responseDetails']['responseTime']);
      } else if (request['acceptedAt'] != null &&
          sosRequest['createdAt'] != null) {
        // Calculate response time from timestamps
        final createdAt = DateTime.tryParse(sosRequest['createdAt']);
        final acceptedAt = DateTime.tryParse(request['acceptedAt']);
        if (createdAt != null && acceptedAt != null) {
          final responseTimeSeconds =
              acceptedAt.difference(createdAt).inSeconds;
          if (responseTimeSeconds > 0) {
            responseTimes.add(responseTimeSeconds);
          }
        }
      }
    }

    if (responseTimes.isEmpty) return 0.0;
    return responseTimes.reduce((a, b) => a + b) / responseTimes.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SOS Analytics',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red[600],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
              });
              _loadAnalytics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '7d', child: Text('Last 7 days')),
              const PopupMenuItem(value: '30d', child: Text('Last 30 days')),
              const PopupMenuItem(value: '90d', child: Text('Last 90 days')),
            ],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedPeriod == '7d'
                        ? '7D'
                        : _selectedPeriod == '30d'
                            ? '30D'
                            : '90D',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewCards(),
                    const SizedBox(height: 24),
                    _buildEmergencyTypeChart(),
                    const SizedBox(height: 24),
                    _buildSeverityChart(),
                    const SizedBox(height: 24),
                    _buildResponseTimeCard(),
                    const SizedBox(height: 24),
                    _buildRecentActivity(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Total Requests',
            _analytics['totalRequests']?.toString() ?? '0',
            Icons.emergency,
            Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Completed',
            _analytics['completedRequests']?.toString() ?? '0',
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Acceptance Rate',
            '${(_analytics['acceptanceRate'] ?? 0).toStringAsFixed(1)}%',
            Icons.trending_up,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyTypeChart() {
    final emergencyTypes =
        _analytics['emergencyTypes'] as Map<String, int>? ?? {};

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency Types',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (emergencyTypes.isEmpty)
              const Center(
                child: Text('No emergency data available'),
              )
            else
              ...emergencyTypes.entries.map((entry) => _buildChartBar(
                    entry.key,
                    entry.value,
                    _analytics['totalRequests'] ?? 1,
                    Colors.red,
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityChart() {
    final severityDistribution =
        _analytics['severityDistribution'] as Map<String, int>? ?? {};

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Severity Distribution',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (severityDistribution.isEmpty)
              const Center(
                child: Text('No severity data available'),
              )
            else
              ...severityDistribution.entries.map((entry) => _buildChartBar(
                    entry.key,
                    entry.value,
                    _analytics['totalRequests'] ?? 1,
                    _getSeverityColor(entry.key),
                  )),
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red[800]!;
      case 'high':
        return Colors.red[600]!;
      case 'medium':
        return Colors.orange[600]!;
      case 'low':
        return Colors.green[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildChartBar(String label, int value, int total, Color color) {
    final percentage = total > 0 ? (value / total) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(fontSize: 14),
              ),
              Text(
                '$value (${(percentage * 100).toStringAsFixed(1)}%)',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildResponseTimeCard() {
    final avgResponseTime = _analytics['averageResponseTime'] ?? 0.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Response Time',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.timer,
                  color: avgResponseTime < 60
                      ? Colors.green
                      : avgResponseTime < 120
                          ? Colors.orange
                          : Colors.red,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${avgResponseTime.toStringAsFixed(1)} seconds',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: avgResponseTime < 60
                            ? Colors.green
                            : avgResponseTime < 120
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                    Text(
                      'Average response time',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    // Get recent SOS requests from analytics data
    final sosRequests =
        _analytics['recentRequests'] as List<Map<String, dynamic>>? ?? [];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (sosRequests.isEmpty)
              const Center(
                child: Text('No recent SOS activity'),
              )
            else
              ...sosRequests
                  .take(5)
                  .map((request) => _buildActivityItem(request)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> request) {
    final sosRequest = request['sosRequestId'] ?? request;
    final patientName = sosRequest['patientName'] ?? 'Unknown Patient';
    final emergencyType = sosRequest['emergencyType'] ?? 'Unknown';
    final severity = sosRequest['severity'] ?? 'Unknown';
    final status = request['hospitalStatus'] ?? 'Unknown';
    final createdAt = DateTime.tryParse(sosRequest['createdAt'] ?? '');

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'Pending';
        break;
      case 'accepted':
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle_outline;
        statusText = 'Accepted';
        break;
      case 'admitted':
        statusColor = Colors.purple;
        statusIcon = Icons.local_hospital;
        statusText = 'Admitted';
        break;
      case 'discharged':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = status;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$emergencyType • $severity',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              if (createdAt != null)
                Text(
                  _formatTime(createdAt),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
