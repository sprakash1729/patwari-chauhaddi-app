import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/patwari_model.dart';

class PatwariProvider with ChangeNotifier {
  PatwariProfile? _profile;
  bool _isLoading = true;

  PatwariProfile? get profile => _profile;
  bool get isLoading => _isLoading;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> fetchProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      DocumentSnapshot doc = await _firestore.collection('patwaris').doc(user.uid).get();
      if (doc.exists) {
        _profile = PatwariProfile.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      } else {
        _profile = null;
      }
    } catch (e) {
      print("Error fetching profile: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveProfile(PatwariProfile profileData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('patwaris').doc(user.uid).set(profileData.toMap());
      _profile = profileData;
    } catch (e) {
       print("Error saving profile: $e");
       rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
