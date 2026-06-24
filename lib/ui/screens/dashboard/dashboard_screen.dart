import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/inspection_report_model.dart';
import '../../../core/providers/inspection_provider.dart';
import '../auth/login_screen.dart';
import '../assessment/assessment_screen.dart';
import '../export/export_screen.dart';
import '../history/inspection_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static const String routeName = '/dashboard';

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _sessionKey(InspectionReportModel inspection) {
    final refNo = inspection.refNo.trim();
    final project = inspection.projectName.trim();
    final date = DateFormat('yyyyMMdd').format(inspection.timestamp);

    if (refNo.isNotEmpty) {
      return 'ref:$refNo|$date';
    }
    if (project.isNotEmpty) {
      return 'project:$project|$date';
    }
    return 'date:$date';
  }

  int _currentSessionCount(List<InspectionReportModel> inspections) {
    if (inspections.isEmpty) return 0;

    final latest = inspections.reduce(
      (a, b) => a.timestamp.isAfter(b.timestamp) ? a : b,
    );
    final latestKey = _sessionKey(latest);
    return inspections.where((item) => _sessionKey(item) == latestKey).length;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InspectionProvider>().loadInspections();
    });
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await Provider.of<AuthProvider>(context, listen: false)
                    .logout();
                if (!context.mounted) return;
                Navigator.pushReplacementNamed(context, LoginScreen.routeName);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final authProvider = Provider.of<AuthProvider>(context);
    final inspectionProvider = Provider.of<InspectionProvider>(context);
    final currentSessionCount =
      _currentSessionCount(inspectionProvider.inspections);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        actions: [
          PopupMenuButton(
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Text('Profile'),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Logout'),
              ),
            ],
            onSelected: (value) {
              if (value == 'profile') {
                _showProfileDialog();
              } else if (value == 'logout') {
                _logout();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${authProvider.currentUser?.name ?? 'Inspector'}',
                        style: TextStyle(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Inspector ID: ${authProvider.currentUser?.inspectorId ?? 'N/A'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Statistics Section
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Total Inspections',
                      value: inspectionProvider.inspectionCount.toString(),
                      icon: Icons.assignment_outlined,
                      color: Colors.blue,
                      isMobile: isMobile,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'This Session',
                      value: currentSessionCount.toString(),
                      icon: Icons.today,
                      color: Colors.green,
                      isMobile: isMobile,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AssessmentScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('New Inspection'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InspectionHistoryScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Inspection History'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExportScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.file_download),
                  label: const Text('Export Report'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Recent Inspections
              Text(
                'Recent Inspections',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (inspectionProvider.inspections.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No inspections yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: inspectionProvider.inspections.take(5).length,
                  itemBuilder: (context, index) {
                    final inspection = inspectionProvider.inspections[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: inspection.primaryPhotoPath.isNotEmpty &&
                                  File(inspection.primaryPhotoPath).existsSync()
                              ? Image.file(
                                  File(inspection.primaryPhotoPath),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image_not_supported),
                                ),
                        ),
                        title: Text(inspection.defectCode),
                        subtitle: Text(
                          '${inspection.projectName.isNotEmpty ? '${inspection.projectName} • ' : ''}${inspection.location}',
                        ),
                        trailing: Chip(
                          label: Text(inspection.status),
                          backgroundColor:
                              _getImpactColor(inspection.impactCategory),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AssessmentScreen(
                                existingInspection: inspection,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isMobile,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 24 : 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getImpactColor(String impact) {
    switch (impact) {
      case 'Minor':
        return Colors.green.withValues(alpha: 0.7);
      case 'Moderate':
        return Colors.orange.withValues(alpha: 0.7);
      case 'Major':
        return Colors.red.withValues(alpha: 0.7);
      default:
        return Colors.grey.withValues(alpha: 0.7);
    }
  }

  void _showProfileDialog() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Profile Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileRow('Name', user?.name ?? 'N/A'),
              _buildProfileRow('Username', user?.username ?? 'N/A'),
              _buildProfileRow('Inspector ID', user?.inspectorId ?? 'N/A'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}
