import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/patwari_provider.dart';
import '../utils/pdf_generator.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'patwari');
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  Future<void> _handleDownload(Map<String, dynamic> formData) async {
    if (formData['pdfUrl'] != null && formData['pdfUrl'].toString().isNotEmpty) {
       final url = Uri.parse(formData['pdfUrl']);
       if (await canLaunchUrl(url)) {
         await launchUrl(url, mode: LaunchMode.externalApplication);
       } else {
         await launchUrl(url, mode: LaunchMode.externalApplication);
       }
    } else {
       final result = await PdfGenerator.generateAndUploadChaturseema(data: formData);
       await _firestore.collection('generated_forms').doc(formData['id']).update({'pdfUrl': result.downloadUrl});
       final url = Uri.parse(result.downloadUrl);
       await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showActionOptions(BuildContext context, Map<String, dynamic> formData) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Actions for ${formData['applicantName']}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Download PDF'),
              onTap: () {
                Navigator.pop(context);
                _handleDownload(formData);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Color(0xFF006064)),
              title: const Text('Clone Form'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/create', arguments: formData);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<PatwariProvider>(context).profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'History Log',
          style: TextStyle(color: Color(0xFF1A1C1E), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF006064)),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by Khasra or Name...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF74777F)),
                filled: true,
                fillColor: const Color(0xFFF0F3F3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          Expanded(
            child: profile == null
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF006064)))
              : StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('generated_forms')
                      .where('patwariId', isEqualTo: profile.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Error loading history.'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF006064)));
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(child: Text('No records found.'));
                    }

                    final sortedDocs = docs.toList();
                    sortedDocs.sort((a, b) {
                      final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                      final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                      if (aTime == null && bTime == null) return 0;
                      if (aTime == null) return 1;
                      if (bTime == null) return -1;
                      return bTime.compareTo(aTime); // descending
                    });

                    final filteredForms = sortedDocs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      data['id'] = doc.id;
                      return data;
                    }).where((form) {
                      if (_searchQuery.isEmpty) return true;

                      final name = (form['applicantName'] ?? '').toString().toLowerCase();
                      final khasra = (form['khasraNumber'] ?? '').toString().toLowerCase();
                      
                      String dateStr = '';
                      if (form['createdAt'] != null) {
                         final date = (form['createdAt'] as Timestamp).toDate();
                         dateStr = DateFormat('dd/MM/yyyy').format(date);
                      }

                      final isNumericOrDate = RegExp(r'[0-9/]').hasMatch(_searchQuery);
                      
                      if (isNumericOrDate) {
                        return khasra.contains(_searchQuery) || dateStr.contains(_searchQuery);
                      } else {
                        return name.contains(_searchQuery);
                      }
                    }).toList();

                    if (filteredForms.isEmpty) {
                      return const Center(child: Text('No records match your search.'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredForms.length,
                      itemBuilder: (context, index) {
                        final form = filteredForms[index];
                        String dateStr = 'Unknown Date';
                        if (form['createdAt'] != null) {
                           final date = (form['createdAt'] as Timestamp).toDate();
                           dateStr = DateFormat('dd/MM/yyyy').format(date);
                        }

                        return RecordCard(
                          name: form['applicantName']?.toString() ?? 'No Name',
                          date: dateStr,
                          khasra: form['khasraNumber']?.toString() ?? '-',
                          village: form['village']?.toString() ?? '-',
                          onOptionsTap: () => _showActionOptions(context, form),
                        );
                      },
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/create'),
        backgroundColor: const Color(0xFF006064),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Chaturseema', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: const Color(0xFF006064),
        unselectedItemColor: const Color(0xFF74777F),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Maps'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class RecordCard extends StatelessWidget {
  final String name;
  final String date;
  final String khasra;
  final String village;
  final VoidCallback onOptionsTap;

  const RecordCard({
    super.key,
    required this.name,
    required this.date,
    required this.khasra,
    required this.village,
    required this.onOptionsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF74777F)),
                  onPressed: onOptionsTap,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Date: $date',
              style: const TextStyle(color: Color(0xFF74777F), fontSize: 14),
            ),
            const Divider(height: 24),
            Row(
              children: [
                _infoChip(Icons.tag, 'Khasra: $khasra'),
                const SizedBox(width: 12),
                _infoChip(Icons.location_on_outlined, village),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF006064)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF006064),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}