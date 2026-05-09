import 'dart:io';
import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:flutter/services.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:showcaseview/showcaseview.dart';

import '../constants.dart';
import '../models/student.dart';
import '../models/inventory.dart';
import '../models/sports.dart';
import '../models/report.dart';
import '../widgets/calendar_view.dart';
import '../widgets/emergency_card.dart';
import '../showcase_keys.dart';

class DirectoryView extends StatefulWidget {
  final String role;
  final List<Student> database;
  final List<InventoryItem> inventory;
  final List<InventoryFolder> folders;
  final List<GameEvent> schedule;
  final List<InjuryReport> injuries;
  final List<String> notifications;
  final String currentSchool; 
  final List<SportDefinition> availableSports; 
  final Function(int, String) onAddInjury;
  final VoidCallback onMarkInjuriesRead;
  final Function(InjuryReport) onClearInjury;
  final Function(int, bool, {String? reason}) onClearanceAction;
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
  final VoidCallback onSimulateCronJob; 
  final Function(String) onSyncICal;
  final Function(String) onRestockPing;
  final Function(String, String) onLoanMedicalItem;
  final Function(String, String, String) onBoomerangPing; 
  final Function(int) onDismissNotification; 

  const DirectoryView({
    super.key, required this.role, required this.database, required this.inventory, required this.folders, required this.schedule, required this.injuries, required this.notifications, required this.currentSchool, required this.availableSports,
    required this.onAddInjury, required this.onMarkInjuriesRead, required this.onClearInjury, required this.onClearanceAction, required this.onCreateItem, required this.onCreateFolder, 
    required this.onDeleteItem, required this.onDeleteFolder, required this.onRenameItem, required this.onRenameFolder, required this.onMoveItem, required this.onMoveFolder,
    required this.onCheckoutItem, required this.onCheckInItem, required this.onMarkMissing, required this.onAddStudentNote, required this.onSimulateCronJob, required this.onSyncICal,
    required this.onRestockPing, required this.onLoanMedicalItem, required this.onBoomerangPing, required this.onDismissNotification
  });

  @override
  State<DirectoryView> createState() => _DirectoryViewState();
}

class _DirectoryViewState extends State<DirectoryView> {
  final _icalCtrl = TextEditingController(); 
  final _checkoutIdCtrl = TextEditingController(); 
  final _checkoutBarcodeCtrl = TextEditingController();
  final _restockCtrl = TextEditingController();
  final _medItemNameCtrl = TextEditingController();
  
  Student? _foundStudent;
  String? _navSport; 
  String? _navLevel; 
  String? _currentFolderId;
  String _reportSelection = "Athletics Summary"; 
  String? _checkInBarcodeScanned;
  String? _inviteSportSelection; 
  
  @override
  void dispose() {
    _icalCtrl.dispose(); 
    _checkoutIdCtrl.dispose(); 
    _checkoutBarcodeCtrl.dispose(); 
    _restockCtrl.dispose(); 
    _medItemNameCtrl.dispose();
    super.dispose();
  }

  void _resetNav() => setState(() { _navSport = null; _navLevel = null; _foundStudent = null; });

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

