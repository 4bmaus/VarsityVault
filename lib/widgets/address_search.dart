import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddressSearchField extends StatelessWidget {
  final TextEditingController stCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController zipCtrl;
  final String label;

  const AddressSearchField({
    super.key, 
    required this.stCtrl, 
    required this.cityCtrl, 
    required this.stateCtrl, 
    required this.zipCtrl, 
    this.label = "Address"
  });

  // TODO: PASTE YOUR LOCATIONIQ API KEY HERE BEFORE THE DEMO
  static const String _locationIqApiKey = 'pk.222964c3bf084bb82e21f2f68246b017';

  Future<Iterable<Map<String, String>>> _searchAddress(String query) async {
    if (query.length < 3) return const Iterable<Map<String, String>>.empty();

    final url = Uri.parse(
        'https://api.locationiq.com/v1/autocomplete?key=$_locationIqApiKey&q=${Uri.encodeComponent(query)}&limit=5&countrycodes=us');

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // FIX: Explicitly cast the map output to <Map<String, String>> 
        return data.map<Map<String, String>>((item) {
          final addressData = item['address'] ?? {};
          
          // FIX: Added .toString() to ensure we never accidentally pass an int as a String
          String houseNumber = addressData['house_number']?.toString() ?? '';
          String road = addressData['road']?.toString() ?? addressData['pedestrian']?.toString() ?? '';
          String city = addressData['city']?.toString() ?? addressData['town']?.toString() ?? addressData['village']?.toString() ?? '';
          String state = addressData['state']?.toString() ?? '';
          String postcode = addressData['postcode']?.toString() ?? '';
          
          String streetStr = "$houseNumber $road".trim();
          if (streetStr.isEmpty && item['display_name'] != null) {
            streetStr = item['display_name'].toString().split(',')[0]; 
          }

          // FIX: Explicitly returning <String, String> types
          return <String, String>{
            "display": item['display_name']?.toString() ?? "Unknown Location",
            "st": streetStr,
            "ci": city,
            "sta": state,
            "zip": postcode,
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("API Error: $e");
    }
    
    return const Iterable<Map<String, String>>.empty();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Map<String, String>>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        return _searchAddress(textEditingValue.text);
      },
      displayStringForOption: (option) => option["display"]!,
      onSelected: (selection) {
        stCtrl.text = selection["st"]!;
        cityCtrl.text = selection["ci"]!;
        stateCtrl.text = selection["sta"]!;
        zipCtrl.text = selection["zip"]!;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        if (controller.text.isEmpty && stCtrl.text.isNotEmpty) {
           controller.text = "${stCtrl.text}, ${cityCtrl.text}";
        }
        return TextField(
          controller: controller, 
          focusNode: focusNode, 
          decoration: InputDecoration(
            labelText: label, 
            suffixIcon: const Icon(Icons.map),
            helperText: "Powered by LocationIQ"
          ), 
          onChanged: (v) => stCtrl.text = v
        );
      },
    );
  }
}