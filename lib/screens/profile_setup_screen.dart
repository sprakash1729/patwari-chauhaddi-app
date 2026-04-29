import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/patwari_provider.dart';
import '../models/patwari_model.dart';
import 'home_screen.dart'; // Implement this separately

class ProfileSetupScreen extends StatefulWidget {
  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _districtController = TextEditingController(text: 'Korba');
  final TextEditingController _tehsilController = TextEditingController(text: 'Korba');
  final TextEditingController _riCircleController = TextEditingController();
  final TextEditingController _halkaNumbersController = TextEditingController();
  final TextEditingController _villagesController = TextEditingController();

  bool _isSaving = false;

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isSaving = true; });
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final halkaList = _halkaNumbersController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final villageList = _villagesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      final profile = PatwariProfile(
        uid: user.uid,
        name: _nameController.text.trim(),
        district: _districtController.text.trim(),
        tehsil: _tehsilController.text.trim(),
        riCircle: _riCircleController.text.trim(),
        halkaNumbers: halkaList,
        villages: villageList,
      );

      try {
        await Provider.of<PatwariProvider>(context, listen: false).saveProfile(profile);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen()));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      } finally {
        if (mounted) setState(() { _isSaving = false; });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _districtController.dispose();
    _tehsilController.dispose();
    _riCircleController.dispose();
    _halkaNumbersController.dispose();
    _villagesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Patwari Profile Setup')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Please complete your profile to continue", style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Enter your name' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _districtController,
                decoration: InputDecoration(labelText: 'District', border: OutlineInputBorder()),
                readOnly: true, // Korba by default based on spec
                validator: (value) => value == null || value.isEmpty ? 'Enter district' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _tehsilController,
                decoration: InputDecoration(labelText: 'Tehsil', border: OutlineInputBorder()),
                readOnly: true, // Korba by default based on spec
                validator: (value) => value == null || value.isEmpty ? 'Enter tehsil' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _riCircleController,
                decoration: InputDecoration(labelText: 'Revenue Inspector Circle (रा.नि.मं.)', border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Enter RI Circle' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _halkaNumbersController,
                decoration: InputDecoration(
                  labelText: 'Halka Numbers (प.ह.न.)', 
                  hintText: 'e.g. 12, 14, 15',
                  border: OutlineInputBorder()
                ),
                validator: (value) => value == null || value.isEmpty ? 'Enter at least one Halka Number' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _villagesController,
                decoration: InputDecoration(
                  labelText: 'Assigned Villages', 
                  hintText: 'e.g. Rampur, Sitapur',
                  border: OutlineInputBorder()
                ),
                validator: (value) => value == null || value.isEmpty ? 'Enter at least one Village' : null,
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
                child: _isSaving 
                   ? CircularProgressIndicator(color: Colors.white) 
                   : Text('Save Profile', style: TextStyle(fontSize: 16)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
