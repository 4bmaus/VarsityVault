import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sports.dart';
import '../constants.dart';

class LoginScreen extends StatefulWidget {
  final String? inviteLinkRole;
  final String? inviteLinkSchool;
  final String? inviteLinkSport;
  final Function(String, String, String, String, String, DateTime, String, String, String) onCreateProfile;
  final Function(String, String, String, String, String?) onCreateStaffProfile;
  final Function(String) onRealLogin;
  final Function(String, String?, String, bool) onStaffLogin;
  final Function(String) onDemoStudentLogin;
  final List<SportDefinition> globalSports;
  final Function(String) onSchoolSelected;
  final Function(String) onThemeChanged;
  final String activeTheme;

  const LoginScreen({
    super.key, required this.inviteLinkRole, required this.inviteLinkSchool, required this.inviteLinkSport,
    required this.onCreateProfile, required this.onCreateStaffProfile, required this.onRealLogin,
    required this.onStaffLogin, required this.onDemoStudentLogin, required this.globalSports,
    required this.onSchoolSelected, required this.onThemeChanged, required this.activeTheme,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  // PROPOSAL REQUIREMENT: The system shall allow users to sign in with their Google account.
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');
      googleProvider.setCustomParameters({'prompt': 'select_account'}); 

      UserCredential userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      String userEmail = (userCredential.user?.email ?? "").toLowerCase().trim();
      String uid = userCredential.user!.uid;

      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      bool userExists = doc.exists;

      bool isDistrictEmail = userEmail.endsWith('@ggusd.net') || userEmail.endsWith('@stu.ggusd.net');
      bool hasInviteToken = widget.inviteLinkRole != null;

      if (!userExists && !isDistrictEmail && !hasInviteToken) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Access Denied: You must use a @ggusd.net email, or possess a valid Staff Invite Link."),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 6),
            )
          );
        }
        setState(() => _isLoading = false);
        return; 
      }

      if (userExists) {
        if (hasInviteToken) {
          Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
          
          // 1. THE ULTIMATE HAT MERGER: Scours the database for any historical roles
          List<dynamic> existingRoles = [];
          if (userData.containsKey('myAssignedRoles')) existingRoles.addAll(List.from(userData['myAssignedRoles']));
          if (userData.containsKey('roles')) existingRoles.addAll(List.from(userData['roles']));
          if (userData.containsKey('role')) existingRoles.add(userData['role']);
          
          existingRoles = existingRoles.toSet().toList();
          if (existingRoles.isEmpty) existingRoles = ['Student'];
          
          // 2. Append the newly invited role
          if (!existingRoles.contains(widget.inviteLinkRole)) {
              existingRoles.add(widget.inviteLinkRole!);
          }

          // 3. Update coaching sport memberships securely
          List<dynamic> memberships = [];
          if (userData.containsKey('memberships')) {
            memberships = List.from(userData['memberships']);
          }
          
          if (widget.inviteLinkSport != null && widget.inviteLinkRole!.contains('Coach')) {
             bool hasSport = memberships.any((m) => m is Map && m['sport'] == widget.inviteLinkSport);
             if (!hasSport) {
                 memberships.add({
                     'sport': widget.inviteLinkSport,
                     'level': 'Varsity', 
                     'isActive': true,
                 });
             }
          }

          // 4. Update Firebase
          // PROPOSAL REQUIREMENT: The system shall support a "Many Hats" architecture, allowing one user to hold multiple roles simultaneously.
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'role': widget.inviteLinkRole!, 
            'school': 'Rancho Alamitos High School', 
            'myAssignedRoles': existingRoles,
            'memberships': memberships, 
            'showTutorial': true, 
          }, SetOptions(merge: true));
        }
        widget.onRealLogin(uid);
      } else {
        if (hasInviteToken) {
          widget.onCreateStaffProfile(
            uid, 
            userEmail, 
            widget.inviteLinkRole!, 
            'Rancho Alamitos High School', 
            widget.inviteLinkSport
          );
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'showTutorial': true,
            'myAssignedRoles': [widget.inviteLinkRole!],
          }, SetOptions(merge: true));
        } else {
          _showStudentRegistrationDialog(userCredential.user!);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: ${e.toString()}"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showStudentRegistrationDialog(User user) {
    final firstCtrl = TextEditingController(text: user.displayName?.split(' ').first ?? '');
    final lastCtrl = TextEditingController(text: user.displayName?.split(' ').last ?? '');
    final idCtrl = TextEditingController();
    String? selectedGrade; String? selectedSex; String typedSchool = '';
    DateTime now = DateTime.now();
    DateTime maxDate = DateTime(now.year - 14, 12, 31); DateTime minDate = DateTime(now.year - 19, 1, 1);   
    DateTime tempDob = DateTime(now.year - 14, 1, 1);   

    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text("Student Registration", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Welcome to Varsity Vault! Please complete your profile to continue.", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))),
                  const SizedBox(height: 20),
                  TextField(controller: firstCtrl, decoration: const InputDecoration(labelText: "First Name")),
                  TextField(controller: lastCtrl, decoration: const InputDecoration(labelText: "Last Name")),
                  TextField(controller: idCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Student ID Number")),
                  DropdownButtonFormField<String>(value: selectedGrade, hint: const Text("Select Grade"), items: ["9th", "10th", "11th", "12th"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (val) => setDialogState(() => selectedGrade = val), decoration: const InputDecoration(labelText: "Grade")),
                  DropdownButtonFormField<String>(value: selectedSex, hint: const Text("Select Sex"), items: ["Male", "Female", "Other"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (val) => setDialogState(() => selectedSex = val), decoration: const InputDecoration(labelText: "Sex")),
                  ListTile(contentPadding: EdgeInsets.zero, title: const Text("Date of Birth"), subtitle: Text("${tempDob.month}/${tempDob.day}/${tempDob.year}"), trailing: const Icon(Icons.calendar_today), onTap: () async { final d = await showDatePicker(context: context, initialDate: tempDob, firstDate: minDate, lastDate: maxDate); if (d != null) setDialogState(() => tempDob = d); }),
                  Autocomplete<String>(optionsBuilder: (v) => v.text.isEmpty ? kSocalHighSchools : kSocalHighSchools.where((s) => s.toLowerCase().contains(v.text.toLowerCase())), onSelected: (s) => typedSchool = s, fieldViewBuilder: (c, t, f, o) => TextField(controller: t, focusNode: f, decoration: const InputDecoration(labelText: "High School"), onChanged: (val) => typedSchool = val)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () async { await FirebaseAuth.instance.signOut(); Navigator.pop(ctx); }, child: const Text("Cancel & Logout", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
              onPressed: () async {
                if (idCtrl.text.isEmpty || firstCtrl.text.isEmpty || lastCtrl.text.isEmpty || selectedGrade == null || selectedSex == null || typedSchool.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please completely fill out all fields!"), backgroundColor: Colors.red)); return;
                }
                widget.onCreateProfile(user.uid, firstCtrl.text, lastCtrl.text, idCtrl.text, selectedGrade!, tempDob, selectedSex!, user.email ?? "", typedSchool);
                // PROPOSAL REQUIREMENT: The system shall assign new users the default role of "Student".
                await FirebaseFirestore.instance.collection('users').doc(user.uid).set({ 'myAssignedRoles': ['Student'], 'showTutorial': true }, SetOptions(merge: true));
                Navigator.pop(ctx);
              }, 
              child: const Text("Create Profile")
            )
          ],
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasInvite = widget.inviteLinkRole != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/Rancho_Alamitos_High_School_logo.png', height: 120, errorBuilder: (c,e,s) => Icon(Icons.shield, size: 120, color: Theme.of(context).primaryColor)),
                  const SizedBox(height: 20),
                  Text("Varsity Vault", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                  const SizedBox(height: 10),
                  
                  if (hasInvite) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), border: Border.all(color: Colors.green), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          const Icon(Icons.verified, color: Colors.green, size: 30),
                          const SizedBox(height: 5),
                          Text("VIP Invite Active", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                          Text("You have been invited to join ${widget.inviteLinkSchool} as a ${widget.inviteLinkRole}.", textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    const Text("Secure High School Athletics Management", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 30),
                  ],

                  _isLoading 
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.login),
                          label: const Text("Sign In with Google", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
                          ),
                          onPressed: _signInWithGoogle,
                        ),
                      ),
                  
                  const SizedBox(height: 20),
                  const Text("Secured by Google Identity & District IAM", style: TextStyle(fontSize: 10, color: Colors.grey)),
                  
                  const Divider(height: 40),
                  TextButton(
                    onPressed: () => widget.onDemoStudentLogin("1001"),
                    child: const Text("Bypass Login (Developer Mode)", style: TextStyle(color: Colors.grey))
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}