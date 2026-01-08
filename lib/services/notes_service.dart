import 'dart:convert';
import 'package:deltamind/models/note.dart';
import 'package:deltamind/services/supabase_service.dart';
import 'package:flutter/foundation.dart';

/// Service for managing notes
class NotesService {
  /// Convert plain text to Delta JSON format for Quill editor
  /// Delta format: [{"insert":"text\n"}]
  static String convertPlainTextToDelta(String plainText) {
    if (plainText.isEmpty) {
      return '[{"insert":"\n"}]';
    }

    // Split by newlines and create Delta operations
    // Combine text and newline in the same operation for efficiency
    final lines = plainText.split('\n');
    final List<Map<String, dynamic>> deltaOps = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      // Combine text with newline (except for the last line if it's not empty)
      if (i < lines.length - 1) {
        // Not the last line, add newline
        deltaOps.add({'insert': '$line\n'});
      } else {
        // Last line - add newline only if line is not empty or if it's the only line
        if (line.isNotEmpty || lines.length == 1) {
          deltaOps.add({'insert': '$line\n'});
        } else {
          // Last line is empty and there are multiple lines, just add newline
          deltaOps.add({'insert': '\n'});
        }
      }
    }

    // If no operations were created, add at least one newline
    if (deltaOps.isEmpty) {
      deltaOps.add({'insert': '\n'});
    }

    return jsonEncode(deltaOps);
  }

  /// Get all notes for the current user
  static Future<List<Note>> getUserNotes({
    String? searchQuery,
    List<String>? tags,
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      var query =
          SupabaseService.client.from('notes').select().eq('user_id', userId);

      // Apply filters
      if (searchQuery != null && searchQuery.isNotEmpty) {
        // Tìm kiếm bằng ilike trong tiêu đề
        query = query.ilike('title', '%${searchQuery}%');
      }

      if (tags != null && tags.isNotEmpty) {
        // Filter by any of the tags using the PostgreSQL array overlap operator
        query = query.overlaps('tags', tags);
      }

      // Order by pinned first, then by most recently updated
      final finalQuery = query
          .order('is_pinned', ascending: false)
          .order('updated_at', ascending: false);

      final response = await finalQuery;

      return (response as List).map((note) => Note.fromJson(note)).toList();
    } catch (e) {
      debugPrint('Error getting user notes: $e');
      rethrow;
    }
  }

  /// Get a note by ID
  static Future<Note> getNoteById(String noteId) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await SupabaseService.client
          .from('notes')
          .select()
          .eq('id', noteId)
          .eq('user_id', userId)
          .single();

      return Note.fromJson(response);
    } catch (e) {
      debugPrint('Error getting note by ID: $e');
      rethrow;
    }
  }

  /// Create a new note
  static Future<Note> createNote({
    required String title,
    String? content,
    List<String>? tags,
    String? color,
    bool isPinned = false,
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final Map<String, dynamic> noteData = {
        'user_id': userId,
        'title': title,
        'content': content,
        'tags': tags ?? [],
        'color': color,
        'is_pinned': isPinned,
      };

      final response = await SupabaseService.client
          .from('notes')
          .insert(noteData)
          .select()
          .single();

      return Note.fromJson(response);
    } catch (e) {
      debugPrint('Error creating note: $e');
      rethrow;
    }
  }

  /// Update a note
  static Future<Note> updateNote({
    required String id,
    String? title,
    String? content,
    List<String>? tags,
    String? color,
    bool? isPinned,
    bool updateColor =
        false, // Flag to indicate if color should be updated (even if null)
  }) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Build update data
      final Map<String, dynamic> updateData = {};
      if (title != null) updateData['title'] = title;
      if (content != null) updateData['content'] = content;
      if (tags != null) updateData['tags'] = tags;
      // Always update color if updateColor flag is true (even if null to reset to default)
      if (updateColor) updateData['color'] = color;
      if (isPinned != null) updateData['is_pinned'] = isPinned;

      // Always update the updated_at timestamp
      updateData['updated_at'] = DateTime.now().toIso8601String();

      final response = await SupabaseService.client
          .from('notes')
          .update(updateData)
          .eq('id', id)
          .eq('user_id', userId)
          .select()
          .single();

      return Note.fromJson(response);
    } catch (e) {
      debugPrint('Error updating note: $e');
      rethrow;
    }
  }

  /// Delete a note (hard delete)
  static Future<void> deleteNote(String id) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await SupabaseService.client
          .from('notes')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error deleting note: $e');
      rethrow;
    }
  }

  /// Get all unique tags for the current user
  static Future<List<String>> getUserTags() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Get all notes for the user
      final response = await SupabaseService.client
          .from('notes')
          .select('tags')
          .eq('user_id', userId);

      // Extract unique tags
      final Set<String> uniqueTags = {};
      for (final note in response) {
        final tags = note['tags'] as List?;
        if (tags != null) {
          for (final tag in tags) {
            uniqueTags.add(tag.toString());
          }
        }
      }

      return uniqueTags.toList()..sort();
    } catch (e) {
      debugPrint('Error getting user tags: $e');
      return [];
    }
  }
}
