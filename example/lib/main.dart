import 'dart:async';

import 'package:apple_intelligence_flutter/apple_intelligence_flutter.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apple Intelligence Flutter Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Apple Intelligence Flutter Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _contextController = TextEditingController();
  final TextProcessingService _textService = TextProcessingService();
  AppleIntelligenceAvailability? _availability;
  TextProcessingResponse? _response;
  String? _initError;
  String _streamingText = '';
  bool _initializing = true;
  bool _isProcessing = false;
  bool _useStreaming = false;
  StreamSubscription<AppleIntelligenceStreamChunk>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _initializeClient();
  }

  Future<void> _initializeClient() async {
    setState(() {
      _initializing = true;
      _initError = null;
    });

    try {
      final availability = await AppleIntelligenceClient.instance.initialize(
        instructions: 'You are an Apple Intelligence assistant that answers succinctly.',
      );
      if (!mounted) return;
      setState(() {
        _availability = availability;
      });
    } on AppleIntelligenceException catch (error) {
      if (!mounted) return;
      setState(() {
        _initError = error.message;
        if (error.details is Map) {
          _availability = AppleIntelligenceAvailability.fromPlatformResponse(
            Map<String, dynamic>.from(error.details as Map),
          );
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initError = '$error';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _initializing = false;
      });
    }
  }

  Future<void> _processText() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
      _response = null;
      _streamingText = '';
    });

    final request = TextProcessingRequest(
      text: _textController.text,
      context: _contextController.text.trim().isEmpty ? null : _contextController.text,
    );

    if (_useStreaming) {
      _startStreaming(request);
      return;
    }

    try {
      final response = await _textService.processText(request);
      if (!mounted) return;
      setState(() {
        _response = response;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _response = TextProcessingResponse(
          success: false,
          error: 'Unexpected error: $e',
        );
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _startStreaming(TextProcessingRequest request) {
    _streamSubscription?.cancel();
    _streamSubscription = _textService.streamText(request).listen(
      (chunk) {
        if (!mounted) return;
        setState(() {
          _streamingText = chunk.cumulativeText ?? _streamingText;
          if (chunk.isFinal) {
            _response = TextProcessingResponse(
              success: true,
              processedText: _streamingText.isNotEmpty ? _streamingText : null,
              metadata: {
                if (chunk.rawJson != null) 'raw': chunk.rawJson,
              },
            );
            _isProcessing = false;
          }
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _response = TextProcessingResponse(
            success: false,
            error: '$error',
          );
          _isProcessing = false;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
        });
      },
    );
  }

  Widget _buildAvailabilityCard() {
    if (_initializing) {
      return const ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        title: Text('Checking Apple Intelligence availability...'),
      );
    }

    if (_initError != null) {
      return ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red),
        title: const Text('Initialization failed'),
        subtitle: Text(_initError!),
      );
    }

    final availability = _availability;
    if (availability == null) {
      return const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('Awaiting availability information...'),
      );
    }

    final subtitle = [
      if (availability.reason != null) availability.reason!,
      availability.sessionReady ? 'Session ready.' : 'Session will be created on demand.',
    ].join('\n');

    return ListTile(
      leading: Icon(
        availability.available ? Icons.check_circle : Icons.info_outline,
        color: availability.available ? Colors.green : Colors.orange,
      ),
      title: Text(availability.available ? 'Apple Intelligence available' : 'Apple Intelligence unavailable'),
      subtitle: Text(subtitle),
    );
  }

  Widget _buildResponseCard() {
    final response = _response;
    if (response == null) {
      return const SizedBox.shrink();
    }

    final headline = response.success ? 'Result' : 'Error';
    final bodyText = response.success
        ? (response.processedText?.isNotEmpty == true ? response.processedText! : 'No result returned.')
        : response.error ?? 'Unknown error occurred.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headline,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: response.success ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(bodyText),
            if (response.metadata != null && response.metadata!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Metadata',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    ...response.metadata!.entries.map(
                      (entry) => Text('${entry.key}: ${entry.value}'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamingCard() {
    if (!_useStreaming) {
      return const SizedBox.shrink();
    }

    if (_streamingText.isEmpty && !_isProcessing) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt),
                const SizedBox(width: 8),
                Text(_isProcessing ? 'Streaming response…' : 'Stream complete'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _streamingText.isEmpty ? 'Waiting for streaming data…' : _streamingText,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(child: _buildAvailabilityCard()),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Enter text to process',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contextController,
              decoration: const InputDecoration(
                labelText: 'Optional context',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: _useStreaming,
              onChanged: _isProcessing
                  ? null
                  : (value) {
                      setState(() {
                        _useStreaming = value;
                      });
                      if (!value) {
                        _streamSubscription?.cancel();
                      }
                    },
              title: const Text('Stream response incrementally'),
              subtitle: const Text('Receive partial output as Apple Intelligence generates it'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: (_isProcessing || _initializing) ? null : _processText,
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Process Text'),
            ),
            const SizedBox(height: 16),
            _buildStreamingCard(),
            _buildResponseCard(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _contextController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}
