import 'package:cloud_firestore/cloud_firestore.dart';
import 'report.dart'; 
import 'sports.dart';

enum ClearanceStatus { notStarted, pending, approved, denied }

class Student {
  int id;
  String firstName;
  String lastName;
  String grade;
  DateTime dob;
  String sex;
  String accountEmail;
  String school;

  // Clearance Data
  String street; String city; String state; String zip;
  String homePhone; String mobilePhone;
  String p1First; String p1Last; String p1Mobile; String p1Email;
  String p2First; String p2Last; String p2Mobile; String p2Email;
  String physicianName; String physicianPhone;
  bool isInsured; String insuranceCompany; String insurancePolicyNum;
  String medicalConditions; String hospitalPreference; String hospitalLocation;
  String? physicalFrontPath; String? physicalBackPath;
  String? insuranceFrontPath; String? insuranceBackPath;
  String height; String weight;
  String livingArrangement; String educationHistory; String lastSchoolAttended;
  String emgFirst; String emgLast; String emgPhone; String emgRel;
  DateTime? lastPhysicalDate;
  
  ClearanceStatus clearanceStatus;
  String? denialReason;
  String graduationYear;

  List<TeamMembership> memberships;
  List<DoctorsNote> doctorsNotes;
  List<AbsenceRequest> absences;
  List<InjuryReport> injuryHistory;
  List<String> staffNotes;
  List<String> notifications;
  int unreadAlerts;
  bool isReleased;
  String? releaseTime;

  Student({
    required this.id, required this.firstName, required this.lastName, required this.grade, required this.dob, required this.sex, required this.accountEmail, required this.school,
    this.street = '', this.city = '', this.state = '', this.zip = '', this.homePhone = '', this.mobilePhone = '',
    this.p1First = '', this.p1Last = '', this.p1Mobile = '', this.p1Email = '', this.p2First = '', this.p2Last = '', this.p2Mobile = '', this.p2Email = '',
    this.physicianName = '', this.physicianPhone = '', this.isInsured = true, this.insuranceCompany = '', this.insurancePolicyNum = '',
    this.medicalConditions = '', this.hospitalPreference = '', this.hospitalLocation = '',
    this.physicalFrontPath, this.physicalBackPath, this.insuranceFrontPath, this.insuranceBackPath,
    this.height = '', this.weight = '', this.livingArrangement = '', this.educationHistory = '', this.lastSchoolAttended = '',
    this.emgFirst = '', this.emgLast = '', this.emgPhone = '', this.emgRel = '', this.lastPhysicalDate,
    this.clearanceStatus = ClearanceStatus.notStarted, this.denialReason, this.graduationYear = '',
    this.memberships = const [], this.doctorsNotes = const [], this.absences = const [], this.injuryHistory = const [],
    this.staffNotes = const [], this.notifications = const [], this.unreadAlerts = 0, this.isReleased = false, this.releaseTime,
  });

  String get fullName => "$firstName $lastName";
  String get displayEmail => accountEmail;
  String get email => accountEmail; 
  String get emgRelation => emgRel;
  String get fullAddress => street.isEmpty ? "No Address Provided" : "$street, $city, $state $zip";
  
