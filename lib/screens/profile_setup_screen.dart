import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/patwari_provider.dart';
import '../model/patwari_model.dart';
import 'history_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  _ProfileSetupScreenState createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _districtController = TextEditingController(text: 'कोरबा');
  final TextEditingController _tehsilController = TextEditingController(text: 'कोरबा');
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
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HistoryScreen()));
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
    const primaryTeal = Color(0xFF006064);
    const bgColor = Color(0xFFF5F7F7);
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Profile Setup'),
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1C1E),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please complete your profile details to continue.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF74777F),
                ),
              ),
              const SizedBox(height: 32),
              
              // Personal Information Card
              _buildSectionCard(
                title: 'Personal Details',
                children: [
                  _buildTextField(
                    label: 'Full Name', 
                    hint: 'Enter your full name',
                    controller: _nameController,
                    validator: (value) => value == null || value.isEmpty ? 'Enter your name' : null,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Location Information Card
              _buildSectionCard(
                title: 'Official Location',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'District', 
                          hint: 'कोरबा',
                          controller: _districtController,
                          validator: (value) => value == null || value.isEmpty ? 'Enter district' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          label: 'Tehsil', 
                          hint: 'कोरबा',
                          controller: _tehsilController,
                          validator: (value) => value == null || value.isEmpty ? 'Enter tehsil' : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Jurisdiction Information Card
              _buildSectionCard(
                title: 'Jurisdiction & Assignment',
                children: [
                  _buildTextField(
                    label: 'Revenue Inspector Circle (रा.नि.मं.)', 
                    hint: 'Enter RI Circle',
                    controller: _riCircleController,
                    validator: (value) => value == null || value.isEmpty ? 'Enter RI Circle' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Halka Numbers (प.ह.न.)', 
                    hint: 'e.g. 12, 14, 15',
                    controller: _halkaNumbersController,
                    validator: (value) => value == null || value.isEmpty ? 'Enter at least one Halka Number' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Assigned Villages', 
                    hint: 'e.g. Rampur, Sitapur',
                    maxLines: 2,
                    controller: _villagesController,
                    validator: (value) => value == null || value.isEmpty ? 'Enter at least one Village' : null,
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isSaving 
                     ? const CircularProgressIndicator(color: Colors.white) 
                     : const Text(
                         'Save Profile',
                         style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: Color(0xFF006064),
              ),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label, 
    required String hint, 
    required TextEditingController controller,
    required String? Function(String?) validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF44474E),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField( // Changed from TextField to TextFormField for validation
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFC4C7C5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFC4C7C5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF006064), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}