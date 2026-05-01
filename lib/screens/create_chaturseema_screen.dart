import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/patwari_provider.dart';
import '../utils/pdf_generator.dart';

class Farmer {
  final String name;
  final String relationName;
  final String caste;

  Farmer({required this.name, required this.relationName, required this.caste});
  
  factory Farmer.fromMap(Map<String, dynamic> data) {
    return Farmer(
      name: data['name'] ?? '',
      relationName: data['relationName'] ?? '',
      caste: data['caste'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'relationName': relationName,
    'caste': caste,
  };
}

class CreateChaturseemaScreen extends StatefulWidget {
  const CreateChaturseemaScreen({super.key});

  @override
  State<CreateChaturseemaScreen> createState() => _CreateChaturseemaScreenState();
}

class _CreateChaturseemaScreenState extends State<CreateChaturseemaScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'patwari');

  String? _selectedHalka;
  String? _selectedVillage;
  
  final TextEditingController _applicantNameController = TextEditingController();
  final TextEditingController _relationNameController = TextEditingController();
  final TextEditingController _casteController = TextEditingController();
  
  final TextEditingController _khasraNumberController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  String _areaUnit = 'Hectare'; // Hectare or Acre
  
  final TextEditingController _northController = TextEditingController();
  final TextEditingController _southController = TextEditingController();
  final TextEditingController _eastController = TextEditingController();
  final TextEditingController _westController = TextEditingController();

