import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

import '../constants.dart';
import '../models/student.dart';
import '../models/inventory.dart';
import '../models/sports.dart';
import '../models/report.dart';
import 'student_view.dart';
import 'coach_view.dart';
import 'directory_view.dart';
import '../showcase_keys.dart';
import '../widgets/calendar_view.dart';

class DashboardScreen extends StatefulWidget {
  final bool showTutorial;
  final String role;
  final String sportFilter;
  final int currentId;
  final bool isGodMode;
  final String currentSchool;
  final List<String> myAssignedRoles;
  final String activeTheme;
  final bool isColorBlindMode;
  final List<Student> students;
  final List<InventoryItem> inventory;
  final List<InventoryFolder> folders;
  final List<GameEvent> schedule;
  final List<InjuryReport> injuries;
  final List<SportDefinition> availableSports;
  final List<String> adminNotes;
  final List<String> coachNotes;
  final Function(String) onRoleChanged;
  final Function(String) onSportFilterChanged;
  final Function(String) onThemeChanged;
  final Function(bool) onColorBlindChanged;
  final Function(int, Map<String, dynamic>, List<String>) onSubmitClearance;
  final Function(int, AbsenceRequest) onSubmitAbsence;
  final Function(int, DoctorsNote) onSubmitDoctorsNote;
  final Function(int, bool, {String? reason}) onProcessClearance;
  final Function(String, bool) onUploadPhysical;
  final Function(String, String, String, DateTime, DateTime, TimeOfDay?, TimeOfDay?, RosterLevel) onAddGame;
  final Function(String, int, int) onUpdateScore;
  final Function(int, String) onAddInjury;
  final VoidCallback onMarkInjuriesRead;
  final Function(InjuryReport) onClearInjury;
  final Function(String, String, String?) onCreateItem;
  final Function(String, String?) onCreateFolder;
  final Function(String) onDeleteItem;
  final Function(String) onDeleteFolder;
  final Function(String, String) onRenameItem;
  final Function(String, String) onRenameFolder;
  final Function(String, String?) onMoveItem;
  final Function(String, String?) onMoveFolder;
  final Function(String, String) onCheckoutItem;
  final Function(String) onCheckInItem;
  final Function(String, double) onMarkMissing;
  final Function(int, String) onAddStudentNote;
  final Function(int, String, bool) onCoachRosterAction;
  final Function(List<int>, String, RosterLevel) onBatchAdd;
  final Function(int, String, RosterLevel) onMovePlayer;
  final Function({bool isAuto}) onSimulateCronJob;
  final Function(int) onClearNotifications;
  final Function(String) onLoginAsStudent;
  final VoidCallback onLogout;
  final Function(String) onSyncICal;
  final Function(int) onDismissAdminNote;

