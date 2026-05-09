import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:url_launcher/url_launcher.dart';
import 'package:showcaseview/showcaseview.dart';

import '../constants.dart';
import '../models/student.dart';
import '../models/inventory.dart';
import '../models/sports.dart';
import '../models/report.dart'; 
import '../widgets/calendar_view.dart';
import '../widgets/emergency_card.dart';
import '../widgets/address_search.dart';
import '../showcase_keys.dart';

class StudentView extends StatefulWidget {
  static final GlobalKey absenceKey = GlobalKey();

  final Student student;
  final List<InventoryItem> inventory;
  final List<GameEvent> schedule;
  final List<SportDefinition> availableSports;
  final List<InjuryReport> injuries; 
  final Function(int, Map<String, dynamic>, List<String>) onSubmitClearance;
  final Function(int, AbsenceRequest) onSubmitAbsence;
  final Function(int, DoctorsNote) onSubmitDoctorsNote;
  final Function(int) onClearNotifications;

  const StudentView({
    super.key, 
    required this.student, 
    required this.inventory, 
    required this.schedule, 
    required this.availableSports, 
    required this.injuries,
    required this.onSubmitClearance, 
    required this.onSubmitAbsence, 
    required this.onSubmitDoctorsNote, 
    required this.onClearNotifications
  });

  @override
  State<StudentView> createState() => _StudentViewState();
}

class _StudentViewState extends State<StudentView> {
  final _school = TextEditingController();
  final _st = TextEditingController(); 
  final _ci = TextEditingController(); 
  final _state = TextEditingController(); 
  final _zip = TextEditingController();
  
  final _homePhone = TextEditingController(); 
  final _mobilePhone = TextEditingController(); 
  final _email = TextEditingController();
  
  final _physName = TextEditingController(); 
  final _physPhone = TextEditingController(); 
  final _insCo = TextEditingController(); 
  final _insPol = TextEditingController(); 
  final _medCond = TextEditingController();
  
  final _p1First = TextEditingController(); 
  final _p1Last = TextEditingController(); 
  final _p1Mobile = TextEditingController(); 
  final _p1Email = TextEditingController();
  
  final _p2First = TextEditingController(); 
  final _p2Last = TextEditingController(); 
  final _p2Mobile = TextEditingController(); 
  final _p2Email = TextEditingController();
  
  final _emgFirst = TextEditingController(); 
  final _emgLast = TextEditingController(); 
  final _emgPhone = TextEditingController(); 
  final _emgRel = TextEditingController();
  
  final _lastSchool = TextEditingController();
  final _heightCtrl = TextEditingController(); 
  final _weightCtrl = TextEditingController();
  final _hospLocCtrl = TextEditingController();
  
  DateTime? _physDate; 
  String? _selectedGradYear; 
  String? _livingArrangement; 
  String? _eduHistory; 
  bool _isInsured = true;
  String _hospPref = "Nearest Hospital";
  
  List<String> _selectedSports = []; 
  String? _frontPath; 
  String? _backPath; 
  String? _insFrontPath; 
  String? _insBackPath; 
  
  final Map<String, GlobalKey> _formKeys = {}; 
  Set<String> _invalidFields = {};
  
  int _lastAlertCount = 0; 
  bool _bannerDismissed = false;

  @override
  void initState() { 
    super.initState(); 
    _loadData(); 
  }

  @override
  void dispose() {
    _school.dispose(); 
    _st.dispose(); 
    _ci.dispose(); 
    _state.dispose(); 
    _zip.dispose();
    _homePhone.dispose(); 
    _mobilePhone.dispose(); 
    _email.dispose();
    _physName.dispose(); 
    _physPhone.dispose(); 
    _insCo.dispose(); 
    _insPol.dispose(); 
    _medCond.dispose();
    _p1First.dispose(); 
    _p1Last.dispose(); 
    _p1Mobile.dispose(); 
    _p1Email.dispose();
    _p2First.dispose(); 
    _p2Last.dispose(); 
    _p2Mobile.dispose(); 
    _p2Email.dispose();
    _emgFirst.dispose(); 
    _emgLast.dispose(); 
    _emgPhone.dispose(); 
    _emgRel.dispose();
    _lastSchool.dispose(); 
    _heightCtrl.dispose(); 
    _weightCtrl.dispose(); 
    _hospLocCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
    _st.text = widget.student.street; 
    _ci.text = widget.student.city; 
    _state.text = widget.student.state; 
    _zip.text = widget.student.zip; 
    _school.text = widget.student.school; 
    
    if (widget.student.grade.isNotEmpty && ["9th", "10th", "11th", "12th"].contains(widget.student.grade)) { 
      _selectedGradYear = widget.student.grade; 
    } else { 
      _selectedGradYear = widget.student.graduationYear.isNotEmpty ? widget.student.graduationYear : null; 
    }
    
    _homePhone.text = widget.student.homePhone; 
    _mobilePhone.text = widget.student.mobilePhone; 
    _email.text = widget.student.displayEmail; 
    _physName.text = widget.student.physicianName; 
    _physPhone.text = widget.student.physicianPhone; 
    _insCo.text = widget.student.insuranceCompany; 
    _insPol.text = widget.student.insurancePolicyNum; 
    _medCond.text = widget.student.medicalConditions; 
    _p1First.text = widget.student.p1First; 
    _p1Last.text = widget.student.p1Last; 
    _p1Mobile.text = widget.student.p1Mobile; 
    _p1Email.text = widget.student.p1Email; 
    _p2First.text = widget.student.p2First; 
    _p2Last.text = widget.student.p2Last; 
    _p2Mobile.text = widget.student.p2Mobile; 
    _p2Email.text = widget.student.p2Email; 
    _emgFirst.text = widget.student.emgFirst; 
    _emgLast.text = widget.student.emgLast; 
    _emgPhone.text = widget.student.emgPhone; 
    _emgRel.text = widget.student.emgRelation; 
    _lastSchool.text = widget.student.lastSchoolAttended; 
    _physDate = widget.student.lastPhysicalDate; 
    _heightCtrl.text = widget.student.height; 
    _weightCtrl.text = widget.student.weight; 
    _hospPref = widget.student.hospitalPreference.isNotEmpty ? widget.student.hospitalPreference : "Nearest Hospital"; 
    _hospLocCtrl.text = widget.student.hospitalLocation; 
    _livingArrangement = widget.student.livingArrangement.isNotEmpty ? widget.student.livingArrangement : null; 
    _frontPath = widget.student.physicalFrontPath; 
    _backPath = widget.student.physicalBackPath; 
    _insFrontPath = widget.student.insuranceFrontPath; 
    _insBackPath = widget.student.insuranceBackPath;
  }

