import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:maengelapp/services/supabase_service.dart';

class MyReportsScreen extends StatefulWidget {
  @override
  _MyReportsScreenState createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final SupabaseService _supabase = SupabaseService();
  List<Map<String, dynamic>> _reports = [];
  Map<int, List<Map<String, dynamic>>> _reportMarks =
      {}; // Speichert Markierungen pro Report-ID
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final reports = await _supabase.getMyReports();
      final marks = await _supabase.getMarkedReports();

      final marksMap = <int, List<Map<String, dynamic>>>{};
      for (final mark in marks) {
        final reportId = mark['report_id'] as int?;
        if (reportId != null) {
          marksMap.putIfAbsent(reportId, () => []).add(mark);
        }
      }

      if (mounted) {
        setState(() {
          _reports = reports;
          _reportMarks = marksMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fehler beim Laden: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Meine Meldungen")),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_reports.isEmpty) {
      return Center(child: Text("Keine Meldungen gefunden."));
    }

    return ListView.builder(
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        final reportId = report['id'] as int;
        final marks = _reportMarks[reportId] ?? [];
        return _buildReportTile(report, marks);
      },
    );
  }

  Widget _buildReportTile(
    Map<String, dynamic> report,
    List<Map<String, dynamic>> marks,
  ) {
    // Helper function to safely get status name
    String getStatusName() {
      try {
        // 1. Try to get from joined status_types
        if (report['status_types'] is Map) {
          return report['status_types']?['name']?.toString() ?? 'Offen';
        }

        // 2. Fallback to status_id mapping
        const statusMap = {1: 'Offen', 2: 'In Bearbeitung', 3: 'Erledigt'};
        return statusMap[report['status_id'] as int] ?? 'Unbekannt';
      } catch (e) {
        return 'Status fehlt';
      }
    }

    final categoryName =
        report['categories']?['name'] ?? 'Unbekannte Kategorie';
    final subcategoryName = report['subcategories']?['name'] ?? '';
    final description = report['description'] ?? '';
    final createdAt = report['created_at'] != null
        ? DateFormat(
            'dd.MM.yyyy HH:mm',
          ).format(DateTime.parse(report['created_at'].toString()))
        : 'Unbekanntes Datum';
    final statusId = report['status_id'] as int? ?? 1;
    final statusName = getStatusName(); // Using the safe getter

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kategorie und Unterkategorie
            Text(
              categoryName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (subcategoryName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subcategoryName,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),

            // Beschreibung
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(description, style: TextStyle(fontSize: 14)),
            ),

            // Status mit Chip für bessere Sichtbarkeit
            Chip(
              label: Text(statusName),
              backgroundColor: _getStatusColor(statusId),
              labelStyle: TextStyle(color: Colors.white),
            ),

            // Markierungen
            if (marks.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                'Markierungen:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                children: marks
                    .map(
                      (mark) => Chip(
                        label: Text(mark['name']?.toString() ?? 'Unbekannt'),
                        backgroundColor: Colors.blue[100],
                      ),
                    )
                    .toList(),
              ),
            ],

            // Status Dropdown und Datum
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _supabase.getStatusTypes(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return SizedBox.shrink();

                      return DropdownButton<int>(
                        value: statusId,
                        isExpanded: true,
                        items: snapshot.data!
                            .map(
                              (status) => DropdownMenuItem<int>(
                                value: status['id'] as int,
                                child: Text(
                                  status['name']?.toString() ?? 'Unbekannt',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            _onStatusChanged(value, report['id']),
                      );
                    },
                  ),
                ),

                Text(
                  createdAt,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Hilfsfunktion für Status-Farben
  Color _getStatusColor(int? statusId) {
    switch (statusId) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _onStatusChanged(int? newStatusId, int reportId) async {
    if (newStatusId == null) return;

    setState(() => _isLoading = true);
    try {
      final success = await _supabase.updateReportStatus(
        reportId: reportId,
        newStatus: newStatusId.toString(),
      );

      if (!mounted) return;

      if (success) {
        // Lokale Aktualisierung (ohne Netzwerk-Request)
        setState(() {
          final report = _reports.firstWhere((r) => r['id'] == reportId);
          report['status_id'] = newStatusId;
          if (report['status_types'] is Map) {
            report['status_types']['name'] = _getStatusName(newStatusId);
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Status aktualisiert")));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Keine Berechtigung!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Fehler: ${e.toString()}")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Hilfsmethode für Statusnamen
  Future<String> _getStatusName(int statusId) async {
    final types = await _supabase.getStatusTypes();
    return types.firstWhere((t) => t['id'] == statusId)['name'] ?? 'Unbekannt';
  }
}
