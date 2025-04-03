import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'note_model.dart';
import 'note_editor_sheet.dart';
import 'auth_page.dart';
import 'utils/modal_route.dart';

class NotesPage extends StatelessWidget {

  static const Color noteCardColor = Color(0xFFB8C9B8);
  static const Color darkNoteCardColor = Color(0xFF2D4033);

  const NotesPage({super.key});

  void _createNewNote(BuildContext context) {
    Navigator.of(context).push(
      ModalPageRoute(
        page: const ModalNoteEditor(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Notes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : primaryColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, size: 24, color: isDarkMode ? Colors.white : primaryColor),
                  onPressed: () => _createNewNote(context),
                  tooltip: 'Create Note',
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  splashRadius: 20,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search, size: 18, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Search',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnapshot) {
                if (authSnapshot.connectionState == ConnectionState.waiting) {
                  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                  final primaryColor = Theme.of(context).colorScheme.primary;
                  final accentColor = Theme.of(context).colorScheme.tertiary;
                  
                  return Center(
                    child: LoadingAnimationWidget.stretchedDots(
                      color: isDarkMode ? accentColor : primaryColor,
                      size: 50,
                    ),
                  );
                }

                final user = authSnapshot.data;
                if (user == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note_alt_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Sign in to view your notes',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AuthPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          child: const Text('Sign In'),
                        ),
                      ],
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('notes')
                      .where('userID', isEqualTo: user.uid)
                      .orderBy('updatedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                      final primaryColor = Theme.of(context).colorScheme.primary;
                      final accentColor = Theme.of(context).colorScheme.tertiary;
                      
                      return Center(
                        child: LoadingAnimationWidget.stretchedDots(
                          color: isDarkMode ? accentColor : primaryColor,
                          size: 50,
                        ),
                      );
                    }

                    final notes = snapshot.data?.docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return Note.fromMap(doc.id, data);
                    }).toList() ?? [];

                    if (notes.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.note_add_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No notes yet. Create one!',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Create Note'),
                              onPressed: () => _showNoteEditor(context),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: notes.length,
                      padding: const EdgeInsets.all(20),
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return _buildNoteCard(context, note);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, Note note) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isDarkMode ? darkNoteCardColor : noteCardColor,
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
          width: 0.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showNoteEditor(context, note),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                note.content,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.black54,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat.yMMMd().format(note.updatedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _confirmDeleteNote(context, note.id!),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNoteEditor(BuildContext context, [Note? existingNote]) {
    Navigator.of(context).push(
      ModalPageRoute(
        page: ModalNoteEditor(note: existingNote),
      ),
    );
  }

  Future<void> _confirmDeleteNote(BuildContext context, String noteId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete ❌'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('notes')
          .doc(noteId)
          .delete();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted successfully ✅')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting note: ${e.toString()}')),
        );
      }
    }
  }
}