import 'package:flutter/material.dart';

const kSchoolGreen = Color(0xFF006400); 
const kSchoolGold = Color(0xFFFFD700);  
const kBackground = Color(0xFF121212);
const kSurfaceDark = Color(0xFF1E1E1E);
const kTextWhite = Colors.white;
const kErrorRed = Color(0xFFCF6679);
const kWarningOrange = Colors.orangeAccent;

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

const List<String> kSocalHighSchools = [
  "Rancho Alamitos High School", "Garden Grove High School", "Bolsa Grande High School", 
  "La Quinta High School", "Los Amigos High School", "Santiago High School", "Pacifica High School",
  "Mater Dei High School", "Servite High School", "Orange Lutheran High School"
];

const Map<String, Map<String, Color>> kSchoolColors = {
  "Rancho Alamitos High School": {"primary": Color(0xFF006400), "secondary": Color(0xFFFFD700)}, 
  "Garden Grove High School": {"primary": Color(0xFFB22222), "secondary": Color(0xFFB22222)}, // Red/Red
  "Pacifica High School": {"primary": Color(0xFF000080), "secondary": Color(0xFFC0C0C0)}, 
  "Bolsa Grande High School": {"primary": Color(0xFF00008B), "secondary": Color(0xFFDC143C)}, 
  "La Quinta High School": {"primary": Color(0xFF0000CD), "secondary": Color(0xFFFFD700)}, 
  "Los Amigos High School": {"primary": Color(0xFFCC5500), "secondary": Color(0xFFCC5500)}, // Orange/Orange
  "Santiago High School": {"primary": Color(0xFF5A2E8A), "secondary": Color(0xFF5A2E8A)}, // Purple/Purple
  "Default": {"primary": Color(0xFF006400), "secondary": Color(0xFFFFD700)}
};