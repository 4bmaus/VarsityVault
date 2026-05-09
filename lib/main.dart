import 'dart:io';
import 'dart:convert'; 
import 'dart:async'; 
import 'dart:math' as math; 
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; 
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:http/http.dart' as http; 
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'firebase_options.dart'; 

import 'constants.dart';
import 'models/student.dart';
import 'models/inventory.dart';
import 'models/sports.dart';
import 'models/report.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'widgets/emergency_card.dart'; 

void main() async { 
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: "env.txt"); 
  } catch (e) {
    debugPrint("Warning: .env file not found.");
  }
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform
  );
  
  runApp(const VarsityVaultApp()); 
}

class VarsityVaultApp extends StatefulWidget {
  const VarsityVaultApp({super.key});
  
  @override
  State<VarsityVaultApp> createState() => _VarsityVaultAppState();
}

class _VarsityVaultAppState extends State<VarsityVaultApp> with WidgetsBindingObserver {
  bool isLoggedIn = false;
  bool isGodMode = false; 
  String currentRole = 'Student'; 
  int currentStudentId = 0; 
  String currentSportFilter = 'Football (11 person)'; 
  String currentSchool = 'Rancho Alamitos High School'; 
  List<String> myAssignedRoles = []; 
  
  String _activeTheme = "Ocean Dark"; 
  bool _isColorBlindMode = false; 
  ThemeMode _themeMode = ThemeMode.dark; 
  Color _primaryColor = const Color(0xFF0D47A1); 
  Color _secondaryColor = const Color(0xFF64B5F6);

  bool _triggerWalkthroughOnLoad = false;

  List<Student> globalStudents = []; 
  List<InventoryFolder> globalFolders = [];
  List<SportDefinition> globalSports = [
    SportDefinition(name: "Baseball", gender: "Boys", coachId: "Coach1"),
    SportDefinition(name: "Basketball Boys", gender: "Boys", coachId: "Coach4"),
    SportDefinition(name: "Basketball Girls", gender: "Girls", coachId: "Coach4"),
    SportDefinition(name: "Cheer and Song", gender: "Co-Ed", coachId: "Coach9"),
    SportDefinition(name: "Cross Country", gender: "Co-Ed", coachId: "Coach7"),
    SportDefinition(name: "Flag Football", gender: "Girls", coachId: "Coach11"), 
    SportDefinition(name: "Football (11 person)", gender: "Boys", coachId: "Coach1"),
    SportDefinition(name: "Golf Boys", gender: "Boys", coachId: "Coach5"), 
    SportDefinition(name: "Golf Girls", gender: "Girls", coachId: "Coach5"), 
    SportDefinition(name: "Soccer Boys", gender: "Boys", coachId: "Coach3"),
    SportDefinition(name: "Soccer Girls", gender: "Girls", coachId: "Coach3"),
    SportDefinition(name: "Softball", gender: "Girls", coachId: "Coach9"),
    SportDefinition(name: "Swimming & Diving", gender: "Co-Ed", coachId: "Coach12"),
    SportDefinition(name: "Tennis Boys", gender: "Boys", coachId: "Coach2"),
    SportDefinition(name: "Tennis Girls", gender: "Girls", coachId: "Coach2"),
    SportDefinition(name: "Track & Field", gender: "Co-Ed", coachId: "Coach13"),
    SportDefinition(name: "Volleyball Boys", gender: "Boys", coachId: "Coach10"), 
    SportDefinition(name: "Volleyball Girls", gender: "Girls", coachId: "Coach10"),
    SportDefinition(name: "Water Polo Boys", gender: "Boys", coachId: "Coach14"), 
    SportDefinition(name: "Water Polo Girls", gender: "Girls", coachId: "Coach14"),
    SportDefinition(name: "Wrestling Boys", gender: "Boys", coachId: "Coach15"), 
    SportDefinition(name: "Wrestling Girls", gender: "Girls", coachId: "Coach15"), 
  ];
  
  List<InventoryItem> globalInventory = [];
  List<GameEvent> globalSchedule = [];
  List<InjuryReport> globalInjuries = [];
  List<String> adminNotifications = [];
  List<String> coachNotifications = [];

  StreamSubscription<QuerySnapshot>? _staffStudentsSub;
  StreamSubscription<QuerySnapshot>? _scheduleSub;
  StreamSubscription<DocumentSnapshot>? _studentSub;