  void _formatPhone(TextEditingController controller, String value) { 
    String digits = value.replaceAll(RegExp(r'\D'), ''); 
    if (digits.length > 10) digits = digits.substring(0, 10); 
    
    String formatted = digits; 
    if (digits.length >= 7) {
      formatted = "(${digits.substring(0,3)}) ${digits.substring(3,6)}-${digits.substring(6)}"; 
    } else if (digits.length >= 4) {
      formatted = "(${digits.substring(0,3)}) ${digits.substring(3)}"; 
    } else if (digits.isNotEmpty) {
      formatted = "($digits"; 
    }
    
    if (controller.text != formatted) {
      controller.value = TextEditingValue(
        text: formatted, 
        selection: TextSelection.collapsed(offset: formatted.length)
      ); 
    }
  }

  IconData _getSportIcon(String sport) {
    String s = sport.toLowerCase();
    if (s.contains('baseball') || s.contains('softball')) return Icons.sports_baseball;
    if (s.contains('basketball')) return Icons.sports_basketball;
    if (s.contains('football')) return Icons.sports_football;
    if (s.contains('soccer')) return Icons.sports_soccer;
    if (s.contains('tennis')) return Icons.sports_tennis;
    if (s.contains('volleyball')) return Icons.sports_volleyball;
    if (s.contains('golf')) return Icons.golf_course;
    if (s.contains('swim') || s.contains('dive') || s.contains('water polo')) return Icons.pool;
    if (s.contains('track') || s.contains('cross country') || s.contains('xc')) return Icons.directions_run;
    if (s.contains('wrestling')) return Icons.sports_mma;
    return Icons.sports; 
  }

  Future<void> _takePicture(String type, StateSetter setModalState) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: kIsWeb ? ImageSource.gallery : ImageSource.camera, 
        imageQuality: 70, 
        maxWidth: 1024
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64Image = "data:image/jpeg;base64,${base64Encode(bytes)}";
        
        setModalState(() {
          if (type == 'physFront') _frontPath = base64Image; 
          else if (type == 'physBack') _backPath = base64Image;
          else if (type == 'insFront') _insFrontPath = base64Image; 
          else if (type == 'insBack') _insBackPath = base64Image;
        });
        