  // Dynamically calculates the student's age based on their birthday
  String get age {
    int a = DateTime.now().year - dob.year;
    if (DateTime.now().month < dob.month || (DateTime.now().month == dob.month && DateTime.now().day < dob.day)) {
      a--;
    }
    return a.toString();
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    DateTime parsedDob = DateTime.now();
    if (json['dob'] != null) {
      if (json['dob'] is Timestamp) parsedDob = (json['dob'] as Timestamp).toDate();
      else if (json['dob'] is String) parsedDob = DateTime.tryParse(json['dob']) ?? DateTime.now();
    }
    
    DateTime? parsedPhysDate;
    if (json['lastPhysicalDate'] != null) {
      if (json['lastPhysicalDate'] is Timestamp) parsedPhysDate = (json['lastPhysicalDate'] as Timestamp).toDate();
      else if (json['lastPhysicalDate'] is String) parsedPhysDate = DateTime.tryParse(json['lastPhysicalDate']);
    }

    return Student(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      grade: json['grade'] ?? '',
      dob: parsedDob,
      sex: json['sex'] ?? 'Unknown',
      accountEmail: json['email'] ?? json['accountEmail'] ?? '',
      school: json['school'] ?? 'Unknown',
      
      street: json['street'] ?? '', city: json['city'] ?? '', state: json['state'] ?? '', zip: json['zip'] ?? '',
      homePhone: json['homePhone'] ?? '', mobilePhone: json['mobilePhone'] ?? '',
      p1First: json['p1First'] ?? '', p1Last: json['p1Last'] ?? '', p1Mobile: json['p1Mobile'] ?? '', p1Email: json['p1Email'] ?? '',
      p2First: json['p2First'] ?? '', p2Last: json['p2Last'] ?? '', p2Mobile: json['p2Mobile'] ?? '', p2Email: json['p2Email'] ?? '',
      physicianName: json['physicianName'] ?? '', physicianPhone: json['physicianPhone'] ?? '',
      isInsured: json['isInsured'] ?? true, insuranceCompany: json['insuranceCompany'] ?? '', insurancePolicyNum: json['insurancePolicyNum'] ?? '',
      medicalConditions: json['medicalConditions'] ?? '', hospitalPreference: json['hospitalPreference'] ?? '', hospitalLocation: json['hospitalLocation'] ?? '',
      physicalFrontPath: json['physicalFrontPath'], physicalBackPath: json['physicalBackPath'],
      insuranceFrontPath: json['insuranceFrontPath'], insuranceBackPath: json['insuranceBackPath'],
      height: json['height'] ?? '', weight: json['weight'] ?? '',
      livingArrangement: json['livingArrangement'] ?? '', educationHistory: json['educationHistory'] ?? '', lastSchoolAttended: json['lastSchoolAttended'] ?? '',
      emgFirst: json['emgFirst'] ?? '', emgLast: json['emgLast'] ?? '', emgPhone: json['emgPhone'] ?? '', emgRel: json['emgRel'] ?? '',
      lastPhysicalDate: parsedPhysDate,
      
      clearanceStatus: ClearanceStatus.values.firstWhere((e) => e.name == (json['clearanceStatus'] ?? 'notStarted'), orElse: () => ClearanceStatus.notStarted),
      denialReason: json['denialReason'],
      
      memberships: (json['memberships'] as List?)?.map((m) => TeamMembership(
        sport: m['sport'], gender: m['gender'] ?? 'Co-Ed', level: RosterLevel.values.firstWhere((e) => e.name == m['level'], orElse: () => RosterLevel.varsity), isActive: m['isActive'] ?? false
      )).toList() ?? [],
      doctorsNotes: (json['doctorsNotes'] as List?)?.map((n) => DoctorsNote(
        imagePath: n['imagePath'], datesOut: n['datesOut'], extent: n['extent'], injuryDesc: n['injuryDesc'], isCleared: n['isCleared'] ?? false, clearanceNotePath: n['clearanceNotePath']
      )).toList() ?? [],
      absences: (json['absences'] as List?)?.map((a) => AbsenceRequest(date: a['date'], reason: a['reason'])).toList() ?? [],
      staffNotes: List<String>.from(json['staffNotes'] ?? []),
      notifications: List<String>.from(json['notifications'] ?? []),
      unreadAlerts: json['unreadAlerts'] ?? 0,
      isReleased: json['isReleased'] ?? false,
      releaseTime: json['releaseTime'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'firstName': firstName, 'lastName': lastName, 'grade': grade, 'dob': Timestamp.fromDate(dob), 'sex': sex, 'email': accountEmail, 'school': school,
    'street': street, 'city': city, 'state': state, 'zip': zip, 'homePhone': homePhone, 'mobilePhone': mobilePhone,
    'p1First': p1First, 'p1Last': p1Last, 'p1Mobile': p1Mobile, 'p1Email': p1Email, 'p2First': p2First, 'p2Last': p2Last, 'p2Mobile': p2Mobile, 'p2Email': p2Email,
    'physicianName': physicianName, 'physicianPhone': physicianPhone, 'isInsured': isInsured, 'insuranceCompany': insuranceCompany, 'insurancePolicyNum': insurancePolicyNum,
    'medicalConditions': medicalConditions, 'hospitalPreference': hospitalPreference, 'hospitalLocation': hospitalLocation,
    'physicalFrontPath': physicalFrontPath, 'physicalBackPath': physicalBackPath, 'insuranceFrontPath': insuranceFrontPath, 'insuranceBackPath': insuranceBackPath,
    'height': height, 'weight': weight, 'livingArrangement': livingArrangement, 'educationHistory': educationHistory, 'lastSchoolAttended': lastSchoolAttended,
    'emgFirst': emgFirst, 'emgLast': emgLast, 'emgPhone': emgPhone, 'emgRel': emgRel, 'lastPhysicalDate': lastPhysicalDate != null ? Timestamp.fromDate(lastPhysicalDate!) : null,
    'clearanceStatus': clearanceStatus.name, 'denialReason': denialReason,
    'memberships': memberships.map((m) => { 'sport': m.sport, 'gender': m.gender, 'level': m.level.name, 'isActive': m.isActive }).toList(),
    'doctorsNotes': doctorsNotes.map((n) => { 'imagePath': n.imagePath, 'datesOut': n.datesOut, 'extent': n.extent, 'injuryDesc': n.injuryDesc, 'isCleared': n.isCleared, 'clearanceNotePath': n.clearanceNotePath }).toList(),
    'absences': absences.map((a) => { 'date': a.date, 'reason': a.reason }).toList(),
    'staffNotes': staffNotes, 'notifications': notifications, 'unreadAlerts': unreadAlerts, 'isReleased': isReleased, 'releaseTime': releaseTime,
  };

  void addNotification(String msg) { notifications.insert(0, msg); unreadAlerts++; }
  void clearBadge() { unreadAlerts = 0; }
}

class TeamMembership {
  String sport; String gender; RosterLevel level; bool isActive;
  TeamMembership({required this.sport, required this.gender, required this.level, required this.isActive});
}
class DoctorsNote {
  String imagePath; String datesOut; String extent; String injuryDesc; bool isCleared; String? clearanceNotePath;
  DoctorsNote({required this.imagePath, required this.datesOut, required this.extent, required this.injuryDesc, this.isCleared = false, this.clearanceNotePath});
}
class AbsenceRequest {
  String date; String reason;
  AbsenceRequest({required this.date, required this.reason});
}