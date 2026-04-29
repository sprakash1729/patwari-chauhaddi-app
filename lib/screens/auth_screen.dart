import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../providers/patwari_provider.dart';
import 'profile_setup_screen.dart';
import 'home_screen.dart'; // Create your Home Screen

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  String _verificationId = '';
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isOtpSent = false;
  bool _isLoading = false;

  void _setLoading(bool val) {
    setState(() { _isLoading = val; });
  }

  Future<void> _signInWithGoogle() async {
    try {
      _setLoading(true);
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
         _setLoading(false);
         return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      await _checkUserExists();
    } catch (e) {
      print("Google Sign In Error: $e");
      _setLoading(false);
    }
  }

  Future<void> _verifyPhone() async {
    _setLoading(true);
    await _auth.verifyPhoneNumber(
      phoneNumber: '+91${_phoneController.text.trim()}',
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        await _checkUserExists();
      },
      verificationFailed: (FirebaseAuthException e) {
        print("Phone Verification Failed: ${e.message}");
        _setLoading(false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification Failed: ${e.message}')));
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isOtpSent = true;
          _isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
         _verificationId = verificationId;
      },
    );
  }

  Future<void> _signInWithOtp() async {
    try {
      _setLoading(true);
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _otpController.text.trim(),
      );
      await _auth.signInWithCredential(credential);
      await _checkUserExists();
    } catch (e) {
      print("OTP Sign In Error: $e");
      _setLoading(false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid OTP')));
    }
  }

  Future<void> _checkUserExists() async {
    if (!mounted) return;
    final provider = Provider.of<PatwariProvider>(context, listen: false);
    await provider.fetchProfile();
    
    _setLoading(false);
    if (!mounted) return;

    if (provider.profile == null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ProfileSetupScreen()));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen()));
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Chaturseema Login'),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.map_outlined, size: 80, color: Theme.of(context).primaryColor),
              SizedBox(height: 32),
              if (_isLoading)
                 Center(child: CircularProgressIndicator())
              else if (!_isOtpSent) ...[
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number', 
                    prefixText: '+91 ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _verifyPhone,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
                  child: Text('Get OTP', style: TextStyle(fontSize: 16)),
                ),
              ] else ...[
                TextField(
                  controller: _otpController,
                  decoration: InputDecoration(
                    labelText: 'Enter OTP',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _signInWithOtp,
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
                  child: Text('Verify OTP', style: TextStyle(fontSize: 16)),
                ),
                TextButton(
                  onPressed: () => setState(() { _isOtpSent = false; _otpController.clear(); }),
                  child: Text('Change Phone Number'),
                )
              ],
              SizedBox(height: 32),
              Row(
                children: [
                   Expanded(child: Divider()),
                   Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("OR")),
                   Expanded(child: Divider()),
                ]
              ),
              SizedBox(height: 32),
              OutlinedButton.icon(
                icon: Icon(Icons.login),
                label: Text('Continue with Google'),
                onPressed: _isLoading ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: Colors.black87,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
