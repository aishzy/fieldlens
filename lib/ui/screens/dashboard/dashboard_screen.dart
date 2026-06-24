import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/inspection_provider.dart';
import '../assessment/assessment_screen.dart';
import '../auth/login_screen.dart';
import '../export/export_screen.dart';
import '../history/inspection_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  static const String routeName = '/dashboard';

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
                await Provider.of<AuthProvider>(context, listen: false).logout();
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

  void _showProfileDialog() {
    final user = context.read<AuthProvider>().currentUser;

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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isMobile ? 26 : 32,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final authProvider = context.watch<AuthProvider>();
    final inspectionProvider = context.watch<InspectionProvider>();
    final inspections = List.of(inspectionProvider.inspections)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        actions: [
          PopupMenuButton(
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem(
                value: 'profile',
                child: Text('Profile'),
              ),
              PopupMenuItem(
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
              _buildStatCard(
                title: 'Total Inspections',
                value: inspectionProvider.inspectionCount.toString(),
                icon: Icons.assignment_outlined,
                color: Colors.blue,
                isMobile: isMobile,
              ),
              const SizedBox(height: 24),
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 58,
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
                  label: const Text('Add Inspection'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 58,
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
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 58,
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
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Recent Inspections',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (inspectionProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (inspections.isEmpty)
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
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: inspections.take(5).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final inspection = inspections[index];
                    final imagePath = inspection.primaryPhotoPath;
                    final imageFile = imagePath.isNotEmpty ? File(imagePath) : null;
                    return Card(
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageFile != null && imageFile.existsSync()
                              ? Image.file(
                                  imageFile,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 56,
                                  height: 56,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image_not_supported),
                                ),
                        ),
                        title: Text(
                          inspection.itemNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${DateFormat('yyyy-MM-dd HH:mm').format(inspection.timestamp)}\n'
                          '${inspection.status} • ${inspection.location}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const InspectionHistoryScreen(),
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
}