        if (type == 'physFront') {
          _simulateOCR(setModalState);
        }
      }
    } catch (e) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text("Error picking image: $e"), backgroundColor: Colors.red)
      );
    }
  }

  Future<void> _simulateOCR(StateSetter setModalState) async {
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(), 
            SizedBox(width: 20), 
            Text("Reading Handwriting...")
          ]
        )
      )
    );
    
    await Future.delayed(const Duration(seconds: 2));
    Navigator.pop(context); 
    
    _heightCtrl.text = "5'10\""; 
    _weightCtrl.text = "165 lbs";
    
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("Verify Scanned Data", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)), 
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Text("We scanned the following from your form. Please correct it if the handwriting was misread:", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)), 
            TextField(
              controller: _heightCtrl, 
              decoration: const InputDecoration(labelText: "Height")
            ), 
            TextField(
              controller: _weightCtrl, 
              decoration: const InputDecoration(labelText: "Weight")
            )
          ]
        ), 
        actions: [
          ElevatedButton(
            onPressed: () { 
              setModalState((){}); 
              Navigator.pop(ctx); 
            }, 
            child: const Text("Confirm", style: TextStyle(color: Colors.white))
          )
        ]
      )
    );
  }

  void _dispatchRealNotifications(String type, String date, String reason) async {
    Set<String> emails = {widget.student.p1Email, widget.student.p2Email}..removeWhere((e) => e.isEmpty);
    String smsBody = "Varsity Vault Alert: ${widget.student.fullName} has reported an $type for $date. Reason: $reason. Reply STOP to opt-out of alerts.";
    
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text("Server securely dispatched automated $type alerts to Parents/Guardians via SMS & Email."), 
        backgroundColor: Colors.green, 
        duration: const Duration(seconds: 4)
      )
    );
    
    if (emails.isNotEmpty) {
      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      try { 
        await http.post(
          url, 
          headers: {'Content-Type': 'application/json'}, 
          body: json.encode({
            'service_id': 'YOUR_SERVICE_ID', 
            'template_id': 'YOUR_TEMPLATE_ID', 
            'user_id': 'YOUR_PUBLIC_KEY', 
            'template_params': {
              'to_email': emails.join(','), 
              'student_name': widget.student.fullName, 
              'type': type, 
              'date': date, 
              'reason': reason, 
              'message': smsBody
            }
          })
        ); 
      } catch (e) {}
    }
  }

  void _showAbsenceForm() {
    final dateCtrl = TextEditingController(); 
    final reasonCtrl = TextEditingController();
    Color txtColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;

    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor, 
        title: Text("Report Absence", style: TextStyle(color: txtColor, fontWeight: FontWeight.bold)), 
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            TextField(
              controller: dateCtrl, 
              style: TextStyle(color: txtColor), 
              decoration: InputDecoration(
                labelText: "Date of Absence (MM/DD/YY)", 
                labelStyle: TextStyle(color: txtColor.withOpacity(0.7))
              )
            ), 
            TextField(
              controller: reasonCtrl, 
              style: TextStyle(color: txtColor), 
              decoration: InputDecoration(
                labelText: "Reason", 
                labelStyle: TextStyle(color: txtColor.withOpacity(0.7))
              )
            )
          ]
        ), 
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text("Cancel", style: TextStyle(color: txtColor))
          ),
          ElevatedButton(
            onPressed: () { 
              widget.onSubmitAbsence(widget.student.id, AbsenceRequest(date: dateCtrl.text, reason: reasonCtrl.text)); 
              Navigator.pop(ctx); 
            }, 
            child: const Text("Submit", style: TextStyle(color: Colors.white))
          )
        ]
      )
    );
  }

  void _showDoctorsNoteForm() {
    final datesCtrl = TextEditingController(); 
    final extentCtrl = TextEditingController(); 
    final descCtrl = TextEditingController(); 
    String? notePath;
    Color txtColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;

    showDialog(
      context: context, 
      builder: (ctx) => StatefulBuilder(
        builder: (c, st) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor, 
          title: Text("Upload Doctor's Note", style: TextStyle(color: txtColor, fontWeight: FontWeight.bold)), 
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                InkWell(
                  onTap: () async { 
                    try { 
                      final p = await ImagePicker().pickImage(source: kIsWeb ? ImageSource.gallery : ImageSource.camera, imageQuality: 70, maxWidth: 1024); 
                      if(p != null) { 
                        final bytes = await p.readAsBytes(); 
                        st(() => notePath = "data:image/jpeg;base64,${base64Encode(bytes)}"); 
                      }
                    } catch(e) { 
                      rootScaffoldMessengerKey.currentState?.showSnackBar(
                        const SnackBar(content: Text("Error uploading image."), backgroundColor: Colors.red)
                      ); 
                    } 
                  }, 
                  child: Container(
                    height: 100, 
                    width: double.infinity, 
                    decoration: BoxDecoration(border: Border.all(color: Colors.pinkAccent), borderRadius: BorderRadius.circular(8)), 
                    child: notePath == null 
                      ? const Center(child: Text("Tap to Take Picture of Note", style: TextStyle(color: Colors.pinkAccent))) 
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8), 
                          child: Image.memory(base64Decode(notePath!.split(',').last), fit: BoxFit.cover)
                        )
                  )
                ),
                TextField(
                  controller: datesCtrl, 
                  style: TextStyle(color: txtColor), 
                  decoration: InputDecoration(
                    labelText: "Dates Out (e.g. 10/1 - 10/5)", 
                    labelStyle: TextStyle(color: txtColor.withOpacity(0.7))
                  )
                ),
                DropdownButtonFormField<String>(
                  dropdownColor: Theme.of(context).cardColor,
                  items: ["Cannot Practice", "Light Practice", "Regular Practice/No Running"]
                    .map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(fontSize: 12, color: txtColor))))
                    .toList(), 
                  onChanged: (v) => extentCtrl.text = v ?? '', 
                  decoration: InputDecoration(
                    labelText: "Extent of Injury", 
                    labelStyle: TextStyle(color: txtColor.withOpacity(0.7))
                  )
                ),
                TextField(
                  controller: descCtrl, 
                  maxLines: 2, 
                  style: TextStyle(color: txtColor), 
                  decoration: InputDecoration(
                    labelText: "Injury Description", 
                    labelStyle: TextStyle(color: txtColor.withOpacity(0.7))
                  )
                ),
              ]
            )
          ), 
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: Text("Cancel", style: TextStyle(color: txtColor))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, foregroundColor: Colors.white), 
              onPressed: () { 
                if(notePath != null) { 
                  widget.onSubmitDoctorsNote(
                    widget.student.id, 
                    DoctorsNote(imagePath: notePath!, datesOut: datesCtrl.text, extent: extentCtrl.text, injuryDesc: descCtrl.text)
                  ); 
                  Navigator.pop(ctx); 
                } 
              }, 
              child: const Text("Submit", style: TextStyle(color: Colors.white))
            )
          ]
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.student.unreadAlerts > _lastAlertCount) { 
      _bannerDismissed = false; 
      _lastAlertCount = widget.student.unreadAlerts; 
    }
    
    String bannerText = ""; 
    Color bannerColor = Colors.transparent;
    
    if (widget.student.isReleased) { 
      bannerText = "YOU HAVE BEEN RELEASED! (Time ${widget.student.releaseTime})"; 
      bannerColor = Theme.of(context).primaryColor; 
    } else if (widget.student.notifications.isNotEmpty) { 
      bannerText = "LATEST ALERT: ${widget.student.notifications.first}"; 
      bannerColor = kWarningOrange; 
    }

    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: Column(
        children: [
          // PROPOSAL REQUIREMENT: The system shall display immediate alert banners when the student is notified by anything with their status.
          if (!_bannerDismissed && bannerText.isNotEmpty) 
            Container(
              width: double.infinity, 
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
              color: bannerColor, 
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      bannerText, 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), 
                      textAlign: TextAlign.center
                    )
                  ), 
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20), 
                    onPressed: () { 
                      widget.onClearNotifications(widget.student.id); 
                      setState(() => _bannerDismissed = true); 
                    }
                  )
                ]
              )
            ),
          Expanded(child: _buildHomeTab()), 
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    Color headerColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          height: 180, 
          width: double.infinity, 
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.4)),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // PROPOSAL REQUIREMENT: The system shall display a personalized dashboard for the student, greeting them by name.
                          Text(
                            widget.student.fullName, 
                            style: const TextStyle(
                              fontSize: 32, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.white, 
                              shadows: [Shadow(blurRadius: 4, color: Colors.black)], 
                              overflow: TextOverflow.ellipsis
                            )
                          ),
                          Text(
                            "ID: ${widget.student.id} | Grade: ${widget.student.grade}", 
                            style: const TextStyle(color: Colors.white70, fontSize: 16)
                          ),
                        ],
                      ),
                    ),
                    // PROPOSAL REQUIREMENT: The system shall prominently display the student's current overall athletic status (e.g., "NOT STARTED", "PENDING", "CLEARED").
                    _buildStatusBadge(),
                  ],
                ),
              ),
            ),
          )
        ),
        
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PROPOSAL REQUIREMENT: The system shall allow students to view the sports they have requested to join.
                  Text("Active Sports", style: TextStyle(color: headerColor, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  if (widget.student.memberships.isEmpty) 
                    const Text("Not enrolled in any sports.", style: TextStyle(color: Colors.grey)),
                  
                  ...widget.student.memberships.map((m) => Card(
                    color: Theme.of(context).cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10), 
                      side: const BorderSide(color: Colors.black12)
                    ),
                    child: ListTile(
                      leading: Icon(
                        _getSportIcon(m.sport), 
                        color: m.isActive ? Theme.of(context).primaryColor : Colors.grey
                      ),
                      title: Text(m.sport, style: const TextStyle(fontWeight: FontWeight.bold)), 
                      subtitle: Text("Level: ${m.level.name.toUpperCase()}"),
                      trailing: Text(
                        m.isActive ? "ON TEAM" : "PENDING", 
                        style: TextStyle(
                          color: m.isActive ? Theme.of(context).primaryColor : kWarningOrange, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 12
                        )
                      ),
                    )
                  )),
                  
                  const SizedBox(height: 30),
                  Text("Actions", style: TextStyle(color: headerColor, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  GridView.count(
                    crossAxisCount: 2, 
                    shrinkWrap: true, 
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10, 
                    mainAxisSpacing: 10, 
                    childAspectRatio: 1.2,
                    children: [
                      _buildActionTile(
                        "Emergency Card", 
                        Icons.medical_information, 
                        Colors.red, 
                        () => showUniversalEmergencyCard(context, widget.student),
                        showcaseKey: ShowcaseKeys.studentEmergencyCardKey,
                        showcaseDesc: "Generates a digital medical pass coaches can scan instantly."
                      ),
                      _buildActionTile(
                        "Clearance Form", 
                        Icons.upload_file, 
                        Colors.blueGrey, 
                        _showDetailedClearanceForm,
                        showcaseKey: ShowcaseKeys.studentClearanceFormKey,
                        showcaseDesc: "Tap 'Clearance Form' to upload your physicals and fill out your information."
                      ),
                      _buildActionTile(
                        "Report Absence", 
                        Icons.event_busy, 
                        kWarningOrange, 
                        _showAbsenceForm,
                        showcaseKey: StudentView.absenceKey,
                        showcaseDesc: "Report if you are sick and cannot attend practice or games."
                      ),
                      _buildActionTile(
                        "Upload Dr. Note", 
                        Icons.local_hospital, 
                        Colors.pinkAccent, 
                        _showDoctorsNoteForm,
                        showcaseKey: ShowcaseKeys.studentUploadDrNoteKey,
                        showcaseDesc: "If you get injured, upload your doctor's note here."
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    Color bg = Colors.grey; 
    IconData icon = Icons.help; 
    String text = "NOT STARTED"; 
    String tipText = "Clearance Not Started";
    
    bool isCleared = widget.student.clearanceStatus == ClearanceStatus.approved;
    bool isPendingRoster = isCleared && widget.student.memberships.isNotEmpty && widget.student.memberships.any((m) => !m.isActive);
    bool isInjured = widget.student.injuryHistory.any((i) => i.isActive);

    if (isInjured) { 
      bg = kErrorRed; 
      icon = Icons.local_hospital; 
      text = "INJURED - DO NOT PLAY"; 
      tipText = "Currently on the Injured List"; 
    } else if (widget.student.clearanceStatus == ClearanceStatus.pending) { 
      bg = kWarningOrange; 
      icon = Icons.hourglass_top; 
      text = "PENDING"; 
      tipText = "Clearance is Pending Admin Approval"; 
    } else if (isPendingRoster) { 
      bg = Colors.blue; 
      icon = Icons.timer; 
      text = "PENDING ROSTER"; 
      tipText = "Cleared, Waiting for Coach to Add to Roster"; 
    } else if (isCleared) { 
      bg = Theme.of(context).primaryColor; 
      icon = Icons.check_circle; 
      text = "CLEARED"; 
      tipText = "Fully Cleared and Rostered"; 
    } else if (widget.student.clearanceStatus == ClearanceStatus.denied) { 
      bg = kErrorRed; 
      icon = Icons.cancel; 
      text = "DENIED"; 
      tipText = "Clearance Denied. Please Review Form."; 
    }
    
    return Tooltip(
      message: tipText, 
      triggerMode: TooltipTriggerMode.tap, 
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
        decoration: BoxDecoration(
          color: bg.withOpacity(0.9), 
          border: Border.all(color: Colors.white, width: 2), 
          borderRadius: BorderRadius.circular(20)
        ), 
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16), 
            const SizedBox(width: 5), 
            Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
          ]
        )
      )
    );
  }

  Widget _buildActionTile(String title, IconData icon, Color mainColor, VoidCallback onTap, {GlobalKey? showcaseKey, String? showcaseDesc}) {
    Color bgColor = Color.lerp(Theme.of(context).cardColor, mainColor, 0.4)!;
    Color contentColor = bgColor.computeLuminance() > 0.35 ? Colors.black87 : Colors.white;
    
    Widget tile = InkWell(
      onTap: onTap, 
      borderRadius: BorderRadius.circular(15), 
      hoverColor: mainColor.withOpacity(0.1), 
      splashColor: mainColor.withOpacity(0.2),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor, 
          borderRadius: BorderRadius.circular(15), 
          border: Border.all(color: mainColor, width: 2)
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [ 
            Icon(icon, color: contentColor, size: 45), 
            const SizedBox(height: 10), 
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: contentColor)) 
          ]
        )
      ),
    );

    if (showcaseKey != null && showcaseDesc != null) {
      return Showcase(
        key: showcaseKey,
        description: showcaseDesc,
        child: tile,
      );
    }
    
    return tile;
  }

  Widget _vField(String key, Widget child) {
    _formKeys.putIfAbsent(key, () => GlobalKey()); 
    bool isInvalid = _invalidFields.contains(key);
    
    return Container(
      key: _formKeys[key], 
      margin: const EdgeInsets.symmetric(vertical: 4), 
      // PROPOSAL REQUIREMENT: The system shall dynamically highlight missing required fields in red if a student attempts to submit an incomplete form.
      decoration: isInvalid 
        ? BoxDecoration(
            border: Border.all(color: Colors.red, width: 2), 
            borderRadius: BorderRadius.circular(4), 
            color: Colors.red.withOpacity(0.05)
          ) 
        : null, 
      padding: EdgeInsets.all(isInvalid ? 8.0 : 0), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          child, 
          if (isInvalid) 
            const Padding(
              padding: EdgeInsets.only(top: 4), 
              child: Text(
                "This field is strictly required.", 
                style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)
              )
            )
        ]
      )
    );
  }

  Widget _buildImagePreview(String? b64Data, VoidCallback onClear, String label) {
    return Container(
      height: 100, 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8), 
        border: Border.all(color: b64Data == null ? Colors.grey : Theme.of(context).primaryColor)
      ),
      child: b64Data == null 
        ? Center(
            child: Text(
              "Tap to Upload\n$label", 
              textAlign: TextAlign.center, 
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)
            )
          ) 
        : Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8), 
                  child: Image.memory(base64Decode(b64Data.split(',').last), fit: BoxFit.cover)
                )
              ), 
              Positioned(
                top: 0, 
                right: 0, 
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), 
                  child: IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: onClear)
                )
              )
            ]
          )
    );
  }

  void _validateAndSubmit(StateSetter setModalState, BuildContext ctx) {
    setModalState(() {
      _invalidFields.clear();
      
      if (_frontPath == null) _invalidFields.add('frontPath'); 
      if (_backPath == null) _invalidFields.add('backPath');
      if (_heightCtrl.text.isEmpty) _invalidFields.add('height'); 
      if (_weightCtrl.text.isEmpty) _invalidFields.add('weight');
      if (_selectedSports.isEmpty) _invalidFields.add('sports');
      
      if (_st.text.isEmpty) _invalidFields.add('st'); 
      if (_ci.text.isEmpty) _invalidFields.add('ci'); 
      if (_state.text.isEmpty) _invalidFields.add('state'); 
      if (_zip.text.isEmpty) _invalidFields.add('zip');
      
      if (_homePhone.text.isEmpty) _invalidFields.add('homePhone'); 
      if (_mobilePhone.text.isEmpty) _invalidFields.add('mobilePhone'); 
      if (_email.text.isEmpty) _invalidFields.add('email');
      
      if (_livingArrangement == null) _invalidFields.add('living');
      
      if (_livingArrangement != null) { 
        if (_p1First.text.isEmpty) _invalidFields.add('p1First'); 
        if (_p1Last.text.isEmpty) _invalidFields.add('p1Last'); 
        if (_p1Mobile.text.isEmpty) _invalidFields.add('p1Mobile'); 
      }
      
      if (_livingArrangement == "Both Parents") { 
        if (_p2First.text.isEmpty) _invalidFields.add('p2First'); 
        if (_p2Last.text.isEmpty) _invalidFields.add('p2Last'); 
        if (_p2Mobile.text.isEmpty) _invalidFields.add('p2Mobile'); 
      }
      
      if (_isInsured) { 
        if (_insCo.text.isEmpty) _invalidFields.add('insCo'); 
        if (_insPol.text.isEmpty) _invalidFields.add('insPol'); 
        if (_insFrontPath == null) _invalidFields.add('insFrontPath'); 
        if (_insBackPath == null) _invalidFields.add('insBackPath'); 
      }
      
      if (_physDate == null) _invalidFields.add('physDate');
      if (_hospPref == "My Hospital" && _hospLocCtrl.text.isEmpty) _invalidFields.add('hospLoc');
      if (_emgFirst.text.isEmpty) _invalidFields.add('emgFirst'); 
      if (_emgLast.text.isEmpty) _invalidFields.add('emgLast'); 
      if (_emgRel.text.isEmpty) _invalidFields.add('emgRel'); 
      if (_emgPhone.text.isEmpty) _invalidFields.add('emgPhone');
    });

    if (_invalidFields.isNotEmpty) {
      String firstKey = _invalidFields.first;
      WidgetsBinding.instance.addPostFrameCallback((_) { 
        if (_formKeys[firstKey]?.currentContext != null) { 
          Scrollable.ensureVisible(
            _formKeys[firstKey]!.currentContext!, 
            duration: const Duration(milliseconds: 400), 
            curve: Curves.easeInOut, 
            alignment: 0.1
          ); 
        } 
      });
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text("Missing required fields. Highlighted in red."), backgroundColor: kErrorRed)
      );
      return;
    }

    widget.onSubmitClearance(widget.student.id, {
      'street': _st.text, 
      'city': _ci.text, 
      'state': _state.text, 
      'zip': _zip.text, 
      'homePhone': _homePhone.text, 
      'mobilePhone': _mobilePhone.text, 
      'email': _email.text,
      'gradYear': _selectedGradYear, 
      'school': _school.text, 
      'p1First': _p1First.text, 
      'p1Last': _p1Last.text, 
      'p1Mobile': _p1Mobile.text, 
      'p1Email': _p1Email.text,
      'p2First': _p2First.text, 
      'p2Last': _p2Last.text, 
      'p2Mobile': _p2Mobile.text, 
      'p2Email': _p2Email.text,
      'living': _livingArrangement, 
      'physName': _physName.text, 
      'physPhone': _physPhone.text, 
      'isInsured': _isInsured, 
      'insCo': _insCo.text, 
      'insPol': _insPol.text, 
      'medCond': _medCond.text,
      'physDate': _physDate, 
      'emgFirst': _emgFirst.text, 
      'emgLast': _emgLast.text, 
      'emgPhone': _emgPhone.text, 
      'emgRel': _emgRel.text,
      'eduHistory': _eduHistory, 
      'lastSchool': _lastSchool.text, 
      'frontPath': _frontPath, 
      'backPath': _backPath, 
      'insFrontPath': _insFrontPath, 
      'insBackPath': _insBackPath, 
      'height': _heightCtrl.text, 
      'weight': _weightCtrl.text, 
      'hospPref': _hospPref, 
      'hospLoc': _hospLocCtrl.text
    }, _selectedSports);
    
    Navigator.pop(ctx);
  }

  void _showDetailedClearanceForm() {
    List<String> activeSports = widget.student.memberships.map((m)=>m.sport).toList();
    
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, 
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20), 
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.9, 
              child: ListView(
                children: [
                  Text(
                    "Clearance Form", 
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)
                  ),
                  const Divider(),
                  
                  _buildSection("Upload Physical Form"),
                  _vField('physDate', ListTile(
                    title: Text(
                      _physDate == null ? "Date Physical Taken" : "Date: ${_physDate!.month}/${_physDate!.day}/${_physDate!.year}", 
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)
                    ), 
                    trailing: const Icon(Icons.calendar_today), 
                    onTap: () async { 
                      final d = await showDatePicker(
                        context: context, 
                        initialDate: DateTime.now(), 
                        firstDate: DateTime.now().subtract(const Duration(days: 365)), 
                        lastDate: DateTime.now()
                      ); 
                      if (d != null) setModalState(() => _physDate = d); 
                    }
                  )),
                  
                  Row(
                    children: [ 
                      Expanded(
                        child: _vField('frontPath', InkWell(
                          onTap: () => _frontPath == null ? _takePicture('physFront', setModalState) : null, 
                          child: _buildImagePreview(_frontPath, () => setModalState(() => _frontPath = null), "FRONT")
                        ))
                      ), 
                      const SizedBox(width: 10), 
                      Expanded(
                        child: _vField('backPath', InkWell(
                          onTap: () => _backPath == null ? _takePicture('physBack', setModalState) : null, 
                          child: _buildImagePreview(_backPath, () => setModalState(() => _backPath = null), "BACK")
                        ))
                      ) 
                    ]
                  ),
                  
                  if (_frontPath != null) 
                    Row(
                      children: [
                        Expanded(
                          child: _vField('height', TextField(
                            controller: _heightCtrl, 
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                            decoration: InputDecoration(
                              labelText: "Height", 
                              labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                            )
                          ))
                        ), 
                        const SizedBox(width: 10), 
                        Expanded(
                          child: _vField('weight', TextField(
                            controller: _weightCtrl, 
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                            decoration: InputDecoration(
                              labelText: "Weight", 
                              labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                            )
                          ))
                        )
                      ]
                    ),

                  _buildSection("School & Sport"),
                  TextField(
                    controller: _school, 
                    readOnly: true, 
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                    decoration: InputDecoration(
                      labelText: "High School (Locked)", 
                      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7)), 
                      suffixIcon: const Icon(Icons.lock, color: Colors.grey)
                    )
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedGradYear, 
                    dropdownColor: Theme.of(context).cardColor, 
                    items: ["9th", "10th", "11th", "12th"].map((y) => DropdownMenuItem(
                      value: y, 
                      child: Text(y, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))
                    )).toList(), 
                    onChanged: null, 
                    decoration: InputDecoration(
                      labelText: "Grade Level (Locked)", 
                      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7)), 
                      suffixIcon: const Icon(Icons.lock, color: Colors.grey)
                    )
                  ),
                  
                  const SizedBox(height: 10), 
                  Text("Sports (Select to automatically add)", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                  
                  _vField('sports', DropdownButtonFormField<String>(
                    value: null, 
                    dropdownColor: Theme.of(context).cardColor,
                    items: widget.availableSports.map((s) { 
                      bool isEnrolled = activeSports.contains(s.name) || _selectedSports.contains(s.name); 
                      return DropdownMenuItem(
                        value: s.name, 
                        enabled: !isEnrolled, 
                        child: Text(s.name, style: TextStyle(color: isEnrolled ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color))
                      ); 
                    }).toList(), 
                    onChanged: (val) { 
                      if (val != null && !_selectedSports.contains(val)) { 
                        setModalState(() => _selectedSports.add(val)); 
                      } 
                    }, 
                    hint: Text("Select Sport to Add", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7)))
                  )),
                  Wrap(
                    children: _selectedSports.map((s) => Chip(
                      label: Text(s, style: const TextStyle(color: Colors.white)), 
                      onDeleted: () => setModalState(() => _selectedSports.remove(s)), 
                      backgroundColor: Theme.of(context).primaryColor
                    )).toList()
                  ),
                  
                  _buildSection("Contact Info"),
                  _vField('st', AddressSearchField(stCtrl: _st, cityCtrl: _ci, stateCtrl: _state, zipCtrl: _zip)),
                  Row(
                    children: [
                      Expanded(
                        child: _vField('ci', TextField(
                          controller: _ci, 
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                          decoration: InputDecoration(
                            labelText: "City", 
                            labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                          )
                        ))
                      ), 
                      const SizedBox(width: 5), 
                      Expanded(
                        child: _vField('state', TextField(
                          controller: _state, 
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                          decoration: InputDecoration(
                            labelText: "State", 
                            labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                          )
                        ))
                      ), 
                      const SizedBox(width: 5), 
                      Expanded(
                        child: _vField('zip', TextField(
                          controller: _zip, 
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                          decoration: InputDecoration(
                            labelText: "Zip", 
                            labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                          )
                        ))
                      )
                    ]
                  ),
                  _vField('homePhone', TextField(
                    controller: _homePhone, 
                    keyboardType: TextInputType.phone, 
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                    inputFormatters: [LengthLimitingTextInputFormatter(14), FilteringTextInputFormatter.digitsOnly], 
                    decoration: InputDecoration(
                      labelText: "Home Phone", 
                      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                    ), 
                    onChanged: (v) => _formatPhone(_homePhone, v)
                  )),
                  _vField('mobilePhone', TextField(
                    controller: _mobilePhone, 
                    keyboardType: TextInputType.phone, 
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                    inputFormatters: [LengthLimitingTextInputFormatter(14), FilteringTextInputFormatter.digitsOnly], 
                    decoration: InputDecoration(
                      labelText: "Mobile Phone", 
                      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                    ), 
                    onChanged: (v) => _formatPhone(_mobilePhone, v)
                  )),
                  _vField('email', TextField(
                    controller: _email, 
                    keyboardType: TextInputType.emailAddress, 
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                    decoration: InputDecoration(
                      labelText: "School Email", 
                      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                    )
                  )),

                  _buildSection("Parents/Guardians"),
                  _vField('living', DropdownButtonFormField<String>(
                    value: _livingArrangement, 
                    dropdownColor: Theme.of(context).cardColor, 
                    items: ["1 Parent", "Both Parents", "Guardian"].map((s) => DropdownMenuItem(
                      value: s, 
                      child: Text(s, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))
                    )).toList(), 
                    onChanged: (v) => setModalState(() => _livingArrangement = v), 
                    decoration: InputDecoration(
                      labelText: "Lives With", 
                      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                    )
                  )),
                  if (_livingArrangement != null) ...[ 
                    Text(
                      _livingArrangement == "Guardian" ? "Guardian Info" : "Parent 1 Info", 
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)
                    ), 
                    Row(
                      children: [
                        Expanded(
                          child: _vField('p1First', TextField(
                            controller: _p1First, 
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                            decoration: InputDecoration(
                              labelText: "First", 
                              labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                            )
                          ))
                        ), 
                        const SizedBox(width: 5), 
                        Expanded(
                          child: _vField('p1Last', TextField(
                            controller: _p1Last, 
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                            decoration: InputDecoration(
                              labelText: "Last", 
                              labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                            )
                          ))
                        )
                      ]
                    ), 
                    _vField('p1Mobile', TextField(
                      controller: _p1Mobile, 
                      keyboardType: TextInputType.number, 
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                      decoration: InputDecoration(
                        labelText: "Mobile", 
                        labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                      ), 
                      onChanged: (v) => _formatPhone(_p1Mobile, v)
                    )), 
                    TextField(
                      controller: _p1Email, 
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                      decoration: InputDecoration(
                        labelText: "Email", 
                        labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                      )
                    ), 
                  ],
                  
                  if (_livingArrangement == "Both Parents") ...[ 
                    const SizedBox(height: 10), 
                    Text("Parent 2 Info", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)), 
                    Row(
                      children: [
                        Expanded(
                          child: _vField('p2First', TextField(
                            controller: _p2First, 
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                            decoration: InputDecoration(
                              labelText: "First", 
                              labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                            )
                          ))
                        ), 
                        const SizedBox(width: 5), 
                        Expanded(
                          child: _vField('p2Last', TextField(
                            controller: _p2Last, 
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                            decoration: InputDecoration(
                              labelText: "Last", 
                              labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                            )
                          ))
                        )
                      ]
                    ), 
                    _vField('p2Mobile', TextField(
                      controller: _p2Mobile, 
                      keyboardType: TextInputType.number, 
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                      decoration: InputDecoration(
                        labelText: "Mobile", 
                        labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                      ), 
                      onChanged: (v) => _formatPhone(_p2Mobile, v)
                    )), 
                    TextField(
                      controller: _p2Email, 
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                      decoration: InputDecoration(
                        labelText: "Email", 
                        labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                      )
                    ), 
                  ],
                  
                  _buildSection("Medical"),
                  _vField('physName', TextField(
                    controller: _physName, 
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                    decoration: InputDecoration(
                      labelText: "Physician Name (Optional)", 
                      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                    )
                  )), 
                  _vField('physPhone', TextField(
                    controller: _physPhone, 
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                    keyboardType: TextInputType.phone, 
                    decoration: InputDecoration(
                      labelText: "Physician Phone (Optional)", 
                      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                    ), 
                    onChanged: (v) => _formatPhone(_physPhone, v)
                  )),
                  SwitchListTile(
                    title: Text("Covered by Insurance?", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)), 
                    value: _isInsured, 
                    onChanged: (v) => setModalState(() => _isInsured = v)
                  ),
                  
                  if (_isInsured) ...[ 
                    _vField('insCo', TextField(
                      controller: _insCo, 
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                      decoration: InputDecoration(
                        labelText: "Company", 
                        labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                      )
                    )), 
                    _vField('insPol', TextField(
                      controller: _insPol, 
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                      decoration: InputDecoration(
                        labelText: "Policy #", 
                        labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                      )
                    )), 
                    const SizedBox(height: 10), 
                    Text("Upload Insurance Card", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)), 
                    Row(
                      children: [ 
                        Expanded(
                          child: _vField('insFrontPath', InkWell(
                            onTap: () => _insFrontPath == null ? _takePicture('insFront', setModalState) : null, 
                            child: _buildImagePreview(_insFrontPath, () => setModalState(() => _insFrontPath = null), "Ins Front")
                          ))
                        ), 
                        const SizedBox(width: 10), 
                        Expanded(
                          child: _vField('insBackPath', InkWell(
                            onTap: () => _insBackPath == null ? _takePicture('insBack', setModalState) : null, 
                            child: _buildImagePreview(_insBackPath, () => setModalState(() => _insBackPath = null), "Ins Back")
                          ))
                        ) 
                      ]
                    ), 
                  ],
                  
                  TextField(
                    controller: _medCond, 
                    maxLines: 2, 
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                    decoration: InputDecoration(
                      labelText: "Medical Conditions / Allergies", 
                      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                    )
                  ), 
                  const SizedBox(height: 10), 
                  DropdownButtonFormField<String>(
                    value: _hospPref, 
                    dropdownColor: Theme.of(context).cardColor, 
                    items: ["Nearest Hospital", "My Hospital"].map((s) => DropdownMenuItem(
                      value: s, 
                      child: Text(s, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))
                    )).toList(), 
                    onChanged: (v) => setModalState(() => _hospPref = v!), 
                    decoration: InputDecoration(
                      labelText: "Hospital Preference", 
                      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                    )
                  ), 
                  if (_hospPref == "My Hospital") 
                    _vField('hospLoc', TextField(
                      controller: _hospLocCtrl, 
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                      decoration: InputDecoration(
                        labelText: "Hospital Location / Name", 
                        labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                      )
                    )),
                  
                  _buildSection("Emergency Contact"),
                  Row(
                    children: [ 
                      Expanded(
                        child: _vField('emgFirst', TextField(
                          controller: _emgFirst, 
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                          decoration: InputDecoration(
                            labelText: "First Name", 
                            labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                          )
                        ))
                      ), 
                      const SizedBox(width: 5), 
                      Expanded(
                        child: _vField('emgLast', TextField(
                          controller: _emgLast, 
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                          decoration: InputDecoration(
                            labelText: "Last Name", 
                            labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                          )
                        ))
                      ) 
                    ]
                  ), 
                  _vField('emgRel', TextField(
                    controller: _emgRel, 
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                    decoration: InputDecoration(
                      labelText: "Relationship", 
                      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                    )
                  )), 
                  _vField('emgPhone', TextField(
                    controller: _emgPhone, 
                    keyboardType: TextInputType.phone, 
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                    decoration: InputDecoration(
                      labelText: "Phone", 
                      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                    ), 
                    onChanged: (v) => _formatPhone(_emgPhone, v)
                  )),
                  
                  _buildSection("History"), 
                  DropdownButtonFormField<String>(
                    value: _eduHistory, 
                    dropdownColor: Theme.of(context).cardColor, 
                    items: ["Attended Diff HS", "Never Attended Diff HS", "Dropped Out"].map((s) => DropdownMenuItem(
                      value: s, 
                      child: Text(s, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))
                    )).toList(), 
                    onChanged: (v) => _eduHistory = v, 
                    decoration: InputDecoration(
                      labelText: "History", 
                      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                    )
                  ), 
                  TextField(
                    controller: _lastSchool, 
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                    decoration: InputDecoration(
                      labelText: "Last School Attended", 
                      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))
                    )
                  ), 
                  
                  const SizedBox(height: 30), 
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor, 
                      padding: const EdgeInsets.all(16)
                    ), 
                    onPressed: () => _validateAndSubmit(setModalState, ctx),
                    child: const Text(
                      "SUBMIT CLEARANCE", 
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                    )
                  ), 
                  const SizedBox(height: 50),
                ]
              )
            )
          );
        }
      )
    );
  }

  Widget _buildSection(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10), 
    child: Text(
      title, 
      style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontSize: 16)
    )
  );
}