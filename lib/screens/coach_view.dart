import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http; 
import '../models/student.dart';
import '../models/inventory.dart';
import '../models/sports.dart';
import '../models/report.dart';
import '../widgets/calendar_view.dart';
import '../widgets/emergency_card.dart';
import 'package:showcaseview/showcaseview.dart';
import '../showcase_keys.dart';

class CoachView extends StatefulWidget {
  final List<Student> database;
  final List<InventoryItem> inventory;
  final String sport;
  final List<GameEvent> schedule;
  final List<InjuryReport> injuries; 
  final List<String> notifications;
  final Function(String, String, String, DateTime, DateTime, TimeOfDay?, TimeOfDay?, RosterLevel) onAddGame;
  final Function(String, int, int) onUpdateScore; 
  final Function(int, String, bool) onRosterAction;
  final Function(List<int>, String, RosterLevel) onBatchAdd;
  final Function(int, String, RosterLevel) onMovePlayer;
  final bool isReadOnly; 

  const CoachView({
    super.key, required this.database, required this.inventory, required this.sport, required this.schedule, required this.injuries, required this.notifications, required this.onAddGame, required this.onUpdateScore, required this.onRosterAction, required this.onBatchAdd, required this.onMovePlayer, this.isReadOnly = false
  });

  @override
  State<CoachView> createState() => _CoachViewState();
}

class _CoachViewState extends State<CoachView> {
  RosterLevel? _expandedLevel; 
  final Set<int> _selectedStudents = {};

