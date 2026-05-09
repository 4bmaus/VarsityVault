class InjuryReport {
  final int studentId;
  final String studentName;
  final String date;
  final String description;
  final String recordedBy;
  bool isRead; 
  bool isActive; 

  InjuryReport({
    required this.studentId, required this.studentName, required this.date, 
    required this.description, required this.recordedBy, this.isRead = false, this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'studentId': studentId, 'studentName': studentName, 'date': date,
    'description': description, 'recordedBy': recordedBy,
    'isRead': isRead, 'isActive': isActive,
  };

  factory InjuryReport.fromJson(Map<String, dynamic> json) => InjuryReport(
    studentId: json['studentId'] ?? 0,
    studentName: json['studentName'] ?? '',
    date: json['date'] ?? '',
    description: json['description'] ?? '',
    recordedBy: json['recordedBy'] ?? '',
    isRead: json['isRead'] ?? false,
    isActive: json['isActive'] ?? true,
  );
}