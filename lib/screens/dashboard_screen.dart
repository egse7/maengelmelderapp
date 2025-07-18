import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maengelapp/screens/appscaffold.dart';
import 'package:maengelapp/services/map_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:maengelapp/services/supabase_service.dart';
import 'package:maengelapp/screens/my_reports_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int closedReportsCount = 0;
  List<String> savedReportIds = [];

  @override
  void initState() {
    super.initState();
    _loadSavedReports();
  }

  Future<void> _loadSavedReports() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      savedReportIds = prefs.getStringList('saved_reports') ?? [];
    });
  }

  Future<void> _toggleSaveReport(Map<String, dynamic> report) async {
    try {
      final success = await SupabaseService().toggleReportMark(
        reportId: report['id'],
        reportTitle: report['title'],
        categoryId: report['category_id'],
      );

      setState(() {
        if (success) {
          savedReportIds.add(report['id'].toString());
        } else {
          savedReportIds.remove(report['id'].toString());
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Report markiert" : "Markierung entfernt"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Fehler: ${e.toString()}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MainAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Die Karte
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 500,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: MapWidget(showAllReports: true),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Rechte Seite: Filter + Infos
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MyReportsScreen(),
                          ),
                        ),
                        child: Text("Meine Meldungen"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              // Nimmt verfügbaren vertikalen Raum ein
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchRecentReports(), // Neue Methode (siehe unten)
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return Center(child: Text("Keine Meldungen gefunden"));
                  }

                  return ListView.builder(
                    physics: AlwaysScrollableScrollPhysics(), // Immer scrollbar
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final report = snapshot.data![index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: buildReportCard(
                          report,
                        ), // Gemeinsame Karten-Widget
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }

  // Holt die letzten 5 Meldungen
  Future<List<Map<String, dynamic>>> _fetchRecentReports() async {
    try {
      final res = await Supabase.instance.client
          .from('reports')
          .select('*, categories(name), status_types(name)')
          .order('created_at', ascending: false)
          .limit(5);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('Fehler beim Laden: $e');
      return [];
    }
  }

  // Gemeinsame Karten-Widget für alle Meldungen
  Widget buildReportCard(Map<String, dynamic> report) {
    final categoryName = report['categories']?['name'] ?? 'Unbekannt';
    final subcategoryName = report['subcategories']?['name'] ?? '';
    final isSaved = savedReportIds.contains(report['id']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titelzeile mit Kategorie und Speichern-Button
            Row(
              children: [
                Expanded(
                  child: Text(
                    categoryName, // Hauptkategorie als Titel
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isSaved ? Colors.blue : null,
                  ),
                  onPressed: () => _toggleSaveReport(report),
                ),
              ],
            ),

            // Unterkategorie
            if (subcategoryName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  subcategoryName,
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ),

            // Beschreibung
            Text(report['description'] ?? ''),

            // Status und Datum
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      report['status_types']?['name']?.toString() ??
                          'Kein Status',
                    ),
                  ),
                  Spacer(),
                  Text(
                    DateFormat(
                      'dd.MM.yyyy',
                    ).format(DateTime.parse(report['created_at'].toString())),
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
