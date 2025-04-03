import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'note_model.dart';
import 'image_to_text_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class NoteEditorPage extends StatefulWidget {
  final Note? note;

  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderlined = false;
  bool _isLoading = false;

  void _showImageToTextDialog() {
    showDialog(
      context: context,
      builder: (context) => ImageToTextDialog(
        onAddToNote: (text) {
          final currentText = _contentController.text;
          final newText = currentText.isEmpty 
              ? text 
              : '$currentText\n\n$text';
          _contentController.text = newText;
        },
      ),
    );
  }
  
  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (!mounted) return;

    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and content cannot be empty')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save notes')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    
    try {
      final note = Note(
        id: widget.note?.id,
        title: _titleController.text,
        content: _contentController.text,
        createdAt: widget.note?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        userID: currentUser.uid,
      );

      if (widget.note?.id != null) {
        await FirebaseFirestore.instance
            .collection('notes')
            .doc(widget.note!.id)
            .update(note.toMap());
      } else {
        await FirebaseFirestore.instance
            .collection('notes')
            .add(note.toMap());
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note saved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving note: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final borderColor = isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;

    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                bottom: BorderSide(color: borderColor),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.format_bold, 
                      color: _isBold ? primaryColor : textColor?.withOpacity(0.7)),
                    onPressed: () => setState(() => _isBold = !_isBold),
                    tooltip: 'Bold',
                  ),
                  IconButton(
                    icon: Icon(Icons.format_italic, 
                      color: _isItalic ? primaryColor : textColor?.withOpacity(0.7)),
                    onPressed: () => setState(() => _isItalic = !_isItalic),
                    tooltip: 'Italic',
                  ),
                  IconButton(
                    icon: Icon(Icons.format_underlined, 
                      color: _isUnderlined ? primaryColor : textColor?.withOpacity(0.7)),
                    onPressed: () => setState(() => _isUnderlined = !_isUnderlined),
                    tooltip: 'Underline',
                  ),
                  const VerticalDivider(thickness: 1),
                  IconButton(
                    icon: Icon(Icons.format_list_bulleted, 
                      color: textColor?.withOpacity(0.7)),
                    onPressed: () {},
                    tooltip: 'Bullet List',
                  ),
                  IconButton(
                    icon: Icon(Icons.format_list_numbered, 
                      color: textColor?.withOpacity(0.7)),
                    onPressed: () {},
                    tooltip: 'Numbered List',
                  ),
                  const VerticalDivider(thickness: 1),
                  IconButton(
                    icon: Icon(Icons.image_search, 
                      color: primaryColor),
                    onPressed: _showImageToTextDialog,
                    tooltip: 'Image to Text',
                  ),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _titleController,
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Note Title',
                hintStyle: TextStyle(
                  color: textColor?.withOpacity(0.5),
                  fontSize: 22,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, 
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
              ),
            ),
          ),
        
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _contentController,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
                  fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
                  decoration: _isUnderlined ? TextDecoration.underline : TextDecoration.none,
                ),
                decoration: InputDecoration(
                  hintText: 'Start typing your note...',
                  hintStyle: TextStyle(
                    color: textColor?.withOpacity(0.5),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: borderColor),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Last edited: ${widget.note?.updatedAt != null ? 
                    _formatDate(widget.note!.updatedAt) : 
                    'Just now'}',
                  style: TextStyle(
                    color: textColor?.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                
                const Spacer(),
                
                _isLoading
                    ? SizedBox(
                        width: 36, 
                        height: 36,
                        child: LoadingAnimationWidget.stretchedDots(
                          color: primaryColor,
                          size: 36,
                        ),
                      )
                    : Row(
                        children: [
                          if (widget.note?.id != null)
                            ElevatedButton(
                              onPressed: () => _confirmDeleteNote(context, widget.note!.id!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.all(12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size(48, 48),
                              ),
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveNote,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.all(12), 
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              minimumSize: const Size(48, 48),
                            ),
                            child: const Icon(Icons.save, color: Colors.white),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ],
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
      
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting note: ${e.toString()}')),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class NoteEditorSheet extends StatefulWidget {
  final Note? note;

  const NoteEditorSheet({super.key, this.note});

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      height: MediaQuery.of(context).size.height * 0.9,
      child: NoteEditorPage(note: widget.note),
    );
  }
}

class ModalNoteEditor extends StatelessWidget {
  final Note? note;
  
  const ModalNoteEditor({super.key, this.note});
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: screenHeight * 0.85,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          note != null ? 'Edit Note' : 'New Note',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.titleLarge?.color,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          iconSize: 24,
                        ),
                      ],
                    ),
                  ),
                  
                  Expanded(
                    child: NoteEditorPage(note: note),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
