import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/models/inspection_report_model.dart';
import '../../../core/providers/inspection_provider.dart';

class AssessmentScreen extends StatefulWidget {
  final InspectionReportModel? existingInspection;

  const AssessmentScreen({super.key, this.existingInspection});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  late TextEditingController _itemNumberController;
  late TextEditingController _locationController;
  late TextEditingController _commentsController;
  late TextEditingController _refNoController;
  late TextEditingController _sectionController;
  late TextEditingController _siteLocationController;
  bool _scopeInternal = false;
  bool _scopeExternal = false;
  bool _scopeME = false;
  bool _scopePublicFacilities = false;

  final List<String> _selectedPhotoPaths = [];
  final Set<String> _selectedDefectCodes = {};
  String? _selectedImpactCategory;
  String? _selectedStatus;
  DateTime? _photoCapturedAt;
  bool _isSaving = false;
  String _inspectionMode = 'defect'; // 'overall' or 'defect'

  final ImagePicker _imagePicker = ImagePicker();

  // Each entry: code -> description (as shown in reference table)
  static const Map<String, Map<String, String>> defectCodeInfo = {
    'Crack (WC)': {
      'WC1': 'Hairline crack. Width < 0.1mm',
      'WC2': 'Fine crack. Width 0.1 – 0.3mm',
      'WC3': 'Medium crack. Width 0.3 – 1.0mm',
      'WC4': 'Wide crack. Width > 1.0mm',
    },
    'Crack (FC)': {
      'FC1': 'Fine but noticeable cracks. Slab reasonably level.',
      'FC2': 'Cracks noticeable. Slight displacement possible.',
      'FC3': 'Cracks several mm wide. Possible tripping hazard.',
      'FC4': 'Wide cracks > 5mm. Structural concern.',
    },
    'Bent (B)': {
      'B1': 'Slight bending. Barely noticeable deflection.',
      'B2': 'Noticeable bending. Deflection visible.',
      'B3': 'Significant bending. Deflection > L/360.',
      'B4': 'Severe bending. Structural integrity compromised.',
    },
    'Damage (D)': {
      'D1': 'Surface damage only. Cosmetic issue.',
      'D2': 'Moderate damage. Functionality slightly affected.',
      'D3': 'Significant damage. Requires repair.',
      'D4': 'Severe damage. Immediate action required.',
    },
  };

  // Flattened list of all codes grouped by category header
  static const List<String> _allDefectCategories = [
    'Crack (WC)',
    'Crack (FC)',
    'Bent (B)',
    'Damage (D)',
  ];

  final List<String> impactCategories = ['Minor', 'Moderate', 'Major'];
  final List<String> statusCategories = [
    'No Defect',
    'Minor Defect',
    'Major Defect',
    'Crack Found',
    'Water Leakage',
    'Poor Finishing',
    'Safety Hazard',
    'Incomplete Work',
    'Completed',
  ];

