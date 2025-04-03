import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import '../services/math_solver_service.dart';
import '../services/text_recognition_service.dart';

class MathSolverPage extends StatefulWidget {
  const MathSolverPage({Key? key}) : super(key: key);

  @override
  State<MathSolverPage> createState() => _MathSolverPageState();
}

class _MathSolverPageState extends State<MathSolverPage> {
  final TextEditingController _equationController = TextEditingController();
  String _solution = '';
  File? _image;
  bool _isLoading = false;
  bool _isProcessingImage = false;
  final ImagePicker _picker = ImagePicker();
  String _processingStatus = '';
  String _errorMessage = '';
  int _retryCount = 0;
  String _detectedEquationType = '';

  // Create instances of our services
  final MathSolverService _mathSolverService = MathSolverService();
  final TextRecognitionService _textRecognitionService =
      TextRecognitionService();

  // Working example equations
  final List<String> _exampleEquations = [
    '2x + 5 = 15',
    'x^2 - 4 = 0',
    'factor(x^2 + 2x + 1)',
    'derive(x^2)',
    'integrate(2x)',
    'sin(pi/3)',
    '5+5',
    'sqrt(16)',
    'log(100)',
  ];

  @override
  void initState() {
    super.initState();
    _equationController.addListener(() {
      if (_errorMessage.isNotEmpty) {
        setState(() {
          _errorMessage = '';
        });
      }

      // Clear detected type when equation changes
      _updateDetectedEquationType();
    });
  }

  void _updateDetectedEquationType() {
    if (_equationController.text.isNotEmpty) {
      setState(() {
        _detectedEquationType =
            _mathSolverService.detectEquationType(_equationController.text);
      });
    } else {
      setState(() {
        _detectedEquationType = '';
      });
    }
  }

  @override
  void dispose() {
    _equationController.dispose();
    _textRecognitionService.dispose();
    super.dispose();
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
          _isProcessingImage = true;
          _processingStatus = 'Analyzing image...';
          _solution = '';
          _errorMessage = '';
          _detectedEquationType = '';
        });

        await _recognizeEquation();
      }
    } catch (e) {
      setState(() {
        _isProcessingImage = false;
        _errorMessage = 'Error processing image: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _recognizeEquation() async {
    try {
      if (_image == null) return;

      setState(() {
        _processingStatus = 'Recognizing equation...';
      });

      String extractedText =
          await _textRecognitionService.recognizeTextFromImage(_image!);

      if (extractedText.isNotEmpty) {
        setState(() {
          _equationController.text = extractedText;
          _processingStatus = 'Equation detected!';
          _isProcessingImage = false;
        });

        _updateDetectedEquationType();

        // Automatically solve the equation
        await _solveEquation();
      } else {
        setState(() {
          _processingStatus = '';
          _isProcessingImage = false;
          _errorMessage =
              'No equation detected. Please try again with a clearer image.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'No equation detected. Please try again with a clearer image.')),
        );
      }
    } catch (e) {
      setState(() {
        _processingStatus = '';
        _isProcessingImage = false;
        _errorMessage = 'Error recognizing equation: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recognizing equation: ${e.toString()}')),
      );
    }
  }

  Future<void> _solveEquation() async {
    if (_equationController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an equation';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an equation')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _solution = '';
      _processingStatus = 'Solving equation...';
      _errorMessage = '';
    });

    try {
      String solution =
          await _mathSolverService.solveEquation(_equationController.text);

      setState(() {
        _solution = solution;
        _isLoading = false;
        _processingStatus = '';

        if (solution.contains('Error:')) {
          _retryCount++;
          if (_retryCount > 1) {
            _showExampleSuggestion();
          }
        } else {
          _retryCount = 0;
        }
      });
    } catch (e) {
      setState(() {
        _solution =
            'Error: Could not solve the equation. Please check your input and try again.';
        _isLoading = false;
        _processingStatus = '';

        _retryCount++;
        if (_retryCount > 1) {
          _showExampleSuggestion();
        }
      });
    }
  }

  void _showExampleSuggestion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Try an Example'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Having trouble? Try one of these example equations:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _exampleEquations.length,
                  itemBuilder: (context, index) {
                    return InkWell(
                      onTap: () {
                        _equationController.text = _exampleEquations[index];
                        Navigator.pop(context);
                        _updateDetectedEquationType();
                        _solveEquation();
                      },
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_exampleEquations[index]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _equationController,
                    decoration: InputDecoration(
                      labelText: 'Enter your equation',
                      hintText: 'e.g. 2x + 5 = 15',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: _equationController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _equationController.clear();
                                  _solution = '';
                                  _errorMessage = '';
                                  _detectedEquationType = '';
                                });
                              },
                            )
                          : null,
                      errorText:
                          _errorMessage.isNotEmpty ? _errorMessage : null,
                    ),
                    onChanged: (value) {
                      setState(() {});
                      _updateDetectedEquationType();
                    },
                    onSubmitted: (_) =>
                        _solveEquation(),
                  ),

                  if (_detectedEquationType.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Detected: $_detectedEquationType',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _showExampleSuggestion,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 6),
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'See examples',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Flexible(
                    child: Text(
                      'Equation type will be detected automatically',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _getImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor:
                            isDarkMode ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _getImage(ImageSource.gallery),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: (_isLoading || _isProcessingImage)
                      ? null
                      : _solveEquation,
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDarkMode ? Colors.white : Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'SOLVE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              if (_processingStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                Center(
                  child: Column(
                    children: [
                      Text(
                        _processingStatus,
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_image != null) ...[
                      Row(
                        children: [
                          Text(
                            'Image Preview:',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 14),
                            onPressed: () {
                              setState(() {
                                _image = null;
                              });
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 18,
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 70,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _image!,
                                height: 70,
                                width: 90,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_equationController.text.isNotEmpty)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Detected:',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(
                                        height: 2),
                                    Text(
                                      _equationController.text,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Divider(
                          height: 12, thickness: 0.5, color: Colors.grey[300]),
                    ],

                    if (_solution.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 2, bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              'Solution:',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(
                                        ClipboardData(text: _solution))
                                    .then((_) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Solution copied to clipboard'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.copy,
                                      size: 14,
                                      color: primaryColor,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Copy',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: primaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey[800]
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _solution,
                              style: TextStyle(
                                fontSize:
                                    16.5,
                                height:
                                    1.5,
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (_isLoading &&
                        _solution.isEmpty &&
                        !_isProcessingImage &&
                        _image == null) ...[
                      const Spacer(),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                            const SizedBox(height: 16),
                            const Text('Processing...'),
                          ],
                        ),
                      ),
                      const Spacer(),
                    ],

                    if (!_isLoading &&
                        _solution.isEmpty &&
                        !_isProcessingImage &&
                        _image == null) ...[
                      const Spacer(),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calculate_outlined,
                              size: 70,
                              color: Colors.grey.withOpacity(0.7),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Enter an equation or take a photo to solve a math problem',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