  const DashboardScreen({
    super.key,
    required this.showTutorial,
    required this.role,
    required this.sportFilter,
    required this.isGodMode,
    required this.currentSchool,
    required this.myAssignedRoles,
    required this.activeTheme,
    required this.isColorBlindMode,
    required this.students,
    required this.inventory,
    required this.folders,
    required this.schedule,
    required this.injuries,
    required this.availableSports,
    required this.currentId,
    required this.adminNotes,
    required this.coachNotes,
    required this.onRoleChanged,
    required this.onSportFilterChanged,
    required this.onThemeChanged,
    required this.onColorBlindChanged,
    required this.onSubmitClearance,
    required this.onSubmitAbsence,
    required this.onSubmitDoctorsNote,
    required this.onProcessClearance,
    required this.onUploadPhysical,
    required this.onAddGame,
    required this.onUpdateScore,
    required this.onAddInjury,
    required this.onMarkInjuriesRead,
    required this.onClearInjury,
    required this.onCreateItem,
    required this.onCreateFolder,
    required this.onDeleteItem,
    required this.onDeleteFolder,
    required this.onRenameItem,
    required this.onRenameFolder,
    required this.onMoveItem,
    required this.onMoveFolder,
    required this.onCheckoutItem,
    required this.onCheckInItem,
    required this.onMarkMissing,
    required this.onAddStudentNote,
    required this.onCoachRosterAction,
    required this.onBatchAdd,
    required this.onMovePlayer,
    required this.onSimulateCronJob,
    required this.onClearNotifications,
    required this.onLoginAsStudent,
    required this.onLogout,
    required this.onSyncICal,
    required this.onDismissAdminNote,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  BuildContext? _innerContext;
  BuildContext? _tabContext;
  List<String> _liveAssignedRoles = [];
  List<String> _myCoachingSports = [];
  StreamSubscription<DocumentSnapshot>? _userSub;
  bool _initialSportSynced = false;

  final GlobalKey studentCalendarTabKey = GlobalKey();
  final GlobalKey studentAlertsTabKey = GlobalKey();
  final GlobalKey settingsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _liveAssignedRoles = List.from(widget.myAssignedRoles);
    _startLiveRoleSync();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.showTutorial) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  "Launching Welcome Tour...",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Theme.of(context).primaryColor,
                duration: const Duration(seconds: 2),
              )
            );
            _startWalkthroughSequence();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  void _startLiveRoleSync() {
    User? u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      _userSub = FirebaseFirestore.instance.collection('users').doc(u.uid).snapshots().listen((doc) {
        if (doc.exists) {
          var data = doc.data()!;
          List<String> combinedRoles = [];
          if (data.containsKey('myAssignedRoles')) {
            combinedRoles.addAll(List<String>.from(data['myAssignedRoles']));
          }
          if (data.containsKey('roles')) {
            combinedRoles.addAll(List<String>.from(data['roles']));
          }
          if (data.containsKey('role')) {
            combinedRoles.add(data['role'] ?? widget.role);
          }
          
          combinedRoles = combinedRoles.toSet().toList();

          List<String> activeSports = [];
          if (data.containsKey('memberships')) {
            for (var m in data['memberships']) {
              if (m is Map && m['isActive'] == true && m['sport'] != null) {
                activeSports.add(m['sport'].toString());
              }
            }
          }

          if (mounted) {
            setState(() {
              _liveAssignedRoles = combinedRoles;
              _myCoachingSports = activeSports;
            });
          }

          if (!data.containsKey('myAssignedRoles') || List<String>.from(data['myAssignedRoles']).length != combinedRoles.length) {
            FirebaseFirestore.instance.collection('users').doc(u.uid).update({'myAssignedRoles': combinedRoles});
          }

          String dbRole = data['role'] ?? widget.role;
          if (!_initialSportSynced && dbRole.contains('Coach') && activeSports.isNotEmpty) {
            String actualSport = activeSports.first;
            if (actualSport != widget.sportFilter && mounted) {
              widget.onSportFilterChanged(actualSport);
              _initialSportSynced = true;
            }
          }
        }
      });
    }
  }

  // PROPOSAL REQUIREMENT: The system shall present an interactive, guided walkthrough tutorial the very first time a user logs into a new role.
  void _startWalkthroughSequence() {
    if (!mounted || _innerContext == null) return;

    if (widget.role == 'Student') {
      ShowCaseWidget.of(_innerContext!).startShowCase([
        ShowcaseKeys.studentAthletesTabKey,
        ShowcaseKeys.studentClearanceFormKey,
        StudentView.absenceKey,
        ShowcaseKeys.studentUploadDrNoteKey,
        ShowcaseKeys.studentEmergencyCardKey,
        studentCalendarTabKey,
        studentAlertsTabKey,
        settingsKey,
      ]);
    } else if (widget.role.contains('Coach')) {
      ShowCaseWidget.of(_innerContext!).startShowCase([
        ShowcaseKeys.coachRosterCheckboxKey
      ]);
    } else if (widget.role == 'Athletic Director') {
      ShowCaseWidget.of(_innerContext!).startShowCase([
        ShowcaseKeys.adClearanceBadgeKey
      ]);
    } else if (widget.role == 'Trainer') {
      ShowCaseWidget.of(_innerContext!).startShowCase([
        ShowcaseKeys.trainerMedBayHubTabKey
      ]);
    } else if (widget.role == 'Attendant') {
      ShowCaseWidget.of(_innerContext!).startShowCase([
        ShowcaseKeys.attendantCheckOutTabKey
      ]);
    }
  }

  void _triggerWalkthroughFromBot() {
    if (Navigator.canPop(context)) Navigator.pop(context);
    Future.delayed(const Duration(milliseconds: 500), () => _startWalkthroughSequence());
  }

  String _getAvatarForSport(String s) {
    String l = s.toLowerCase();
    if (l.contains('baseball') || l.contains('softball')) return "⚾";
    if (l.contains('basketball')) return "🏀";
    if (l.contains('football')) return "🏈";
    if (l.contains('soccer')) return "⚽";
    if (l.contains('tennis')) return "🎾";
    if (l.contains('volleyball')) return "🏐";
    if (l.contains('golf')) return "⛳";
    if (l.contains('swim') || l.contains('dive') || l.contains('water polo')) return "🏊";
    if (l.contains('track') || l.contains('cross country') || l.contains('xc')) return "🏃";
    return "🤖";
  }

  List<String> _getSeasonalEmojis() {
    int m = DateTime.now().month;
    if (m >= 8 && m <= 11) return ["🏈", "🏐", "🎾", "🏃", "⛳", "🤽"];
    if (m == 12 || m <= 2) return ["🏀", "⚽", "🤼"];
    return ["⚾", "🥎", "🏃", "🏊", "⛳", "🎾", "🏐"];
  }

  Widget _buildSmoothThemeBubble(String themeName, String activeThemeName, Function(String) onSelect) {
    Color prim = Colors.blue;
    Color bg = Colors.grey.shade900;
    Color text = Colors.white;

    if (themeName.contains("Light") || themeName == "Minimalist Monochrome") {
      bg = Colors.white;
      text = Colors.black87;
    } else {
      bg = const Color(0xFF121212);
      text = Colors.white;
    }

    if (themeName.contains("Ruby") || themeName.contains("Crimson")) prim = Colors.red;
    else if (themeName.contains("Amber") || themeName.contains("Sunset")) prim = Colors.orange;
    else if (themeName.contains("Maize") || themeName.contains("Gold")) prim = Colors.amber;
    else if (themeName.contains("Mint") || themeName.contains("Forest")) prim = Colors.green;
    else if (themeName.contains("Sky") || themeName.contains("Ocean")) prim = Colors.blue;
    else if (themeName.contains("Lavender") || themeName.contains("Violet")) prim = Colors.purple;
    else if (themeName == "Minimalist Monochrome") prim = Colors.black87;

    bool isCyberpunk = themeName == "Neon Cyberpunk";
    bool isSelected = activeThemeName == themeName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () => onSelect(themeName),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? (isCyberpunk ? Colors.cyanAccent : prim) : Colors.transparent,
              width: isSelected ? 2 : 0
            )
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCyberpunk ? null : prim,
                  gradient: isCyberpunk
                      ? const SweepGradient(colors: [Colors.cyanAccent, Colors.purpleAccent, Colors.pinkAccent, Colors.cyanAccent])
                      : null
                )
              ),
              const SizedBox(width: 12),
              Text(
                themeName.replaceAll(" Theme", ""),
                style: TextStyle(
                  color: text,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  letterSpacing: 0.5
                )
              ),
              const Spacer(),
              if (isSelected)
                Icon(Icons.check_circle, color: isCyberpunk ? Colors.cyanAccent : prim, size: 20)
            ]
          ),
        ),
      ),
    );
  }

  void _showSettingsMenu(BuildContext context) {
    String initialTheme = widget.activeTheme;
    String tempTheme = widget.activeTheme;
    List<String> darkThemes = ["Crimson Dark", "Sunset Dark", "Gold Dark", "Forest Dark", "Ocean Dark", "Deep Violet Dark", "Neon Cyberpunk"];
    List<String> lightThemes = ["Ruby Light", "Amber Light", "Maize Light", "Mint Light", "Sky Light", "Lavender Light", "Minimalist Monochrome"];

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 60.0, right: 10.0),
          child: Material(
            borderRadius: BorderRadius.circular(12),
            elevation: 8,
            color: Theme.of(context).cardColor,
            child: Container(
              width: 340,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(
                builder: (c, setDialogState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Settings & Preferences",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 10),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              const Text("Dark Themes", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 10),
                              ...darkThemes.map((t) => _buildSmoothThemeBubble(t, tempTheme, (val) {
                                setDialogState(() => tempTheme = val);
                                widget.onThemeChanged(val);
                              })),
                              const SizedBox(height: 15),
                              const Text("Light Themes", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                              const SizedBox(height: 10),
                              ...lightThemes.map((t) => _buildSmoothThemeBubble(t, tempTheme, (val) {
                                setDialogState(() => tempTheme = val);
                                widget.onThemeChanged(val);
                              })),
                            ]
                          )
                        )
                      ),
                      const Divider(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red)
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(ctx, false);
                            widget.onLogout();
                          }
                        )
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              widget.onThemeChanged(initialTheme);
                              Navigator.pop(ctx, false);
                            },
                            child: const Text("Cancel", style: TextStyle(color: Colors.grey))
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("Save")
                          )
                        ]
                      ),
                    ]
                  );
                }
              )
            )
          )
        )
      )
    ).then((saved) {
      if (saved != true) {
        widget.onThemeChanged(initialTheme);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Color iconColor = (widget.activeTheme.contains("Light") || widget.activeTheme == "Minimalist Monochrome") ? Theme.of(context).primaryColor : Colors.white;
    
    if (widget.activeTheme == "High Contrast" || widget.activeTheme == "Gold Dark") {
      iconColor = Colors.yellowAccent;
    }

    Color btnTextColor = Theme.of(context).primaryColor.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;
    
    if (widget.activeTheme == "High Contrast" || widget.activeTheme == "Neon Cyberpunk") {
      btnTextColor = Colors.black;
    }

    String activeAvatar = "🤖";
    List<String> backgroundEmojis = _getSeasonalEmojis();

    if (widget.role == 'Student') {
      try {
        String s = widget.students.firstWhere((s) => s.id == widget.currentId).memberships.first.sport;
        activeAvatar = _getAvatarForSport(s);
        backgroundEmojis = [activeAvatar];
      } catch (e) {}
    } else if (widget.role.contains('Coach')) {
      activeAvatar = _getAvatarForSport(widget.sportFilter);
      backgroundEmojis = [activeAvatar];
    }

    bool isDarkTheme = widget.activeTheme.contains("Dark") || widget.activeTheme == "Neon Cyberpunk" || widget.activeTheme == "High Contrast" || widget.activeTheme == "Forest Athletic";
    Color safeTextColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    Color activeTabColor = isDarkTheme ? Theme.of(context).colorScheme.secondary : safeTextColor;

    int tabLength = 1;
    if (widget.role == 'Student') {
      tabLength = 3;
    } else if (widget.role.contains('Coach')) {
      tabLength = 3;
    } else if (widget.role == 'Athletic Director') {
      tabLength = 6;
    } else if (widget.role == 'Trainer') {
      tabLength = 5;
    } else if (widget.role == 'Attendant') {
      tabLength = 6;
    }

    return ShowCaseWidget(
      onComplete: (index, key) {
        if (_tabContext == null) return;
        
        if (key == ShowcaseKeys.coachRosterCheckboxKey) {
          DefaultTabController.of(_tabContext!)?.animateTo(1);
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.coachPendingActionsTabKey]));
        } else if (key == ShowcaseKeys.coachPendingActionsTabKey) {
          DefaultTabController.of(_tabContext!)?.animateTo(2);
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.coachScheduleTabKey]));
        } else if (key == ShowcaseKeys.coachScheduleTabKey) {
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.coachAddGameKey]));
        } else if (key == ShowcaseKeys.coachAddGameKey) {
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([settingsKey]));
        } else if (key == ShowcaseKeys.adClearanceBadgeKey) {
          DefaultTabController.of(_tabContext!)?.animateTo(1);
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.adClearanceTabKey]));
        } else if (key == ShowcaseKeys.adClearanceTabKey) {
          DefaultTabController.of(_tabContext!)?.animateTo(2);
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.adInjuredListKey]));
        } else if (key == ShowcaseKeys.adInjuredListKey) {
          DefaultTabController.of(_tabContext!)?.animateTo(3);
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.adSystemOpsTabKey]));
        } else if (key == ShowcaseKeys.adSystemOpsTabKey) {
          DefaultTabController.of(_tabContext!)?.animateTo(4);
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.adMasterCalendarTabKey]));
        } else if (key == ShowcaseKeys.adMasterCalendarTabKey) {
          DefaultTabController.of(_tabContext!)?.animateTo(5);
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.adReportsTabKey]));
        } else if (key == ShowcaseKeys.adReportsTabKey) {
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([settingsKey]));
        } else if (key == ShowcaseKeys.trainerMedBayHubTabKey) {
          DefaultTabController.of(_tabContext!)?.animateTo(1);
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.trainerInjuredListTabKey]));
        } else if (key == ShowcaseKeys.trainerInjuredListTabKey) {
          DefaultTabController.of(_tabContext!)?.animateTo(2);
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.trainerDocNotesTabKey]));
        } else if (key == ShowcaseKeys.trainerDocNotesTabKey) {
          DefaultTabController.of(_tabContext!)?.animateTo(3);
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.trainerInventoryTabKey]));
        } else if (key == ShowcaseKeys.trainerInventoryTabKey) {
          DefaultTabController.of(_tabContext!)?.animateTo(4);
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.trainerReportsTabKey]));
        } else if (key == ShowcaseKeys.trainerReportsTabKey) {
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([settingsKey]));
        } else if (key == ShowcaseKeys.attendantCheckOutTabKey) {
          DefaultTabController.of(_tabContext!)?.animateTo(1);
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.attendantCheckInTabKey]));
        } else if (key == ShowcaseKeys.attendantCheckInTabKey) {
          DefaultTabController.of(_tabContext!)?.animateTo(2);
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.attendantCatalogTabKey]));
        } else if (key == ShowcaseKeys.attendantCatalogTabKey) {
          DefaultTabController.of(_tabContext!)?.animateTo(3);
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.attendantReportsTabKey]));
        } else if (key == ShowcaseKeys.attendantReportsTabKey) {
          DefaultTabController.of(_tabContext!)?.animateTo(4);
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.attendantLostFinesTabKey]));
        } else if (key == ShowcaseKeys.attendantLostFinesTabKey) {
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([settingsKey]));
        } else if (key == settingsKey) {
          Future.delayed(const Duration(milliseconds: 400), () => ShowCaseWidget.of(_innerContext!).startShowCase([ShowcaseKeys.vaultBotKey]));
        } else if (key == ShowcaseKeys.vaultBotKey) {
          User? u = FirebaseAuth.instance.currentUser;
          if (u != null) {
            FirebaseFirestore.instance.collection('users').doc(u.uid).update({'showTutorial': false});
          }
        }
      },
      builder: (innerContext) {
        _innerContext = innerContext;
        return DefaultTabController(
          key: ValueKey("${widget.role}_$tabLength"),
          length: tabLength,
          child: Builder(
            builder: (tabContext) {
              _tabContext = tabContext;

              List<Widget> activeTabs = [];
              if (widget.role == 'Student') {
                activeTabs = [
                  Tab(
                    icon: const Icon(Icons.home),
                    child: Showcase(
                      key: ShowcaseKeys.studentAthletesTabKey,
                      description: "This is your main Home dashboard.",
                      child: const Text("Home", style: TextStyle(fontWeight: FontWeight.bold))
                    )
                  ),
                  Tab(
                    icon: const Icon(Icons.calendar_today),
                    child: Showcase(
                      key: studentCalendarTabKey,
                      description: "View your upcoming games, practices, and early release times here.",
                      child: const Text("Calendar", style: TextStyle(fontWeight: FontWeight.bold))
                    )
                  ),
                  Tab(
                    icon: const Icon(Icons.notifications),
                    child: Showcase(
                      key: studentAlertsTabKey,
                      description: "Important alerts and notifications from your coaches will appear here.",
                      child: Builder(
                        builder: (ctx) {
                          final s = widget.students.firstWhere(
                            (s) => s.id == widget.currentId,
                            orElse: () => Student(
                              id: 0,
                              firstName: "",
                              lastName: "",
                              grade: "",
                              dob: DateTime.now(),
                              sex: "",
                              accountEmail: "",
                              school: ""
                            )
                          );
                          return Badge(
                            isLabelVisible: s.unreadAlerts > 0,
                            label: Text('${s.unreadAlerts}'),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text("Alerts", style: TextStyle(fontWeight: FontWeight.bold))
                            )
                          );
                        }
                      )
                    )
                  )
                ];
              }

              List<Map<String, String>> myHats = [];
              for (String r in _liveAssignedRoles) {
                if (!r.contains('Coach') && r != 'Student') {
                  myHats.add({'role': r, 'sport': ''});
                }
              }

              if (_liveAssignedRoles.any((r) => r.contains('Coach'))) {
                String cTitle = _liveAssignedRoles.firstWhere((r) => r.contains('Coach'));
                if (_myCoachingSports.isEmpty) {
                  myHats.add({'role': cTitle, 'sport': widget.sportFilter});
                } else {
                  for (String sport in _myCoachingSports) {
                    myHats.add({'role': cTitle, 'sport': sport});
                  }
                }
              }

              return Scaffold(
                appBar: AppBar(
                  leading: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.asset(
                      'assets/Rancho_Alamitos_High_School_logo.png',
                      errorBuilder: (c, e, s) => Icon(Icons.shield, color: iconColor)
                    )
                  ),
                  title: Text(
                    widget.role.contains('Coach') ? '${widget.role}: ${widget.sportFilter}' : widget.role,
                    style: TextStyle(color: iconColor)
                  ),
                  actions: [
                    Showcase(
                      key: settingsKey,
                      description: "Customize your app! Tap here to change your Theme, adjust settings, or securely Log Out.",
                      child: IconButton(
                        icon: Icon(Icons.settings, color: iconColor),
                        onPressed: () => _showSettingsMenu(context),
                        tooltip: "Settings"
                      )
                    ),
                    if (widget.isGodMode)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.swap_horiz, color: Colors.orangeAccent),
                        onSelected: (val) {
                          if (val.contains('Coach')) {
                            _showCoachSportPicker(context, val);
                          } else if (val == 'Student') {
                            widget.onLoginAsStudent('1001');
                          } else {
                            widget.onRoleChanged(val);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'Student', child: Text("View as Student")),
                          const PopupMenuItem(value: 'Athletic Director', child: Text("View as Athletic Director", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                          const PopupMenuItem(value: 'Trainer', child: Text("View as Trainer")),
                          const PopupMenuItem(value: 'Attendant', child: Text("View as Attendant")),
                          const PopupMenuItem(value: 'Head Coach', child: Text("View as Head Coach")),
                          const PopupMenuItem(value: 'Assistant Coach', child: Text("View as Assistant Coach"))
                        ]
                      )
                    else if (myHats.length > 1)
                      PopupMenuButton<Map<String, String>>(
                        icon: Icon(Icons.swap_horiz, color: iconColor),
                        tooltip: "Switch Role",
                        onSelected: (hat) {
                          if (hat['role']!.contains('Coach')) {
                            widget.onSportFilterChanged(hat['sport']!);
                            widget.onRoleChanged(hat['role']!);
                          } else {
                            widget.onRoleChanged(hat['role']!);
                          }
                        },
                        itemBuilder: (context) => myHats.map((h) {
                          String label = h['role']!.contains('Coach') ? h['sport']! : h['role']!;
                          return PopupMenuItem(
                            value: h,
                            child: Text("Switch to $label", style: const TextStyle(fontWeight: FontWeight.bold))
                          );
                        }).toList(),
                      )
                  ],
                ),
                body: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedSportBackground(
                        emojis: backgroundEmojis,
                        isDark: isDarkTheme
                      )
                    ),
                    Positioned.fill(
                      child: widget.role == 'Student'
                          ? Column(
                              children: [
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 800),
                                    child: Container(
                                      color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.85),
                                      child: TabBar(
                                        labelColor: activeTabColor,
                                        unselectedLabelColor: Colors.grey,
                                        indicatorColor: activeTabColor,
                                        isScrollable: true,
                                        tabAlignment: TabAlignment.center,
                                        tabs: activeTabs
                                      )
                                    )
                                  )
                                ),
                                Expanded(child: _getBody(tabContext))
                              ]
                            )
                          : _getBody(tabContext)
                    ),
                  ],
                ),
                floatingActionButton: Showcase(
                  key: ShowcaseKeys.vaultBotKey,
                  description: "I'll be right here to assist! Ask me to walk you through the app anytime.",
                  child: FloatingActionButton.extended(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: btnTextColor,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    icon: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 15,
                      child: Text(activeAvatar, style: const TextStyle(fontSize: 18))
                    ),
                    label: const Text("Ask VaultBot", style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => VaultBotSheet(
                          role: widget.role,
                          avatar: activeAvatar,
                          onTriggerWalkthrough: _triggerWalkthroughFromBot,
                          schedule: widget.schedule,
                          availableSports: widget.availableSports
                        )
                      );
                    },
                  ),
                ),
              );
            }
          ),
        );
      }
    );
  }

  void _showCoachSportPicker(BuildContext context, String specificRole) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text("Select Sport"),
        children: widget.availableSports.map((s) => SimpleDialogOption(
          child: Text(s.name),
          onPressed: () {
            widget.onSportFilterChanged(s.name);
            widget.onRoleChanged(specificRole);
            Navigator.pop(ctx);
          }
        )).toList()
      )
    );
  }

  Widget _getBody(BuildContext context) {
    switch (widget.role) {
      case 'Student':
        final me = widget.students.firstWhere(
          (s) => s.id == widget.currentId,
          orElse: () => Student(
            id: 0,
            firstName: "Err",
            lastName: "Err",
            grade: "0",
            dob: DateTime.now(),
            sex: "Male",
            accountEmail: "",
            school: widget.currentSchool
          )
        );
        return TabBarView(
          children: [
            StudentView(
              student: me,
              inventory: widget.inventory,
              schedule: widget.schedule,
              injuries: widget.injuries,
              availableSports: widget.availableSports,
              onSubmitClearance: widget.onSubmitClearance,
              onSubmitAbsence: widget.onSubmitAbsence,
              onSubmitDoctorsNote: widget.onSubmitDoctorsNote,
              onClearNotifications: widget.onClearNotifications
            ),
            SharedCalendarView(
              events: widget.schedule.where((GameEvent e) => me.memberships.any((m) => m.sport == e.sport && m.isActive)).toList(),
              filterSport: null,
              homeSchool: me.school
            ),
            me.notifications.isEmpty
                ? const Center(child: Text("No alerts."))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: me.notifications.length,
                    itemBuilder: (ctx, i) => Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Colors.black12)
                          ),
                          color: Theme.of(context).cardColor,
                          child: ListTile(
                            leading: Icon(Icons.notifications, color: Theme.of(context).colorScheme.secondary),
                            title: Text(me.notifications[i])
                          )
                        )
                      )
                    )
                  )
          ]
        );
      case 'Head Coach':
      case 'Assistant Coach':
        return CoachView(
          database: widget.students,
          inventory: widget.inventory,
          sport: widget.sportFilter,
          schedule: widget.schedule,
          injuries: widget.injuries,
          notifications: widget.coachNotes.where((note) => note.startsWith("${widget.sportFilter}|")).toList(),
          onAddGame: widget.onAddGame,
          onUpdateScore: widget.onUpdateScore,
          onRosterAction: widget.onCoachRosterAction,
          onBatchAdd: widget.onBatchAdd,
          onMovePlayer: widget.onMovePlayer,
          isReadOnly: widget.role == 'Assistant Coach'
        );
      case 'Athletic Director':
      case 'Trainer':
      case 'Attendant':
        return DirectoryView(
          role: widget.role,
          database: widget.students,
          inventory: widget.inventory,
          folders: widget.folders,
          schedule: widget.schedule,
          injuries: widget.injuries,
          notifications: widget.adminNotes,
          currentSchool: widget.currentSchool,
          availableSports: widget.availableSports,
          onAddInjury: widget.onAddInjury,
          onMarkInjuriesRead: widget.onMarkInjuriesRead,
          onClearInjury: widget.onClearInjury,
          onClearanceAction: widget.onProcessClearance,
          onCreateItem: widget.onCreateItem,
          onCreateFolder: widget.onCreateFolder,
          onDeleteItem: widget.onDeleteItem,
          onDeleteFolder: widget.onDeleteFolder,
          onRenameItem: widget.onRenameItem,
          onRenameFolder: widget.onRenameFolder,
          onMoveItem: widget.onMoveItem,
          onMoveFolder: widget.onMoveFolder,
          onCheckoutItem: widget.onCheckoutItem,
          onCheckInItem: widget.onCheckInItem,
          onMarkMissing: widget.onMarkMissing,
          onAddStudentNote: widget.onAddStudentNote,
          onSimulateCronJob: () => widget.onSimulateCronJob(isAuto: false),
          onSyncICal: widget.onSyncICal,
          onRestockPing: (itemStr) {
            widget.adminNotes.insert(0, "RESTOCK NEEDED: Trainer requested $itemStr on ${DateTime.now().toString().split(' ')[0]}");
          },
          onLoanMedicalItem: (studentIdStr, itemNameStr) {
            String dummyBarcode = "MED_${DateTime.now().millisecondsSinceEpoch}";
            widget.inventory.add(InventoryItem(
              barcode: dummyBarcode,
              name: itemNameStr,
              status: ItemStatus.checkedOut,
              assignedToStudentId: studentIdStr,
              dateCheckedOut: DateTime.now(),
              checkoutHistory: ["Loaned out to ID $studentIdStr on ${DateTime.now().toString().split(' ')[0]}"]
            ));
          },
          onBoomerangPing: (studentIdStr, sportStr, itemNameStr) {
            int sid = int.tryParse(studentIdStr) ?? 0;
            try {
              final s = widget.students.firstWhere((st) => st.id == sid);
              s.addNotification("URGENT: Please return $itemNameStr to the Trainer's Med-Bay immediately.");
              widget.coachNotes.insert(0, "$sportStr|URGENT MED-BAY: ${s.fullName} needs to return $itemNameStr.");
              FirebaseFirestore.instance.collection('users').where('id', isEqualTo: s.id).get().then((q) {
                if (q.docs.isNotEmpty) {
                  FirebaseFirestore.instance.collection('users').doc(q.docs.first.id).update(s.toJson());
                }
              });
            } catch (e) {}
          },
          onDismissNotification: widget.onDismissAdminNote
        );
      default:
        return const Center(child: Text("Unknown Role"));
    }
  }
}