  final List<String> presetComments = [
    'No defect observed. Area is in satisfactory condition.',
    'Hairline crack observed on wall/slab surface. Monitor for progression.',
    'Fine crack noticed at road curb / pedestrian walkway. Slab reasonably level.',
    'Wide crack observed. Significant displacement may be present.',
    'Spalling of concrete cover exposing reinforcement bars.',
    'Sinkhole observed under the concrete walkway.',
    'Surface deterioration and delamination detected.',
    'Water seepage / staining observed on ceiling / wall surface.',
    'Dampness and efflorescence observed. Possible water infiltration.',
    'Distribution Box (DB) found in good, stable condition.',
    'Mechanical & Electrical (M&E) component in serviceable condition.',
    'Settlement observed. Possible undermining of foundation.',
    'Structural element shows signs of significant deflection.',
    'Corrosion of exposed metallic element. Requires immediate treatment.',
    'Incomplete works noted. To be completed as per contract.',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingInspection;
    _itemNumberController =
        TextEditingController(text: existing?.itemNumber ?? '');
    _locationController = TextEditingController(text: existing?.location ?? '');
    _commentsController = TextEditingController(
      text: existing?.inspectorComments ?? '',
    );
    _refNoController = TextEditingController(text: existing?.refNo ?? '');
    _sectionController = TextEditingController(text: existing?.section ?? '');
    _siteLocationController = TextEditingController(text: existing?.siteLocation ?? '');
    _scopeInternal = existing?.scopeInternal ?? false;
    _scopeExternal = existing?.scopeExternal ?? false;
    _scopeME = existing?.scopeME ?? false;
    _scopePublicFacilities = existing?.scopePublicFacilities ?? false;

    _inspectionMode = existing?.inspectionMode ?? 'defect';
    _selectedDefectCodes.addAll(existing?.selectedDefectCodes ?? []);
    _selectedImpactCategory =
        existing?.impactCategory ?? impactCategories.first;
    _selectedStatus = existing?.status ?? statusCategories.first;
    _photoCapturedAt = existing?.timestamp;
    if (existing != null) {
      _selectedPhotoPaths.addAll(existing.photoPaths);
    }
  }

