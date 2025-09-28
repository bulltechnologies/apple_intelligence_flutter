import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models/models.dart';

/// Exception thrown when Apple Intelligence interactions fail.
///
/// Errors are surfaced with a short [code], a readable [message], and optional
/// [details] provided by the native platform. Most errors originate from the
/// iOS `FoundationModels` framework and can be used to drive in-app messaging
/// or fallbacks.
class AppleIntelligenceException implements Exception {
  const AppleIntelligenceException({
    required this.code,
    required this.message,
    this.details,
  });

  final String code;
  final String message;
  final dynamic details;

  factory AppleIntelligenceException.fromPlatformException(
    PlatformException exception,
  ) {
    return AppleIntelligenceException(
      code: exception.code,
      message: exception.message ?? 'Apple Intelligence call failed.',
      details: exception.details,
    );
  }

  @override
  String toString() => 'AppleIntelligenceException($code, $message, $details)';
}

/// Represents availability information returned by the host platform.
///
/// During initialization and availability checks the native plugin reports
/// whether Apple Intelligence can service requests on this device. The
/// [code] aligns with the native availability reason and is suitable for
/// analytics or conditional UI, while [reason] contains a person-friendly
/// explanation. When [sessionReady] is `true`, a cached session is ready to
/// serve prompts immediately.
class AppleIntelligenceAvailability {
  const AppleIntelligenceAvailability({
    required this.available,
    required this.code,
    this.reason,
    this.sessionReady = false,
  });

  final bool available;
  final String code;
  final String? reason;
  final bool sessionReady;