  void _showRosterMoveDialog() {
    if (_selectedStudents.isEmpty) return;
    RosterLevel targetLevel = RosterLevel.varsity;
    
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: Text("Move ${_selectedStudents.length} Players", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
      content: DropdownButtonFormField<RosterLevel>(
        value: targetLevel, decoration: const InputDecoration(labelText: "Destination Level"),
        items: RosterLevel.values.map((l) => DropdownMenuItem(
          value: l, 
          child: Text(l.name.toUpperCase(), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))
        )).toList(),
        onChanged: (v) => setState(() => targetLevel = v!)
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
          onPressed: () {
            widget.onBatchAdd(_selectedStudents.toList(), widget.sport, targetLevel);
            setState(() { _selectedStudents.clear(); _expandedLevel = targetLevel; });
            Navigator.pop(ctx);
          }, 
          child: const Text("Move Players", style: TextStyle(color: Colors.white))
        )
      ]
    ));
  }

  void _showAddGameDialog() {
    final oppCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    RosterLevel lvl = RosterLevel.varsity;
    bool isHome = true;
    
    DateTime selectedDate = DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 15, minute: 0); 
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0); 
    TimeOfDay? releaseTime;
    TimeOfDay? busTime;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text("Schedule New Game", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<RosterLevel>(
                    value: lvl, decoration: const InputDecoration(labelText: "Roster Level"),
                    items: RosterLevel.values.map((l) => DropdownMenuItem(value: l, child: Text(l.name.toUpperCase(), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)))).toList(),
                    onChanged: (v) => setDialogState(() => lvl = v!)
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text("Match Type: "),
                      Switch(value: isHome, activeColor: Theme.of(context).primaryColor, onChanged: (v) => setDialogState(() => isHome = v)),
                      Text(isHome ? "HOME" : "AWAY", style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  TextField(controller: oppCtrl, decoration: const InputDecoration(labelText: "Opponent School Name")),
                  
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue v) async {
                      if (v.text.length < 3) return const Iterable<String>.empty();
                      try {
                        final res = await http.get(Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(v.text)}&format=json&limit=5')).timeout(const Duration(seconds: 5));
                        if (res.statusCode == 200) {
                          final List data = json.decode(res.body);
                          return data.map((e) => e['display_name'].toString());
                        }
                      } catch(e) {}
                      return const Iterable<String>.empty();
                    },
                    onSelected: (String s) => locCtrl.text = s,
                    fieldViewBuilder: (ctx, ctrl, focus, submit) => TextField(
                      controller: ctrl, focusNode: focus,
                      decoration: const InputDecoration(labelText: "Address / Location (Live Search)", suffixIcon: Icon(Icons.location_on))
                    )
                  ),
                  
                  const Divider(height: 30),
                  
                  ListTile(
                    contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_today),
                    title: const Text("Game Date"), subtitle: Text("${selectedDate.month}/${selectedDate.day}/${selectedDate.year}"),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                      if (d != null) setDialogState(() => selectedDate = d);
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero, title: const Text("Start Time", style: TextStyle(fontSize: 12)), subtitle: Text("${startTime.hour > 12 ? startTime.hour - 12 : startTime.hour}:${startTime.minute.toString().padLeft(2, '0')} ${startTime.hour >= 12 ? 'PM' : 'AM'}"),
                          onTap: () async { final t = await showTimePicker(context: context, initialTime: startTime); if (t != null) setDialogState(() => startTime = t); },
                        ),
                      ),
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero, title: const Text("End Time", style: TextStyle(fontSize: 12)), subtitle: Text("${endTime.hour > 12 ? endTime.hour - 12 : endTime.hour}:${endTime.minute.toString().padLeft(2, '0')} ${endTime.hour >= 12 ? 'PM' : 'AM'}"),
                          onTap: () async { final t = await showTimePicker(context: context, initialTime: endTime); if (t != null) setDialogState(() => endTime = t); },
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  
                  const Text("Logistics & Notifications", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ListTile(
                    tileColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    leading: const Icon(Icons.notifications_active, color: Colors.orange),
                    title: const Text("Early Release Time"), 
                    subtitle: Text(releaseTime == null ? "Not Required" : "${releaseTime!.hour > 12 ? releaseTime!.hour - 12 : releaseTime!.hour}:${releaseTime!.minute.toString().padLeft(2, '0')} ${releaseTime!.hour >= 12 ? 'PM' : 'AM'}"),
                    onTap: () async { final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 13, minute: 30)); if (t != null) setDialogState(() => releaseTime = t); },
                    trailing: releaseTime != null ? IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: () => setDialogState(()=>releaseTime = null)) : null,
                  ),
                  const SizedBox(height: 5),
                  ListTile(
                    tileColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    leading: const Icon(Icons.directions_bus, color: Colors.blue),
                    title: const Text("Bus Departure Time"), 
                    subtitle: Text(busTime == null ? "Not Required" : "${busTime!.hour > 12 ? busTime!.hour - 12 : busTime!.hour}:${busTime!.minute.toString().padLeft(2, '0')} ${busTime!.hour >= 12 ? 'PM' : 'AM'}"),
                    onTap: () async { final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 14, minute: 00)); if (t != null) setDialogState(() => busTime = t); },
                    trailing: busTime != null ? IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: () => setDialogState(()=>busTime = null)) : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () {
                if (oppCtrl.text.isEmpty || locCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill out Opponent and Location!"), backgroundColor: Colors.red));
                  return;
                }
                String finalOpp = isHome ? "vs ${oppCtrl.text}" : "@ ${oppCtrl.text}";
                DateTime sDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, startTime.hour, startTime.minute);
                DateTime eDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, endTime.hour, endTime.minute);
                
                widget.onAddGame(widget.sport, finalOpp, locCtrl.text, sDate, eDate, releaseTime, busTime, lvl);
                Navigator.pop(ctx);
              }, 
              child: const Text("Schedule & Notify")
            )
          ],
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    // PROPOSAL REQUIREMENT: The system shall restrict Coaches from seeing any athlete who has not been medically approved by the AD.
    List<Student> pending = widget.database.where((s) => 
        s.clearanceStatus == ClearanceStatus.approved && 
        s.memberships.any((m) => m.sport == widget.sport && !m.isActive)
    ).toList();

    return Column(
      children: [
        TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          tabs: [
            Showcase(
              key: ShowcaseKeys.coachRosterCheckboxKey,
              description: "Manage your active roster here.",
              child: const Tab(text: "Roster"),
            ), 
            Showcase(
              key: ShowcaseKeys.coachPendingActionsTabKey,
              description: "Approve or Deny incoming athletes.",
              // PROPOSAL REQUIREMENT: The system shall display a "Pending" tab for Coaches, showing cleared athletes who want to join their specific sport.
              child: Tab(
                child: Badge(
                  isLabelVisible: pending.isNotEmpty, 
                  label: Text('${pending.length}'), 
                  child: const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text("Pending"))
                )
              ),
            ), 
            Showcase(
              key: ShowcaseKeys.coachScheduleTabKey,
              description: "View and edit your season schedule.",
              child: const Tab(text: "Schedule")
            )
          ]
        ),
        Expanded(
          child: TabBarView(
            children: [
              // Roster Tab 
              Column(
                children: [
                  if (_expandedLevel == null)
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(10),
                        children: RosterLevel.values.map((l) {
                          int count = widget.database.where((s) => s.memberships.any((m) => m.sport == widget.sport && m.level == l && m.isActive)).length;
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: Card(
                                color: Theme.of(context).cardColor,
                                child: ListTile(
                                  leading: const Icon(Icons.folder, color: Colors.orangeAccent),
                                  title: Text(l.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text("$count Athletes"),
                                  trailing: const Icon(Icons.arrow_forward_ios),
                                  onTap: () => setState(() => _expandedLevel = l),
                                )
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    )
                  else ...[
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.drive_folder_upload, color: Colors.green),
                              title: const Text("Go Back to Levels"),
                              subtitle: Text("Current View: ${_expandedLevel!.name.toUpperCase()}"),
                              onTap: () => setState(() { _expandedLevel = null; _selectedStudents.clear(); }),
                            ),
                            if (_selectedStudents.isNotEmpty && !widget.isReadOnly)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0), 
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                                  icon: const Icon(Icons.swap_horiz, color: Colors.white), 
                                  label: Text("Move ${_selectedStudents.length} Players", style: const TextStyle(color: Colors.white)), 
                                  onPressed: _showRosterMoveDialog
                                )
                              ),
                            const Divider(),
                          ],
                        )
                      ),
                    ),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          List<Student> roster = widget.database.where((s) => s.memberships.any((m) => m.sport == widget.sport && m.level == _expandedLevel && m.isActive)).toList();
                          if (roster.isEmpty) return const Center(child: Text("Empty Roster"));
                          return ListView.builder(
                            itemCount: roster.length,
                            itemBuilder: (ctx, i) {
                              final s = roster[i];
                              bool isMedicallyCleared = s.clearanceStatus == ClearanceStatus.approved;
                              bool hasActiveDrNote = s.doctorsNotes.any((n) => !n.isCleared);
                              bool isInjured = widget.injuries.any((inj) => inj.studentId == s.id && inj.isActive);
                              
                              // PROPOSAL REQUIREMENT: The system shall alert the Coach visually if a rostered athlete is marked as injured or has a medical hold.
                              Color statusColor = Colors.green; String statusText = "CLEARED";
                              if (isInjured) { statusColor = Colors.red; statusText = "INJURED - DO NOT PLAY"; }
                              else if (!isMedicallyCleared) { statusColor = Colors.red; statusText = "UNCLEARED - DO NOT PLAY"; }
                              else if (hasActiveDrNote) { statusColor = Colors.orange; statusText = "MEDICAL HOLD"; }

                              return Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 800),
                                  child: Card(
                                    color: Theme.of(context).cardColor,
                                    child: ListTile(
                                      leading: widget.isReadOnly ? const CircleAvatar(child: Icon(Icons.person)) : Checkbox(value: _selectedStudents.contains(s.id), onChanged: (v) => setState(() { if (v == true) _selectedStudents.add(s.id); else _selectedStudents.remove(s.id); })),
                                      title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text("ID: ${s.id} | Grade: ${s.grade}\nStatus: $statusText", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                                      trailing: IconButton(icon: const Icon(Icons.medical_information, color: Colors.red), onPressed: () => showUniversalEmergencyCard(context, s), tooltip: "Emergency Card"),
                                    )
                                  )
                                )
                              );
                            }
                          );
                        }
                      )
                    )
                  ]
                ],
              ),
              
              // Pending Tab
              ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: const Text("Action Center", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
                  ...widget.notifications.map((n) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: Card(color: Theme.of(context).primaryColor.withOpacity(0.1), child: ListTile(leading: const Icon(Icons.info, color: Colors.blue), title: Text(n)))))).toList(),
                  const Divider(height: 40),
                  Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: const Text("Pending Roster Requests", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
                  if (pending.isEmpty) 
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0), 
                        child: Text(
                          "No pending requests. \n(Athletes will only appear here after the Athletic Director approves their medical clearance.)", 
                          textAlign: TextAlign.center, 
                          style: TextStyle(color: Colors.grey)
                        )
                      )
                    ),
                  ...pending.map((s) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: Card(color: Theme.of(context).cardColor, child: ListTile(title: Text(s.fullName), subtitle: Text("Grade: ${s.grade} | Clearance: ${s.clearanceStatus.name.toUpperCase()}"), trailing: widget.isReadOnly ? const SizedBox() : Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => widget.onRosterAction(s.id, widget.sport, false)), IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => widget.onRosterAction(s.id, widget.sport, true))])))))).toList()
                ]
              ),

              // Schedule Tab
              SharedCalendarView(
                events: widget.schedule, 
                filterSport: widget.sport, 
                onUpdateScore: widget.onUpdateScore,
                topWidget: widget.isReadOnly ? null : Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Showcase(
                      key: ShowcaseKeys.coachAddGameKey,
                      description: "Add a new game here to notify athletes of their release times.",
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text("Schedule Game & Trigger Releases", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: _showAddGameDialog
                      ),
                    ),
                  ),
                )
              )
            ]
          )
        )
      ],
    );
  }
}