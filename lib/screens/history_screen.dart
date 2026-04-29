import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/patwari_provider.dart';
import 'create_chaturseema_screen.dart'; // Ensure you handle pre-filling in Create Screen
import '../utils/pdf_generator.dart'; // Assuming you use this to re-generate if not in storage, or fetch from storage

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _allForms = [];
  List<Map<String, dynamic>> _filteredForms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchForms();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchForms() async {
    final profile = Provider.of<PatwariProvider>(context, listen: false).profile;
    if (profile == null) return;

    try {
      final snapshot = await _firestore
          .collection('generated_forms')
          .where('patwariId', isEqualTo: profile.uid)
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _allForms = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _filteredForms = _allForms;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching history: $e");
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    
    if (query.isEmpty) {
      setState(() => _filteredForms = _allForms);
      return;
    }

    setState(() {
      _filteredForms = _allForms.where((form) {
        final name = (form['applicantName'] ?? '').toString().toLowerCase();
        final khasra = (form['khasraNumber'] ?? '').toString().toLowerCase();
        
        String dateStr = '';
        if (form['createdAt'] != null) {
           final date = (form['createdAt'] as Timestamp).toDate();
           dateStr = DateFormat('dd/MM/yyyy').format(date);
        }

        // Logic: if query has digits or slashes, try matching khasra or date
        final isNumericOrDate = RegExp(r'[0-9/]').hasMatch(query);
        
        if (isNumericOrDate) {
          return khasra.contains(query) || dateStr.contains(query);
        } else {
          return name.contains(query);
        }
      }).toList();
    });
  }

  void _showActionOptions(BuildContext context, Map<String, dynamic> formData) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text('Download PDF'),
                onTap: () {
                  Navigator.pop(context);
                  // Call PDF Generator or download from Firebase Storage
                  PdfGenerator.generateAndShareChaturseema(data: formData);
                },
              ),
              ListTile(
                leading: Icon(Icons.copy, color: Colors.blue),
                title: Text('Clone Form'),
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to Create Screen and pass data for pre-filling
                  // Navigator.push(context, MaterialPageRoute(builder: (_) => CreateChaturseemaScreen(initialData: formData)));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Clone feature integration requires updating Create Screen.')));
                },
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Name, Khasra, or Date (DD/MM/YYYY)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator())
              : _filteredForms.isEmpty
                ? Center(child: Text('No records found.'))
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredForms.length,
                    itemBuilder: (context, index) {
                      final form = _filteredForms[index];
                      String dateStr = 'Unknown Date';
                      if (form['createdAt'] != null) {
                         final date = (form['createdAt'] as Timestamp).toDate();
                         dateStr = DateFormat('dd/MM/yyyy').format(date);
                      }

                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          title: Text(form['applicantName'] ?? 'No Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Padding(
                            padding: const EdgeInsets.top(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Date: $dateStr'),
                                Text('Khasra: ${form['khasraNumber']}  |  Village: ${form['village']}'),
                              ],
                            ),
                          ),
                          trailing: Icon(Icons.more_vert),
                          onTap: () => _showActionOptions(context, form),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