  @override
  void dispose() {
    _itemNumberController.dispose();
    _locationController.dispose();
    _commentsController.dispose();
    _refNoController.dispose();
    _sectionController.dispose();
    _siteLocationController.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (photo != null) {
        if (!mounted) return;
        setState(() {
          _selectedPhotoPaths.add(photo.path);
          _photoCapturedAt = DateTime.now();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo captured successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error capturing photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importFromGallery() async {
    try {
      final photos = await _imagePicker.pickMultiImage(
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 85,
      );
      if (photos.isEmpty || !mounted) return;

      setState(() {
        _selectedPhotoPaths.addAll(photos.map((item) => item.path));
        _photoCapturedAt ??= DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${photos.length} photo(s) imported')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing photos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<String>> _persistPhotosToAppStorage() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${baseDir.path}/inspection_photos');
    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }

    final persisted = <String>[];
    for (final sourcePath in _selectedPhotoPaths) {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) continue;
      if (p.isWithin(photoDir.path, sourcePath)) {
        persisted.add(sourcePath);
        continue;
      }

      final destinationName =
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}';
      final destinationPath = p.join(photoDir.path, destinationName);
      final copied = await sourceFile.copy(destinationPath);
      persisted.add(copied.path);
    }
    return persisted;
  }

  Future<void> _savePhotoToGallery(String photoPath) async {
    try {
      final sourceFile = File(photoPath);
      if (!await sourceFile.exists()) {
        throw Exception('Photo file not found');
      }

      final targetDir = Platform.isAndroid
          ? Directory('/storage/emulated/0/Pictures/FieldLens')
          : await getApplicationDocumentsDirectory();
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final destination = File(
        p.join(
          targetDir.path,
          'fieldlens_${DateTime.now().millisecondsSinceEpoch}_${p.basename(photoPath)}',
        ),
      );
      await sourceFile.copy(destination.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo saved to Pictures/FieldLens')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving to gallery: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteRemovedPhotos(
      List<String> previous, List<String> current) async {
    final removed = previous.where((item) => !current.contains(item));
    for (final path in removed) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _saveInspection() async {
    if (_itemNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Item Number')),
      );
      return;
    }

    if (_locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Location')),
      );
      return;
    }

    if (_selectedPhotoPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please capture or import at least one photo')),
      );
      return;
    }

    if (_selectedStatus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an inspection status')),
      );
      return;
    }

    if (_inspectionMode == 'defect' && _selectedImpactCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Impact Category')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final inspectionProvider =
        Provider.of<InspectionProvider>(context, listen: false);

    final storedPhotoPaths = await _persistPhotosToAppStorage();
    final codes = _selectedDefectCodes.toList();
    // Derive primary defect type and code from selected codes for backward compat
    String defectType = 'General';
    String defectCode = 'ND0';
    if (codes.isNotEmpty) {
      final first = codes.first;
      if (first.startsWith('FC') || first.startsWith('WC')) {
        defectType = 'Crack';
      } else if (first.startsWith('B')) {
        defectType = 'Bent';
      } else if (first.startsWith('D')) {
        defectType = 'Damage';
      }
      defectCode = first;
    }

    bool success;
    final existing = widget.existingInspection;
    if (existing == null) {
      success = await inspectionProvider.saveInspection(
        itemNumber: _itemNumberController.text.trim(),
        photoPaths: storedPhotoPaths,
        defectType: defectType,
        defectCode: defectCode,
        location: _locationController.text.trim(),
        inspectorComments: _commentsController.text.trim(),
        impactCategory: _selectedImpactCategory ?? 'Minor',
        status: _selectedStatus!,
        timestamp: _photoCapturedAt ?? DateTime.now(),
        refNo: _refNoController.text.trim(),
        section: _sectionController.text.trim(),
        scopeInternal: _scopeInternal,
        scopeExternal: _scopeExternal,
        scopeME: _scopeME,
        scopePublicFacilities: _scopePublicFacilities,
        selectedDefectCodes: codes,
        inspectionMode: _inspectionMode,
        siteLocation: _siteLocationController.text.trim(),
      );
    } else {
      success = await inspectionProvider.updateInspection(
        existing.copyWith(
          itemNumber: _itemNumberController.text.trim(),
          photoPaths: storedPhotoPaths,
          defectType: defectType,
          defectCode: defectCode,
          location: _locationController.text.trim(),
          inspectorComments: _commentsController.text.trim(),
          impactCategory: _selectedImpactCategory ?? 'Minor',
          status: _selectedStatus!,
          timestamp: _photoCapturedAt ?? existing.timestamp,
          refNo: _refNoController.text.trim(),
          section: _sectionController.text.trim(),
          scopeInternal: _scopeInternal,
          scopeExternal: _scopeExternal,
          scopeME: _scopeME,
          scopePublicFacilities: _scopePublicFacilities,
          selectedDefectCodes: codes,
          siteLocation: _siteLocationController.text.trim(),
        ),
      );
      if (success) {
        await _deleteRemovedPhotos(existing.photoPaths, storedPhotoPaths);
      }
    }
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null
              ? 'Inspection saved successfully'
              : 'Inspection updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(inspectionProvider.error ?? 'Failed to save inspection'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingInspection == null
            ? 'New Inspection'
            : 'Edit Inspection'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Capture & Import Section
              Text(
                'Inspection Photos',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (_selectedPhotoPaths.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (context, index) {
                      final path = _selectedPhotoPaths[index];
                      return Stack(
                        children: [
                          GestureDetector(
                            onTap: () => _openPhotoViewer(path),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(path),
                                height: 120,
                                width: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedPhotoPaths.removeAt(index);
                                  });
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.close,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemCount: _selectedPhotoPaths.length,
                  ),
                )
              else
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No photo selected yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _capturePhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _importFromGallery,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                      ),
                    ),
                  ),
                ],
              ),
              if (_selectedPhotoPaths.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        _savePhotoToGallery(_selectedPhotoPaths.first),
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Save first photo to Pictures/FieldLens'),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Item Number
              Text(
                'Item Number',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _itemNumberController,
                decoration: InputDecoration(
                  hintText: 'e.g., 001',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // REF.NO. & Section
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('REF. NO.',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _refNoController,
                          decoration: InputDecoration(
                            hintText: 'e.g., B ME 1',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Section',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _sectionController,
                          decoration: InputDecoration(
                            hintText: 'e.g., L / M / R',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Location
              Text(
                'Location',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'e.g., Ground Floor Lobby',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Site Location
              Text(
                'Site Location',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _siteLocationController,
                decoration: InputDecoration(
                  hintText: 'e.g., Hospital Serdang, Apartment Block A',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Scope of Inspection
              Text(
                'Scope of Inspection',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 0,
                runSpacing: 0,
                children: [
                  CheckboxMenuButton(
                    value: _scopeInternal,
                    onChanged: (v) =>
                        setState(() => _scopeInternal = v ?? false),
                    child: const Text('Internal'),
                  ),
                  CheckboxMenuButton(
                    value: _scopeExternal,
                    onChanged: (v) =>
                        setState(() => _scopeExternal = v ?? false),
                    child: const Text('External'),
                  ),
                  CheckboxMenuButton(
                    value: _scopeME,
                    onChanged: (v) => setState(() => _scopeME = v ?? false),
                    child: const Text('M&E'),
                  ),
                  CheckboxMenuButton(
                    value: _scopePublicFacilities,
                    onChanged: (v) =>
                        setState(() => _scopePublicFacilities = v ?? false),
                    child: const Text('Public Facilities'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Inspection Mode Selection
              Text(
                'Report Layout Mode',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Choose the PDF report layout for this item',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Overall View'),
                    selected: _inspectionMode == 'overall',
                    onSelected: widget.existingInspection != null
                        ? null // Cannot change mode on existing items
                        : (selected) {
                            setState(() {
                              _inspectionMode = 'overall';
                              if (_inspectionMode == 'overall') {
                                _selectedDefectCodes.clear();
                                _selectedImpactCategory = null;
                              }
                            });
                          },
                  ),
                  ChoiceChip(
                    label: const Text('Defect Assessment'),
                    selected: _inspectionMode == 'defect',
                    onSelected: widget.existingInspection != null
                        ? null
                        : (selected) {
                            setState(() {
                              _inspectionMode = 'defect';
                              _selectedImpactCategory ??= impactCategories.first;
                            });
                          },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Assessment Types — checkbox grid per category (only for Defect Mode)
              if (_inspectionMode == 'defect') ...[
                Text(
                  'Assessment Types',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Select all applicable defect codes',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ...(_allDefectCategories.map((category) {
                  final codes = defectCodeInfo[category]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          category,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Theme.of(context).dividerColor),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(8),
                          ),
                        ),
                        child: Column(
                          children: codes.entries.map((entry) {
                            final code = entry.key;
                            final desc = entry.value;
                            return CheckboxListTile(
                              dense: true,
                              value: _selectedDefectCodes.contains(code),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedDefectCodes.add(code);
                                  } else {
                                    _selectedDefectCodes.remove(code);
                                  }
                                });
                              },
                              title: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '$code  ',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    TextSpan(
                                      text: desc,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                }).toList()),
                const SizedBox(height: 12),

                Text(
                  'Inspection Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: statusCategories.map((status) {
                    return ChoiceChip(
                      label: Text(status),
                      selected: _selectedStatus == status,
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatus = selected ? status : null;
                          if (_selectedStatus == 'No Defect') {
                            _selectedDefectCodes.clear();
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Impact Category (only for Defect Mode)
                Text(
                  'Impact Category',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: impactCategories.map((category) {
                    return FilterChip(
                      label: Text(category),
                      selected: _selectedImpactCategory == category,
                      backgroundColor:
                          _getImpactColor(category).withValues(alpha: 0.3),
                      selectedColor: _getImpactColor(category),
                      labelStyle: TextStyle(
                        color: _selectedImpactCategory == category
                            ? Colors.white
                            : Colors.black,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedImpactCategory = selected ? category : null;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // Comments
              Text(
                'Inspector\'s Comments',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Quick Options',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: presetComments.map((comment) {
                  return ActionChip(
                    label: Text(
                      comment,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () {
                      setState(() {
                        _commentsController.text = comment;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentsController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter or edit inspector comments here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveInspection,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(widget.existingInspection == null
                      ? 'Save to Worksheet'
                      : 'Update Inspection'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Color _getImpactColor(String impact) {
    switch (impact) {
      case 'Minor':
        return Colors.green;
      case 'Moderate':
        return Colors.orange;
      case 'Major':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _openPhotoViewer(String path) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