  factory AppleIntelligenceAvailability.fromPlatformResponse(
    Map<String, dynamic>? response,
  ) {
    if (response == null) {
      return const AppleIntelligenceAvailability(
        available: false,
        code: 'unknown',
        reason: 'No availability information returned from native platform.',
      );
    }

    return AppleIntelligenceAvailability(
      available: response['available'] as bool? ?? false,
      code: response['code'] as String? ?? 'unknown',
      reason: response['reason'] as String?,
      sessionReady: response['sessionReady'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'available': available,
        'code': code,
        if (reason != null) 'reason': reason,
        'sessionReady': sessionReady,
      };
}

/// Main entry point for interacting with Apple Intelligence on-device models.
///
/// The client proxies method calls to the underlying iOS plugin which hosts a
/// `LanguageModelSession`. On unsupported platforms (non-iOS or iOS versions
/// earlier than 26) the methods short-circuit with availability information so
/// that apps can gracefully disable intelligence features.
class AppleIntelligenceClient {
  static AppleIntelligenceClient? _instance;

  AppleIntelligenceClient._();

  static const MethodChannel _channel =
      MethodChannel('apple_intelligence_flutter');
  static const EventChannel _streamChannel =
      EventChannel('apple_intelligence_flutter/stream');

  AppleIntelligenceAvailability? _lastAvailability;

  /// Get singleton instance
  static AppleIntelligenceClient get instance {
    _instance ??= AppleIntelligenceClient._();
    return _instance!;
  }

  /// Initialize the Apple Intelligence client.
  ///
  /// Optionally provide [instructions] to guide the on-device model. The
  /// native plugin stores the instructions and reuses them for the lifetime of
  /// the process, ensuring consistent outputs across prompts. On unsupported
  /// platforms, the call resolves with an unavailable result rather than
  /// throwing.
  Future<AppleIntelligenceAvailability> initialize(
      {String? instructions}) async {
    if (!_isPlatformSupported) {
      const availability = AppleIntelligenceAvailability(
        available: false,
        code: 'unsupported_platform',
        reason:
            'Apple Intelligence is currently available on iOS devices only.',
      );
      _lastAvailability = availability;
      return availability;
    }

    try {
      final sanitizedInstructions = instructions?.trim();
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'initialize',
        <String, dynamic>{
          if (sanitizedInstructions != null && sanitizedInstructions.isNotEmpty)
            'instructions': sanitizedInstructions,
        },
      );

      final availability =
          AppleIntelligenceAvailability.fromPlatformResponse(response);
      _lastAvailability = availability;
      return availability;
    } on PlatformException catch (e) {
      throw AppleIntelligenceException.fromPlatformException(e);
    }
  }

  /// Check if Apple Intelligence is available on the current device.
  ///
  /// This call triggers a lightweight availability probe on the host platform
  /// so it is safe to call during app start or before showing intelligence
  /// features.
  Future<bool> isAvailable() async {
    if (!_isPlatformSupported) {
      return false;
    }

    try {
      final response =
          await _channel.invokeMapMethod<String, dynamic>('isAvailable');
      final availability =
          AppleIntelligenceAvailability.fromPlatformResponse(response);
      _lastAvailability = availability;
      return availability.available;
    } on PlatformException catch (e) {
      throw AppleIntelligenceException.fromPlatformException(e);
    }
  }

  /// Send a prompt to Apple Intelligence and receive the generated text.
  ///
  /// When Apple Intelligence is unavailable or the prompt is empty an
  /// [AppleIntelligenceException] is thrown immediately. Otherwise the native
  /// session generates a response using the previously configured
  /// instructions. The returned [TextProcessingResponse] mirrors the rest of
  /// the package API for callers that rely on the service layer.
  Future<TextProcessingResponse> sendPrompt({
    required String prompt,
    String? context,
  }) async {
    if (!_isPlatformSupported) {
      throw const AppleIntelligenceException(
        code: 'unsupported_platform',
        message:
            'Apple Intelligence is currently available on iOS devices only.',
      );
    }

    final sanitizedPrompt = prompt.trim();
    if (sanitizedPrompt.isEmpty) {
      throw const AppleIntelligenceException(
        code: 'empty_prompt',
        message: 'Prompt must not be empty.',
      );
    }

    final sanitizedContext = context?.trim();

    try {
      final response = await _channel.invokeMethod<String>('sendPrompt', {
        'prompt': sanitizedPrompt,
        if (sanitizedContext != null && sanitizedContext.isNotEmpty)
          'context': sanitizedContext,
      });

      if (response == null) {
        throw const AppleIntelligenceException(
          code: 'no_response',
          message: 'Apple Intelligence returned an empty response.',
        );
      }

      return TextProcessingResponse(
        success: true,
        processedText: response,
        metadata: _lastAvailability?.toJson(),
      );
    } on PlatformException catch (e) {
      throw AppleIntelligenceException.fromPlatformException(e);
    }
  }

  /// Creates a cancellable streaming session for a prompt.
  ///
  /// The returned [AppleIntelligenceStreamSession] exposes a [Stream] of
  /// [AppleIntelligenceStreamChunk] updates and a [AppleIntelligenceStreamSession.stop]
  /// method that aborts the native request immediately.
  AppleIntelligenceStreamSession streamPromptSession({
    required String prompt,
    String? context,
  }) {
    if (!_isPlatformSupported) {
      final controller = StreamController<AppleIntelligenceStreamChunk>();
      controller.onListen = () {
        controller.addError(
          const AppleIntelligenceException(
            code: 'unsupported_platform',
            message:
                'Apple Intelligence is currently available on iOS devices only.',
          ),
        );
        controller.close();
      };
      controller.onCancel = () async {
        if (!controller.isClosed) {
          await controller.close();
        }
      };
      return AppleIntelligenceStreamSession._(
        controller,
        () async {
          if (!controller.isClosed) {
            await controller.close();
          }
        },
      );
    }

    final sanitizedPrompt = prompt.trim();
    if (sanitizedPrompt.isEmpty) {
      final controller = StreamController<AppleIntelligenceStreamChunk>();
      controller.onListen = () {
        controller.addError(
          const AppleIntelligenceException(
            code: 'empty_prompt',
            message: 'Prompt must not be empty.',
          ),
        );
        controller.close();
      };
      controller.onCancel = () async {
        if (!controller.isClosed) {
          await controller.close();
        }
      };
      return AppleIntelligenceStreamSession._(
        controller,
        () async {
          if (!controller.isClosed) {
            await controller.close();
          }
        },
      );
    }

    final sanitizedContext = context?.trim();
    final args = <String, dynamic>{
      'prompt': sanitizedPrompt,
      if (sanitizedContext != null && sanitizedContext.isNotEmpty)
        'context': sanitizedContext,
    };

    final controller = StreamController<AppleIntelligenceStreamChunk>();
    StreamSubscription<dynamic>? subscription;
    String previousText = '';
    var hasShutdown = false;

    Future<void> shutdown() async {
      if (hasShutdown) {
        return;
      }
      hasShutdown = true;
      await subscription?.cancel();
      subscription = null;
      if (!controller.isClosed) {
        await controller.close();
      }
    }

    controller.onListen = () {
      subscription = _streamChannel.receiveBroadcastStream(args).listen(
        (event) {
          final chunk = AppleIntelligenceStreamChunk.fromNativeEvent(
            event,
            previousText: previousText,
          );
          if (chunk.cumulativeText != null) {
            previousText = chunk.cumulativeText!;
          }

          if (!controller.isClosed) {
            controller.add(chunk);
          }

          if (chunk.isFinal) {
            // Close the session once the final payload has been delivered.
            unawaited(shutdown());
          }
        },
        onError: (error) {
          if (!controller.isClosed) {
            controller.addError(_mapStreamError(error));
          }
          unawaited(shutdown());
        },
        onDone: () {
          unawaited(shutdown());
        },
        cancelOnError: false,
      );
    };

    controller.onCancel = () async {
      await shutdown();
    };

    return AppleIntelligenceStreamSession._(
      controller,
      () async {
        await shutdown();
      },
    );
  }

  /// Continuously receives generated text for a prompt as Apple Intelligence streams tokens.
  ///
  /// Prefer [streamPromptSession] when you need a handle to cancel the request explicitly.
  /// The returned stream emits [AppleIntelligenceStreamChunk] instances with cumulative
  /// text, delta updates, and raw JSON payloads from the native `GeneratedContent` type.
  /// The final event has [AppleIntelligenceStreamChunk.isFinal] set to `true`.
  Stream<AppleIntelligenceStreamChunk> streamPrompt({
    required String prompt,
    String? context,
  }) {
    final session = streamPromptSession(
      prompt: prompt,
      context: context,
    );
    return session.stream;
  }

  /// Convenience helper that emits only the cumulative text for each streamed chunk.
  Stream<String> streamPromptText({
    required String prompt,
    String? context,
  }) {
    return streamPrompt(prompt: prompt, context: context)
        .where((chunk) => chunk.cumulativeText != null)
        .map((chunk) => chunk.cumulativeText!);
  }

  /// Last availability information reported by the host platform.
  ///
  /// Useful for debugging and providing richer UI without making an extra
  /// platform channel call.
  AppleIntelligenceAvailability? get lastAvailability => _lastAvailability;

  bool get _isPlatformSupported {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  Object _mapStreamError(Object error) {
    if (error is AppleIntelligenceException) {
      return error;
    }

    if (error is PlatformException) {
      return AppleIntelligenceException.fromPlatformException(error);
    }

    return error;
  }
}

/// Represents an active streaming session that can be canceled on-demand.
class AppleIntelligenceStreamSession {
  AppleIntelligenceStreamSession._(
    this._controller,
    this._stopCallback,
  );

  final StreamController<AppleIntelligenceStreamChunk> _controller;
  final Future<void> Function() _stopCallback;
  bool _stopInvoked = false;

  /// Stream of incremental chunks emitted by Apple Intelligence.
  Stream<AppleIntelligenceStreamChunk> get stream => _controller.stream;

  /// Indicates whether the session is still receiving updates.
  bool get isActive => !_controller.isClosed && !_stopInvoked;

  /// Cancels the underlying native request and closes the stream.
  Future<void> stop() async {
    if (_stopInvoked || _controller.isClosed) {
      _stopInvoked = true;
      return;
    }

    _stopInvoked = true;
    await _stopCallback();
  }

  /// Completes when the stream has finished emitting.
  Future<void> get done => _controller.done;
}

/// Represents a streaming update produced by Apple Intelligence.
class AppleIntelligenceStreamChunk {
  AppleIntelligenceStreamChunk({
    required this.isFinal,
    this.cumulativeText,
    this.delta,
    this.rawJson,
  });

  factory AppleIntelligenceStreamChunk.fromNativeEvent(
    dynamic event, {
    required String previousText,
  }) {
    if (event is! Map) {
      return AppleIntelligenceStreamChunk(isFinal: true);
    }

    final map = Map<String, dynamic>.from(event as Map);
    final isFinal = map['done'] as bool? ?? false;
    final cumulativeText = map['cumulativeText'] as String?;
    final rawJson = map['raw'] as String?;
    final deltaFromNative = map['deltaText'] as String?;

    String? delta;
    if (deltaFromNative != null && deltaFromNative.isNotEmpty) {
      delta = deltaFromNative;
    } else if (cumulativeText != null &&
        cumulativeText.startsWith(previousText)) {
      delta = cumulativeText.substring(previousText.length);
    } else {
      delta = cumulativeText;
    }

    return AppleIntelligenceStreamChunk(
      isFinal: isFinal,
      cumulativeText: cumulativeText,
      delta: delta?.isEmpty == true ? null : delta,
      rawJson: rawJson,
    );
  }

  final bool isFinal;
  final String? cumulativeText;
  final String? delta;
  final String? rawJson;
}
