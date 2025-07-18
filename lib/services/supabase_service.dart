import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/shared_prefs_helper.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // ==================== REPORT MANAGEMENT ====================
  Future<void> submitReport({
    required int categoryId,
    int? subcategoryId,
    required String description,
    double? latitude,
    double? longitude,
    int? statusId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    String? token;

    // Token nur holen, wenn der Nutzer anonym ist
    if (userId == null) {
      token = await SharedPrefsHelper.getOrCreateToken();
    }

    final reportData = {
      'category_id': categoryId,
      'subcategory_id': subcategoryId,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'status_id': statusId,
      'created_at': DateTime.now().toIso8601String(),
      if (userId != null) 'user_id': userId,
      if (userId == null) 'anonymous_author_token': token,
    };

    try {
      final response = await _client.from('reports').insert(reportData);
      print("Report submitted: $response");
    } catch (e) {
      print("Fehler beim Übermitteln der Meldung: $e");
      rethrow;
    }
  }

  // ==================== CATEGORIES ====================
  Future<List<Map<String, dynamic>>> getCategories() async {
    final res = await _client.from('categories').select();
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getSubcategories(int categoryId) async {
    final res = await _client
        .from('subcategories')
        .select()
        .eq('category_id', categoryId);
    return List<Map<String, dynamic>>.from(res);
  }

  // ==================== MARKING SYSTEM ====================
  Future<bool> toggleReportMark({
    required int reportId,
    String? reportTitle,
    int? categoryId,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      String? token;
      if (userId == null) {
        token = await SharedPrefsHelper.getOrCreateToken();
      }

      final existingMark = await _client
          .from('report_marks')
          .select()
          .eq('report_id', reportId)
          .eq(userId != null ? 'user_id' : 'anonymous_token', userId ?? token!)
          .maybeSingle();

      if (existingMark != null) {
        await _client
            .from('report_marks')
            .delete()
            .eq('id', existingMark['id']);
        return false;
      } else {
        await _client.from('report_marks').insert({
          'report_id': reportId,
          if (userId != null) 'user_id': userId,
          if (userId == null) 'anonymous_token': token,
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } catch (e) {
      print("Fehler beim Speichern: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getMarkedReports() async {
    final userId = _client.auth.currentUser?.id;
    final token = userId == null
        ? await SharedPrefsHelper.getOrCreateToken()
        : null;

    final markedReports = userId != null
        ? await _client
              .from('report_marks')
              .select('report_id')
              .eq('user_id', userId)
        : await _client
              .from('report_marks')
              .select('report_id')
              .eq('anonymous_token', token!);

    print("Marked reports query result: $markedReports");
    print(
      "First report mark: ${markedReports.isNotEmpty ? markedReports.first : 'empty'}",
    );

    final markedIds = markedReports.map((m) => m['report_id'] as int).toList();

    if (markedIds.isEmpty) return [];

    return await _client
        .from('reports')
        .select('*, categories(name)')
        .inFilter('id', markedIds);
  }

  // ==================== STATUS MANAGEMENT ====================
  Future<List<Map<String, dynamic>>> getStatusTypes() async {
    try {
      final response = await _client
          .from('status_types')
          .select()
          .order('order_index');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching status types: $e');
      return [];
    }
  }

  Future<List<String>> getStatusOptions() async {
    try {
      final res = await _client
          .from('status_types')
          .select('name')
          .order('order_index');
      return res.map<String>((status) => status['name'] as String).toList();
    } catch (e) {
      print('Error fetching status options: $e');
      return [];
    }
  }

  Future<bool> updateReportStatus({
    required int reportId,
    required String newStatus,
  }) async {
    try {
      final response = await _client
          .from('reports')
          .update({'status_id': newStatus})
          .eq('id', reportId)
          .select('status_id') // Rückgabe des aktualisierten Status
          .maybeSingle();

      // Erfolg, wenn die Datenbank die Änderung bestätigt
      return response != null && response['status_id'].toString() == newStatus;
    } catch (e) {
      print('Fehler beim Status-Update: $e');
      return false;
    }
  }

  Future<bool> _hasPermissionToUpdate(int reportId) async {
    try {
      final userId = _client.auth.currentUser?.id.toString();
      final token = userId == null
          ? await SharedPrefsHelper.getOrCreateToken()
          : null;

      // 1. Check if user is the creator
      final report = await _client
          .from('reports')
          .select('user_id, anonymous_author_token')
          .eq('id', reportId)
          .maybeSingle();

      if (report == null) {
        print('Report $reportId does not exist');
        return false;
      }

      if (userId != null) {
        if (report['user_id']?.toString() == userId) return true;
      } else if (report['anonymous_author_token'] == token) {
        return true;
      }

      // 2. Check if report is marked by user
      final marked = userId != null
          ? await _client
                .from('report_marks')
                .select()
                .eq('report_id', reportId)
                .eq('user_id', userId)
                .maybeSingle()
          : await _client
                .from('report_marks')
                .select()
                .eq('report_id', reportId)
                .eq('anonymous_token', token!)
                .maybeSingle();

      return marked != null;
    } catch (e) {
      print('Error checking permissions for report $reportId: $e');
      return false;
    }
  }

  // ==================== USER REPORTS ====================
  Future<List<Map<String, dynamic>>> getMyReports() async {
    final userId = _client.auth.currentUser?.id;
    final token = userId == null
        ? await SharedPrefsHelper.getOrCreateToken()
        : null;

    List<Map<String, dynamic>> ownReports = [];
    List<Map<String, dynamic>> markedReports = [];

    if (userId != null) {
      // Eingeloggte Benutzer
      ownReports = await _client
          .from('reports')
          .select('*, categories(name), status_types(name)')
          .eq('user_id', userId);

      final marks = await _client
          .from('report_marks')
          .select('report_id')
          .eq('user_id', userId);

      final markedIds = marks.map((m) => m['report_id'] as int).toList();

      if (markedIds.isNotEmpty) {
        markedReports = await _client
            .from('reports')
            .select('*, categories(name)')
            .inFilter('id', markedIds);
      }
    } else {
      // Anonyme Benutzer
      ownReports = await _client
          .from('reports')
          .select('*, categories(name), status_types(name)')
          .eq('anonymous_author_token', token!);

      final marks = await _client
          .from('report_marks')
          .select('report_id')
          .eq('anonymous_token', token);

      final markedIds = marks.map((m) => m['report_id'] as int).toList();

      if (markedIds.isNotEmpty) {
        markedReports = await _client
            .from('reports')
            .select('*, categories(name)')
            .inFilter('id', markedIds);
      }
    }

    return {...ownReports, ...markedReports}.toList(); // set union
  }
}
