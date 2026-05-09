import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/sports.dart';
import '../constants.dart';
import 'address_search.dart'; 

class SharedCalendarView extends StatefulWidget {
  final List<GameEvent> events;
  final String? filterSport;
  final String? homeSchool; 
  final Function(String, String, String, DateTime, DateTime, TimeOfDay?, TimeOfDay?, RosterLevel)? onAddGame;
  final Function(String, int, int)? onUpdateScore; 
  final Widget? topWidget; 

  const SharedCalendarView({super.key, required this.events, this.filterSport, this.onAddGame, this.onUpdateScore, this.homeSchool, this.topWidget});

  @override
  State<SharedCalendarView> createState() => _SharedCalendarViewState();
}

class _SharedCalendarViewState extends State<SharedCalendarView> {
  final List<String> _weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  final List<String> _months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  
  String _viewMode = "Month"; 
  String _seasonFilter = "All Seasons"; 
  DateTime _currentDate = DateTime.now();
  
  final ScrollController _scrollCtrl = ScrollController();
  bool _isScrolled = false;

  final Set<String> _hiddenSports = {};

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (!_scrollCtrl.hasClients) return; 
      
      if (_scrollCtrl.offset > 30 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollCtrl.offset <= 30 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _formatTime12(TimeOfDay t) {
    int h = t.hour; String ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12; if (h == 0) h = 12;
    return "$h:${t.minute.toString().padLeft(2, '0')} $ampm";
  }

  Color _getSportColor(String sportName) {
    List<Color> palette = [Colors.red, Colors.blue, Colors.green, Colors.purple, Colors.orange, Colors.cyan, Colors.pink, Colors.brown, Colors.indigo, Colors.teal, Colors.lime.shade700, Colors.deepOrange];
    int hash = sportName.runes.fold(0, (prev, elem) => prev + elem);
    return palette[hash % palette.length];
  }

  void _showGameDetailsDialog(GameEvent game) {
    int wins = 0, losses = 0, ties = 0;
    for (var past in widget.events.where((g) => g.sport == game.sport && g.level == game.level && g.result.isNotEmpty)) {
      if (past.result == "W") wins++;
      else if (past.result == "L") losses++;
      else if (past.result == "T") ties++;
    }
    String recordText = ties > 0 ? "($wins-$losses-$ties)" : "($wins-$losses)";

    bool canEditScore = widget.onUpdateScore != null && game.id != null;
    final ourCtrl = TextEditingController(text: game.ourScore?.toString() ?? "");
    final oppCtrl = TextEditingController(text: game.oppScore?.toString() ?? "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: _getSportColor(game.sport), shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "${game.sport.toUpperCase()} (${game.level.name.toUpperCase()})", 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)
              )
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(game.opponent, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Theme.of(context).textTheme.bodyLarge?.color)),
              const SizedBox(height: 15),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.access_time, color: Theme.of(context).primaryColor, size: 28),
                title: Text("${_formatTime12(TimeOfDay.fromDateTime(game.dateTime))} - ${game.endTime != null ? _formatTime12(TimeOfDay.fromDateTime(game.endTime!)) : 'TBD'}", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                subtitle: Text("${_weekdays[game.dateTime.weekday == 7 ? 0 : game.dateTime.weekday]}, ${_months[game.dateTime.month]} ${game.dateTime.day}, ${game.dateTime.year}", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on, color: Colors.redAccent, size: 28),
                title: Text("Location", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                subtitle: Text(game.location, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                title: Text("Season Record", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                subtitle: Text(recordText, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7))),
              ),
              
              if (game.result.isNotEmpty && !canEditScore) ...[
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                Center(
                  child: Column(
                    children: [
                      const Text("FINAL SCORE", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(
                        "[${game.result}]  ${game.ourScore} - ${game.oppScore}", 
                        style: TextStyle(
                          fontSize: 32, 
                          fontWeight: FontWeight.w900, 
                          color: game.result == 'W' ? Colors.green : (game.result == 'L' ? Colors.red : Colors.grey)
                        )
                      ),
                    ],
                  ),
                )
              ],
              
              if (canEditScore) ...[
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                const Text("Update Final Score", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: ourCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Our Score", border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: oppCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Opp. Score", border: OutlineInputBorder()))),
                  ],
                )
              ]
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close", style: TextStyle(color: Colors.grey))),
          if (canEditScore)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
              onPressed: () {
                int? us = int.tryParse(ourCtrl.text);
                int? them = int.tryParse(oppCtrl.text);
                if (us != null && them != null) {
                  widget.onUpdateScore!(game.id!, us, them);
                }
                Navigator.pop(ctx);
              }, 
              child: const Text("Save Score")
            )
        ],
      )
    );
  }
  
  @override
  Widget build(BuildContext context) {
    List<GameEvent> baseEvents = widget.filterSport == null ? widget.events : widget.events.where((e) => e.sport == widget.filterSport).toList();
    
    if (_seasonFilter != "All Seasons") {
      baseEvents = baseEvents.where((e) {
        int m = e.dateTime.month;
        if (_seasonFilter == "Fall" && (m >= 8 && m <= 11)) return true;
        if (_seasonFilter == "Winter" && (m == 12 || m <= 2)) return true;
        if (_seasonFilter == "Spring" && (m >= 3 && m <= 7)) return true;
        return false;
      }).toList();
    }

    Set<String> sportsPresent = baseEvents.map((e) => e.sport).toSet();
    List<String> sortedSports = sportsPresent.toList()..sort();
    final List<GameEvent> displayEvents = baseEvents.where((e) => !_hiddenSports.contains(e.sport)).toList();

    return Column( 
      children: [
        if (widget.topWidget != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: _isScrolled ? 0 : 75,
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: widget.topWidget!,
            ),
          ),

        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Container(
              padding: const EdgeInsets.all(8), color: Theme.of(context).cardColor.withOpacity(0.9),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 15,
                runSpacing: 10,
                children: [
                  ToggleButtons(
                    isSelected: [_viewMode == "Month", _viewMode == "Week", _viewMode == "Day"],
                    onPressed: (i) => setState(() => _viewMode = ["Month", "Week", "Day"][i]),
                    children: const [Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("Month")), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("Week")), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("Day"))],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(border: Border.all(color: Theme.of(context).primaryColor), borderRadius: BorderRadius.circular(8)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _seasonFilter,
                        icon: Icon(Icons.filter_list, color: Theme.of(context).primaryColor),
                        items: ["All Seasons", "Fall", "Winter", "Spring"].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                        onChanged: (v) => setState(() { _seasonFilter = v!; _hiddenSports.clear(); }),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
        
        if (sortedSports.isNotEmpty && widget.filterSport == null)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Card(
                elevation: 0,
                color: Theme.of(context).cardColor.withOpacity(0.7),
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), 
                  side: BorderSide(color: Colors.grey.withOpacity(0.2))
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: false, 
                    leading: Icon(Icons.palette, color: Theme.of(context).primaryColor),
                    title: Text(
                      "Filter Sports & Legend", 
                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)
                    ),
                    subtitle: Text(
                      "${sortedSports.length - _hiddenSports.length} of ${sortedSports.length} sports visible",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                        child: Wrap(
                          spacing: 15, runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: sortedSports.map((s) {
                            bool isActive = !_hiddenSports.contains(s);
                            return InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  if (isActive) {
                                    if (sortedSports.length - _hiddenSports.length <= 1) {
                                      _hiddenSports.clear();
                                    } else {
                                      _hiddenSports.add(s);
                                    }
                                  } else {
                                    _hiddenSports.remove(s);
                                  }
                                });
                              },
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: isActive ? 1.0 : 0.4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 12, height: 12, 
                                        decoration: BoxDecoration(
                                          color: isActive ? _getSportColor(s) : Colors.grey.shade600, 
                                          shape: BoxShape.circle
                                        )
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        s, 
                                        style: TextStyle(
                                          fontSize: 12, 
                                          fontWeight: FontWeight.bold,
                                          color: isActive ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey.shade500
                                        )
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        )
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        
        Expanded(
          child: ListView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              _buildSelectedView(displayEvents),
            ],
          )
        ),
      ],
    );
  }

  Widget _buildSelectedView(List<GameEvent> events) {
    if (_viewMode == "Day") return _buildDayView(events);
    if (_viewMode == "Week") return _buildWeekView(events);
    return _buildMonthView(events);
  }

  Widget _buildMonthView(List<GameEvent> events) {
    DateTime monthStart = DateTime(_currentDate.year, _currentDate.month, 1);
    int daysInMonth = DateUtils.getDaysInMonth(monthStart.year, monthStart.month);
    int firstWeekday = monthStart.weekday == 7 ? 0 : monthStart.weekday; 
    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10), color: Theme.of(context).primaryColor.withOpacity(0.8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: () => setState(() => _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1))),
                  Text("${_months[monthStart.month]} ${monthStart.year}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white), onPressed: () => setState(() => _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1))),
                ]
              )
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8), color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: _weekdays.map((w) => Expanded(child: Center(child: Text(w, style: const TextStyle(fontWeight: FontWeight.bold))))).toList()),
            ),
            Container(
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(), shrinkWrap: true, 
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.8, crossAxisSpacing: 4, mainAxisSpacing: 4),
                itemCount: daysInMonth + firstWeekday,
                itemBuilder: (ctx, i) {
                  if (i < firstWeekday) return const SizedBox();
                  int dayNum = i - firstWeekday + 1;
                  DateTime day = DateTime(monthStart.year, monthStart.month, dayNum);
                  bool isToday = day.year == DateTime.now().year && day.month == DateTime.now().month && day.day == DateTime.now().day;
                  final dayEvents = events.where((e) => e.dateTime.year == day.year && e.dateTime.month == day.month && e.dateTime.day == day.day).toList();
                  
                  return GestureDetector(
                    onTap: () => setState(() { _currentDate = day; _viewMode = "Day"; }),
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.3)), borderRadius: BorderRadius.circular(4), color: isToday ? Theme.of(context).primaryColor.withOpacity(0.3) : Theme.of(context).cardColor),
                      child: Column(
                        children: [
                          Text("$dayNum", style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                          const SizedBox(height: 2),
                          Wrap(alignment: WrapAlignment.center, spacing: 2, runSpacing: 2, children: dayEvents.map((e) => Container(width: 8, height: 8, decoration: BoxDecoration(color: _getSportColor(e.sport), shape: BoxShape.circle))).toList())
                        ]
                      )
                    )
                  );
                }
              ),
            )
          ]
        ),
      ),
    );
  }

  Widget _buildWeekView(List<GameEvent> events) {
    DateTime weekStart = _currentDate.subtract(Duration(days: _currentDate.weekday == 7 ? 0 : _currentDate.weekday));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10), color: Theme.of(context).primaryColor.withOpacity(0.8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: () => setState(() => _currentDate = _currentDate.subtract(const Duration(days: 7)))),
                  Text("Week of ${_months[weekStart.month]} ${weekStart.day}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white), onPressed: () => setState(() => _currentDate = _currentDate.add(const Duration(days: 7)))),
                ]
              )
            ),
            Container(
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
              height: 600, 
              child: Row(
                children: List.generate(7, (i) {
                  DateTime day = weekStart.add(Duration(days: i));
                  bool isToday = day.year == DateTime.now().year && day.month == DateTime.now().month && day.day == DateTime.now().day;
                  final dayEvents = events.where((e) => e.dateTime.year == day.year && e.dateTime.month == day.month && e.dateTime.day == day.day).toList();
                  
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() { _currentDate = day; _viewMode = "Day"; }),
                      child: Container(
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.2)), color: isToday ? Theme.of(context).primaryColor.withOpacity(0.1) : null),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8), color: Theme.of(context).cardColor,
                              child: Center(child: Text("${_weekdays[i]}\n${day.day}", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                            ),
                            Expanded(
                              child: ListView(
                                children: dayEvents.map((e) => GestureDetector(
                                  onTap: () => _showGameDetailsDialog(e), 
                                  child: Container(
                                    margin: const EdgeInsets.all(2), padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: _getSportColor(e.sport), borderRadius: BorderRadius.circular(4)),
                                    child: Text(e.opponent, style: const TextStyle(fontSize: 8, color: Colors.white), overflow: TextOverflow.ellipsis),
                                  ),
                                )).toList()
                              )
                            )
                          ]
                        )
                      ),
                    )
                  );
                })
              ),
            )
          ]
        ),
      ),
    );
  }

  Widget _buildDayView(List<GameEvent> events) {
    final dailyEvents = events.where((e) => e.dateTime.day == _currentDate.day && e.dateTime.month == _currentDate.month && e.dateTime.year == _currentDate.year).toList();
    dailyEvents.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    List<int> eventCols = List.filled(dailyEvents.length, 0);
    int maxCols = 1;
    for(int i = 0; i < dailyEvents.length; i++) {
        int col = 0;
        while(true) {
            bool collision = false;
            for(int j = 0; j < i; j++) {
                if(eventCols[j] == col) {
                    DateTime sA = dailyEvents[i].dateTime;
                    DateTime eA = dailyEvents[i].endTime ?? sA.add(const Duration(hours: 2));
                    DateTime sB = dailyEvents[j].dateTime;
                    DateTime eB = dailyEvents[j].endTime ?? sB.add(const Duration(hours: 2));
                    if(sA.isBefore(eB) && eA.isAfter(sB)) { collision = true; break; }
                }
            }
            if(!collision) break;
            col++;
        }
        eventCols[i] = col;
        if(col + 1 > maxCols) maxCols = col + 1;
    }

    const double hourHeight = 110.0; 
    const int startHour = 6;
    const int endHour = 22; 
    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10), color: Theme.of(context).primaryColor.withOpacity(0.8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: () => setState(() => _currentDate = _currentDate.subtract(const Duration(days: 1)))),
                  Text("${_weekdays[_currentDate.weekday == 7 ? 0 : _currentDate.weekday]}, ${_months[_currentDate.month]} ${_currentDate.day}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  IconButton(icon: const Icon(Icons.chevron_right, color: Colors.white), onPressed: () => setState(() => _currentDate = _currentDate.add(const Duration(days: 1)))),
                ]
              )
            ),
            Container(
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double availableWidth = constraints.maxWidth - 65;
                  double eventWidth = availableWidth / maxCols;
              
                  return SizedBox(
                    height: (endHour - startHour + 1) * hourHeight,
                    child: Stack(
                      children: [
                        Column(
                          children: List.generate(endHour - startHour + 1, (i) {
                            int h = i + startHour;
                            return Container(
                              height: hourHeight,
                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2)))),
                              child: Row(children: [
                                SizedBox(width: 60, child: Center(child: Text(_formatTime12(TimeOfDay(hour: h, minute: 0)), style: const TextStyle(color: Colors.grey, fontSize: 12)))),
                                Expanded(child: Container(decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey.withOpacity(0.2))))))
                              ])
                            );
                          })
                        ),
                        ...List.generate(dailyEvents.length, (i) {
                           final e = dailyEvents[i];
                           double topOffset = (e.dateTime.hour - startHour + (e.dateTime.minute / 60.0)) * hourHeight;
                           double durationHours = e.endTime != null ? e.endTime!.difference(e.dateTime).inMinutes / 60.0 : 2.0;
                           if (durationHours <= 0.5) durationHours = 1.0; 
                           
                           Color bgColor = _getSportColor(e.sport);
                           double leftOffset = 65 + (eventWidth * eventCols[i]);
                           
                           // CRITICAL FIX: The logic now accurately maps Home/Away using the actual Location
                           bool isHome = false;
                           String lowerOpp = e.opponent.toLowerCase();
                           String lowerLoc = e.location.toLowerCase();
                           
                           if (lowerLoc.contains("home") || lowerLoc.contains("rancho alamitos") || lowerLoc.contains("11351 dale")) {
                               isHome = true;
                           } else if (widget.homeSchool != null && lowerLoc.contains(widget.homeSchool!.toLowerCase())) {
                               isHome = true;
                           } else if (lowerOpp.contains(" vs ") || lowerOpp.contains(" vs. ")) {
                               isHome = true;
                           } else {
                               isHome = false;
                           }

                           int wins = 0, losses = 0, ties = 0;
                           for (var past in widget.events.where((g) => g.sport == e.sport && g.level == e.level && g.result.isNotEmpty)) {
                             if (past.result == "W") wins++;
                             else if (past.result == "L") losses++;
                             else if (past.result == "T") ties++;
                           }
                           String recordText = ties > 0 ? "($wins-$losses-$ties)" : "($wins-$losses)";
                           
                           Color scoreColor = Colors.white;
                           if (e.result == "W") scoreColor = Colors.greenAccent;
                           if (e.result == "L") scoreColor = Colors.redAccent;
              
                           return Positioned(
                             top: topOffset, left: leftOffset, width: eventWidth - 4, height: durationHours * hourHeight,
                             child: GestureDetector(
                               onTap: () => _showGameDetailsDialog(e),
                               child: Container(
                                 padding: const EdgeInsets.all(8),
                                 decoration: BoxDecoration(
                                   color: Theme.of(context).cardColor, 
                                   borderRadius: BorderRadius.circular(8), 
                                   border: Border.all(color: bgColor, width: 3) 
                                 ),
                                 child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                   // CRITICAL FIX: Made all these fonts dynamic based on the theme (No more dark grey on black)
                                   Text("${_formatTime12(TimeOfDay.fromDateTime(e.dateTime))} - ${e.endTime != null ? _formatTime12(TimeOfDay.fromDateTime(e.endTime!)) : 'TBD'}", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                   
                                   Text("${e.sport.toUpperCase()} (${e.level.name.toUpperCase()}) $recordText", style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7) ?? Colors.grey.shade400), overflow: TextOverflow.ellipsis),
                                   
                                   if (e.result.isNotEmpty)
                                     Padding(
                                       padding: const EdgeInsets.only(top: 4),
                                       child: Text("[${e.result}] ${e.ourScore} - ${e.oppScore}", style: TextStyle(color: scoreColor, fontSize: 18, fontWeight: FontWeight.bold)),
                                     )
                                   else
                                     Text(e.opponent, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                     
                                   Expanded(child: Text(e.location, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.6) ?? Colors.grey.shade500, fontSize: 10), overflow: TextOverflow.fade)),
                                   
                                   Container(
                                     width: double.infinity,
                                     margin: const EdgeInsets.only(top: 4),
                                     padding: const EdgeInsets.symmetric(vertical: 4),
                                     decoration: BoxDecoration(
                                       color: bgColor.withOpacity(0.2), 
                                       borderRadius: BorderRadius.circular(4)
                                     ),
                                     child: Text(
                                       isHome ? "HOME" : "AWAY", 
                                       textAlign: TextAlign.center, 
                                       style: TextStyle(
                                         color: bgColor, 
                                         fontSize: 12, 
                                         fontWeight: FontWeight.bold,
                                         letterSpacing: 1.5
                                       )
                                     ),
                                   )
                                 ]),
                               ),
                             )
                           );
                        })
                      ]
                    )
                  );
                }
              ),
            )
          ]
        ),
      ),
    );
  }
}