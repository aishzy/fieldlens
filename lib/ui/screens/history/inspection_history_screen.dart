import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/inspection_report_model.dart';
import '../../../core/providers/inspection_provider.dart';
import '../assessment/assessment_screen.dart';

class InspectionHistoryScreen extends StatefulWidget {
  const InspectionHistoryScreen({super.key});

  @override
  State<InspectionHistoryScreen> createState() =>
      _InspectionHistoryScreenState();
}

class _InspectionHistoryScreenState extends State<InspectionHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';
  bool _sortNewestFirst = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<InspectionReportModel> _buildFilteredData(
      List<InspectionReportModel> source) {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = source.where((inspection) {
      final statusMatch =
          _statusFilter == 'All' || inspection.status == _statusFilter;
      final queryMatch = query.isEmpty ||
          inspection.location.toLowerCase().contains(query) ||
          inspection.status.toLowerCase().contains(query) ||
          inspection.inspectorComments.toLowerCase().contains(query);
      return statusMatch && queryMatch;
    }).toList();

    filtered.sort((a, b) => _sortNewestFirst
        ? b.timestamp.compareTo(a.timestamp)
        : a.timestamp.compareTo(b.timestamp));

    return filtered;
  }

  Future<void> _confirmDelete(InspectionReportModel inspection) async {
    final provider = context.read<InspectionProvider>();
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete inspection'),
        content: const Text(
          'This will remove the inspection record and related photo files. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    final ok = await provider.deleteInspection(inspection.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            ok ? 'Inspection deleted' : (provider.error ?? 'Delete failed')),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InspectionProvider>();
    final statuses = [
      'All',
      ...{
        ...provider.inspections.map((e) => e.status),
        'No Defect',
        'Minor Defect',
        'Major Defect',
        'Crack Found',
        'Water Leakage',
        'Poor Finishing',
        'Safety Hazard',
        'Incomplete Work',
        'Completed',
      }
    ];
    final inspections = _buildFilteredData(provider.inspections);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection History'),
        actions: [
          IconButton(
            tooltip:
                _sortNewestFirst ? 'Sort oldest first' : 'Sort newest first',
            onPressed: () =>
                setState(() => _sortNewestFirst = !_sortNewestFirst),
            icon: Icon(_sortNewestFirst ? Icons.south : Icons.north),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by project, status, location, comments',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, index) {
                final status = statuses[index];
                return ChoiceChip(
                  label: Text(status),
                  selected: _statusFilter == status,
                  onSelected: (_) => setState(() => _statusFilter = status),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: statuses.length,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: inspections.isEmpty
                ? const Center(child: Text('No inspections found'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (_, index) {
                      final inspection = inspections[index];
                      final imageFile = File(inspection.primaryPhotoPath);
                      return Card(
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: imageFile.existsSync()
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
                                    child:
                                        const Icon(Icons.image_not_supported),
                                  ),
                          ),
                          title: Text(
                            inspection.itemNumber.isEmpty
                                ? 'Inspection ${inspection.id}'
                                : inspection.itemNumber,
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
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AssessmentScreen(
                                      existingInspection: inspection,
                                    ),
                                  ),
                                );
                              } else if (value == 'delete') {
                                _confirmDelete(inspection);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
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
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: inspections.length,
                  ),
          ),
        ],
      ),
    );
  }
}