  @override
  void initState() { 
    super.initState(); 
    WidgetsBinding.instance.addObserver(this); 
    _loadSavedTheme(); 
    _generateDummyData(); 
    
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null && !isLoggedIn) {
        _realLogin(user.uid);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); 
    _staffStudentsSub?.cancel();
    _scheduleSub?.cancel();
    _studentSub?.cancel();
    super.dispose();
  }

  Future<void> _seedDummyStudents({bool isAuto = false}) async {
    List<String> firstNames = ["Alex", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Cameron", "Quinn", "Avery", "Skyler", "Bryce", "Drew"];
    List<String> lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez", "Lee", "Perez"];
    List<String> grades = ["9th", "10th", "11th", "12th"];
    int idCounter = 90000; 
    int totalCreated = 0;

    rootScaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text("Generating dynamic test students..."), backgroundColor: Colors.orange)
    );

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var sportDef in globalSports) {
        for (int i = 0; i < 5; i++) {
          idCounter++; 
          firstNames.shuffle(); 
          lastNames.shuffle(); 
          grades.shuffle();
          
          String fName = firstNames.first; 
          String lName = lastNames.first;
          
          double rand = math.Random().nextDouble();
          bool isActive = false; 
          String clearanceStatus = "pending";
          
          if (rand < 0.3) { 
            clearanceStatus = "approved"; 
            isActive = true; 
          } else if (rand < 0.6) { 
            clearanceStatus = "approved"; 
            isActive = false; 
          } else if (rand < 0.8) { 
            clearanceStatus = "pending"; 
            isActive = false; 
          } else { 
            clearanceStatus = "denied"; 
            isActive = false; 
          }

          bool hasInjury = math.Random().nextDouble() < 0.15; 

          Map<String, dynamic> rawPayload = {
             'id': idCounter, 
             'firstName': fName, 
             'lastName': lName, 
             'grade': grades.first,
             'sex': sportDef.gender == "Girls" ? "Female" : "Male", 
             'school': currentSchool,
             'email': "${fName.toLowerCase()}.${lName.toLowerCase()}$idCounter@student.com",
             'roles': ['Student'], 
             'clearanceStatus': clearanceStatus,
             'memberships': [{
               'sport': sportDef.name, 
               'gender': sportDef.gender, 
               'level': 'varsity', 
               'isActive': isActive
             }],
             'injuryHistory': hasInjury ? [{
               'studentId': idCounter, 
               'studentName': "$fName $lName", 
               'date': "2026-04-20", 
               'description': "Simulated Test Injury", 
               'isActive': true, 
               'recordedBy': "Trainer", 
               'isRead': false
             }] : [],
             'physicalFrontPath': "simulated_front_image", 
             'physicalBackPath': "simulated_back_image",
             'insuranceFrontPath': "simulated_ins_front", 
             'insuranceBackPath': "simulated_ins_back",
             'isInsured': true, 
             'insuranceCompany': "Kaiser", 
             'insurancePolicyNum': "12345",
             'physicianName': "Dr. House", 
             'physicianPhone': "555-1234", 
             'height': "5'10", 
             'weight': "160",
             'street': "123 Main St", 
             'city': "Garden Grove", 
             'state': "CA", 
             'zip': "92840",
             'p1First': "Jane", 
             'p1Last': lName, 
             'p1Mobile': "555-9876", 
             'p1Email': "parent@test.com",
             'emgFirst': "John", 
             'emgLast': lName, 
             'emgPhone': "555-5555", 
             'emgRel': "Father",
             'unreadAlerts': 0, 
             'notifications': [], 
             'staffNotes': [], 
             'absences': [], 
             'doctorsNotes': []
          };

          DocumentReference docRef = FirebaseFirestore.instance.collection('users').doc("dummy_user_$idCounter");
          batch.set(docRef, rawPayload);
          totalCreated++;
        }
      }
      await batch.commit(); 
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text("Success! $totalCreated dynamic students created."), backgroundColor: Colors.green)
      );
    } catch (e) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text("Failed to seed database: $e"), backgroundColor: Colors.red, duration: const Duration(seconds: 10))
      );
    }
  }

  Future<void> _syncStudentToCloud(Student s) async {
    try {
      String? targetDocId;
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentRole == 'Student' && currentUser != null) {
        targetDocId = currentUser.uid;
      } else {
        var query = await FirebaseFirestore.instance.collection('users').where('id', isEqualTo: s.id).get();
        if (query.docs.isEmpty) {
          query = await FirebaseFirestore.instance.collection('users').where('id', isEqualTo: s.id.toString()).get();
        }
        if (query.docs.isNotEmpty) {
          targetDocId = query.docs.first.id;
        }
      }

      if (targetDocId != null) {
        Map<String, dynamic> payload = s.toJson();
        payload['injuryHistory'] = s.injuryHistory.map((i) => {
          'studentId': i.studentId,
          'studentName': i.studentName,
          'date': i.date,
          'description': i.description,
          'isActive': i.isActive,
          'recordedBy': i.recordedBy,
          'isRead': i.isRead
        }).toList();

        // PROPOSAL REQUIREMENT: The system shall process database queries on the Server side (Firebase Rules) to guarantee data security.
        await FirebaseFirestore.instance.collection('users').doc(targetDocId).update(payload);
      }
    } catch (e) {
      debugPrint("Cloud Sync Error: $e");
    }
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedTheme = prefs.getString('vault_theme');
    if (savedTheme != null) {
      _applyTheme(savedTheme);
    }
  }

  void _generateDummyData() {
    Set<String> baseSports = {"Baseball", "Basketball", "Cheer", "Cross Country", "Flag Football", "Football", "Golf", "Soccer", "Softball", "Tennis", "Volleyball", "Swimming & Diving", "Track & Field", "Water Polo", "Wrestling"};
    
    for (String sport in baseSports) { 
      String rootId = "f_$sport"; 
      globalFolders.add(InventoryFolder(id: rootId, name: sport)); 
      
      for (String gender in ["Boys", "Girls"]) { 
        String genId = "${rootId}_$gender"; 
        globalFolders.add(InventoryFolder(id: genId, name: gender, parentId: rootId)); 
        
        for (String level in ["Varsity", "JV", "Frosh"]) { 
          globalFolders.add(InventoryFolder(id: "${genId}_$level", name: level, parentId: genId)); 
        } 
      } 
    }
  }

  // PROPOSAL REQUIREMENT: The system shall provide over 10 dynamic UI themes, saving the user's preference to the cloud.
  void _applyTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance(); 
    await prefs.setString('vault_theme', themeName);
    
    setState(() {
      _activeTheme = themeName;
      if (themeName == "Ruby Light") { _primaryColor = const Color(0xFFC62828); _secondaryColor = const Color(0xFFFFCDD2); _themeMode = ThemeMode.light; }
      else if (themeName == "Crimson Dark") { _primaryColor = const Color(0xFFD32F2F); _secondaryColor = const Color(0xFFEF5350); _themeMode = ThemeMode.dark; }
      else if (themeName == "Amber Light") { _primaryColor = const Color(0xFFE65100); _secondaryColor = const Color(0xFFFFE082); _themeMode = ThemeMode.light; }
      else if (themeName == "Sunset Dark") { _primaryColor = const Color(0xFFFF9800); _secondaryColor = const Color(0xFFFFB74D); _themeMode = ThemeMode.dark; }
      else if (themeName == "Maize Light") { _primaryColor = const Color(0xFFF57F17); _secondaryColor = const Color(0xFFFFF9C4); _themeMode = ThemeMode.light; }
      else if (themeName == "Gold Dark") { _primaryColor = const Color(0xFFFFB300); _secondaryColor = const Color(0xFFFFF176); _themeMode = ThemeMode.dark; }
      else if (themeName == "Mint Light") { _primaryColor = const Color(0xFF2E7D32); _secondaryColor = const Color(0xFFC8E6C9); _themeMode = ThemeMode.light; }
      else if (themeName == "Forest Dark") { _primaryColor = const Color(0xFF388E3C); _secondaryColor = const Color(0xFF81C784); _themeMode = ThemeMode.dark; }
      else if (themeName == "Sky Light") { _primaryColor = const Color(0xFF1565C0); _secondaryColor = const Color(0xFFBBDEFB); _themeMode = ThemeMode.light; }
      else if (themeName == "Ocean Dark") { _primaryColor = const Color(0xFF1976D2); _secondaryColor = const Color(0xFF64B5F6); _themeMode = ThemeMode.dark; }
      else if (themeName == "Lavender Light") { _primaryColor = const Color(0xFF6A1B9A); _secondaryColor = const Color(0xFFE1BEE7); _themeMode = ThemeMode.light; }
      else if (themeName == "Deep Violet Dark") { _primaryColor = const Color(0xFF7B1FA2); _secondaryColor = const Color(0xFFBA68C8); _themeMode = ThemeMode.dark; }
      else if (themeName == "Neon Cyberpunk") { _primaryColor = Colors.purpleAccent; _secondaryColor = Colors.cyanAccent; _themeMode = ThemeMode.dark; }
      else if (themeName == "Minimalist Monochrome") { _primaryColor = Colors.black87; _secondaryColor = Colors.grey; _themeMode = ThemeMode.light; }
      else { _primaryColor = const Color(0xFF1976D2); _secondaryColor = const Color(0xFF64B5F6); _themeMode = ThemeMode.dark; }
      
      if (_isColorBlindMode) { 
        _primaryColor = const Color(0xFF005AB5); 
        _secondaryColor = const Color(0xFFFF8300); 
      }
    });
  }

  void _changeTheme(String themeName) { 
    _applyTheme(themeName); 
    User? u = FirebaseAuth.instance.currentUser; 
    if (u != null) { 
      FirebaseFirestore.instance.collection('users').doc(u.uid).set({'theme': themeName}, SetOptions(merge: true)); 
    } 
  }
  
  void _updateSchoolTheme(String schoolName) { 
    setState(() { 
      currentSchool = schoolName; 
      _applyTheme(_activeTheme); 
    }); 
  }

  void _checkDailyReleases() async {
    DateTime now = DateTime.now();
    if (now.hour >= 9 && currentSchool.isNotEmpty) {
      String todayStr = "${now.year}-${now.month}-${now.day}";
      try {
        DocumentSnapshot meta = await FirebaseFirestore.instance.collection('schools').doc(currentSchool).get();
        if (meta.exists && meta.data() != null) { 
          var data = meta.data() as Map<String, dynamic>; 
          if (data['last_release_date'] == todayStr) return; 
        }
        _seedDummyStudents();
        await FirebaseFirestore.instance.collection('schools').doc(currentSchool).set({'last_release_date': todayStr}, SetOptions(merge: true));
      } catch(e) {}
    }
  }

  void _autoSyncCalendarFromCloud(String schoolName) async { 
    try { 
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('schools').doc(schoolName).get(); 
      if (doc.exists && doc.data() != null) { 
        var data = doc.data() as Map<String, dynamic>; 
        if (data.containsKey('ical_url')) { 
          _syncICal(data['ical_url'], isBackgroundAutoSync: true); 
        } 
      } 
    } catch (e) {} 
  }

  void _listenToSchoolSchedule(String schoolName) {
    _scheduleSub?.cancel();
    _scheduleSub = FirebaseFirestore.instance.collection('schools').doc(schoolName).collection('schedule').snapshots().listen((snap) {
      if (mounted) {
        setState(() {
          globalSchedule = snap.docs.map((d) {
            var data = d.data();
            return GameEvent(
              id: d.id, 
              sport: data['sport'], 
              opponent: data['opponent'], 
              location: data['location'],
              dateTime: (data['dateTime'] as Timestamp).toDate(),
              endTime: data['endTime'] != null ? (data['endTime'] as Timestamp).toDate() : null,
              level: RosterLevel.values.firstWhere((e) => e.name == data['level'], orElse: () => RosterLevel.varsity),
              ourScore: int.tryParse(data['ourScore']?.toString() ?? ''), 
              oppScore: int.tryParse(data['oppScore']?.toString() ?? '')
            );
          }).toList();
          
          _checkDailyReleases(); 
        });
      }
    });
  }

  // PROPOSAL REQUIREMENT: The system shall calculate and display the season Win-Loss-Tie record when authorized staff update final game scores.
  void _updateGameScore(String gameId, int ourScore, int oppScore) { 
    setState(() { 
      int idx = globalSchedule.indexWhere((g) => g.id == gameId); 
      if (idx != -1) { 
        globalSchedule[idx].ourScore = ourScore; 
        globalSchedule[idx].oppScore = oppScore; 
      } 
    }); 
    FirebaseFirestore.instance.collection('schools').doc(currentSchool).collection('schedule').doc(gameId).update({
      'ourScore': ourScore, 
      'oppScore': oppScore
    }); 
  }

  Future<void> _createProfile(String uid, String first, String last, String idString, String grade, DateTime dob, String sex, String accEmail, String school) async { 
    int id = int.tryParse(idString) ?? DateTime.now().millisecondsSinceEpoch % 10000; 
    final newStudent = Student(id: id, firstName: first, lastName: last, grade: grade, dob: dob, sex: sex, accountEmail: accEmail, school: school); 
    Map<String, dynamic> data = newStudent.toJson(); 
    // PROPOSAL REQUIREMENT: The system shall assign new users the default role of "Student".
    data['roles'] = ['Student']; 
    
    await FirebaseFirestore.instance.collection('users').doc(uid).set(data); 
    _triggerWalkthroughOnLoad = true; 
    _realLogin(uid); 
  }

  Future<void> _createStaffProfile(String uid, String email, String role, String school, String? sport) async { 
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get(); 
    List<String> roles = []; 
    String combinedRole = sport != null ? "$role:$sport" : role; 
    
    if (doc.exists) { 
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>; 
      if (data.containsKey('roles')) roles = List<String>.from(data['roles']); 
      if (!roles.contains(combinedRole)) roles.add(combinedRole); 
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'roles': roles}); 
    } else { 
      roles.add(combinedRole); 
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'roles': roles, 
        'school': school, 
        'email': email, 
        'id': DateTime.now().millisecondsSinceEpoch % 10000
      }); 
    } 
    _triggerWalkthroughOnLoad = true; 
    _realLogin(uid); 
  }

  // PROPOSAL REQUIREMENT: The system shall allow users to sign in with their Google account.
  Future<void> _realLogin(String uid) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<String> extractedRoles = [];
        
        if (data.containsKey('myAssignedRoles')) extractedRoles.addAll(List<String>.from(data['myAssignedRoles']));
        if (data.containsKey('roles')) extractedRoles.addAll(List<String>.from(data['roles']));
        if (data.containsKey('role')) extractedRoles.add(data['role'] ?? '');
        
        extractedRoles = extractedRoles.toSet().toList(); 
        if (extractedRoles.isEmpty) extractedRoles.add('Student');
        
        if (data.containsKey('theme')) { _applyTheme(data['theme']); }
        // PROPOSAL REQUIREMENT: The system shall present an interactive, guided walkthrough tutorial the very first time a user logs into a new role.
        if (data.containsKey('showTutorial')) { _triggerWalkthroughOnLoad = data['showTutorial'] == true; }
        
        currentSchool = data.containsKey('school') ? data['school'] : 'Rancho Alamitos High School';
        if (currentSchool == 'All') currentSchool = 'Rancho Alamitos High School';
        
        _listenToSchoolSchedule(currentSchool); 
        _autoSyncCalendarFromCloud(currentSchool); 
        _setupPushNotifications(uid);
        
        if (extractedRoles.contains('Student') && extractedRoles.length == 1) {
          _studentSub?.cancel();
          _studentSub = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((snap) {
            if (snap.exists && mounted) {
              var snapData = snap.data() as Map<String, dynamic>;
              Student loadedStudent = Student.fromJson(snapData);
              if (snapData['injuryHistory'] != null) {
                loadedStudent.injuryHistory = (snapData['injuryHistory'] as List).map((i) {
                  var report = InjuryReport(
                    studentId: i['studentId'] ?? loadedStudent.id,
                    studentName: i['studentName'] ?? loadedStudent.fullName,
                    date: i['date'] ?? '',
                    description: i['description'] ?? '',
                    isActive: i['isActive'] ?? false,
                    recordedBy: i['recordedBy'] ?? ''
                  );
                  try { report.isRead = i['isRead'] ?? true; } catch(e){}
                  return report;
                }).toList();
              }

              setState(() {
                List<Student> refreshedStudents = List.from(globalStudents);
                refreshedStudents.removeWhere((s) => s.id == loadedStudent.id);
                refreshedStudents.add(loadedStudent);
                
                globalStudents = refreshedStudents; 
                currentStudentId = loadedStudent.id; 
                currentRole = 'Student'; 
                myAssignedRoles = ['Student']; 
                isGodMode = false; 
                isLoggedIn = true; 
                _updateSchoolTheme(loadedStudent.school); 
              });
            }
          });
        } else {
          String primaryRole;
          if (isLoggedIn && currentRole != 'Student' && currentRole.isNotEmpty && extractedRoles.any((r) => r.contains(currentRole))) {
              primaryRole = currentRole;
          } else {
              primaryRole = data['role'] ?? extractedRoles.firstWhere((r) => r != 'Student', orElse: () => 'Athletic Director'); 
          }
          
          String r = primaryRole; 
          String? sp;
          if (primaryRole.contains(':')) { 
            var parts = primaryRole.split(':'); 
            r = parts[0]; 
            sp = parts[1]; 
          }
          
          bool isSuperAdmin = extractedRoles.contains('Super Admin'); 
          if (isSuperAdmin && r == 'Super Admin') r = 'Athletic Director'; 
          
          // PROPOSAL REQUIREMENT: The system shall support a "Many Hats" architecture, allowing one user to hold multiple roles simultaneously.
          myAssignedRoles = extractedRoles; 
          _loginAsStaff(r, sp, currentSchool, isSuperAdmin);
        }
      }
    } catch (e) { 
      print("Login Error: $e"); 
    }
  }

  Future<void> _setupPushNotifications(String uid) async { 
    String vapidKey = "BL8yGKqXH03onxCvRkB7tmUBRG29SOCA_3KLPGfUFcT141zgzSXRahWyPXcHhjoMFN067JbVMM5KKVysT3QxTKA"; 
    if (vapidKey.contains("PASTE_YOUR")) return; 
    
    FirebaseMessaging messaging = FirebaseMessaging.instance; 
    NotificationSettings settings = await messaging.requestPermission(alert: true, badge: true, sound: true); 
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) { 
      try { 
        String? token = await messaging.getToken(vapidKey: vapidKey); 
        if (token != null) { 
          await FirebaseFirestore.instance.collection('users').doc(uid).set({'fcmToken': token}, SetOptions(merge: true)); 
        } 
      } catch (e) { } 
    } 
    
    FirebaseMessaging.onMessage.listen((RemoteMessage message) { 
      if (message.notification != null) { 
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text("${message.notification!.title}: ${message.notification!.body}", style: const TextStyle(fontWeight: FontWeight.bold)), 
            backgroundColor: Colors.blueAccent, 
            duration: const Duration(seconds: 5)
          )
        ); 
      } 
    }); 
  }

  void _loginAsStaff(String role, String? sport, String school, bool god) {
    if (god) _listenToSchoolSchedule('Rancho Alamitos High School'); 
    _staffStudentsSub?.cancel();
    
    _staffStudentsSub = FirebaseFirestore.instance.collection('users').snapshots().listen((snapshot) {
      List<Student> cloudStudents = snapshot.docs.where((d) { 
        var data = d.data() as Map<String, dynamic>; 
        String userSchool = data['school'] ?? ''; 
        if (!god && userSchool != school && userSchool != 'All') return false;
        
        List<String> rls = []; 
        if (data.containsKey('myAssignedRoles')) rls.addAll(List<String>.from(data['myAssignedRoles'])); 
        if (data.containsKey('roles')) rls.addAll(List<String>.from(data['roles'])); 
        if (data.containsKey('role')) rls.add(data['role'] ?? '');
        
        return rls.contains('Student') || rls.isEmpty; 
      }).map((doc) {
         var docData = doc.data() as Map<String, dynamic>; 
         Student st = Student.fromJson(docData);
         if (docData['injuryHistory'] != null) {
           st.injuryHistory = (docData['injuryHistory'] as List).map((i) {
             var report = InjuryReport(
               studentId: i['studentId'] ?? st.id,
               studentName: i['studentName'] ?? st.fullName,
               date: i['date'] ?? '',
               description: i['description'] ?? '',
               isActive: i['isActive'] ?? false,
               recordedBy: i['recordedBy'] ?? ''
             );
             try { report.isRead = i['isRead'] ?? true; } catch(e){}
             return report;
           }).toList();
         }
         return st;
      }).toList();
      
      if (mounted) { 
         setState(() { 
           List<Student> refreshedStudents = List.from(globalStudents);
           if (!god) {
             refreshedStudents.removeWhere((s) => s.school == school); 
           } else {
             refreshedStudents.clear(); 
           }
           
           for (var cs in cloudStudents) { 
             refreshedStudents.removeWhere((ls) => ls.id == cs.id); 
             refreshedStudents.add(cs); 
           } 
           globalStudents = refreshedStudents; 
           
           globalInjuries.clear();
           for(var s in globalStudents) { 
             globalInjuries.addAll(s.injuryHistory); 
           }
         }); 
      }
    });
    
    setState(() { 
      currentRole = role; 
      if (sport != null) currentSportFilter = sport; 
      isGodMode = god; 
      isLoggedIn = true; 
      currentSchool = school; 
      _updateSchoolTheme(school); 
    });
  }
  
  void _loginAsStudent(String idString) { 
    setState(() { 
      currentRole = 'Student'; 
      isGodMode = false; 
      currentStudentId = int.tryParse(idString) ?? 0; 
      isLoggedIn = true; 
      currentSchool = globalStudents.firstWhere((s) => s.id == currentStudentId).school; 
      _listenToSchoolSchedule(currentSchool); 
      _updateSchoolTheme(currentSchool); 
    }); 
  }
  
  void _logout() async { 
    await FirebaseAuth.instance.signOut(); 
    _staffStudentsSub?.cancel(); 
    _scheduleSub?.cancel(); 
    _studentSub?.cancel(); 
    setState(() { 
      isLoggedIn = false; 
      isGodMode = false; 
      myAssignedRoles = []; 
      globalStudents = []; 
      globalSchedule = []; 
      _triggerWalkthroughOnLoad = false; 
    }); 
  }
  
  // PROPOSAL REQUIREMENT: The system shall allow students to upload photos of the front and back of their Medical Physical and Insurance Cards.
  void _uploadPhysicalSim(String idString, bool isFront) { 
    setState(() { 
      try { 
        final s = globalStudents.firstWhere((e) => e.id.toString() == idString); 
        if (isFront) {
          s.physicalFrontPath = 'simulated'; 
        } else {
          s.physicalBackPath = 'simulated'; 
        }
        _syncStudentToCloud(s); 
      } catch (e) {} 
    }); 
  }
  
  // PROPOSAL REQUIREMENT: The system shall provide a digital "Clearance Form" for students to input their medical, emergency, and guardian information.
  void _submitClearanceForm(int id, Map<String, dynamic> data, List<String> sports) async { 
    final s = globalStudents.firstWhere((e) => e.id == id);
    setState(() {
      s.street = data['street'] ?? ''; s.city = data['city'] ?? ''; s.state = data['state'] ?? ''; s.zip = data['zip'] ?? ''; s.homePhone = data['homePhone'] ?? ''; s.mobilePhone = data['mobilePhone'] ?? ''; s.p1First = data['p1First'] ?? ''; s.p1Last = data['p1Last'] ?? ''; s.p1Mobile = data['p1Mobile'] ?? ''; s.p1Email = data['p1Email'] ?? ''; s.p2First = data['p2First'] ?? ''; s.p2Last = data['p2Last'] ?? ''; s.p2Mobile = data['p2Mobile'] ?? ''; s.p2Email = data['p2Email'] ?? ''; s.physicianName = data['physName'] ?? ''; s.physicianPhone = data['physPhone'] ?? ''; s.insuranceCompany = data['insCo'] ?? ''; s.insurancePolicyNum = data['insPol'] ?? ''; s.medicalConditions = data['medCond'] ?? ''; s.hospitalPreference = data['hospPref'] ?? ''; s.hospitalLocation = data['hospLoc'] ?? ''; s.physicalFrontPath = data['frontPath']; s.physicalBackPath = data['backPath']; s.insuranceFrontPath = data['insFrontPath']; s.insuranceBackPath = data['insBackPath']; s.height = data['height'] ?? ''; s.weight = data['weight'] ?? ''; s.livingArrangement = data['living'] ?? ''; s.educationHistory = data['eduHistory'] ?? ''; s.lastSchoolAttended = data['lastSchool'] ?? ''; s.emgFirst = data['emgFirst'] ?? ''; s.emgLast = data['emgLast'] ?? ''; s.emgPhone = data['emgPhone'] ?? ''; s.emgRel = data['emgRel'] ?? ''; s.lastPhysicalDate = data['physDate']; s.clearanceStatus = ClearanceStatus.pending;
      
      for (String sp in sports) { 
        if (!s.memberships.any((m) => m.sport == sp)) { 
          var def = globalSports.firstWhere((d) => d.name == sp, orElse: () => SportDefinition(name: sp, gender: "Co-Ed", coachId: "")); 
          s.memberships = List.from(s.memberships)..add(TeamMembership(sport: sp, gender: def.gender, level: RosterLevel.varsity, isActive: false)); 
        } 
      }
    });
    _syncStudentToCloud(s);
  }

  // PROPOSAL REQUIREMENT: The system shall provide a "Report Absence" feature for students to notify coaches of illness or missed practice.
  void _submitAbsence(int studentId, AbsenceRequest absence) { 
    final s = globalStudents.firstWhere((e) => e.id == studentId); 
    setState(() { 
      s.absences = List.from(s.absences)..add(absence); 
      for (var m in s.memberships.where((m) => m.isActive)) { 
        coachNotifications = List.from(coachNotifications)..add("${m.sport}|ABSENCE: ${s.fullName} on ${absence.date} (Pending Parent Auth)"); 
      } 
    }); 
    _syncStudentToCloud(s); 
  }
  
  // PROPOSAL REQUIREMENT: The system shall provide an "Upload Doctor's Note" feature for injured athletes to submit medical restrictions.
  void _submitDoctorsNote(int studentId, DoctorsNote note) { 
    final s = globalStudents.firstWhere((e) => e.id == studentId); 
    setState(() { 
      s.doctorsNotes = List.from(s.doctorsNotes)..add(note); 
      for (var m in s.memberships.where((m) => m.isActive)) { 
        coachNotifications = List.from(coachNotifications)..add("${m.sport}|DR NOTE: ${s.fullName} out ${note.datesOut}"); 
      } 
      adminNotifications = List.from(adminNotifications)..insert(0, "TRAINER|DR NOTE: ${s.fullName} uploaded a note."); 
    }); 
    _syncStudentToCloud(s); 
  }
  
  // PROPOSAL REQUIREMENT: The system shall allow the AD to explicitly "Approve" or "Deny" a student's clearance, prompting for a written reason upon denial.
  void _processClearance(int id, bool approved, {String? reason}) { 
    final s = globalStudents.firstWhere((e) => e.id == id); 
    setState(() { 
      s.clearanceStatus = approved ? ClearanceStatus.approved : ClearanceStatus.denied; 
      if (!approved) { 
        s.denialReason = reason; 
        s.notifications = List.from(s.notifications)..insert(0, "Clearance DENIED: $reason."); 
        s.unreadAlerts += 1;
      } else {
        s.notifications = List.from(s.notifications)..insert(0, "Clearance APPROVED!");
        s.unreadAlerts += 1;
      }
    }); 
    _syncStudentToCloud(s); 
  }
  
  // PROPOSAL REQUIREMENT: The system shall allow Coaches to categorize rostered athletes into Varsity, JV, and Frosh levels in bulk.
  void _batchAddToRoster(List<int> studentIds, String sport, RosterLevel level) { 
    setState(() { 
      for (var id in studentIds) { 
        final s = globalStudents.firstWhere((e) => e.id == id); 
        s.memberships = List.from(s.memberships)..removeWhere((m) => m.sport == sport); 
        var def = globalSports.firstWhere((sp) => sp.name == sport, orElse: () => SportDefinition(name: sport, gender: "Co-Ed", coachId: "")); 
        s.memberships = List.from(s.memberships)..add(TeamMembership(sport: sport, gender: def.gender, level: level, isActive: true)); 
        _syncStudentToCloud(s); 
      } 
    }); 
  }
  
  void _movePlayerLevel(int studentId, String sport, RosterLevel newLevel) { 
    final s = globalStudents.firstWhere((e) => e.id == studentId); 
    setState(() {
      final idx = s.memberships.indexWhere((m) => m.sport == sport);
      if (idx != -1) {
        final m = s.memberships[idx];
        m.level = newLevel;
        s.memberships = List.from(s.memberships); 
      }
    });
    _syncStudentToCloud(s); 
  }
  
  // PROPOSAL REQUIREMENT: The system shall allow Coaches to accept or deny athletes onto their active roster.
  void _coachApproveRoster(int id, String sport, bool approved) { 
    final s = globalStudents.firstWhere((e) => e.id == id); 
    setState(() { 
      try { 
        final m = s.memberships.firstWhere((m) => m.sport == sport && !m.isActive); 
        if (approved) {
          m.isActive = true; 
          s.memberships = List.from(s.memberships);
        } else { 
          s.memberships = List.from(s.memberships)..remove(m); 
        } 
      } catch (e) {} 
    }); 
    _syncStudentToCloud(s); 
  }
  
  // PROPOSAL REQUIREMENT: The system shall allow Coaches to manually schedule games, setting early release and bus departure times.
  void _addGame(String sport, String opp, String loc, DateTime start, DateTime end, TimeOfDay? rel, TimeOfDay? bus, RosterLevel lvl) {
    String generatedId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() { 
      globalSchedule = List.from(globalSchedule)..add(GameEvent(id: generatedId, sport: sport, opponent: opp, location: loc, dateTime: start, endTime: end, level: lvl)); 
    });
    
    FirebaseFirestore.instance.collection('schools').doc(currentSchool).collection('schedule').doc(generatedId).set({
      'sport': sport, 'opponent': opp, 'location': loc, 'dateTime': Timestamp.fromDate(start), 'endTime': Timestamp.fromDate(end), 'level': lvl.name, 'releaseTime': rel != null ? "${rel.hour}:${rel.minute}" : null, 'busTime': bus != null ? "${bus.hour}:${bus.minute}" : null
    });
    
    if (rel != null) {
      String ampm = rel.hour >= 12 ? 'PM' : 'AM'; 
      int h = rel.hour % 12; 
      if (h == 0) h = 12; 
      String rTime = "$h:${rel.minute.toString().padLeft(2, '0')} $ampm";
      
      setState(() { 
        for (var s in globalStudents) { 
          if (s.memberships.any((m) => m.isActive && m.sport == sport && m.level == lvl)) { 
            s.isReleased = true; 
            s.releaseTime = rTime; 
            s.notifications = List.from(s.notifications)..insert(0, "UPCOMING GAME: You are scheduled for early release at $rTime for the game against $opp."); 
            s.unreadAlerts += 1; 
            _syncStudentToCloud(s); 
          } 
        } 
      });
      rootScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Game added and athletes notified of Early Release!"), backgroundColor: Colors.green));
    } else { 
      rootScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Game scheduled successfully!"), backgroundColor: Colors.green)); 
    }
  }

  // PROPOSAL REQUIREMENT: The system shall allow Trainers to log a new injury for an athlete, automatically changing the athlete's status to "INJURED".
  void _logInjury(int id, String desc) { 
    final s = globalStudents.firstWhere((e) => e.id == id); 
    setState(() { 
      final report = InjuryReport(studentId: id, studentName: s.fullName, date: DateTime.now().toString().split(' ')[0], description: desc, isActive: true, recordedBy: "Trainer"); 
      
      s.injuryHistory = List.from(s.injuryHistory)..add(report); 
      globalInjuries = List.from(globalInjuries)..add(report); 
      
      s.notifications = List.from(s.notifications)..insert(0, "MEDICAL ALERT: You have been placed on the Injured List for: $desc. DO NOT PLAY."); 
      s.unreadAlerts += 1;

      adminNotifications = List.from(adminNotifications)..insert(0, "MEDICAL ALERT: ${s.fullName} was moved to the Injured List ($desc)");
      for (var m in s.memberships) {
        if (m.isActive) {
          coachNotifications = List.from(coachNotifications)..insert(0, "${m.sport}|MEDICAL ALERT: ${s.fullName} moved to Injured List ($desc).");
        }
      }
    }); 
    _syncStudentToCloud(s); 
  }

  // PROPOSAL REQUIREMENT: The system shall allow Trainers to formally "Clear" an injury, returning the athlete to active status.
  void _clearInjury(InjuryReport report) { 
    setState(() { report.isActive = false; }); 
    try { 
      final s = globalStudents.firstWhere((st) => st.id == report.studentId); 
      setState(() {
        s.notifications = List.from(s.notifications)..insert(0, "MEDICAL: You have been cleared to play!"); 
        s.unreadAlerts += 1;

        adminNotifications = List.from(adminNotifications)..insert(0, "MEDICAL CLEARANCE: ${s.fullName} has been cleared from the Injured List.");
        for (var m in s.memberships) {
           if (m.isActive) {
             coachNotifications = List.from(coachNotifications)..insert(0, "${m.sport}|MEDICAL CLEARANCE: ${s.fullName} is cleared to play.");
           }
        }
      });
      _syncStudentToCloud(s); 
    } catch(e) {} 
  }
  
  void _markInjuriesRead() => setState(() { 
    for (var i in globalInjuries) { i.isRead = true; } 
    globalInjuries = List.from(globalInjuries);
  });
  
  // PROPOSAL REQUIREMENT: The system shall allow the AD to manually log private administrative notes on a student's profile.
  void _addStudentNote(int studentId, String note) { 
    final s = globalStudents.firstWhere((e) => e.id == studentId); 
    setState(() => s.staffNotes = List.from(s.staffNotes)..add("${DateTime.now().toString().split(' ')[0]} ($currentRole): $note")); 
    _syncStudentToCloud(s); 
  }
  
  void _createFolder(String name, String? parentId) => setState(() => globalFolders = List.from(globalFolders)..add(InventoryFolder(id: DateTime.now().toString(), name: name, parentId: parentId)));
  void _createInventoryItem(String barcode, String name, String? folderId) => setState(() => globalInventory = List.from(globalInventory)..add(InventoryItem(barcode: barcode, name: name, folderId: folderId)));
  void _deleteItem(String barcode) => setState(() => globalInventory = List.from(globalInventory)..removeWhere((i) => i.barcode == barcode));
  void _deleteFolder(String id) => setState(() => globalFolders = List.from(globalFolders)..removeWhere((f) => f.id == id));
  void _renameItem(String barcode, String newName) => setState(() { final idx = globalInventory.indexWhere((i) => i.barcode == barcode); if(idx != -1) { globalInventory[idx].name = newName; globalInventory = List.from(globalInventory); } });
  void _renameFolder(String id, String newName) => setState(() { final idx = globalFolders.indexWhere((f) => f.id == id); if(idx != -1) { globalFolders[idx].name = newName; globalFolders = List.from(globalFolders); } });
  void _moveItem(String barcode, String? newFolderId) => setState(() { final idx = globalInventory.indexWhere((i) => i.barcode == barcode); if(idx != -1) { globalInventory[idx].folderId = newFolderId; globalInventory = List.from(globalInventory); } });
  void _moveFolder(String id, String? newParentId) => setState(() { final idx = globalFolders.indexWhere((f) => f.id == id); if(idx != -1) { globalFolders[idx].parentId = newParentId; globalFolders = List.from(globalFolders); } });
  
  void _checkoutItem(String studentIdStr, String barcode) => setState(() { 
    final itemIndex = globalInventory.indexWhere((i) => i.barcode == barcode); 
    if (itemIndex == -1) return; 
    final item = globalInventory[itemIndex]; 
    if (item.status == ItemStatus.available) { 
      item.status = ItemStatus.checkedOut; 
      item.assignedToStudentId = studentIdStr; 
      item.dateCheckedOut = DateTime.now(); 
      item.checkoutHistory = List.from(item.checkoutHistory)..add("Checked out to ID $studentIdStr"); 
      globalInventory = List.from(globalInventory);
    } 
  });
  
  void _checkInItem(String barcode) => setState(() { 
    final itemIndex = globalInventory.indexWhere((i) => i.barcode == barcode); 
    if (itemIndex == -1) return; 
    final item = globalInventory[itemIndex]; 
    item.status = ItemStatus.available; 
    coachNotifications = List.from(coachNotifications)..removeWhere((note) => note.contains(item.name) && note.contains("URGENT MED-BAY")); 
    item.assignedToStudentId = null; 
    item.fineAmount = 0.0; 
    item.dateCheckedOut = null; 
    item.checkoutHistory = List.from(item.checkoutHistory)..add("Returned on ${DateTime.now().toString().split(' ')[0]}"); 
    globalInventory = List.from(globalInventory);
  });
  
  void _markMissing(String barcode, double fineAmount) => setState(() { 
    final itemIndex = globalInventory.indexWhere((i) => i.barcode == barcode); 
    if(itemIndex != -1) {
      globalInventory[itemIndex].status = ItemStatus.missing; 
      globalInventory[itemIndex].fineAmount = fineAmount;
      globalInventory = List.from(globalInventory);
    }
  });
  
  void _dismissAdminNote(int index) { setState(() { adminNotifications = List.from(adminNotifications)..removeAt(index); }); }

  // PROPOSAL REQUIREMENT: The system shall feature an "iCal Sync" tool allowing the AD to paste a live calendar link.
  Future<void> _syncICal(String url, {bool isBackgroundAutoSync = false}) async {
    try {
      if (!isBackgroundAutoSync) { 
        try { 
          await FirebaseFirestore.instance.collection('schools').doc(currentSchool).set({'ical_url': url}, SetOptions(merge: true)); 
        } catch(e) {} 
      }
      
      String fetchUrl = url; 
      if (kIsWeb && !url.contains('cors') && !url.contains('allorigins')) fetchUrl = "https://corsproxy.io/?" + Uri.encodeComponent(url);
      
      final response = await http.get(Uri.parse(fetchUrl));
      if (response.statusCode == 200) {
        if (!response.body.toUpperCase().contains("BEGIN:VCALENDAR")) { 
          if (!isBackgroundAutoSync) rootScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Error: The link returned a webpage, not a Calendar file."), backgroundColor: Colors.red)); 
          return; 
        }
        
        List<GameEvent> parsedEvents = []; 
        var lines = LineSplitter.split(response.body).toList();
        
        bool inEvent = false; String currentSport = ""; String currentOpponent = "TBA"; String currentLocation = "TBA"; DateTime? currentStart; RosterLevel currentLevel = RosterLevel.varsity;

        for (String line in lines) {
          if (line.startsWith(" ")) continue; 
          if (line.startsWith("BEGIN:VEVENT")) { 
            inEvent = true; currentSport = ""; currentOpponent = "TBA"; currentLocation = "TBA"; currentStart = null; currentLevel = RosterLevel.varsity;
          } else if (line.startsWith("END:VEVENT")) {
            inEvent = false;
            if (currentStart != null && currentSport.isNotEmpty) {
               // PROPOSAL REQUIREMENT: The system shall generate a deterministic ID for games to prevent the creation of duplicate events during daily syncing.
               String stableId = "${currentSport}_${currentLevel.name}_${currentStart.millisecondsSinceEpoch}".replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
               parsedEvents.add(GameEvent(id: stableId, sport: currentSport, opponent: currentOpponent, location: currentLocation, dateTime: currentStart, level: currentLevel, ourScore: null, oppScore: null));
            } 
          } else if (inEvent) {
            // PROPOSAL REQUIREMENT: The system shall intelligently parse downloaded iCal text, extracting the Sport, Level, Opponent, Location, and Time.
            if (line.startsWith("SUMMARY:") || line.startsWith("DESCRIPTION:")) {
              String text = line.toLowerCase(); 
              bool isGirls = text.contains("girls") || text.contains("womens") || text.contains("women's"); 
              String baseSport = "";
              
              if (text.contains("cross country") || text.contains("xc")) baseSport = "Cross Country"; 
              else if (text.contains("water polo")) baseSport = "Water Polo"; 
              else if (text.contains("swim") || text.contains("dive")) baseSport = "Swimming & Diving"; 
              else if (text.contains("track") || text.contains("t&f")) baseSport = "Track & Field"; 
              else if (text.contains("cheer") || text.contains("song")) baseSport = "Cheer and Song"; 
              else if (text.contains("baseball")) baseSport = "Baseball"; 
              else if (text.contains("softball")) baseSport = "Softball"; 
              else if (text.contains("basketball")) baseSport = "Basketball"; 
              else if (text.contains("football") && text.contains("flag")) baseSport = "Flag Football"; 
              else if (text.contains("football")) baseSport = "Football (11 person)"; 
              else if (text.contains("soccer")) baseSport = "Soccer"; 
              else if (text.contains("tennis")) baseSport = "Tennis"; 
              else if (text.contains("volleyball")) baseSport = "Volleyball"; 
              else if (text.contains("golf")) baseSport = "Golf"; 
              else if (text.contains("wrestling")) baseSport = "Wrestling"; 
              else if (text.contains("lacrosse")) baseSport = "Lacrosse"; 
              else if (text.contains("badminton")) baseSport = "Badminton";
              
              if (baseSport.isNotEmpty) { 
                if (baseSport == "Baseball" || baseSport == "Softball" || baseSport == "Swimming & Diving" || baseSport == "Cheer and Song" || baseSport == "Track & Field" || baseSport == "Cross Country" || baseSport == "Football (11 person)") { currentSport = baseSport; } 
                else if (baseSport == "Flag Football") { currentSport = "Flag Football"; } 
                else { currentSport = "$baseSport ${isGirls ? 'Girls' : 'Boys'}"; } 
              } else { 
                currentSport = "Other"; 
              }
              
              if (text.contains("jv") || text.contains("junior varsity")) currentLevel = RosterLevel.jv; 
              else if (text.contains("frosh") || text.contains("freshman") || text.contains("fs")) currentLevel = RosterLevel.frosh; 
              else currentLevel = RosterLevel.varsity;
              
              if (line.startsWith("SUMMARY:")) {
                  String cleanSummary = line.substring(8).replaceAll(r'\,', ',').replaceAll(r'\', '');
                  if (cleanSummary.toLowerCase().contains(" vs ") || cleanSummary.toLowerCase().contains(" vs. ")) { currentOpponent = cleanSummary.split(RegExp(r'\s+vs\.?\s+', caseSensitive: false)).last.trim(); } 
                  else if (cleanSummary.toLowerCase().contains(" @ ") || cleanSummary.toLowerCase().contains(" at ")) { currentOpponent = cleanSummary.split(RegExp(r'\s+[@|at]\s+', caseSensitive: false)).last.trim(); if (currentLocation == "TBA" || currentLocation.isEmpty) currentLocation = "Away @ $currentOpponent"; } 
                  else { currentOpponent = cleanSummary; }
              }
            } else if (line.startsWith("LOCATION:")) { 
              currentLocation = line.substring(9).replaceAll(r'\,', ',').replaceAll(r'\', '').trim(); 
              if (currentLocation.toLowerCase().contains("11351 dale") || currentLocation.toLowerCase().contains("rancho alamitos")) currentLocation = "Home (Rancho Alamitos HS)";
            } else if (line.startsWith("DTSTART")) {
              try {
                // PROPOSAL REQUIREMENT: The system shall automatically correct UTC server time to local Pacific Time.
                bool isUtc = line.toUpperCase().endsWith("Z"); 
                String dateStr = line.split(":").last.replaceAll("Z", "").replaceAll("T", "").trim();
                if (dateStr.length >= 14) { 
                  int year = int.parse(dateStr.substring(0,4)); int month = int.parse(dateStr.substring(4,6)); int day = int.parse(dateStr.substring(6,8)); int hour = int.parse(dateStr.substring(8,10)); int min = int.parse(dateStr.substring(10,12)); 
                  if (isUtc) currentStart = DateTime.utc(year, month, day, hour, min).toLocal(); 
                  else currentStart = DateTime(year, month, day, hour, min);
                } else if (dateStr.length == 8) { 
                  int year = int.parse(dateStr.substring(0,4)); int month = int.parse(dateStr.substring(4,6)); int day = int.parse(dateStr.substring(6,8)); 
                  currentStart = DateTime(year, month, day, 12, 0); 
                }
              } catch(e) { }
            }
          }
        }
        
        if (parsedEvents.isNotEmpty) {
           setState(() { 
             for (var newEvent in parsedEvents) { 
               int existingIdx = globalSchedule.indexWhere((e) => e.id == newEvent.id); 
               if (existingIdx != -1) globalSchedule[existingIdx] = newEvent; 
               else globalSchedule.add(newEvent); 
             } 
             globalSchedule = List.from(globalSchedule);
           });
           
           try {
             WriteBatch batch = FirebaseFirestore.instance.batch();
             for (var newEvent in parsedEvents) { 
               DocumentReference docRef = FirebaseFirestore.instance.collection('schools').doc(currentSchool).collection('schedule').doc(newEvent.id); 
               batch.set(docRef, { 'sport': newEvent.sport, 'opponent': newEvent.opponent, 'location': newEvent.location, 'dateTime': Timestamp.fromDate(newEvent.dateTime), 'level': newEvent.level.name, 'ourScore': null, 'oppScore': null }, SetOptions(merge: true)); 
             }
             await batch.commit(); 
             if (!isBackgroundAutoSync) rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text("Successfully synced and saved ${parsedEvents.length} events!"), backgroundColor: Colors.green));
           } catch(e) { 
             if (!isBackgroundAutoSync) rootScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Failed to upload schedule to the database."), backgroundColor: Colors.red)); 
           }
        } else { 
          if (!isBackgroundAutoSync) rootScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Parsed 0 valid events. Ensure it is a valid Calendar URL."), backgroundColor: Colors.orange)); 
        }
      } else { 
        if (!isBackgroundAutoSync) rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text("Failed to download schedule. Status Code ${response.statusCode}"), backgroundColor: Colors.red)); 
      }
    } catch (e) { 
      if (!isBackgroundAutoSync) rootScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Network Error. Ensure you are connected to the internet."), backgroundColor: Colors.red)); 
    }
  }

  void _clearNotifications(int studentId) { 
    final s = globalStudents.firstWhere((e) => e.id == studentId); 
    setState(() { 
      s.clearBadge(); 
      s.notifications = List.from(s.notifications)..clear(); 
    }); 
    _syncStudentToCloud(s); 
  }

  @override
  Widget build(BuildContext context) {
    Color iconColor = (_activeTheme.contains("Light") || _activeTheme == "Minimalist Monochrome") ? _primaryColor : Colors.white;
    if (_activeTheme == "High Contrast" || _activeTheme == "Gold Dark") {
      iconColor = Colors.yellowAccent;
    }

    // PROPOSAL REQUIREMENT: The system shall dynamically calculate background luminance to ensure text is always readable against colored buttons.
    Color btnTextColor = _primaryColor.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;
    if (_activeTheme == "High Contrast" || _activeTheme == "Neon Cyberpunk") {
      btnTextColor = Colors.black;
    }

    String? inviteRole;
    String? inviteSchool;
    String? inviteSport;
    String? emergencyCardToken;

    try {
      if (kIsWeb) {
        if (Uri.base.queryParameters.containsKey('invite')) {
          // PROPOSAL REQUIREMENT: The system shall allow administrators to generate secure invite links to upgrade users to AD, Coach, Trainer, or Attendant roles.
          inviteRole = Uri.base.queryParameters['invite'];
          inviteSchool = Uri.base.queryParameters['school'];
          inviteSport = Uri.base.queryParameters['sport'];
        }
        if (Uri.base.queryParameters.containsKey('card')) {
          emergencyCardToken = Uri.base.queryParameters['card'];
        }
      }
    } catch (e) {}

    if (emergencyCardToken != null) {
      return MaterialApp(
        title: 'VarsityVault Secure Access',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(),
        home: PublicEmergencyCardScreen(token: emergencyCardToken)
      );
    }

    final TextTheme boldTextTheme = const TextTheme(
      bodyLarge: TextStyle(fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(fontWeight: FontWeight.w500),
      titleLarge: TextStyle(fontWeight: FontWeight.bold),
      titleMedium: TextStyle(fontWeight: FontWeight.bold),
      labelLarge: TextStyle(fontWeight: FontWeight.bold)
    );

    final ThemeData darkTheme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF121212),
      primaryColor: _primaryColor,
      textTheme: boldTextTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      appBarTheme: AppBarTheme(backgroundColor: const Color(0xFF1E1E1E), foregroundColor: iconColor, elevation: 1),
      cardTheme: const CardThemeData(color: Color(0xFF1E1E1E), elevation: 4, margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8)),
      colorScheme: ColorScheme.dark(primary: _primaryColor, secondary: _secondaryColor, surface: const Color(0xFF1E1E1E)),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(foregroundColor: btnTextColor, backgroundColor: _primaryColor))
    );

    final ThemeData lightTheme = ThemeData.light().copyWith(
      scaffoldBackgroundColor: const Color(0xFFF0F2F5),
      primaryColor: _primaryColor,
      textTheme: boldTextTheme.apply(bodyColor: Colors.black87, displayColor: Colors.black87),
      appBarTheme: AppBarTheme(backgroundColor: Colors.white, foregroundColor: iconColor, elevation: 1),
      cardTheme: const CardThemeData(color: Colors.white, elevation: 4, margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8)),
      colorScheme: ColorScheme.light(primary: _primaryColor, secondary: _secondaryColor),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(foregroundColor: btnTextColor, backgroundColor: _primaryColor))
    );

    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: isLoggedIn
          ? DashboardScreen(
              showTutorial: _triggerWalkthroughOnLoad,
              role: currentRole,
              sportFilter: currentSportFilter,
              currentId: currentStudentId,
              isGodMode: isGodMode,
              currentSchool: currentSchool,
              myAssignedRoles: myAssignedRoles,
              activeTheme: _activeTheme,
              isColorBlindMode: _isColorBlindMode,
              students: globalStudents,
              inventory: globalInventory,
              folders: globalFolders,
              schedule: globalSchedule,
              injuries: globalInjuries,
              availableSports: globalSports,
              adminNotes: adminNotifications,
              coachNotes: coachNotifications,
              onRoleChanged: (val) => setState(() => currentRole = val),
              onSportFilterChanged: (val) => setState(() => currentSportFilter = val),
              onThemeChanged: _changeTheme,
              onColorBlindChanged: (val) => setState(() {
                _isColorBlindMode = val;
                _changeTheme(_activeTheme);
              }),
              onSubmitClearance: _submitClearanceForm,
              onSubmitAbsence: _submitAbsence,
              onSubmitDoctorsNote: _submitDoctorsNote,
              onProcessClearance: _processClearance,
              onUploadPhysical: _uploadPhysicalSim,
              onAddGame: _addGame,
              onUpdateScore: _updateGameScore,
              onAddInjury: _logInjury,
              onMarkInjuriesRead: _markInjuriesRead,
              onClearInjury: _clearInjury,
              onCreateItem: _createInventoryItem,
              onCreateFolder: _createFolder,
              onDeleteItem: _deleteItem,
              onDeleteFolder: _deleteFolder,
              onRenameItem: _renameItem,
              onRenameFolder: _renameFolder,
              onMoveItem: _moveItem,
              onMoveFolder: _moveFolder,
              onCheckoutItem: _checkoutItem,
              onCheckInItem: _checkInItem,
              onMarkMissing: _markMissing,
              onAddStudentNote: _addStudentNote,
              onCoachRosterAction: _coachApproveRoster,
              onBatchAdd: _batchAddToRoster,
              onMovePlayer: _movePlayerLevel,
              onSimulateCronJob: _seedDummyStudents,
              onClearNotifications: _clearNotifications,
              onLoginAsStudent: _loginAsStudent,
              onLogout: _logout,
              onSyncICal: _syncICal,
              onDismissAdminNote: _dismissAdminNote,
            )
          : LoginScreen(
              inviteLinkRole: inviteRole,
              inviteLinkSchool: inviteSchool,
              inviteLinkSport: inviteSport,
              onCreateProfile: _createProfile,
              onCreateStaffProfile: _createStaffProfile,
              onRealLogin: _realLogin,
              onStaffLogin: _loginAsStaff,
              onDemoStudentLogin: _loginAsStudent,
              globalSports: globalSports,
              onSchoolSelected: _updateSchoolTheme,
              onThemeChanged: _changeTheme,
              activeTheme: _activeTheme,
            ),
    );
  }
}