class AnimatedSportBackground extends StatefulWidget {
  final List<String> emojis;
  final bool isDark;

  const AnimatedSportBackground({
    super.key,
    required this.emojis,
    required this.isDark
  });

  @override
  State<AnimatedSportBackground> createState() => _AnimatedSportBackgroundState();
}

class _AnimatedSportBackgroundState extends State<AnimatedSportBackground> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40)
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: widget.isDark ? 0.10 : 0.15,
          child: Stack(
            children: List.generate(40, (index) {
              double x = (index % 8) * (screen.width / 6) - 50 + (_ctrl.value * 150);
              double y = (index ~/ 8) * (screen.height / 5) - 50 + (_ctrl.value * 150);
              String emoji = widget.emojis[index % widget.emojis.length];
              return Positioned(
                left: x,
                top: y,
                child: Text(emoji, style: const TextStyle(fontSize: 80))
              );
            })
          )
        );
      },
    );
  }
}

class VaultBotSheet extends StatefulWidget {
  final String role;
  final String avatar;
  final VoidCallback onTriggerWalkthrough;
  final List<GameEvent> schedule;
  final List<SportDefinition> availableSports;

  const VaultBotSheet({
    super.key,
    required this.role,
    required this.avatar,
    required this.onTriggerWalkthrough,
    required this.schedule,
    required this.availableSports
  });

