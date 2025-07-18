import 'package:intl/intl.dart';
import 'package:maengelapp/screens/appscaffold.dart';
import 'package:flutter/material.dart';
import '../services/map_widget.dart';
import '../services/supabase_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Map<String, dynamic>? _selectedReport;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MainAppBar(),
      body: Stack(
        children: [
          MapWidget(
            showAllReports: true,
            onMarkerTap: (report) {
              setState(() {
                _selectedReport = report;
              });
            },
          ),
          if (_selectedReport != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: _buildReportInfoCard(),
            ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildReportInfoCard() {
    final createdAt = _selectedReport!['created_at'] != null
        ? DateTime.parse(_selectedReport!['created_at']).toLocal()
        : null;
    final formattedDate = createdAt != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(createdAt)
        : 'Unbekannt';

    return Card(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedReport!['categories'] != null
                  ? _selectedReport!['categories']['name'] ?? 'Keine Kategorie'
                  : 'Keine Kategorie',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (_selectedReport!['subcategories'] != null &&
                _selectedReport!['subcategories']['name'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  _selectedReport!['subcategories']['name'],
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              _selectedReport!['description'] ?? 'Keine Beschreibung',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              'Erstellt: $formattedDate',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.bookmark,
                    color: _isReportSaved(_selectedReport!)
                        ? Colors.blue
                        : Colors.grey,
                  ),
                  onPressed: () => _toggleSaveReport(_selectedReport!),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedReport = null;
                    });
                  },
                  child: const Text('Schließen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isReportSaved(Map<String, dynamic> report) {
    // Implementierung hängt von Ihrer Speicherlogik ab
    return false; // Beispiel - anpassen
  }

  Future<void> _toggleSaveReport(Map<String, dynamic> report) async {
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
