import 'dart:convert';

import 'package:flutter/services.dart';

class MyanmarLocationData {
  MyanmarLocationData(this._regions);

  final Map<String, Map<String, List<String>>> _regions;

  static MyanmarLocationData? _cached;

  static Future<MyanmarLocationData> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/myanmar-townships.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final regions = decoded.map((region, districts) {
      final districtMap = (districts as Map<String, dynamic>).map(
        (district, townships) => MapEntry(
          district,
          (townships as List<dynamic>).map((item) => item.toString()).toList(),
        ),
      );
      return MapEntry(region, districtMap);
    });

    return _cached = MyanmarLocationData(regions);
  }

  List<String> get regions => _regions.keys.toList()..sort();

  List<String> districtsFor(String? region) {
    final districts = _regions[region];
    if (districts == null) return const [];
    return districts.keys.toList()..sort();
  }

  List<String> townshipsFor(String? region, String? district) {
    final townships = _regions[region]?[district];
    if (townships == null) return const [];
    return List<String>.from(townships)..sort();
  }
}
