import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maengelapp/screens/appscaffold.dart';
import '../services/supabase_service.dart';
import '../services/map_widget.dart';
import 'package:maengelapp/screens/dashboard_screen.dart';

enum LocationMode { none, manual, current }

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  int? selectedCategoryId;
  String? selectedCategoryName;
  int? selectedSubcategoryId;
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> subcategories = [];
  List<Map<String, dynamic>> statusTypes = [];

  LocationMode _locationMode = LocationMode.none;
  LatLng? selectedPosition;
  LatLng? currentPosition;
  String? geocodingError;
  bool _isSubmitting = false;
  int? selectedStatusId;
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await Future.wait([
      fetchCategories(),
      _loadCurrentPosition(),
      _fetchStatusTypes(),
    ]);
  }

  Future<void> fetchCategories() async {
    final data = await SupabaseService().getCategories();
    setState(() => categories = data);
  }

  Future<void> _fetchStatusTypes() async {
    final data = await SupabaseService().getStatusTypes();
    setState(() => statusTypes = data);
  }

  Future<void> fetchSubcategories(int categoryId, String categoryName) async {
    print("Lade Unterkategorien für Kategorie ID: $categoryId");
    final data = await SupabaseService().getSubcategories(categoryId);
    setState(() {
      subcategories = data;
      selectedCategoryName = categoryName;
      selectedPosition = null;
      _locationMode = LocationMode.none;
    });
  }

  Future<void> _loadCurrentPosition() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        return;

      final pos = await Geolocator.getCurrentPosition();
      setState(() => currentPosition = LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _submitReport() async {
    if (selectedPosition == null && _locationMode != LocationMode.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bitte wählen Sie einen Standort aus")),
      );
      return;
    }

    if (selectedCategoryId == null || selectedSubcategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bitte wählen Sie eine Kategorie aus")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await SupabaseService().submitReport(
        categoryId: selectedCategoryId!,
        subcategoryId: selectedSubcategoryId!,
        description: _descriptionController.text,
        latitude: selectedPosition?.latitude,
        longitude: selectedPosition?.longitude,
        statusId: selectedStatusId!,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Meldung erfolgreich gesendet!")),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => DashboardScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fehler beim Senden: ${e.toString()}")),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MainAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kategorie Dropdown
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: "Kategorie"),
              value: selectedCategoryId,
              items: categories
                  .map<DropdownMenuItem<int>>(
                    (cat) => DropdownMenuItem<int>(
                      value: cat['id'] as int,
                      child: Text(cat['name'] as String),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedCategoryId = value;
                    final name =
                        categories.firstWhere((c) => c['id'] == value)['name']
                            as String;
                    fetchSubcategories(value, name);
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Unterkategorie Dropdown
            if (selectedCategoryId != null)
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: "Unterkategorie"),
                value: selectedSubcategoryId,
                items: subcategories
                    .map<DropdownMenuItem<int>>(
                      (sub) => DropdownMenuItem<int>(
                        value: sub['id'] as int,
                        child: Text(sub['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => selectedSubcategoryId = value),
              ),
            const SizedBox(height: 16),

            if (selectedSubcategoryId != null) ...[
              // Status Dropdown - NEU HINZUGEFÜGT
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _supabaseService.getStatusTypes(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  final statusTypes = snapshot.data!;
                  return DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: "Status"),
                    value: selectedStatusId,
                    items: statusTypes
                        .map<DropdownMenuItem<int>>(
                          (status) => DropdownMenuItem<int>(
                            value: status['id'] as int,
                            child: Text(status['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => selectedStatusId = value),
                  );
                },
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Beschreibung",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Standort Auswahl
              const Text(
                "Standort hinzufügen",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<LocationMode>(
                      title: const Text("Manuell"),
                      value: LocationMode.manual,
                      groupValue: _locationMode,
                      onChanged: (val) => setState(() {
                        _locationMode = val!;
                        selectedPosition = null;
                        geocodingError = null;
                      }),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<LocationMode>(
                      title: const Text("Aktuell"),
                      value: LocationMode.current,
                      groupValue: _locationMode,
                      onChanged: (val) => setState(() {
                        _locationMode = val!;
                        if (currentPosition != null) {
                          selectedPosition = currentPosition;
                        }
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_locationMode == LocationMode.manual) ...[
                TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: "Adresse eingeben",
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        try {
                          final locations = await locationFromAddress(
                            _addressController.text,
                          );
                          if (locations.isNotEmpty) {
                            setState(() {
                              selectedPosition = LatLng(
                                locations.first.latitude,
                                locations.first.longitude,
                              );
                              geocodingError = null;
                            });
                          }
                        } catch (_) {
                          setState(() {
                            geocodingError = "Adresse nicht gefunden.";
                            selectedPosition = null;
                          });
                        }
                      },
                    ),
                  ),
                ),
                if (geocodingError != null)
                  Text(
                    geocodingError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 16),
              ],

              if (selectedPosition != null) ...[
                const Text(
                  "Gewählter Ort:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  child: MapWidget(
                    center: selectedPosition,
                    showAllReports: false,
                    singleMarkerPosition: selectedPosition,
                  ),
                ),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : const Text("Meldung senden"),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }
}
