import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:math' show min;
import 'package:url_launcher/url_launcher.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shimmer/shimmer.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:html/dom.dart' as dom;

class AiToolsPage extends StatefulWidget {
  const AiToolsPage({Key? key}) : super(key: key);

  @override
  State<AiToolsPage> createState() => _AiToolsPageState();
}

class _AiToolsPageState extends State<AiToolsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  
  bool _isLoading = false;
  
  String _textSummaryResult = '';
  String _youTubeSummaryResult = '';
  String _pdfSummaryResult = '';
  
  final String _apiKey = 'AIzaSyBWsICAzMbqqJOxaaR4Jvj9GuJDmk2b1UQ'; 
  String? _selectedPdfPath;
  String _pdfText = '';

  _YouTubeVideoInfo _videoInfo = _YouTubeVideoInfo.empty();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _summarizeText() async {
    if (_textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text to summarize')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _textSummaryResult = '';
    });

    try {
      final summary = await _callGeminiApi(_textController.text);
      setState(() {
        _textSummaryResult = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _textSummaryResult = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _summarizeYouTube() async {
    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a YouTube URL')),
      );
      return;
    }

    final youtubeUrl = _urlController.text;
    if (!youtubeUrl.contains('youtube.com') && !youtubeUrl.contains('youtu.be')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid YouTube URL')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _youTubeSummaryResult = '';
    });

    try {
      final videoInfoFuture = _fetchYouTubeVideoInfo(_urlController.text);
      final transcriptFuture = _extractYouTubeTranscript(_urlController.text);
      
      final videoInfo = await videoInfoFuture;
      String? transcript = await transcriptFuture;
      
      String prompt;
      
      if (transcript == null || transcript.isEmpty) {
        if (videoInfo.title.isNotEmpty) {
          prompt = """
          I want information about this YouTube video:
          
          Title: ${videoInfo.title}
          Channel: ${videoInfo.channelName}
          ${videoInfo.viewCount.isNotEmpty ? "Views: ${videoInfo.viewCount}" : ""}
          ${videoInfo.uploadDate.isNotEmpty ? "Upload date: ${videoInfo.uploadDate}" : ""}
          
          I understand you can't watch this video directly. Based only on the title and channel information (not making assumptions about content):
          
          1. What topics might this video cover?
          2. What would be the best way for me to summarize this video myself after watching it?
          3. What key elements should I look for based on the title?
          
          Please be very clear that your response is based ONLY on the video metadata, not the actual content.
          """;
        } else {
          prompt = """
          I want to summarize the YouTube video at: ${_urlController.text}
          
          As an AI language model, I cannot directly access or watch YouTube videos, and I wasn't able to retrieve the title, channel or transcript for this video.
          
          Please provide:
          1. A clear explanation that you cannot access the video content
          2. General advice on how I could summarize the video myself
          3. What key elements to look for when watching any video to create a good summary
          
          Please be completely honest about your limitations.
          """;
        }
      } else {
        prompt = """
        Please summarize this YouTube video based on its transcript:
        
        Video Title: ${videoInfo.title}
        Channel: ${videoInfo.channelName}
        ${videoInfo.viewCount.isNotEmpty ? "Views: ${videoInfo.viewCount}" : ""}
        ${videoInfo.uploadDate.isNotEmpty ? "Upload date: ${videoInfo.uploadDate}" : ""}
        
        Transcript:
        $transcript
        
        Please provide a concise summary highlighting the main points and key takeaways from the transcript.
        Format your response with clear sections: Introduction, Main Points, and Conclusion.
        """;
      }
      
      final summary = await _callGeminiApi(prompt);
      
      setState(() {
        _youTubeSummaryResult = summary;
        _videoInfo = videoInfo;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _youTubeSummaryResult = 'Error: ${e.toString()}';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to summarize video: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        setState(() {
          _selectedPdfPath = result.files.single.path;
          _pdfText = '';
          _pdfSummaryResult = '';
        });
        await _extractTextFromPDF();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking PDF: ${e.toString()}')),
      );
    }
  }

  Future<void> _extractTextFromPDF() async {
    if (_selectedPdfPath == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      PdfDocument document = PdfDocument(inputBytes: File(_selectedPdfPath!).readAsBytesSync());
      
      String text = PdfTextExtractor(document).extractText();
      
      text = text.replaceAll('\n\n', '\n').trim();
      
      setState(() {
        _pdfText = text;
        _isLoading = false;
      });
      
      document.dispose();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _pdfText = 'Error extracting text: ${e.toString()}';
      });
    }
  }

  Future<void> _summarizePDF() async {
    if (_pdfText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF first')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _pdfSummaryResult = '';
    });

    try {
      final String textToSummarize = _pdfText.length > 5000 ? 
                                     '${_pdfText.substring(0, 5000)}...' : 
                                     _pdfText;
      
      final prompt = "Summarize the following text from a PDF document:\n\n$textToSummarize";
      final summary = await _callGeminiApi(prompt);
      
      setState(() {
        _pdfSummaryResult = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _pdfSummaryResult = 'Error: ${e.toString()}';
      });
    }
  }

  Future<String> _callGeminiApi(String prompt) async {
    const String baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': prompt,
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'] as List;
        final parts = candidates[0]['content']['parts'] as List;
        return parts[0]['text'] as String;
      } else {
        print('API Error: ${response.statusCode}');
        print('Response body: ${response.body}');
        
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        String errorMessage = '';
        
        if (errorData.containsKey('error')) {
          final error = errorData['error'];
          errorMessage = error['message'] ?? 'Unknown API error';
          
          if (error['code'] == 429 || errorMessage.contains('quota')) {
            return 'API quota exceeded. Please try again later.';
          }
        }
        
        throw 'API Error (${response.statusCode}): $errorMessage';
      }
    } catch (e) {
      if (e is SocketException) {
        return 'Network error. Please check your internet connection.';
      }
      if (e is TimeoutException) {
        return 'Request timed out. Please try again.';
      }
      return 'Error: ${e.toString()}';
    }
  }

  Future<_YouTubeVideoInfo> _fetchYouTubeVideoInfo(String videoUrl) async {
    print('Fetching video info for: $videoUrl');
    
    String videoTitle = '';
    String channelName = '';
    String viewCount = '';
    String uploadDate = '';
    
    try {
      String? videoId;
      if (videoUrl.contains('youtube.com/watch?v=')) {
        videoId = Uri.parse(videoUrl).queryParameters['v'];
      } else if (videoUrl.contains('youtu.be/')) {
        final pathSegments = Uri.parse(videoUrl).pathSegments;
        if (pathSegments.isNotEmpty) {
          videoId = pathSegments.last;
        }
      }
      
      if (videoId == null) {
        print('Could not extract video ID from URL');
        return _YouTubeVideoInfo.empty();
      }
      
      print('Extracted video ID: $videoId');
      
      try {
        final oembedUrl = 'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json';
        
        print('Trying oEmbed API: $oembedUrl');
        
        final oembedResponse = await http.get(
          Uri.parse(oembedUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
            'Accept': 'application/json',
          },
        );
        
        if (oembedResponse.statusCode == 200) {
          print('oEmbed API successful');
          final data = jsonDecode(oembedResponse.body);
          videoTitle = data['title'] ?? '';
          channelName = data['author_name'] ?? '';
          
          print('oEmbed data - Title: $videoTitle, Channel: $channelName');
          
          try {
            final invidiousUrl = 'https://invidious.projectsegfau.lt/api/v1/videos/$videoId';
            final invidiousResponse = await http.get(
              Uri.parse(invidiousUrl),
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Accept': 'application/json',
              },
            ).timeout(const Duration(seconds: 5)); 
            
            if (invidiousResponse.statusCode == 200) {
              final invidiousData = jsonDecode(invidiousResponse.body);
              final viewCountRaw = invidiousData['viewCount'];
              if (viewCountRaw != null) {
                try {
                  final count = int.parse(viewCountRaw.toString());
                  viewCount = _formatViewCount(count);
                  print('Extracted view count from Invidious: $viewCount');
                } catch (e) {
                  print('Error parsing view count from Invidious: $e');
                }
              }
              
              final publishedText = invidiousData['publishedText'];
              if (publishedText != null) {
                uploadDate = publishedText.toString();
                print('Extracted upload date from Invidious: $uploadDate');
              }
            }
          } catch (e) {
            print('Error with Invidious API, will try fallback method: $e');
          }
        } else {
          print('oEmbed API failed: ${oembedResponse.statusCode}');
        }
      } catch (e) {
        print('Error with oEmbed API: $e');
      }
      
      if (videoTitle.isNotEmpty && viewCount.isEmpty) {
        viewCount = 'View count unavailable';
      }
      
      if (videoTitle.isNotEmpty && uploadDate.isEmpty) {
        uploadDate = 'Upload date unavailable';
      }
      
      print('Returning video info - Title: $videoTitle, Channel: $channelName, Views: $viewCount, Date: $uploadDate');
      return _YouTubeVideoInfo(
        title: videoTitle,
        uploadDate: uploadDate,
        viewCount: viewCount,
        channelName: channelName,
      );
    } catch (e) {
      print('Error in YouTube info extraction: $e');
      return _YouTubeVideoInfo.empty();
    }
  }

  String _formatViewCount(int viewCount) {
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M views';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K views';
    } else {
      return '$viewCount views';
    }
  }
  
  String _formatUploadDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
  
  Future<void> _launchYouTubeVideo(String videoUrl) async {
    final Uri url = Uri.parse(videoUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the video')),
        );
      }
    }
  }

  Future<String?> _extractYouTubeTranscript(String videoUrl) async {
    try {
      String? videoId;
      if (videoUrl.contains('youtube.com/watch?v=')) {
        videoId = Uri.parse(videoUrl).queryParameters['v'];
      } else if (videoUrl.contains('youtu.be/')) {
        final pathSegments = Uri.parse(videoUrl).pathSegments;
        if (pathSegments.isNotEmpty) {
          videoId = pathSegments.last;
        }
      }
      
      if (videoId == null) {
        return null;
      }
      
            try {
        final invidiousUrl = 'https://invidious.projectsegfau.lt/api/v1/captions/$videoId?lang=en';
        final response = await http.get(
          Uri.parse(invidiousUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List && data.isNotEmpty) {
            final captionItem = data.firstWhere(
              (item) => item['languageCode'] == 'en',
              orElse: () => data.first,
            );
            
            if (captionItem != null && captionItem['url'] != null) {
              final captionUrl = captionItem['url'];
              final captionResponse = await http.get(Uri.parse(captionUrl));
              
              if (captionResponse.statusCode == 200) {
                final content = captionResponse.body;
                
                if (content.contains('<text ')) {
                  final document = dom.Document.html(content);
                  final textElements = document.querySelectorAll('text');
                  final transcriptParts = textElements.map((element) => element.text).toList();
                  return transcriptParts.join(' ');
                } else if (content.contains('"text":')) {
                  try {
                    final jsonData = jsonDecode(content);
                    if (jsonData['events'] != null) {
                      final List<dynamic> events = jsonData['events'];
                      final texts = events
                          .where((event) => event['segs'] != null)
                          .expand((event) => event['segs'])
                          .where((seg) => seg['utf8'] != null)
                          .map((seg) => seg['utf8'].toString())
                          .toList();
                      return texts.join(' ');
                    }
                  } catch (e) {
                    print('Error parsing JSON transcript: $e');
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        print('Error with Invidious captions API: $e');
      }
      
      try {
        final ytTranscriptUrl = 'https://yt-transcript-proxy.herokuapp.com/$videoId';
        final response = await http.get(Uri.parse(ytTranscriptUrl))
            .timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['transcript'] != null) {
            final transcript = data['transcript'] as List;
            final texts = transcript
                .map((item) => item['text'].toString())
                .toList();
            return texts.join(' ');
          }
        }
      } catch (e) {
        print('Error with transcript proxy API: $e');
      }
      
      try {
        final videoPageUrl = 'https://www.youtube.com/watch?v=$videoId&hl=en';
        final pageResponse = await http.get(
          Uri.parse(videoPageUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml',
          },
        );
        
        if (pageResponse.statusCode == 200) {
          final html = pageResponse.body;
          
          final transcriptMatch = RegExp(r'"captionTracks":\[\{"baseUrl":"([^"]+)"').firstMatch(html);
          
          if (transcriptMatch != null && transcriptMatch.group(1) != null) {
            final captionUrl = transcriptMatch.group(1)!.replaceAll('\\u0026', '&');
            
            final captionResponse = await http.get(Uri.parse(captionUrl));
            if (captionResponse.statusCode == 200) {
              final document = dom.Document.html(captionResponse.body);
              final textElements = document.querySelectorAll('text');
              
              final transcriptParts = textElements.map((element) => element.text).toList();
              return transcriptParts.join(' ');
            }
          }
        }
      } catch (e) {
        print('Error scraping YouTube page for transcript: $e');
      }
      
      print('No transcript found after trying all methods');
      return null;
    } catch (e) {
      print('Error extracting transcript: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Summarization',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Summarize text, videos, and documents using AI',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[800]!.withOpacity(0.5) : Colors.grey[200]!.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.0),
                      color: primaryColor,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    dividerHeight: 0,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: isDarkMode ? Colors.white70 : Colors.grey[700],
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'Text'),
                      Tab(text: 'YouTube'),
                      Tab(text: 'PDF'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 14),
                
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTextTabWithSummary(),
                        _buildYouTubeTabWithSummary(),
                        _buildPDFTabWithSummary(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LoadingAnimationWidget.stretchedDots(
                        color: isDarkMode ? accentColor : primaryColor,
                        size: 40,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Generating summary...',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

=  Widget _buildTextTabWithSummary() {
    return _buildCanteenStyleTab(
      LayoutBuilder(
        builder: (context, constraints) {
          if (_textSummaryResult.isNotEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildSummaryCard(_textSummaryResult),
                ),
                
                const SizedBox(height: 12),
                
                SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _textSummaryResult = '';
                        _textController.clear();
                      });
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text(
                      'Summarize Another Text',
                      style: TextStyle(fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ),
              ],
            );
          }
          
          return _buildTextTab();
        }
      ),
    );
  }
  
  Widget _buildYouTubeTabWithSummary() {
    return _buildCanteenStyleTab(
      LayoutBuilder(
        builder: (context, constraints) {
          if (_youTubeSummaryResult.isNotEmpty) {
            return _buildYouTubeSummaryCard(_youTubeSummaryResult, _urlController.text);
          }
          
          return _buildYouTubeTab();
        }
      ),
    );
  }
  
  Widget _buildPDFTabWithSummary() {
    return _buildCanteenStyleTab(
      LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _pdfSummaryResult.isNotEmpty ?
                    min(200, constraints.maxHeight * 0.45) :
                    constraints.maxHeight,
                child: _buildPDFTab(),
              ),
              
              if (_pdfSummaryResult.isNotEmpty) ...[
                const SizedBox(height: 12),
                Expanded(
                  child: _buildSummaryCard(_pdfSummaryResult),
                ),
              ],
            ],
          );
        }
      ),
    );
  }
  
  Widget _buildSummaryCard(String summaryText) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: accentColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'AI Summary',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Copy to clipboard',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: summaryText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Summary copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    summaryText,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanteenStyleTab(Widget content) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: content,
      ),
    );
  }

  Widget _buildTextTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.text_fields, color: primaryColor, size: 18),
            const SizedBox(width: 6),
            Text(
              'Text Summarization',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TextField(
            controller: _textController,
            decoration: InputDecoration(
              hintText: 'Paste or type text to summarize...',
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primaryColor),
              ),
              filled: true,
              fillColor: isDarkMode ? Colors.grey[800]!.withOpacity(0.3) : Colors.grey[100]!.withOpacity(0.5),
              contentPadding: const EdgeInsets.all(12),
            ),
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _summarizeText,
            icon: const Icon(Icons.summarize, size: 18),
            label: const Text(
              'Summarize Text',
              style: TextStyle(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10), 
              ),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
              elevation: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildYouTubeTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.video_library, color: primaryColor, size: 18),
            const SizedBox(width: 6),
            Text(
              'YouTube Summarization',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        
        TextField(
          controller: _urlController,
          decoration: InputDecoration(
            labelText: 'YouTube Video URL',
            labelStyle: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            hintText: 'https://www.youtube.com/watch?v=...',
            hintStyle: TextStyle(
              fontSize: 13,
              color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: primaryColor),
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800]!.withOpacity(0.3) : Colors.grey[100]!.withOpacity(0.5),
            prefixIcon: Icon(Icons.link, color: accentColor, size: 18),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          ),
          style: TextStyle(
            fontSize: 14,
          ),
        ),
        
        const SizedBox(height: 10),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800]!.withOpacity(0.3) : accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDarkMode ? Colors.grey[700]! : accentColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: isDarkMode ? Colors.grey[400] : accentColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'For the best results, provide a YouTube URL with available closed captions.',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const Spacer(),
        
        SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _summarizeYouTube,
            icon: const Icon(Icons.summarize, size: 18),
            label: const Text(
              'Summarize YouTube Video',
              style: TextStyle(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
              elevation: 1,
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildYouTubeSummaryCard(String summaryText, String videoUrl) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    String? videoId;
    if (videoUrl.contains('youtube.com/watch?v=')) {
      videoId = Uri.parse(videoUrl).queryParameters['v'];
    } else if (videoUrl.contains('youtu.be/')) {
      videoId = videoUrl.split('youtu.be/')[1].split('?').first.split('&').first;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        if (videoId != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GestureDetector(
                        onTap: () => _launchYouTubeVideo(videoUrl),
                        child: Image.network(
                          'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
                          height: 90,
                          width: 120,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return _buildShimmer(
                              width: 120,
                              height: 90,
                              radius: 8,
                              isDarkMode: isDarkMode,
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 90,
                            width: 120,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          _videoInfo.title.isNotEmpty
                              ? Text(
                                  _videoInfo.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : _buildShimmer(
                                  width: double.infinity,
                                  height: 14,
                                  radius: 2,
                                  isDarkMode: isDarkMode,
                                ),
                          
                          const SizedBox(height: 6),
                          
                          _videoInfo.channelName.isNotEmpty
                              ? Text(
                                  _videoInfo.channelName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : _buildShimmer(
                                  width: 100,
                                  height: 12,
                                  radius: 2,
                                  isDarkMode: isDarkMode,
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),
                
                GestureDetector(
                  onTap: () => _launchYouTubeVideo(videoUrl),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_circle_outline, size: 16, color: accentColor),
                        const SizedBox(width: 4),
                        Text(
                          'Watch on YouTube',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),
                
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, 
                               size: 12, 
                               color: isDarkMode ? accentColor.withOpacity(0.7) : primaryColor.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _videoInfo.viewCount.isNotEmpty
                                ? Text(
                                    _videoInfo.viewCount,
                                    style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : _buildShimmer(
                                    width: 40,
                                    height: 12,
                                    radius: 2,
                                    isDarkMode: isDarkMode,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, 
                               size: 14, 
                               color: isDarkMode ? accentColor.withOpacity(0.7) : primaryColor.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _videoInfo.uploadDate.isNotEmpty
                                ? Text(
                                    _videoInfo.uploadDate,
                                    style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : _buildShimmer(
                                    width: 40,
                                    height: 12,
                                    radius: 2,
                                    isDarkMode: isDarkMode,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),
        

        Expanded(
          child: Card(
            elevation: 1,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: accentColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'AI Summary',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Copy to clipboard',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: summaryText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Summary copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                  
                  const Divider(height: 16),
                  

                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          summaryText,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        

        SizedBox(
          height: 38,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _youTubeSummaryResult = '';
                _urlController.clear();
                _videoInfo = _YouTubeVideoInfo.empty();
              });
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text(
              'Summarize Another Video',
              style: TextStyle(fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide(color: primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmer({
    required double width,
    required double height,
    required double radius,
    required bool isDarkMode,
  }) {
    return Shimmer.fromColors(
      baseColor: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDarkMode ? Colors.grey[700]! : Colors.grey[100]!,
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  Widget _buildPDFTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        Row(
          children: [
            Icon(Icons.picture_as_pdf, color: primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'PDF Summarization',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _pickPDF,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text(
              'Select PDF Document',
              style: TextStyle(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: accentColor,
              foregroundColor: isDarkMode ? primaryColor : Colors.white,
              disabledBackgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
              elevation: 1,
            ),
          ),
        ),
        
        if (_selectedPdfPath != null)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: isDarkMode ? accentColor : primaryColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Selected: ${_getFileName(_selectedPdfPath!)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[800],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedPdfPath = null;
                      _pdfText = '';
                      _pdfSummaryResult = '';
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        
        SizedBox(height: _pdfText.isNotEmpty ? 10 : 16),
        
        if (_pdfText.isNotEmpty)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[850]!.withOpacity(0.5) : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(9),
                        topRight: Radius.circular(9),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.text_snippet_outlined,
                          size: 14,
                          color: isDarkMode ? Colors.grey[300] : primaryColor,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Extracted Text',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),

                        const Spacer(),
                        Text(
                          '${_pdfText.length > 10000 ? "10000+" : _pdfText.length} chars',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1, thickness: 1, color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: SingleChildScrollView(
                        child: Text(

                          _pdfText.length > 2000 ? '${_pdfText.substring(0, 2000)}...' : _pdfText,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        const SizedBox(height: 12),
        
        SizedBox(
          height: 38,
          child: ElevatedButton.icon(
            onPressed: _pdfText.isEmpty || _isLoading ? null : _summarizePDF,
            icon: const Icon(Icons.summarize, size: 18),
            label: const Text(
              'Summarize PDF',
              style: TextStyle(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
              elevation: 1,
            ),
          ),
        ),
      ],
    );
  }
  
  String _getFileName(String filePath) {
    final segments = filePath.split(Platform.pathSeparator);
    final fileName = segments.isNotEmpty ? segments.last : filePath;
    
    if (fileName.length > 30) {
      final extension = fileName.contains('.') ? 
          fileName.substring(fileName.lastIndexOf('.')) : '';
      final baseName = fileName.contains('.') ? 
          fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
      
      return '${baseName.substring(0, min(25, baseName.length))}...$extension';
    }
    
    return fileName;
  }

}

class _YouTubeVideoInfo {
  final String title;
  final String uploadDate;
  final String viewCount;
  final String channelName;

  _YouTubeVideoInfo({
    required this.title,
    required this.uploadDate,
    required this.viewCount,
    required this.channelName,
  });

  factory _YouTubeVideoInfo.empty() {
    return _YouTubeVideoInfo(
      title: '',
      uploadDate: '',
      viewCount: '',
      channelName: '',
    );
  }
}