  // PROPOSAL REQUIREMENT: The system shall allow administrators to generate secure invite links to upgrade users to AD, Coach, Trainer, or Attendant roles.
  void _generateInviteLink(String targetRole, {String? sport}) {
    if (!kIsWeb) { 
      rootScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Link generation is only supported on the Live Web Dashboard."), backgroundColor: kWarningOrange)); 
      return; 
    }
    String origin = Uri.base.origin;
    String safeSchool = "Rancho Alamitos High School";
    String inviteUrl = "$origin/?invite=${Uri.encodeComponent(targetRole)}&school=${Uri.encodeComponent(safeSchool)}";
    if (sport != null) inviteUrl += "&sport=${Uri.encodeComponent(sport)}";
    
    Clipboard.setData(ClipboardData(text: inviteUrl));
    rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text("Invite Link for $targetRole Copied!"), backgroundColor: Colors.green));
  }

  void _showInjuryDialog(int id) { 
    final c = TextEditingController(); 
    Color txtColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;

    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: Text("Log Injury", style: TextStyle(color: txtColor, fontWeight: FontWeight.bold)), 
      content: TextField(
        autofocus: true, 
        controller: c, 
        style: TextStyle(color: txtColor),
        decoration: InputDecoration(labelText: "Injury Description", labelStyle: TextStyle(color: txtColor.withOpacity(0.7)))
      ), 
      actions: [ 
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: TextStyle(color: txtColor))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
          onPressed: () { 
            if (c.text.isNotEmpty) { 
              widget.onAddInjury(id, c.text); 
              Navigator.pop(ctx); 
              setState(() {}); 
            } 
          }, 
          child: const Text("Submit", style: TextStyle(color: Colors.white))
        ) 
      ]
    )); 
  }

  void _showAddNoteDialog(int id) { 
    final c = TextEditingController(); 
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor, 
      title: Text("Add Staff Note", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)), 
      content: TextField(
        controller: c, 
        autofocus: true, 
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
        decoration: InputDecoration(labelText: "Enter Note", labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7)))
      ), 
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
        ElevatedButton(onPressed: () { widget.onAddStudentNote(id, c.text); Navigator.pop(ctx); setState(() {}); }, child: const Text("Save", style: TextStyle(color: Colors.white)))
      ]
    )); 
  }

  void _showImageDialog(String title, String? path) { 
    Widget imageWidget = path == null 
      ? Center(child: Text("No document provided.", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))) 
      : (path.startsWith('data:image') 
          ? Image.memory(base64Decode(path.split(',').last), fit: BoxFit.contain) 
          : (path.startsWith('http') ? Image.network(path) : (kIsWeb ? Image.network(path) : Image.file(File(path)))));

    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: Text(title, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)), 
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8, 
        height: MediaQuery.of(context).size.height * 0.8, 
        child: InteractiveViewer(panEnabled: true, minScale: 0.5, maxScale: 4.0, child: imageWidget)
      ),
      actions: [ TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Close", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))) ]
    )); 
  }

  void _simulateReportExport(String title, List<Map<String, dynamic>> dataRows) async {
    if (title == "CSV") {
      String csv = "Sport,Level,Wins,Losses,Ties,WinPct\n";
      for(var row in dataRows) { csv += "${row['sport']},${row['level']},${row['w']},${row['l']},${row['t']},${row['pct']}\n"; }
      final bytes = utf8.encode(csv); 
      final base64Str = base64Encode(bytes);
      try { await launchUrl(Uri.parse("data:text/csv;base64,$base64Str")); } catch (e) {}
    } else if (title == "Email" || title == "Print") {
      final pdf = pw.Document();
      pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (pw.Context context) {
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text("${widget.currentSchool} Athletics", style: pw.TextStyle(fontSize: 18, color: PdfColors.grey)), pw.SizedBox(height: 10),
          pw.Text("Athletics Summary Report", style: pw.TextStyle(fontSize: 30, fontWeight: pw.FontWeight.bold)), pw.Divider(thickness: 2), pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            context: context, 
            cellPadding: const pw.EdgeInsets.all(8), 
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white), 
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green800), 
            data: <List<String>>[['Sport', 'Level', 'W', 'L', 'T', 'Win %'], ...dataRows.map((r) => [r['sport'].toString(), r['level'].toString(), r['w'].toString(), r['l'].toString(), r['t'].toString(), r['pct'].toString()])]
          )
        ]);
      }));
      if (title == "Print") await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Athletics_Summary');
      else if (title == "Email") await Printing.sharePdf(bytes: await pdf.save(), filename: 'Athletics_Summary.pdf');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_foundStudent != null) {
      return Column(children: [AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _resetNav), title: const Text("Search Result")), Expanded(child: _buildStudentProfile(_foundStudent!))]);
    }

    List<Widget> tabs = [const Tab(text: "Athletes")];
    List<Widget> views = [Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: _buildHierarchicalRoster()))]; 
    
    int pendingCount = widget.database.where((s) => s.clearanceStatus == ClearanceStatus.pending).length;
    int unreadInjuries = widget.database.expand((s) => s.injuryHistory).where((i) => !i.isRead && i.isActive).length;

    if (widget.role == 'Athletic Director') {
      tabs.addAll([
        Tab(icon: Showcase(key: ShowcaseKeys.adClearanceTabKey, description: "Review and approve student medical clearances.", child: Badge(isLabelVisible: pendingCount > 0, label: Text('$pendingCount'), child: Showcase(key: ShowcaseKeys.adClearanceBadgeKey, description: "This badge alerts you to new clearance requests.", child: const Icon(Icons.verified_user)))), text: "Clearances"),
        // PROPOSAL REQUIREMENT: The system shall allow the AD to view students who are injured.
        Tab(icon: Showcase(key: ShowcaseKeys.adInjuredListKey, description: "Oversee all currently injured athletes and medical holds.", child: Badge(isLabelVisible: unreadInjuries > 0, label: Text('$unreadInjuries'), child: const Icon(Icons.local_hospital))), text: "Injured List"),
        Tab(icon: Showcase(key: ShowcaseKeys.adSystemOpsTabKey, description: "Manage school-wide settings, roster overrides, and staff invites.", child: const Icon(Icons.settings_system_daydream)), text: "System Ops"),
        Tab(icon: Showcase(key: ShowcaseKeys.adMasterCalendarTabKey, description: "View the master schedule for all sports across the entire school.", child: const Icon(Icons.calendar_month)), text: "Master Calendar"),
        Tab(icon: Showcase(key: ShowcaseKeys.adReportsTabKey, description: "Generate compliance and financial reports.", child: const Icon(Icons.analytics)), text: "Reports"),
      ]);
      views.addAll([
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: _buildClearanceQueue())), 
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: _buildInjuriesTab())), 
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: _buildSystemOpsTab())), 
        _buildMasterCalendar(), 
        _buildReportsTab()
      ]);
    } else if (widget.role == 'Trainer') {
      tabs.addAll([
        Tab(icon: Showcase(key: ShowcaseKeys.trainerMedBayHubTabKey, description: "Your daily Med-Bay traffic and urgent alerts.", child: const Icon(Icons.healing)), text: "Med Bay Hub"),
        Tab(icon: Showcase(key: ShowcaseKeys.trainerInjuredListTabKey, description: "Track active injuries and communicate with coaches.", child: Badge(isLabelVisible: unreadInjuries > 0, label: Text('$unreadInjuries'), child: const Icon(Icons.accessible))), text: "Injured List"),
        Tab(icon: Showcase(key: ShowcaseKeys.trainerDocNotesTabKey, description: "Review uploaded doctor notes to clear players for practice.", child: const Icon(Icons.medical_information)), text: "Doc Notes"),
        Tab(icon: Showcase(key: ShowcaseKeys.trainerInventoryTabKey, description: "Manage tape, braces, and medical supplies.", child: Showcase(key: ShowcaseKeys.trainerReportsTabKey, description: "Log treatment reports and incident histories.", child: const Icon(Icons.inventory))), text: "Inventory"),
      ]);
      views.addAll([
        _buildTrainerMedHub(), 
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: _buildInjuriesTab())), 
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: _buildDoctorNotesTab())), 
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: _buildCatalog()))
      ]);
    } else if (widget.role == 'Attendant') {
      tabs.addAll([
        Tab(icon: Showcase(key: ShowcaseKeys.attendantCheckOutTabKey, description: "Scan barcodes to issue gear to students.", child: const Icon(Icons.outbox)), text: "Check Out"),
        Tab(icon: Showcase(key: ShowcaseKeys.attendantCheckInTabKey, description: "Scan gear to return it to the armory.", child: const Icon(Icons.move_to_inbox)), text: "Check In"),
        Tab(icon: Showcase(key: ShowcaseKeys.attendantCatalogTabKey, description: "Manage your digital locker room and equipment catalog.", child: const Icon(Icons.category)), text: "Catalog"),
        Tab(icon: Showcase(key: ShowcaseKeys.attendantReportsTabKey, description: "Audit inventory and track missing items.", child: const Icon(Icons.assignment)), text: "Reports"),
        Tab(icon: Showcase(key: ShowcaseKeys.attendantLostFinesTabKey, description: "Assign fines to students for lost or damaged equipment.", child: const Icon(Icons.request_quote)), text: "Lost/Fines")
      ]);
      views.addAll([
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: _buildUnifiedCheckOutHub())),
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: _buildCheckInTab())),
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: _buildCatalog())),
        _buildReportsTab(),
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: _buildMissingTab()))
      ]);
    }

    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800), 
            child: Padding(
              padding: const EdgeInsets.all(8.0), 
              // PROPOSAL REQUIREMENT: The system shall provide the AD with a comprehensive list of all students registered in the system with predictive text search.
              child: Autocomplete<Student>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') return const Iterable<Student>.empty();
                  return widget.database.where((Student student) => 
                    student.fullName.toLowerCase().contains(textEditingValue.text.toLowerCase()) || 
                    student.id.toString().contains(textEditingValue.text)
                  );
                },
                displayStringForOption: (Student option) => '${option.fullName} (ID: ${option.id})',
                fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                  return TextField(
                    controller: textEditingController, 
                    focusNode: focusNode,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      labelText: 'Search Athlete by Name or ID...',
                      prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true, 
                      fillColor: Theme.of(context).cardColor,
                    ),
                  );
                },
                onSelected: (Student selection) { setState(() => _foundStudent = selection); },
              )
            )
          )
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800), 
            child: TabBar(isScrollable: true, tabAlignment: TabAlignment.center, tabs: tabs)
          )
        ),
        Expanded(child: TabBarView(children: views))
      ],
    );
  }

  Widget _buildTrainerMedHub() {
    final checkedOutMedItems = widget.inventory.where((i) => i.status == ItemStatus.checkedOut && i.barcode.startsWith("MED_")).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Card(
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade900, width: 2)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                        SizedBox(width: 10),
                        Text("Consumables Restock Alert", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text("Notify the Athletic Director immediately if you are out of Band-Aids, athletic tape, ice packs, or other daily consumables.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(
                          controller: _restockCtrl,
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                          decoration: InputDecoration(labelText: "What do you need ordered?", labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7)), border: const OutlineInputBorder())
                        )),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15)),
                          icon: const Icon(Icons.send, color: Colors.white),
                          label: const Text("Ping AD", style: TextStyle(color: Colors.white)),
                          onPressed: () {
                            if (_restockCtrl.text.isNotEmpty) {
                              widget.onRestockPing(_restockCtrl.text);
                              rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text("Restock Alert sent to Athletic Director: ${_restockCtrl.text}"), backgroundColor: Colors.green));
                              _restockCtrl.clear();
                            }
                          }
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Card(
              color: Theme.of(context).cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Loan Medical Equipment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Text("Checkout crutches, braces, or boots. No barcode required.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(
                          controller: _checkoutIdCtrl, keyboardType: TextInputType.number,
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                          decoration: InputDecoration(labelText: "Student ID Number", labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7)))
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(
                          controller: _medItemNameCtrl,
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                          decoration: InputDecoration(labelText: "Medical Item (e.g. Crutches)", labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7)))
                        )),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                        onPressed: () {
                          if (_checkoutIdCtrl.text.isNotEmpty && _medItemNameCtrl.text.isNotEmpty) {
                            widget.onLoanMedicalItem(_checkoutIdCtrl.text, _medItemNameCtrl.text);
                            _medItemNameCtrl.clear(); _checkoutIdCtrl.clear();
                            setState((){});
                          }
                        },
                        label: const Text("Log Loan", style: TextStyle(color: Colors.white))
                      )
                    )
                  ]
                )
              )
            )
          )
        ),

        const SizedBox(height: 20),
        const Center(child: Text("Active Medical Loans", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
        if (checkedOutMedItems.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No medical items currently checked out.", style: TextStyle(color: Colors.grey)))),

        ...checkedOutMedItems.map((item) {
           Student? student;
           try { student = widget.database.firstWhere((s) => s.id.toString() == item.assignedToStudentId); } catch(e) {}

           String dt = item.dateCheckedOut != null ? "${item.dateCheckedOut!.month}/${item.dateCheckedOut!.day}/${item.dateCheckedOut!.year}" : "Unknown Date";
           return Center(
             child: ConstrainedBox(
               constraints: const BoxConstraints(maxWidth: 800),
               child: Card(
                 color: Theme.of(context).cardColor,
                 child: ListTile(
                   leading: const Icon(Icons.wheelchair_pickup, color: Colors.blue, size: 30),
                   title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                   subtitle: Text("Loaned To: ${student?.fullName ?? 'Unknown'}\nDate: $dt"),
                   trailing: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       IconButton(
                         icon: const Icon(Icons.notifications_active, color: kWarningOrange),
                         tooltip: "Send Boomerang Alert",
                         onPressed: () {
                           if (student == null) return;
                           String activeSport = "Unknown";
                           try { activeSport = student.memberships.firstWhere((m) => m.isActive).sport; } catch(e) {}

                           showDialog(context: context, builder: (ctx) => AlertDialog(
                             backgroundColor: Theme.of(context).cardColor,
                             title: Text("Send Boomerang Alert?", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
                             content: Text("This will send a Push Notification and Email to ${student!.firstName} and the $activeSport Head Coach demanding the immediate return of the ${item.name}.", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                             actions: [
                               TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
                               ElevatedButton(
                                 style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                 onPressed: () {
                                   widget.onBoomerangPing(student!.id.toString(), activeSport, item.name);
                                   Navigator.pop(ctx);
                                   rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
                                     content: Text("Alert successfully dispatched to ${student!.firstName} and $activeSport Coach!"),
                                     backgroundColor: Colors.green
                                   ));
                                 },
                                 child: const Text("Send Alert", style: TextStyle(color: Colors.white))
                               )
                             ],
                           ));
                         }
                       ),
                       IconButton(
                         icon: const Icon(Icons.check_circle, color: Colors.green),
                         tooltip: "Mark Returned",
                         onPressed: () {
                            widget.onCheckInItem(item.barcode);
                            setState((){});
                         }
                       ),
                     ],
                   )
                 )
               )
             )
           );
        })
      ]
    );
  }

  Widget _buildHierarchicalRoster() {
    if (_navSport == null) {
      final uniqueSports = widget.database.expand((s) => s.memberships.map((m) => m.sport)).toSet().toList(); 
      uniqueSports.sort();
      return ListView.builder(
        itemCount: uniqueSports.length, 
        itemBuilder: (ctx, i) {
          int count = widget.database.where((s) => s.memberships.any((m) => m.sport == uniqueSports[i] && m.isActive)).length;
          return Card(
            color: Theme.of(context).cardColor, 
            child: ListTile(
              leading: Icon(_getSportIcon(uniqueSports[i]), color: Theme.of(context).primaryColor, size: 30), 
              title: Text(uniqueSports[i]), 
              subtitle: Text("$count Athletes"), 
              trailing: const Icon(Icons.arrow_forward_ios), 
              onTap: () => setState(() => _navSport = uniqueSports[i])
            )
          );
        }
      );
    }
    if (_navLevel == null) {
      return Column(children: [
        ListTile(
          leading: const Icon(Icons.drive_folder_upload, color: kSchoolGreen), 
          title: const Text("Go Back to Sports"), 
          subtitle: Text("Current: $_navSport"), 
          onTap: () => setState(() => _navSport = null)
        ), 
        const Divider(),
        Expanded(
          child: ListView(
            children: RosterLevel.values.map((l) {
              int count = widget.database.where((s) => s.memberships.any((m) => m.sport == _navSport && m.level == l && m.isActive)).length;
              return Card(
                color: Theme.of(context).cardColor, 
                child: ListTile(
                  leading: const Icon(Icons.group), 
                  title: Text(l.name.toUpperCase()), 
                  subtitle: Text("$count Players"), 
                  trailing: const Icon(Icons.arrow_forward_ios), 
                  onTap: () => setState(() => _navLevel = l.name)
                )
              );
            }).toList()
          )
        )
      ]);
    }
    final roster = widget.database.where((s) => s.memberships.any((m) => m.sport == _navSport && m.level.name.toLowerCase() == _navLevel!.toLowerCase() && m.isActive)).toList();
    return Column(children: [
      ListTile(
        leading: const Icon(Icons.drive_folder_upload, color: kSchoolGreen), 
        title: const Text("Go Back to Levels"), 
        subtitle: Text("Current: $_navSport > $_navLevel"), 
        onTap: () => setState(() => _navLevel = null)
      ), 
      const Divider(),
      Expanded(
        child: roster.isEmpty 
          ? const Center(child: Text("Empty Roster")) 
          : ListView.builder(
              itemCount: roster.length, 
              itemBuilder: (ctx, i) {
                bool isInjured = roster[i].injuryHistory.any((inj) => inj.isActive);
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)), 
                  title: Row(
                    children: [
                      Text(roster[i].fullName), 
                      if(isInjured) const Padding(padding: EdgeInsets.only(left: 8.0), child: Icon(Icons.local_hospital, color: Colors.red, size: 16))
                    ]
                  ), 
                  subtitle: Text("ID: ${roster[i].id}"), 
                  onTap: () => setState(() => _foundStudent = roster[i])
                );
              }
            )
      )
    ]);
  }

  Widget _buildStudentProfile(Student s) {
    bool isInjured = s.injuryHistory.any((i) => i.isActive);
    String clearanceText = isInjured ? "INJURED - DO NOT PLAY" : s.clearanceStatus.name.toUpperCase();
    Color clearanceColor = isInjured ? Colors.red : (s.clearanceStatus == ClearanceStatus.approved ? Colors.green : Colors.orange);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800), 
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(s.fullName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                Text("ID: ${s.id} | Grade: ${s.grade}"),
                const SizedBox(height: 10), 
                const Text("Clearance Status", style: TextStyle(color: Colors.grey)),
                Text(clearanceText, style: TextStyle(color: clearanceColor, fontWeight: FontWeight.bold)),
                const Divider(),
                const Text("Active Sports", style: TextStyle(color: Colors.grey)),
                if (s.memberships.isEmpty) const Text("None"), 
                ...s.memberships.where((m) => m.isActive).map((m) => Text("• ${m.sport} (${m.level.name.toUpperCase()})")),
                const SizedBox(height: 20),
                Row(
                  children: [ 
                    Expanded(
                      // PROPOSAL REQUIREMENT: The system shall provide Trainers with access to student Emergency Cards.
                      child: ElevatedButton(
                        onPressed: () => showUniversalEmergencyCard(context, s), 
                        child: const Text("Emergency Card", style: TextStyle(color: Colors.white))
                      )
                    ), 
                    const SizedBox(width: 10), 
                    if (widget.role == 'Trainer') 
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), 
                          // PROPOSAL REQUIREMENT: The system shall allow Trainers to log injuries, dynamically revoking the student's clearance status until cleared by a doctor.
                          onPressed: () => _showInjuryDialog(s.id), 
                          child: const Text("Log Injury", style: TextStyle(color: Colors.white))
                        )
                      ), 
                  ]
                ),
                const Divider(thickness: 2, height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [ 
                    Text("Staff Notes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)), 
                    IconButton(icon: const Icon(Icons.add_circle, color: kSchoolGreen), onPressed: () => _showAddNoteDialog(s.id)), 
                  ]
                ),
                if (s.staffNotes.isEmpty) const Text("No notes.", style: TextStyle(color: Colors.grey)),
                ...s.staffNotes.reversed.map((note) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text("• $note"))),
              ]
            )
          ]
        )
      )
    );
  }

  Widget _buildUnifiedCheckOutHub() {
    final checkedOutItems = widget.inventory.where((i) => i.status == ItemStatus.checkedOut && !i.barcode.startsWith("MED_")).toList();
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0), 
          child: Column(
            children: [
              const Text("Check Out New Item", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), 
              TextField(
                controller: _checkoutIdCtrl, 
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                decoration: InputDecoration(labelText: "Student ID Number", labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7)))
              ), 
              TextField(
                controller: _checkoutBarcodeCtrl, 
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                decoration: InputDecoration(labelText: "Item Barcode", labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7)))
              ), 
              const SizedBox(height: 10), 
              SizedBox(
                width: double.infinity, 
                child: ElevatedButton(
                  onPressed: () { 
                    widget.onCheckoutItem(_checkoutIdCtrl.text, _checkoutBarcodeCtrl.text); 
                    _checkoutBarcodeCtrl.clear(); 
                    _checkoutIdCtrl.clear(); 
                  }, 
                  child: const Text("Check Out", style: TextStyle(color: Colors.white))
                )
              )
            ]
          )
        ),
        const Divider(),
        const Center(child: Text("Currently Checked Out", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
        if (checkedOutItems.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No items currently checked out.", style: TextStyle(color: Colors.grey)))),
        ...checkedOutItems.map((item) {
           Student? student; 
           try { student = widget.database.firstWhere((s) => s.id.toString() == item.assignedToStudentId); } catch(e){}
           String dt = item.dateCheckedOut != null ? "${item.dateCheckedOut!.month}/${item.dateCheckedOut!.day}/${item.dateCheckedOut!.year}" : "Unknown Date";
           return ListTile(
             leading: const Icon(Icons.checkroom, color: Colors.green), 
             title: Text(item.name), 
             subtitle: Text("Barcode: ${item.barcode}\nStudent: ${student?.fullName ?? 'Unknown'}\nOut Since: $dt"), 
             trailing: IconButton(icon: const Icon(Icons.warning, color: Colors.orange), tooltip: "Mark Missing", onPressed: () => _showMissingDialog(item.barcode))
           );
        })
      ]
    );
  }

  Widget _buildCheckInTab() {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0), 
          child: Column(
            children: [
              TextField(
                autofocus: true, 
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                decoration: InputDecoration(
                  labelText: "Scan Item Barcode to Return", 
                  labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7)), 
                  prefixIcon: const Icon(Icons.qr_code_scanner)
                ), 
                onChanged: (val) => setState(() => _checkInBarcodeScanned = val)
              ), 
              const SizedBox(height: 30), 
              if (_checkInBarcodeScanned != null && _checkInBarcodeScanned!.isNotEmpty) ...[
                Builder(
                  builder: (ctx) { 
                    try { 
                      final item = widget.inventory.firstWhere((i) => i.barcode == _checkInBarcodeScanned && i.status != ItemStatus.available); 
                      Student? student; 
                      try { student = widget.database.firstWhere((s) => s.id.toString() == item.assignedToStudentId); } catch(e){} 
                      return Card(
                        color: Theme.of(context).cardColor, 
                        child: ListTile(
                          leading: const Icon(Icons.check_circle, color: Colors.green, size: 40), 
                          title: Text("Return ${item.name}?"), 
                          subtitle: Text("Currently assigned to: ${student?.fullName ?? 'Unknown'}"), 
                          trailing: ElevatedButton(
                            onPressed: () { 
                              widget.onCheckInItem(item.barcode); 
                              setState(() => _checkInBarcodeScanned = ""); 
                            }, 
                            child: const Text("Confirm Check-In", style: TextStyle(color: Colors.white))
                          )
                        )
                      ); 
                    } catch(e) { 
                      return const Text("No checked-out item matches that barcode.", style: TextStyle(color: Colors.grey)); 
                    } 
                  }
                )
              ] 
            ]
          )
        )
      ]
    );
  }

  void _showMissingDialog(String barcode) { 
    final ctrl = TextEditingController(); 
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor, 
        title: const Text("Mark Missing & Assign Fine", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), 
        content: TextField(
          autofocus: true, controller: ctrl, keyboardType: TextInputType.number, 
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          decoration: InputDecoration(prefixText: "\$", labelText: "Fine Amount", labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7)))
        ), 
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text("Cancel", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
            onPressed: (){ 
              double fine = double.tryParse(ctrl.text) ?? 0.0; 
              widget.onMarkMissing(barcode, fine); 
              Navigator.pop(ctx); 
            }, 
            child: const Text("Submit", style: TextStyle(color: Colors.white))
          )
        ]
      )
    ); 
  }

  Widget _buildMissingTab() {
    final missingItems = widget.inventory.where((i) => i.status == ItemStatus.missing).toList();
    if (missingItems.isEmpty) return const Center(child: Text("No missing items.", style: TextStyle(color: Colors.grey)));
    
    return ListView.builder(
      itemCount: missingItems.length, 
      itemBuilder: (ctx, i) {
        final item = missingItems[i]; 
        Student? student; 
        try { student = widget.database.firstWhere((s) => s.id.toString() == item.assignedToStudentId); } catch(e){}
        return ListTile(
          leading: const Icon(Icons.cancel, color: Colors.red), 
          title: Text(item.name, style: const TextStyle(decoration: TextDecoration.lineThrough)), 
          subtitle: Text("Lost By: ${student?.fullName ?? 'Unknown'}"), 
          trailing: Text("\$${item.fineAmount.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18))
        );
      }
    );
  }

  Widget _buildSystemOpsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.notifications.isNotEmpty) ...[
          const Text("AD Action Center", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
          const SizedBox(height: 10),
          ...widget.notifications.asMap().entries.map((entry) => 
            Card(
              color: Colors.red.withOpacity(0.1), 
              child: ListTile(
                leading: const Icon(Icons.warning, color: Colors.red), 
                title: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.bold)), 
                trailing: IconButton(icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 28), onPressed: () => widget.onDismissNotification(entry.key))
              )
            )
          ).toList(),
          const Divider(height: 40),
        ],
        const Text("Staff Invitation Links", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const Text("Copy and email these specialized links to onboard new district staff to your specific school dashboard.", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 10),
        Card(
          color: Theme.of(context).cardColor, 
          child: ListTile(
            leading: const Icon(Icons.admin_panel_settings), 
            title: const Text("Invite Co-Admin (Athletic Director)"), 
            trailing: const Icon(Icons.copy, color: Colors.blue), 
            onTap: () => _generateInviteLink('Athletic Director')
          )
        ),
        Card(
          color: Theme.of(context).cardColor, 
          child: Padding(
            padding: const EdgeInsets.all(12.0), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                const Text("Invite Head Coach", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), 
                const SizedBox(height: 5),
                Row(
                  children: [ 
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _inviteSportSelection, 
                        dropdownColor: Theme.of(context).cardColor, 
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                        decoration: const InputDecoration(labelText: "Select Sport First", border: OutlineInputBorder()), 
                        items: widget.availableSports.map((s) => DropdownMenuItem(value: s.name, child: Text(s.name))).toList(), 
                        onChanged: (v) => setState(() => _inviteSportSelection = v)
                      )
                    ), 
                    const SizedBox(width: 10), 
                    ElevatedButton.icon(
                      icon: const Icon(Icons.copy, color: Colors.white), 
                      label: const Text("Copy Link", style: TextStyle(color: Colors.white)), 
                      onPressed: () { 
                        if (_inviteSportSelection == null) { 
                          rootScaffoldMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Please select a sport first!"), backgroundColor: kWarningOrange)); 
                        } else { 
                          _generateInviteLink('Head Coach', sport: _inviteSportSelection); 
                        } 
                      }
                    )
                  ]
                )
              ]
            )
          )
        ),
        const SizedBox(height: 10),
        Card(
          color: Theme.of(context).cardColor, 
          child: ListTile(
            leading: const Icon(Icons.medical_services), 
            title: const Text("Invite Trainer"), 
            trailing: const Icon(Icons.copy, color: Colors.blue), 
            onTap: () => _generateInviteLink('Trainer')
          )
        ),
        Card(
          color: Theme.of(context).cardColor, 
          child: ListTile(
            leading: const Icon(Icons.checkroom), 
            title: const Text("Invite Equipment Attendant"), 
            trailing: const Icon(Icons.copy, color: Colors.blue), 
            onTap: () => _generateInviteLink('Attendant')
          )
        ),
        const Divider(height: 40),
        const Text("Server Overrides", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          icon: const Icon(Icons.schedule, color: Colors.white), 
          label: const Text("Simulate Daily Cron Job (Seed Dummy Data)", style: TextStyle(color: Colors.white)), 
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), 
          onPressed: widget.onSimulateCronJob
        )
      ]
    );
  }

  Widget _buildMasterCalendar() {
    return SharedCalendarView(
      events: widget.schedule, 
      filterSport: null, 
      homeSchool: widget.currentSchool,
      topWidget: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800), 
          child: Padding(
            padding: const EdgeInsets.all(8.0), 
            child: Row(
              children: [ 
                Expanded(
                  child: TextField(
                    controller: _icalCtrl, 
                    decoration: const InputDecoration(labelText: "Paste District .ics URL here", border: OutlineInputBorder())
                  )
                ), 
                const SizedBox(width: 10), 
                ElevatedButton.icon(
                  icon: const Icon(Icons.sync, color: Colors.white), 
                  label: const Text("Sync iCal", style: TextStyle(color: Colors.white)), 
                  onPressed: () { 
                    widget.onSyncICal(_icalCtrl.text); 
                    _icalCtrl.clear(); 
                  }
                )
              ]
            )
          )
        )
      )
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4), 
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, 
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)), 
        Text(value, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold))
      ]
    )
  );

  void _showDenyDialog(int id) { 
    final c = TextEditingController(); 
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor, 
        title: const Text("Reason for Denial", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), 
        content: TextField(
          autofocus: true, controller: c, 
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
          decoration: InputDecoration(hintText: "Enter reason...", hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.5)))
        ), 
        actions: [ 
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: Text("Cancel", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))
          ), 
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
            onPressed: () { 
              widget.onClearanceAction(id, false, reason: c.text); 
              Navigator.pop(ctx); 
            }, 
            child: const Text("Submit Denial", style: TextStyle(color: Colors.white))
          ) 
        ]
      )
    ); 
  }

  void _showDetailedReviewDialog(Student s) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("Review Clearance: ${s.fullName}", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500, height: 600, 
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                _infoRow("Grade", s.grade), 
                _infoRow("DOB", "${s.dob.month}/${s.dob.day}/${s.dob.year}"), 
                _infoRow("Sex", s.sex), 
                _infoRow("Vitals", "Height: ${s.height} | Weight: ${s.weight}"), 
                _infoRow("Address", s.fullAddress), 
                _infoRow("Student Phones", "Home: ${s.homePhone} | Cell: ${s.mobilePhone}"), 
                _infoRow("Student Email", s.email), 
                _infoRow("School", "${s.school} (Class of ${s.graduationYear})"), 
                _infoRow("Education History", "${s.educationHistory} - Last: ${s.lastSchoolAttended}"),
                const Divider(), 
                Text("PARENTS/GUARDIANS", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)), 
                _infoRow("Living Arrangement", s.livingArrangement), 
                _infoRow("Parent 1", "${s.p1First} ${s.p1Last}\nPhone: ${s.p1Mobile}\nEmail: ${s.p1Email}"), 
                if (s.livingArrangement == "Both Parents") 
                  _infoRow("Parent 2", "${s.p2First} ${s.p2Last}\nPhone: ${s.p2Mobile}\nEmail: ${s.p2Email}"),
                const Divider(), 
                Text("EMERGENCY CONTACT", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)), 
                _infoRow("Name", "${s.emgFirst} ${s.emgLast} (${s.emgRelation})"), 
                _infoRow("Phone", s.emgPhone),
                const Divider(), 
                Text("MEDICAL & INSURANCE", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)), 
                _infoRow("Physician", "${s.physicianName.isEmpty ? 'N/A' : s.physicianName} (${s.physicianPhone.isEmpty ? 'N/A' : s.physicianPhone})"), 
                _infoRow("Covered by Insurance", s.isInsured ? "Yes" : "No"),
                if (s.isInsured) ...[ 
                  _infoRow("Company", s.insuranceCompany), 
                  _infoRow("Policy #", s.insurancePolicyNum), 
                  Row(
                    children: [ 
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.credit_card, color: Colors.white), 
                          onPressed: () => _showImageDialog("Ins Front", s.insuranceFrontPath), 
                          label: const Text("Ins Front", style: TextStyle(color: Colors.white))
                        )
                      ), 
                      const SizedBox(width: 10), 
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.credit_card, color: Colors.white), 
                          onPressed: () => _showImageDialog("Ins Back", s.insuranceBackPath), 
                          label: const Text("Ins Back", style: TextStyle(color: Colors.white))
                        )
                      ) 
                    ]
                  ) 
                ],
                _infoRow("Hospital Pref", "${s.hospitalPreference} ${s.hospitalLocation.isNotEmpty ? '(${s.hospitalLocation})' : ''}"), 
                _infoRow("Allergies/Conditions", s.medicalConditions.isEmpty ? "None" : s.medicalConditions), 
                _infoRow("Physical Date", s.lastPhysicalDate != null ? "${s.lastPhysicalDate!.month}/${s.lastPhysicalDate!.day}/${s.lastPhysicalDate!.year}" : "N/A"),
                const Divider(), 
                Text("PHYSICAL DOCUMENTS", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)), 
                Row(
                  children: [ 
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showImageDialog("Phys Front", s.physicalFrontPath), 
                        child: const Text("View Front", style: TextStyle(color: Colors.white))
                      )
                    ), 
                    const SizedBox(width: 10), 
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showImageDialog("Phys Back", s.physicalBackPath), 
                        child: const Text("View Back", style: TextStyle(color: Colors.white))
                      )
                    ) 
                  ]
                ),
                const Divider(), 
                Text("REQUESTED SPORTS", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)), 
                ...s.memberships.where((m) => !m.isActive).map((m) => Text("• ${m.sport}", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))),
              ]
            )
          )
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), 
            onPressed: () { 
              Navigator.pop(ctx); 
              _showDenyDialog(s.id); 
            }, 
            child: const Text("DENY", style: TextStyle(color: Colors.white))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), 
            onPressed: () { 
              widget.onClearanceAction(s.id, true); 
              Navigator.pop(ctx); 
            }, 
            child: const Text("APPROVE", style: TextStyle(color: Colors.white))
          ),
        ],
      )
    );
  }

  Widget _buildClearanceQueue() => ListView.builder(
    itemCount: widget.database.where((s) => s.clearanceStatus == ClearanceStatus.pending).length, 
    itemBuilder: (c, i) { 
      var s = widget.database.where((s) => s.clearanceStatus == ClearanceStatus.pending).toList()[i]; 
      return Card(
        elevation: 3, 
        margin: const EdgeInsets.symmetric(vertical: 5), 
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.warning, color: Colors.white)), 
          title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold)), 
          subtitle: Text("Grade: ${s.grade} | ID: ${s.id}"), 
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white), 
            onPressed: () => _showDetailedReviewDialog(s), 
            child: const Text("Review Profile")
          )
        )
      );
    }
  );

  Widget _buildInjuriesTab() {
    final activeInjuries = widget.database.expand((s) => s.injuryHistory).where((i) => i.isActive).toList();
    
    if (activeInjuries.isEmpty) return const Center(child: Text("No active injuries.", style: TextStyle(color: Colors.grey)));
    
    return ListView.builder(
      itemCount: activeInjuries.length, 
      itemBuilder: (c, i) {
        final inj = activeInjuries[i];
        return Card(
          color: Theme.of(context).cardColor, 
          child: ListTile(
            leading: const Icon(Icons.medical_services, color: Colors.red), 
            title: Text(inj.studentName, style: const TextStyle(fontWeight: FontWeight.bold)), 
            subtitle: Text("${inj.date}\n${inj.description}"), 
            trailing: widget.role == 'Trainer' 
              ? ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, color: Colors.white), 
                  label: const Text("Clear Player", style: TextStyle(color: Colors.white)), 
                  onPressed: () => widget.onClearInjury(inj)
                ) 
              : const SizedBox()
          )
        );
      }
    );
  }

  Widget _buildDoctorNotesTab() => const Center(child: Text("No pending doctor notes."));

  Widget _buildReportsTab() {
    List<String> options = [];
    List<String> sports = widget.availableSports.map((s) => s.name).toList()..sort();
    
    if (widget.role == 'Athletic Director') {
      options.add("Athletics Summary");
      options.add("All Outstanding Gear");
      options.addAll(sports.map((s) => "$s Outstanding Gear"));
    } else if (widget.role == 'Attendant') {
      options.add("All Fines");
      options.addAll(sports.map((s) => "$s Fines"));
      options.add("All Inventory");
      options.addAll(sports.map((s) => "$s Inventory"));
      options.add("All Outstanding Gear");
      options.addAll(sports.map((s) => "$s Outstanding Gear"));
    } else {
      options.addAll(["Athletics Summary", "All Fines", "All Inventory", "All Outstanding Gear"]);
      options.addAll(sports.map((s) => "$s Fines"));
      options.addAll(sports.map((s) => "$s Inventory"));
      options.addAll(sports.map((s) => "$s Outstanding Gear"));
    }
    
    if (!options.contains(_reportSelection)) {
      _reportSelection = options.first;
    }

    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000), 
            child: Padding(
              padding: const EdgeInsets.all(16.0), 
              child: DropdownButtonFormField<String>(
                value: _reportSelection, 
                dropdownColor: Theme.of(context).cardColor,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(labelText: "Select Report Type", border: OutlineInputBorder()), 
                items: options.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), 
                onChanged: (v) => setState(() => _reportSelection = v!)
              )
            )
          )
        ),
        Expanded(
          child: Builder(
            builder: (ctx) {
              if (_reportSelection == "Athletics Summary") {
                List<Map<String, dynamic>> summaryData = [];
                for (var sportDef in widget.availableSports) {
                  for (var level in RosterLevel.values) {
                    int w = 0, l = 0, t = 0;
                    var games = widget.schedule.where((g) => g.sport == sportDef.name && g.level == level && g.result.isNotEmpty).toList();
                    if (games.isEmpty) continue; 
                    for (var g in games) { 
                      if (g.result == 'W') w++; 
                      else if (g.result == 'L') l++; 
                      else if (g.result == 'T') t++; 
                    }
                    String winPct = (w + l + t) > 0 ? ((w / (w + l + t)) * 100).toStringAsFixed(1) + "%" : "0.0%";
                    summaryData.add({ 'sport': sportDef.name, 'level': level.name.toUpperCase(), 'w': w, 'l': l, 't': t, 'pct': winPct });
                  }
                }
                if (summaryData.isEmpty) return const Center(child: Text("No game data recorded yet for this season."));
                
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Wrap(
                            spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.print, color: Colors.white), 
                                label: const Text("Print", style: TextStyle(color: Colors.white)), 
                                onPressed: () => _simulateReportExport("Print", summaryData)
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.email, color: Colors.white), 
                                label: const Text("Email", style: TextStyle(color: Colors.white)), 
                                onPressed: () => _simulateReportExport("Email", summaryData)
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.download, color: Colors.white), 
                                label: const Text("CSV", style: TextStyle(color: Colors.white)), 
                                onPressed: () => _simulateReportExport("CSV", summaryData)
                              ),
                            ]
                          )
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(Theme.of(context).primaryColor.withOpacity(0.5)),
                                dataRowMinHeight: 60, dataRowMaxHeight: 70, headingRowHeight: 60, columnSpacing: 40,
                                columns: const [
                                  DataColumn(label: Text('Sport', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                  DataColumn(label: Text('Level', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                  DataColumn(label: Text('Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                  DataColumn(label: Text('Win %', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                ],
                                rows: summaryData.map((row) => DataRow(
                                  cells: [
                                    DataCell(Text(row['sport'], style: const TextStyle(fontSize: 15))),
                                    DataCell(Text(row['level'], style: const TextStyle(fontSize: 15))),
                                    DataCell(Text("${row['w']} - ${row['l']} - ${row['t']}", style: const TextStyle(fontSize: 15))),
                                    DataCell(Text(row['pct'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                                  ]
                                )).toList(),
                              )
                            )
                          )
                        )
                      ]
                    )
                  )
                );
              } 
              else if (_reportSelection.contains("Fines")) {
                String targetSport = _reportSelection.replaceAll(" Fines", "").replaceAll("All", "").trim();
                final finedStudents = widget.database.where((s) {
                   bool hasFine = widget.inventory.any((i) => i.assignedToStudentId == s.id.toString() && i.status == ItemStatus.missing);
                   if (!hasFine) return false;
                   if (targetSport.isEmpty) return true; 
                   return s.memberships.any((m) => m.sport == targetSport);
                }).toList();
                if (finedStudents.isEmpty) return const Center(child: Text("No outstanding fines for this selection."));
                
                return ListView.builder(
                  itemCount: finedStudents.length, 
                  itemBuilder: (c, i) {
                    final student = finedStudents[i];
                    final missingItems = widget.inventory.where((inv) => inv.assignedToStudentId == student.id.toString() && inv.status == ItemStatus.missing).toList();
                    double totalFine = missingItems.fold(0, (sum, item) => sum + item.fineAmount);
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800), 
                        child: ExpansionTile(
                          title: Text(student.fullName, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), 
                          subtitle: Text("Total Owed: \$${totalFine.toStringAsFixed(2)}"), 
                          children: missingItems.map((m) => ListTile(
                            title: Text(m.name), 
                            trailing: Text("\$${m.fineAmount.toStringAsFixed(2)}")
                          )).toList()
                        )
                      )
                    );
                  }
                );
              } 
              else if (_reportSelection.contains("Inventory")) {
                String targetSport = _reportSelection.replaceAll(" Inventory", "").replaceAll("All", "").trim();
                final sportStudents = widget.database.where((s) {
                   bool hasItem = widget.inventory.any((inv) => inv.assignedToStudentId == s.id.toString());
                   if (!hasItem) return false;
                   if (targetSport.isEmpty) return true; 
                   return s.memberships.any((m) => m.sport == targetSport);
                }).toList();
                if (sportStudents.isEmpty) return const Center(child: Text("No inventory checked out for this selection."));
                
                return ListView.builder(
                  itemCount: sportStudents.length, 
                  itemBuilder: (c, i) {
                    final student = sportStudents[i];
                    final items = widget.inventory.where((inv) => inv.assignedToStudentId == student.id.toString()).toList();
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800), 
                        child: ExpansionTile(
                          title: Text(student.fullName), 
                          subtitle: Text("${items.length} items on record"), 
                          children: items.map((m) => ListTile(
                            title: Text(m.name), 
                            trailing: Text(m.status.name.toUpperCase())
                          )).toList()
                        )
                      )
                    );
                  }
                );
              }
              else if (_reportSelection.contains("Outstanding Gear")) {
                String targetSport = _reportSelection.replaceAll(" Outstanding Gear", "").replaceAll("All", "").trim();
                final outstandingStudents = widget.database.where((s) {
                   bool hasItem = widget.inventory.any((inv) => inv.assignedToStudentId == s.id.toString() && inv.status == ItemStatus.checkedOut);
                   if (!hasItem) return false;
                   if (targetSport.isEmpty) return true; 
                   return s.memberships.any((m) => m.sport == targetSport);
                }).toList();
                
                if (outstandingStudents.isEmpty) return const Center(child: Text("No outstanding gear for this selection."));
                
                return ListView.builder(
                  itemCount: outstandingStudents.length, 
                  itemBuilder: (c, i) {
                    final student = outstandingStudents[i];
                    final items = widget.inventory.where((inv) => inv.assignedToStudentId == student.id.toString() && inv.status == ItemStatus.checkedOut).toList();
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800), 
                        child: ExpansionTile(
                          title: Text(student.fullName, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)), 
                          subtitle: Text("${items.length} items not turned in"), 
                          children: items.map((m) => ListTile(
                            title: Text(m.name), 
                            trailing: Text(m.dateCheckedOut != null ? "${m.dateCheckedOut!.month}/${m.dateCheckedOut!.day}/${m.dateCheckedOut!.year}" : "Unknown")
                          )).toList()
                        )
                      )
                    );
                  }
                );
              }
              return Container();
            }
          )
        )
      ]
    );
  }

  Widget _buildCatalog() {
    List<InventoryFolder> subs = widget.folders.where((f) => f.parentId == _currentFolderId).toList();
    List<InventoryItem> items = widget.inventory.where((i) => i.folderId == _currentFolderId && (widget.role == 'Trainer' || !i.barcode.startsWith("MED_"))).toList();
    String currentFolderName = "Root Directory"; 
    if (_currentFolderId != null) { 
      try { 
        currentFolderName = widget.folders.firstWhere((f) => f.id == _currentFolderId).name; 
      } catch(e) {} 
    }

    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListTile(
              leading: _currentFolderId != null 
                ? IconButton(
                    icon: const Icon(Icons.drive_folder_upload, color: Colors.blue), 
                    onPressed: () => setState(() { 
                      try { 
                        final current = widget.folders.firstWhere((f) => f.id == _currentFolderId); 
                        _currentFolderId = current.parentId; 
                      } catch (e) { 
                        _currentFolderId = null; 
                      } 
                    })
                  ) 
                : const Icon(Icons.inventory_2, color: Colors.blue, size: 28),
              title: Text(currentFolderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min, 
                children: [
                  IconButton(
                    icon: const Icon(Icons.create_new_folder, color: Colors.green), 
                    tooltip: "Create Folder", 
                    onPressed: _showCreateFolderDialog
                  ), 
                  IconButton(
                    icon: const Icon(Icons.add_box, color: Colors.orange), 
                    tooltip: "Add Item", 
                    onPressed: _showCreateItemDialog
                  )
                ]
              )
            )
          )
        ),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(10),
            children: [
              if (subs.isEmpty && items.isEmpty) 
                const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("This folder is empty.", style: TextStyle(color: Colors.grey)))),
              
              ...subs.map((f) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800), 
                  child: Card(
                    color: Theme.of(context).cardColor, 
                    child: ListTile(
                      leading: Icon(_getSportIcon(f.name), color: Theme.of(context).primaryColor, size: 30), 
                      title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)), 
                      trailing: PopupMenuButton<String>(
                        onSelected: (v){ 
                          if (v == 'd') widget.onDeleteFolder(f.id); 
                        }, 
                        itemBuilder: (c) => [const PopupMenuItem(value: 'd', child: Text("Delete"))]
                      ), 
                      onTap: () => setState(() => _currentFolderId = f.id)
                    )
                  )
                )
              )),
              
              ...items.map((item) { 
                bool isUnavailable = item.status != ItemStatus.available; 
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800), 
                    child: Card(
                      color: isUnavailable ? Colors.grey.withOpacity(0.1) : Theme.of(context).cardColor, 
                      child: ListTile(
                        leading: Icon(
                          Icons.insert_drive_file, 
                          color: isUnavailable ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color
                        ), 
                        title: Text(item.name), 
                        subtitle: Text("Barcode: ${item.barcode}"), 
                        trailing: isUnavailable 
                          ? const Text("UNAVAILABLE", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)) 
                          : PopupMenuButton<String>(
                              onSelected: (v){ 
                                if(v=='d') widget.onDeleteItem(item.barcode); 
                              }, 
                              itemBuilder: (c) => [const PopupMenuItem(value: 'd', child: Text("Delete"))]
                            )
                      )
                    )
                  )
                ); 
              })
            ],
          )
        )
      ],
    );
  }

  void _showCreateFolderDialog() { 
    String n = ""; 
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor, 
        title: const Text("New Folder"), 
        content: TextField(
          autofocus: true, 
          onChanged: (v) => n = v
        ), 
        actions: [
          ElevatedButton(
            onPressed: () { 
              widget.onCreateFolder(n, _currentFolderId); 
              Navigator.pop(ctx); 
            }, 
            child: const Text("Create", style: TextStyle(color: Colors.white))
          )
        ]
      )
    ); 
  }

  void _showCreateItemDialog() { 
    String b = "", n = ""; 
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor, 
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            TextField(
              autofocus: true, 
              decoration: const InputDecoration(labelText: "Barcode"), 
              onChanged: (v) => b = v
            ), 
            TextField(
              decoration: const InputDecoration(labelText: "Name"), 
              onChanged: (v) => n = v
            ), 
            ElevatedButton(
              onPressed: () { 
                widget.onCreateItem(b, n, _currentFolderId); 
                Navigator.pop(ctx); 
              }, 
              child: const Text("Create Item Here", style: TextStyle(color: Colors.white))
            )
          ]
        )
      )
    ); 
  }
}