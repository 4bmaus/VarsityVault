import 'package:flutter/material.dart';

enum RosterLevel { varsity, jv, frosh }

class SportDefinition {
  final String name;
  final String gender;
  final String coachId;
  SportDefinition({required this.name, required this.gender, required this.coachId});
}

class GameEvent {
  String? id; // Needed to update scores in the database
  String sport;
  String opponent;
  String location;
  DateTime dateTime;
  DateTime? endTime;
  TimeOfDay? releaseTime;
  TimeOfDay? busTime;
  RosterLevel level;
  int? ourScore;
  int? oppScore; 

  GameEvent({
    this.id,
    required this.sport,
    required this.opponent,
    required this.location,
    required this.dateTime,
    this.endTime,
    this.releaseTime,
    this.busTime,
    required this.level,
    this.ourScore,
    this.oppScore,
  });

  // Determines Win/Loss/Tie dynamically
  String get result {
    if (ourScore == null || oppScore == null) return "";
    if (ourScore! > oppScore!) return "W";
    if (ourScore! < oppScore!) return "L";
    return "T";
  }
}