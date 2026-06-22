import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../core/providers/inspection_provider.dart';

class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  late TextEditingController _itemNumberController;
  late TextEditingController _locationController;
  late TextEditingController _commentsController;

  String? _selectedPhotoPath;
  String? _selectedDefectType;
  String? _selectedDefectCode;
  String? _selectedImpactCategory;

  final ImagePicker _imagePicker = ImagePicker();

  final Map<String, List<String>> defectCodes = {
    'Crack': ['FC1', 'FC2', 'FC3', 'FC4', 'WC1', 'WC2', 'WC3', 'WC4'],
    'Bent': ['B1', 'B2', 'B3', 'B4'],
    'Damage': ['D1', 'D2', 'D3', 'D4'],
  };

  final List<String> impactCategories = ['Minor', 'Moderate', 'Major'];

  final List<String> presetComments = [
    'Fine crack noticed at the road curb.',
    'Sinkhole observed under the concrete walkway.',
    'Distribution Box (DB) found in good, stable condition.',
    'Surface deterioration detected.',
    'Minor spalling observed on concrete surface.',
    'Significant settlement noted.',
    'Water pooling in depression area.',
  ];

  @override
  void initState() {
    super.initState();
    _itemNumberController = TextEditingController();
    _locationController = TextEditingController();
    _commentsController = TextEditingController();
  }

  @override
  void dispose() {
    _itemNumberController.dispose();
    _locationController.dispose();
    _commentsController.dispose();
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
          _selectedPhotoPath = photo.path;
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

    if (_selectedPhotoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture a photo')),
      );
      return;
    }

    if (_selectedDefectType == null || _selectedDefectCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Defect Type and Code')),
      );
      return;
    }

    if (_selectedImpactCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Impact Category')),
      );
      return;
    }

    final inspectionProvider =
        Provider.of<InspectionProvider>(context, listen: false);

    final success = await inspectionProvider.saveInspection(
      itemNumber: _itemNumberController.text,
      photoPath: _selectedPhotoPath!,
      defectType: _selectedDefectType!,
      defectCode: _selectedDefectCode!,
      location: _locationController.text,
      inspectorComments: _commentsController.text,
      impactCategory: _selectedImpactCategory!,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inspection saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(inspectionProvider.error ?? 'Failed to save inspection'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Inspection'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Capture Section
              Text(
                'Photo Capture',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (_selectedPhotoPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_selectedPhotoPath!),
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else
                Container(
                  height: 250,
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
                          Icons.camera_alt,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No photo selected',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _capturePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Capture Photo'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
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
                  hintText: 'e.g., CH 165.2, LHS',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
                  hintText: 'e.g., Pusat Pengajian Maktab PAT',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Defect Type
              Text(
                'Assessment Type',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: defectCodes.keys.map((type) {
                  return ChoiceChip(
                    label: Text(type),
                    selected: _selectedDefectType == type,
                    onSelected: (selected) {
                      setState(() {
                        _selectedDefectType = selected ? type : null;
                        _selectedDefectCode = null;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Defect Code
              if (_selectedDefectType != null) ...[
                Text(
                  'Defect Code',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      defectCodes[_selectedDefectType]!.map((code) {
                    return ChoiceChip(
                      label: Text(code),
                      selected: _selectedDefectCode == code,
                      onSelected: (selected) {
                        setState(() {
                          _selectedDefectCode = selected ? code : null;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // Impact Category
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
                        _selectedImpactCategory =
                            selected ? category : null;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

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
                  onPressed: _saveInspection,
                  icon: const Icon(Icons.save),
                  label: const Text('Save to Worksheet'),
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
}
