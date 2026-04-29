import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../providers/patwari_provider.dart';

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
  @override
  _CreateChaturseemaScreenState createState() => _CreateChaturseemaScreenState();
}

class _CreateChaturseemaScreenState extends State<CreateChaturseemaScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = Provider.of<PatwariProvider>(context, listen: false).profile;
      if (profile != null) {
        if (profile.halkaNumbers.isNotEmpty) {
          setState(() { _selectedHalka = profile.halkaNumbers.first; });
        }
        if (profile.villages.isNotEmpty) {
          setState(() { _selectedVillage = profile.villages.first; });
        }
      }
    });
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

      await _firestore.collection('generated_forms').add(formData);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Form Generated Successfully!')));
      // Here you would typically navigate to a PDF preview or clear the form
      
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
      return Scaffold(body: Center(child: Text("Profile not found")));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Create Chaturseema')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Location Details', style: Theme.of(context).textTheme.titleMedium),
                      SizedBox(height: 16),
                      Text('District: ${profile.district}'),
                      SizedBox(height: 8),
                      Text('Tehsil: ${profile.tehsil}'),
                      SizedBox(height: 8),
                      Text('RI Circle: ${profile.riCircle}'),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: 'Halka Number', border: OutlineInputBorder()),
                        value: _selectedHalka,
                        items: profile.halkaNumbers.map((halka) => DropdownMenuItem(value: halka, child: Text(halka))).toList(),
                        onChanged: (val) => setState(() => _selectedHalka = val),
                        validator: (val) => val == null ? 'Select Halka' : null,
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: 'Village', border: OutlineInputBorder()),
                        value: _selectedVillage,
                        items: profile.villages.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                        onChanged: (val) => setState(() => _selectedVillage = val),
                        validator: (val) => val == null ? 'Select Village' : null,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Applicant Details', style: Theme.of(context).textTheme.titleMedium),
                      SizedBox(height: 16),
                      TypeAheadField<Farmer>(
                        builder: (context, controller, focusNode) {
                          return TextFormField(
                            controller: _applicantNameController,
                            focusNode: focusNode,
                            decoration: InputDecoration(labelText: 'Applicant Name (खातेदार)', border: OutlineInputBorder()),
                            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                          );
                        },
                        suggestionsCallback: _getFarmerSuggestions,
                        itemBuilder: (context, Farmer suggestion) {
                          return ListTile(
                            title: Text(suggestion.name),
                            subtitle: Text('${suggestion.relationName} - ${suggestion.caste}'),
                          );
                        },
                        onSelected: (Farmer suggestion) {
                          _applicantNameController.text = suggestion.name;
                          _relationNameController.text = suggestion.relationName;
                          _casteController.text = suggestion.caste;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _relationNameController,
                        decoration: InputDecoration(labelText: 'Father/Husband Name (पिता/पति)', border: OutlineInputBorder()),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _casteController,
                        decoration: InputDecoration(labelText: 'Caste (जाति)', border: OutlineInputBorder()),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Land Details', style: Theme.of(context).textTheme.titleMedium),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _khasraNumberController,
                        decoration: InputDecoration(labelText: 'Khasra Number', border: OutlineInputBorder()),
                        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _areaController,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(labelText: 'Area', border: OutlineInputBorder()),
                              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(border: OutlineInputBorder()),
                              value: _areaUnit,
                              items: ['Hectare', 'Acre'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (val) => setState(() => _areaUnit = val!),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Boundaries (चतुर्सीमा)', style: Theme.of(context).textTheme.titleMedium),
                      SizedBox(height: 16),
                      TextFormField(controller: _northController, decoration: InputDecoration(labelText: 'North (उत्तर)', border: OutlineInputBorder())),
                      SizedBox(height: 16),
                      TextFormField(controller: _southController, decoration: InputDecoration(labelText: 'South (दक्षिण)', border: OutlineInputBorder())),
                      SizedBox(height: 16),
                      TextFormField(controller: _eastController, decoration: InputDecoration(labelText: 'East (पूर्व)', border: OutlineInputBorder())),
                      SizedBox(height: 16),
                      TextFormField(controller: _westController, decoration: InputDecoration(labelText: 'West (पश्चिम)', border: OutlineInputBorder())),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isGenerating ? null : _generateChaturseema,
                style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
                child: _isGenerating
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Generate Chaturseema', style: TextStyle(fontSize: 18)),
              ),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
