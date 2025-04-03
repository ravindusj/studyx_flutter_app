import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class ImageToTextDialog extends StatefulWidget {
  final Function(String) onAddToNote;

  const ImageToTextDialog({Key? key, required this.onAddToNote}) : super(key: key);

  @override
  State<ImageToTextDialog> createState() => _ImageToTextDialogState();
}

class _ImageToTextDialogState extends State<ImageToTextDialog> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String _extractedText = '';
  bool _isProcessing = false;
  bool _isError = false;
  String _errorMessage = '';

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? pickedImage = await _picker.pickImage(source: source);
      
      if (pickedImage == null) return;
      
      setState(() {
        _selectedImage = File(pickedImage.path);
        _extractedText = '';
        _isProcessing = true;
        _isError = false;
      });
      
      await _extractTextFromImage();
    } catch (e) {
      setState(() {
        _isError = true;
        _errorMessage = 'Failed to pick image: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  Future<void> _extractTextFromImage() async {
    if (_selectedImage == null) return;
    
    try {
      final inputImage = InputImage.fromFile(_selectedImage!);
      final textRecognizer = GoogleMlKit.vision.textRecognizer();
      
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      
      setState(() {
        _extractedText = recognizedText.text;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isError = true;
        _errorMessage = 'Failed to extract text: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  void _addTextToNote() {
    if (_extractedText.isNotEmpty) {
      widget.onAddToNote(_extractedText);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final borderColor = isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      backgroundColor: backgroundColor,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Image to Text',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textColor?.withOpacity(0.7)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            
            Divider(color: borderColor, height: 24),
            
            if (_selectedImage == null && !_isProcessing)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceButton(
                    context: context, 
                    icon: Icons.photo_camera,
                    label: 'Camera',
                    onTap: () => _getImage(ImageSource.camera),
                    primaryColor: primaryColor,
                    isDarkMode: isDarkMode,
                  ),
                  _buildSourceButton(
                    context: context, 
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () => _getImage(ImageSource.gallery),
                    primaryColor: primaryColor,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
              
            if (_isProcessing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    LoadingAnimationWidget.stretchedDots(
                      color: isDarkMode ? accentColor : primaryColor,
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Processing image...',
                      style: TextStyle(
                        color: textColor?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              )
            else if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.black54 : Colors.white70,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.refresh, color: primaryColor),
                        onPressed: () {
                          setState(() {
                            _selectedImage = null;
                            _extractedText = '';
                          });
                        },
                        tooltip: 'Change Image',
                        iconSize: 20,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
              
            if (_isError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
            if (_extractedText.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.text_fields, 
                          size: 18,
                          color: textColor?.withOpacity(0.7),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Extracted Text',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.3,
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _extractedText,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: textColor?.withOpacity(0.7),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add to Note'),
                    onPressed: _extractedText.isNotEmpty ? _addTextToNote : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: isDarkMode 
                          ? Colors.grey.shade800 
                          : Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSourceButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color primaryColor,
    required bool isDarkMode,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: primaryColor,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}