import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/shared_prefs_helper.dart';
import '../services/supabase_service.dart';

class MapWidget extends StatefulWidget {
  final LatLng? center;
  final bool showAllReports;
  final LatLng? singleMarkerPosition;
  final Function(Map<String, dynamic>)? onMarkerTap;

  const MapWidget({
    Key? key,
    this.center,
    this.showAllReports = true,
    this.singleMarkerPosition,
    this.onMarkerTap,
  }) : super(key: key);

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  final SupabaseClient _client = Supabase.instance.client;
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.showAllReports) {
      _fetchReports();
    } else {
      _loading = false;
    }
  }

  Future<void> _fetchReports() async {
    try {
      final response = await _client
          .from('reports')
          .select('''
      *,
      categories!inner(name),
      subcategories(name),
      status_types(name)
    ''')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      setState(() {
        _reports = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading reports: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _getCategoryIcon(String? categoryName) {
    if (categoryName == null) {
      return const Icon(Icons.location_on, color: Colors.grey, size: 40);
    }

    final name = categoryName.toLowerCase();

    if (name.contains('baustelle')) {
      return const Icon(Icons.construction, color: Colors.orange, size: 40);
    } else if (name.contains('verunreinigung')) {
      return const Icon(Icons.delete, color: Colors.green, size: 40);
    } else if (name.contains('verkehr')) {
      return const Icon(Icons.warning, color: Colors.red, size: 40);
    } else if (name.contains('straßen')) {
      return const Icon(
        Icons.alt_route,
        color: Color.fromARGB(255, 11, 2, 1),
        size: 40,
      );
    } else if (name.contains('beleuchtung')) {
      return const Icon(
        Icons.light,
        color: Color.fromARGB(255, 255, 251, 0),
        size: 40,
      );
    } else if (name.contains('stadtgrün')) {
      return const Icon(
        Icons.nature,
        color: Color.fromARGB(255, 25, 205, 40),
        size: 40,
      );
    } else {
      return const Icon(Icons.location_on, color: Colors.blue, size: 40);
    }
  }

  Color _getStatusColor(int? statusId) {
    switch (statusId) {
      case 1:
        return Colors.orange; // z. B. "geplant"
      case 2:
        return Colors.blue; // z. B. "in Arbeit"
      case 3:
        return Colors.green; // z. B. "abgeschlossen"
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final initialCenter =
        widget.center ??
        (_reports.isNotEmpty
            ? LatLng(_reports.first['latitude'], _reports.first['longitude'])
            : const LatLng(49.4521, 11.0767));

    final markers = <Marker>[];

    if (widget.singleMarkerPosition != null) {
      markers.add(
        Marker(
          point: widget.singleMarkerPosition!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.purple, size: 40),
        ),
      );
    }

    if (widget.showAllReports) {
      markers.addAll(
        _reports.map((report) {
          final lat = report['latitude'] as double;
          final lng = report['longitude'] as double;
          final categoryName = report['categories']['name'] as String?;
          final isConstruction = report['is_construction'] == true;
          final statusName = report['status_types']?['name'] as String?;

          // Ersetze den Marker-Code in der build-Methode:
          return Marker(
            point: LatLng(lat, lng),
            width: 50,
            height: 50,
            child: GestureDetector(
              onTap: () {
                if (widget.onMarkerTap != null) {
                  widget.onMarkerTap!(report);
                }
              },
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  _getCategoryIcon(categoryName),
                  if (isConstruction && statusName != null)
                    Positioned(
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(report['status_id'] as int?),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      );
    }

    return FlutterMap(
      options: MapOptions(initialCenter: initialCenter, initialZoom: 14.0),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.maengelapp',
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Future<void> _toggleReportMark(Map<String, dynamic> report) async {
    try {
      final success = await SupabaseService().toggleReportMark(
        reportId: report['id'],
        reportTitle: report['title'],
        categoryId: report['category_id'],
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? "Meldung gespeichert" : "Markierung entfernt",
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Fehler: $e")));
    }
  }
}