  @override
  State<VaultBotSheet> createState() => _VaultBotSheetState();
}

class _VaultBotSheetState extends State<VaultBotSheet> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ScrollController _chipScrollCtrl = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  final Map<String, String> _faqDatabase = {
    "How do I upload my physical?": "To upload your physical, go to the Home tab and tap the 'Clearance Form' button. You can take a picture directly from your phone!",
    "How do I check my clearance status?": "Your clearance status is displayed as a badge on your Home dashboard. Green means cleared, Red means uncleared or injured, and Orange means pending.",
    "How do I input a match score?": "Go to the Calendar tab, switch to 'Day View', and tap directly on the game block. If you are the Head Coach, you will see boxes to enter the final score.",
    "How do I add a student to my roster?": "Students must submit their clearance form first. Once they do, they will appear in your 'Pending' tab where you can approve them.",
    "How do I invite staff?": "Navigate to the 'System Ops' tab. Select the sport from the dropdown, and tap 'Copy Link' to generate a secure invite for your new coach or trainer.",
    "How do I clear an injured player?": "Go to the 'Doc Notes' tab. Once you review their uploaded doctor's note, click 'Clear Player' to instantly remove their medical hold.",
    "How do I fine a student?": "In the Equipment hub, go to the 'Check Out / Out' tab. Find the overdue item and tap the orange warning icon to mark it missing and assign a fine.",
  };

  @override
  void initState() {
    super.initState();
    _messages.add({
      "text": "Hi! I'm VaultBot. I see you are logged in as a ${widget.role}. Tap a quick question below, or type a custom request to connect to my AI database!",
      "isAI": true
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _chipScrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({"text": text, "isAI": false});
      _isTyping = true;
    });
    _msgCtrl.clear();

    if (text.contains("Walk me through")) {
      widget.onTriggerWalkthrough();
      setState(() => _isTyping = false);
      return;
    }

    if (_faqDatabase.containsKey(text)) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() {
          _messages.add({"text": _faqDatabase[text], "isAI": true});
          _isTyping = false;
        });
      }
      return;
    }

    String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _isTyping = false;
            _messages.add({
              "text": "I am currently offline. Please check your internet connection or API key.",
              "isAI": true
            });
          });
        }
      });
      return;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-flash-latest',
        apiKey: apiKey,
        systemInstruction: Content.system("You are VaultBot, a highly restricted AI assistant strictly for Varsity Vault. Your current user is logged in as a ${widget.role}. CRITICAL DIRECTIVES: 1. You MUST absolutely refuse to answer any question that is not directly related to using the Varsity Vault application, high school sports management, or the specific features available to a ${widget.role}.")
      );

      final response = await model.generateContent([Content.text(text)]).timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({"text": response.text ?? "I'm not sure.", "isAI": true});
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({"text": "AI Connection Error:\n${e.toString()}", "isAI": true});
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Color btnTextColor = Theme.of(context).primaryColor.computeLuminance() > 0.4 ? Colors.black87 : Colors.white;
    if (Theme.of(context).primaryColor == Colors.yellowAccent || Theme.of(context).primaryColor == Colors.cyanAccent) {
      btnTextColor = Colors.black;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(widget.avatar, style: const TextStyle(fontSize: 20))
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("VaultBot AI", style: TextStyle(color: btnTextColor, fontWeight: FontWeight.bold, fontSize: 18)),
                      Text("Hybrid Mode • Local + Gemini", style: TextStyle(color: btnTextColor.withOpacity(0.7), fontSize: 12))
                    ]
                  )
                ),
                IconButton(
                  icon: Icon(Icons.close, color: btnTextColor),
                  onPressed: () => Navigator.pop(context)
                )
              ]
            )
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text("VaultBot is typing...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                    )
                  );
                }
                
                bool isAI = _messages[i]['isAI'];
                return Align(
                  alignment: isAI ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isAI ? Theme.of(context).cardColor : Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(15)
                    ),
                    child: Text(
                      _messages[i]['text'],
                      style: TextStyle(
                        color: isAI ? Theme.of(context).textTheme.bodyLarge?.color : btnTextColor
                      )
                    )
                  )
                );
              }
            )
          ),
          if (_messages.length == 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              height: 50,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios, size: 16, color: Theme.of(context).primaryColor),
                    onPressed: () => _chipScrollCtrl.animateTo(
                      (_chipScrollCtrl.offset - 250).clamp(0.0, _chipScrollCtrl.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut
                    )
                  ),
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad}),
                      child: SingleChildScrollView(
                        controller: _chipScrollCtrl,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ActionChip(
                              label: const Text("Walk me through how to use this"),
                              onPressed: () => _sendMessage("Walk me through how to use this")
                            ),
                            const SizedBox(width: 8),
                            if (widget.role == 'Student') ...[
                              ActionChip(
                                label: const Text("How do I upload my physical?"),
                                onPressed: () => _sendMessage("How do I upload my physical?")
                              ),
                              const SizedBox(width: 8)
                            ],
                            if (widget.role.contains('Coach')) ...[
                              ActionChip(
                                label: const Text("How do I input a match score?"),
                                onPressed: () => _sendMessage("How do I input a match score?")
                              ),
                              const SizedBox(width: 8)
                            ],
                            if (widget.role == 'Athletic Director') ...[
                              ActionChip(
                                label: const Text("How do I invite staff?"),
                                onPressed: () => _sendMessage("How do I invite staff?")
                              )
                            ]
                          ]
                        )
                      )
                    )
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_forward_ios, size: 16, color: Theme.of(context).primaryColor),
                    onPressed: () => _chipScrollCtrl.animateTo(
                      (_chipScrollCtrl.offset + 250).clamp(0.0, _chipScrollCtrl.position.maxScrollExtent),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut
                    )
                  ),
                ]
              )
            ),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: TextField(
              controller: _msgCtrl,
              onSubmitted: _sendMessage,
              decoration: InputDecoration(
                hintText: "Message VaultBot...",
                suffixIcon: IconButton(
                  icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                  onPressed: () => _sendMessage(_msgCtrl.text)
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                filled: true,
                fillColor: Theme.of(context).cardColor
              )
            )
          )
        ],
      ),
    );
  }
}