  bool _isGenerating = false;
  bool _isPreFilled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = Provider.of<PatwariProvider>(context, listen: false).profile;
      if (profile != null) {
        if (_selectedHalka == null && profile.halkaNumbers.isNotEmpty) {
          setState(() { _selectedHalka = profile.halkaNumbers.first; });
        }
        if (_selectedVillage == null && profile.villages.isNotEmpty) {
          setState(() { _selectedVillage = profile.villages.first; });
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isPreFilled) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<String, dynamic>) {
        final cloneData = args;
        _applicantNameController.text = cloneData['applicantName']?.toString() ?? '';
        _relationNameController.text = cloneData['relationName']?.toString() ?? '';
        _casteController.text = cloneData['caste']?.toString() ?? '';
        _khasraNumberController.text = cloneData['khasraNumber']?.toString() ?? '';
        _areaController.text = cloneData['area']?.toString() ?? '';
        _northController.text = cloneData['boundaryNorth']?.toString() ?? '';
        _southController.text = cloneData['boundarySouth']?.toString() ?? '';
        _eastController.text = cloneData['boundaryEast']?.toString() ?? '';
        _westController.text = cloneData['boundaryWest']?.toString() ?? '';
        
        final clonedUnit = cloneData['areaUnit']?.toString();
        if (clonedUnit == 'Hectare' || clonedUnit == 'Acre') {
          _areaUnit = clonedUnit!;
        } else {
          _areaUnit = 'Hectare';
        }

        final profile = Provider.of<PatwariProvider>(context, listen: false).profile;
        if (profile != null) {
          final clonedHalka = cloneData['halkaNumber']?.toString();
          if (clonedHalka != null && profile.halkaNumbers.contains(clonedHalka)) {
            _selectedHalka = clonedHalka;
          }
          final clonedVillage = cloneData['village']?.toString();
          if (clonedVillage != null && profile.villages.contains(clonedVillage)) {
            _selectedVillage = clonedVillage;
          }
        }
        _isPreFilled = true;
      }
    }
  }

  Future<List<Farmer>> _getFarmerSuggestions(String query) async {
    final profile = Provider.of<PatwariProvider>(context, listen: false).profile;
    if (profile == null || query.isEmpty) return [];

    final snapshot = await _firestore
        .collection('patwaris')
        .doc(profile.uid)
        .collection('farmer_directory')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: query + '\uf8ff')
        .get();

    return snapshot.docs.map((doc) => Farmer.fromMap(doc.data())).toList();
  }

  void _showSuccessDialog(PdfResult result, String khasra) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chaturseema generated and uploaded successfully!'),
            const SizedBox(height: 16),
            Text('Khasra: $khasra'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final url = Uri.parse(result.downloadUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Download Link'),
          ),
          TextButton(
            onPressed: () => PdfGenerator.sharePdf(result.file, khasra),
            child: const Text('Share Document'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006064), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to history
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateChaturseema() async {
    if (!_formKey.currentState!.validate()) return;
    
    final profile = Provider.of<PatwariProvider>(context, listen: false).profile;
    if (profile == null) return;
    
    setState(() { _isGenerating = true; });
    
    try {
      final farmerData = {
        'name': _applicantNameController.text.trim(),
        'relationName': _relationNameController.text.trim(),
        'caste': _casteController.text.trim(),
      };

      // Update farmer directory
      final farmerRef = _firestore
          .collection('patwaris')
          .doc(profile.uid)
          .collection('farmer_directory')
          .doc(farmerData['name']);
      
      await farmerRef.set(farmerData, SetOptions(merge: true));

      // Save generated form
      final formData = {
        'patwariId': profile.uid,
        'patwariName': profile.name,
        'district': profile.district,
        'tehsil': profile.tehsil,
        'riCircle': profile.riCircle,
        'halkaNumber': _selectedHalka,
        'village': _selectedVillage,
        'applicantName': farmerData['name'],
        'relationName': farmerData['relationName'],
        'caste': farmerData['caste'],
        'khasraNumber': _khasraNumberController.text.trim(),
        'area': double.tryParse(_areaController.text.trim()) ?? 0.0,
        'areaUnit': _areaUnit,
        'boundaryNorth': _northController.text.trim(),
        'boundarySouth': _southController.text.trim(),
        'boundaryEast': _eastController.text.trim(),
        'boundaryWest': _westController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('generated_forms').add(formData);
      formData['id'] = docRef.id;
      
      // Trigger PDF generation and upload
      final result = await PdfGenerator.generateAndUploadChaturseema(data: formData);
      
      // Update Firestore with the download URL
      await docRef.update({'pdfUrl': result.downloadUrl});

      if (!mounted) return;
      _showSuccessDialog(result, formData['khasraNumber'] as String);
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() { _isGenerating = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<PatwariProvider>(context).profile;

    if (profile == null) {
      return const Scaffold(body: Center(child: Text("Profile not found")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F7),
      appBar: AppBar(
        title: const Text('New Chaturseema Record'),
        backgroundColor: const Color(0xFF006064),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildSection(
                title: 'Location Details',
                icon: Icons.map_outlined,
                children: [
                  _buildDropdown(
                    label: 'Halka Number',
                    value: _selectedHalka,
                    items: profile.halkaNumbers,
                    onChanged: (val) => setState(() => _selectedHalka = val),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: 'Village',
                    value: _selectedVillage,
                    items: profile.villages,
                    onChanged: (val) => setState(() => _selectedVillage = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Applicant Information',
                icon: Icons.person_outline,
                children: [
                  _buildTypeAheadField('Applicant Name (खातेदार)', 'Enter full name', _applicantNameController),
                  const SizedBox(height: 16),
                  _buildTextField('Father/Husband Name (पिता/पति)', 'Enter name', _relationNameController),
                  const SizedBox(height: 16),
                  _buildTextField('Caste (जाति)', 'Enter community/caste', _casteController),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Land Particulars',
                icon: Icons.landscape_outlined,
                children: [
                  _buildTextField('Khasra Number', 'e.g. 124/2', _khasraNumberController),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTextField('Area', '0.000', _areaController, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: _buildDropdown(
                          label: 'Unit',
                          value: _areaUnit,
                          items: ['Hectare', 'Acre'],
                          onChanged: (val) => setState(() => _areaUnit = val!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Boundaries (चतुर्सीमा)',
                icon: Icons.grid_4x4_outlined,
                children: [
                  _buildTextField('North (उत्तर)', 'Adjoining plot/owner', _northController),
                  const SizedBox(height: 12),
                  _buildTextField('South (दक्षिण)', 'Adjoining plot/owner', _southController),
                  const SizedBox(height: 12),
                  _buildTextField('East (पूर्व)', 'Adjoining plot/owner', _eastController),
                  const SizedBox(height: 12),
                  _buildTextField('West (पश्चिम)', 'Adjoining plot/owner', _westController),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _generateChaturseema,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006064),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isGenerating 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Generate Chaturseema',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E3E3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF006064), size: 20),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color(0xFF006064),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller, {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF44474E))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFC4C7C5)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFC4C7C5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF006064), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeAheadField(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF44474E))),
        const SizedBox(height: 8),
        TypeAheadField<Farmer>(
          builder: (context, typeController, focusNode) {
            return TextFormField(
              controller: controller, // Link back to our passed controller
              focusNode: focusNode,
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFFC4C7C5)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFC4C7C5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF006064), width: 2),
                ),
              ),
            );
          },
          suggestionsCallback: _getFarmerSuggestions,
          itemBuilder: (context, Farmer suggestion) {
            return ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFE0F2F1), child: Icon(Icons.person, color: Color(0xFF006064))),
              title: Text(suggestion.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${suggestion.relationName} - ${suggestion.caste}'),
            );
          },
          onSelected: (Farmer suggestion) {
            _applicantNameController.text = suggestion.name;
            _relationNameController.text = suggestion.relationName;
            _casteController.text = suggestion.caste;
          },
        ),
      ],
    );
  }

  Widget _buildDropdown({required String label, required String? value, required List<String> items, required Function(String?) onChanged}) {
    // Ensure value exists in items to avoid crashing the dropdown if clone data is mismatched
    String? safeValue = items.contains(value) ? value : (items.isNotEmpty ? items.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF44474E))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFC4C7C5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              isExpanded: true,
              items: items.map((String val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(val),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}