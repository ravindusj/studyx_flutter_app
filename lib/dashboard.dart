import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'note_model.dart';
import 'note_editor_sheet.dart';
import 'main_app_scaffold.dart';
import 'main.dart';
import 'utils/modal_route.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  static const Color noteCardColor = Color(0xFFB8C9B8);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isDelayedLoading = false;
  static bool _firstLoad = true;
  
  @override
  void initState() {
    super.initState();
    _checkIfFirstLoad();
  }
  
  Future<void> _checkIfFirstLoad() async {
    if (_firstLoad) {
      setState(() {
        _isDelayedLoading = true;
      });
      _firstLoad = false;
      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isDelayedLoading = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 
                        (user?.email?.split('@').first ?? 'User');
    final firstName = displayName.contains(' ') 
        ? displayName.split(' ')[0] 
        : displayName;
    
    return Scaffold(
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                firstName,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Notes',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () {
                      _navigateToNotesPage(context);
                    },
                    style: TextButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 13),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _isDelayedLoading 
                    ? _buildLoadingIndicator(context) 
                    : _buildNotesList(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
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

  void _navigateToNotesPage(BuildContext context) {
    final scaffoldState = mainAppScaffoldKey.currentState;
    
    if (scaffoldState != null) {
      scaffoldState.selectItem(1);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to navigate to Notes page')),
      );
    }
  }

  Widget _buildNotesList(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in to view your notes',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
              },
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
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
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

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load notes',
              style: TextStyle(color: Colors.grey[600]),
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
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No notes yet. Create one!',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 0),
          clipBehavior: Clip.hardEdge,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            final isLastItem = index == notes.length - 1;
            return _buildNoteCard(
              context, 
              note,
              bottomMargin: isLastItem ? 0 : 16,
              isLast: isLastItem,
            );
          },
        );
      },
    );
  }

  Widget _buildNoteCard(
    BuildContext context, 
    Note note, 
    {double bottomMargin = 16, bool isLast = false}
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      margin: EdgeInsets.only(
        bottom: bottomMargin,
        top: 0,
        left: 0,
        right: 0
      ),
      color: isDarkMode ? const Color(0xFF2D4033) : DashboardPage.noteCardColor,
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
                      color: Colors.grey[600],
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
            child: const Text('Delete'),
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
