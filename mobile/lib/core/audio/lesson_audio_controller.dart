import 'dart:async';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

enum LessonAudioStatus {
  idle,
  loading,
  ready,
  playing,
  paused,
  completed,
  error,
}

enum LessonAudioErrorCode {
  loadFailed,
  interrupted,
  missingPlugin,
  openFailed,
  playFailed,
  replayFailed,
  invalidSource,
}

class LessonAudioState {
  final LessonAudioStatus status;
  final Duration position;
  final Duration? duration;
  final double speed;
  final String? assetPath;
  final String? errorMessage;
  final LessonAudioErrorCode? errorCode;

  const LessonAudioState({
    this.status = LessonAudioStatus.idle,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1.0,
    this.assetPath,
    this.errorMessage,
    this.errorCode,
  });

  bool get isPlaying => status == LessonAudioStatus.playing;
  bool get isLoading => status == LessonAudioStatus.loading;
  bool get hasError => status == LessonAudioStatus.error;

  String? localizedErrorMessage(String uiLocale) {
    if (uiLocale == 'ru' && errorCode != null) {
      switch (errorCode!) {
        case LessonAudioErrorCode.loadFailed:
          return 'Не удалось загрузить аудиофайл.';
        case LessonAudioErrorCode.interrupted:
          return 'Воспроизведение аудио прервано.';
        case LessonAudioErrorCode.missingPlugin:
          return 'Аудиоплеер недоступен на этом устройстве.';
        case LessonAudioErrorCode.openFailed:
          return 'Не удалось открыть аудиофайл.';
        case LessonAudioErrorCode.playFailed:
          return 'Не удалось воспроизвести аудио.';
        case LessonAudioErrorCode.replayFailed:
          return 'Не удалось повторить воспроизведение аудио.';
        case LessonAudioErrorCode.invalidSource:
          return 'Неверный адрес медиафайла.';
      }
    }
    if (errorMessage != null && errorMessage!.trim().isNotEmpty) {
      return errorMessage;
    }
    if (errorCode != null) {
      switch (errorCode!) {
        case LessonAudioErrorCode.loadFailed:
          return 'Audio faylni yuklab bo‘lmadi.';
        case LessonAudioErrorCode.interrupted:
          return 'Audio ijrosi to‘xtatildi.';
        case LessonAudioErrorCode.missingPlugin:
          return 'Audio pleyer ushbu qurilmada mavjud emas.';
        case LessonAudioErrorCode.openFailed:
          return 'Audio faylni ochib bo‘lmadi.';
        case LessonAudioErrorCode.playFailed:
          return 'Audio ijro etilmadi.';
        case LessonAudioErrorCode.replayFailed:
          return 'Audio qayta ijro etilmadi.';
        case LessonAudioErrorCode.invalidSource:
          return 'Media manzili noto‘g‘ri.';
      }
    }
    return null;
  }

  LessonAudioState copyWith({
    LessonAudioStatus? status,
    Duration? position,
    Duration? duration,
    double? speed,
    String? assetPath,
    String? errorMessage,
    LessonAudioErrorCode? errorCode,
    bool clearError = false,
  }) {
    return LessonAudioState(
      status: status ?? this.status,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      assetPath: assetPath ?? this.assetPath,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}

abstract class LessonAudioController {
  LessonAudioState get state;
  Stream<LessonAudioState> get stateStream;

  Future<void> loadAsset(String assetPath, {Duration? fallbackDuration});
  Future<void> play();
  Future<void> pause();
  Future<void> replay();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioLessonController implements LessonAudioController {
  final AudioPlayer _player;
  final StreamController<LessonAudioState> _stateController =
      StreamController<LessonAudioState>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  LessonAudioState _state = const LessonAudioState();
  bool _assetLoaded = false;
  bool _disposed = false;
  int _loadGeneration = 0;

  JustAudioLessonController({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _subscriptions.add(
      _player.positionStream.listen((position) {
        final duration = _state.duration;
        final clamped = duration != null && position > duration
            ? duration
            : position;
        _emit(_state.copyWith(position: clamped));
      }),
    );
    _subscriptions.add(
      _player.durationStream.listen((duration) {
        if (duration != null && duration > Duration.zero) {
          _emit(_state.copyWith(duration: duration));
        }
      }),
    );
    _subscriptions.add(
      _player.speedStream.listen((speed) {
        _emit(_state.copyWith(speed: speed));
      }),
    );
    _subscriptions.add(
      _player.playerStateStream.listen((playerState) {
        if (_state.status == LessonAudioStatus.error) return;
        final processing = playerState.processingState;
        if (processing == ProcessingState.loading ||
            processing == ProcessingState.buffering) {
          _emit(_state.copyWith(status: LessonAudioStatus.loading));
        } else if (processing == ProcessingState.completed) {
          _emit(
            _state.copyWith(
              status: LessonAudioStatus.completed,
              position: _state.duration ?? _state.position,
            ),
          );
        } else if (playerState.playing) {
          _emit(
            _state.copyWith(
              status: LessonAudioStatus.playing,
              clearError: true,
            ),
          );
        } else if (processing == ProcessingState.ready) {
          final nextStatus = _state.position > Duration.zero
              ? LessonAudioStatus.paused
              : LessonAudioStatus.ready;
          _emit(_state.copyWith(status: nextStatus));
        }
      }),
    );
  }

  @override
  LessonAudioState get state => _state;

  @override
  Stream<LessonAudioState> get stateStream => _stateController.stream;

  void _emit(LessonAudioState next) {
    if (_disposed) return;
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  @override
  Future<void> loadAsset(String assetPath, {Duration? fallbackDuration}) async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    _assetLoaded = false;
    _emit(
      _state.copyWith(
        status: LessonAudioStatus.loading,
        assetPath: assetPath,
        position: Duration.zero,
        duration: fallbackDuration,
        clearError: true,
      ),
    );
    try {
      final loadedDuration = await _player.setAsset(assetPath);
      if (_disposed || generation != _loadGeneration) return;
      _assetLoaded = true;
      _emit(
        _state.copyWith(
          status: LessonAudioStatus.ready,
          position: Duration.zero,
          duration: loadedDuration ?? fallbackDuration,
          assetPath: assetPath,
          clearError: true,
        ),
      );
    } on PlayerException catch (e) {
      if (_disposed || generation != _loadGeneration) return;
      _emit(
        _state.copyWith(
          status: LessonAudioStatus.error,
          errorMessage: e.message ?? 'Audio faylni yuklab bo‘lmadi.',
          errorCode: LessonAudioErrorCode.loadFailed,
        ),
      );
    } on PlayerInterruptedException {
      if (_disposed || generation != _loadGeneration) return;
      _emit(
        _state.copyWith(
          status: LessonAudioStatus.error,
          errorMessage: 'Audio ijrosi to‘xtatildi.',
          errorCode: LessonAudioErrorCode.interrupted,
        ),
      );
    } on MissingPluginException {
      if (_disposed || generation != _loadGeneration) return;
      _emit(
        _state.copyWith(
          status: LessonAudioStatus.error,
          errorMessage: 'Audio pleyer ushbu qurilmada mavjud emas.',
          errorCode: LessonAudioErrorCode.missingPlugin,
        ),
      );
    } on PlatformException catch (e) {
      if (_disposed || generation != _loadGeneration) return;
      _emit(
        _state.copyWith(
          status: LessonAudioStatus.error,
          errorMessage: e.message ?? 'Audio faylni ochib bo‘lmadi.',
          errorCode: LessonAudioErrorCode.openFailed,
        ),
      );
    } catch (_) {
      if (_disposed || generation != _loadGeneration) return;
      _emit(
        _state.copyWith(
          status: LessonAudioStatus.error,
          errorMessage: 'Audio faylni ijro etib bo‘lmadi.',
          errorCode: LessonAudioErrorCode.loadFailed,
        ),
      );
    }
  }

  @override
  Future<void> play() async {
    if (_disposed || !_assetLoaded || _state.assetPath == null) return;
    if (_state.hasError) {
      _emit(_state.copyWith(status: LessonAudioStatus.ready, clearError: true));
    }
    try {
      if (_state.status == LessonAudioStatus.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    } on PlayerException catch (e) {
      _emit(
        _state.copyWith(
          status: LessonAudioStatus.error,
          errorMessage: e.message ?? 'Audio ijro etilmadi.',
          errorCode: LessonAudioErrorCode.playFailed,
        ),
      );
    } on PlatformException catch (e) {
      _emit(
        _state.copyWith(
          status: LessonAudioStatus.error,
          errorMessage: e.message ?? 'Audio ijro etilmadi.',
          errorCode: LessonAudioErrorCode.playFailed,
        ),
      );
    } catch (_) {
      _emit(
        _state.copyWith(
          status: LessonAudioStatus.error,
          errorMessage: 'Audio ijro etilmadi.',
          errorCode: LessonAudioErrorCode.playFailed,
        ),
      );
    }
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    try {
      await _player.pause();
    } catch (_) {
      // Ignore pause errors if player is not ready.
    }
  }

  @override
  Future<void> replay() async {
    if (_disposed || !_assetLoaded || _state.assetPath == null) return;
    if (_state.hasError) {
      _emit(_state.copyWith(status: LessonAudioStatus.ready, clearError: true));
    }
    try {
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (_) {
      _emit(
        _state.copyWith(
          status: LessonAudioStatus.error,
          errorMessage: 'Audio qayta ijro etilmadi.',
          errorCode: LessonAudioErrorCode.replayFailed,
        ),
      );
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    try {
      await _player.seek(position);
    } catch (_) {
      // Ignore seek errors on unloaded player.
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    try {
      await _player.setSpeed(speed);
      _emit(_state.copyWith(speed: speed));
    } catch (_) {
      // Ignore speed errors on unsupported backends.
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    final stopGen = ++_loadGeneration;
    try {
      await _player.stop();
      if (_disposed || stopGen != _loadGeneration) return;
      _emit(
        _state.copyWith(
          status: _assetLoaded
              ? LessonAudioStatus.ready
              : LessonAudioStatus.idle,
          position: Duration.zero,
          clearError: true,
        ),
      );
    } catch (_) {
      // Ignore stop errors.
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _loadGeneration++;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    try {
      await _player.dispose();
    } catch (_) {
      // Ignore player dispose errors so state stream always closes cleanly.
    } finally {
      await _stateController.close();
    }
  }
}

class FakeLessonAudioController implements LessonAudioController {
  bool failOnLoad;
  bool failOnPlay;
  final Duration simulatedDuration;
  final Duration tickStep;
  final bool autoAdvanceOnPlay;

  final List<String> loadedAssets = [];
  int loadCalls = 0;
  int playCalls = 0;
  int pauseCalls = 0;
  int replayCalls = 0;
  int seekCalls = 0;
  int speedCalls = 0;
  int disposeCalls = 0;

  final StreamController<LessonAudioState> _stateController =
      StreamController<LessonAudioState>.broadcast();
  LessonAudioState _state = const LessonAudioState();
  Timer? _timer;
  bool _assetLoaded = false;
  bool _disposed = false;
  int _loadGeneration = 0;

  FakeLessonAudioController({
    this.failOnLoad = false,
    this.failOnPlay = false,
    this.simulatedDuration = const Duration(seconds: 6),
    this.tickStep = const Duration(milliseconds: 500),
    this.autoAdvanceOnPlay = false,
  });

  @override
  LessonAudioState get state => _state;

  @override
  Stream<LessonAudioState> get stateStream => _stateController.stream;

  void _emit(LessonAudioState next) {
    if (_disposed) return;
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> loadAsset(String assetPath, {Duration? fallbackDuration}) async {
    if (_disposed) return;
    final generation = ++_loadGeneration;
    _cancelTimer();
    _assetLoaded = false;
    loadCalls++;
    loadedAssets.add(assetPath);
    if (_disposed || generation != _loadGeneration) return;
    if (failOnLoad) {
      _emit(
        _state.copyWith(
          status: LessonAudioStatus.error,
          assetPath: assetPath,
          errorMessage: 'Audio faylni yuklab bo‘lmadi.',
          errorCode: LessonAudioErrorCode.loadFailed,
        ),
      );
      return;
    }
    _assetLoaded = true;
    _emit(
      _state.copyWith(
        status: LessonAudioStatus.ready,
        assetPath: assetPath,
        position: Duration.zero,
        duration: fallbackDuration ?? simulatedDuration,
        clearError: true,
      ),
    );
  }

  void _startAutoAdvanceTimer() {
    if (!autoAdvanceOnPlay) return;
    _cancelTimer();
    _timer = Timer.periodic(tickStep, (_) {
      if (_disposed || _state.status != LessonAudioStatus.playing) {
        _cancelTimer();
        return;
      }
      final total = _state.duration ?? simulatedDuration;
      final nextPos = _state.position + tickStep;
      if (nextPos >= total) {
        _cancelTimer();
        emitCompleted();
      } else {
        emitPosition(nextPos);
      }
    });
  }

  @override
  Future<void> play() async {
    if (_disposed) return;
    playCalls++;
    if (!_assetLoaded || (failOnLoad && _state.hasError)) {
      return;
    }
    if (failOnPlay) {
      _emit(
        _state.copyWith(
          status: LessonAudioStatus.error,
          errorMessage: 'Audio ijro etilmadi.',
          errorCode: LessonAudioErrorCode.playFailed,
        ),
      );
      return;
    }
    final startPos = _state.status == LessonAudioStatus.completed
        ? Duration.zero
        : _state.position;
    _emit(
      _state.copyWith(
        status: LessonAudioStatus.playing,
        position: startPos,
        clearError: true,
      ),
    );
    _startAutoAdvanceTimer();
  }

  @override
  Future<void> pause() async {
    if (_disposed) return;
    _cancelTimer();
    pauseCalls++;
    if (_state.status == LessonAudioStatus.playing) {
      _emit(_state.copyWith(status: LessonAudioStatus.paused));
    }
  }

  @override
  Future<void> replay() async {
    if (_disposed) return;
    _cancelTimer();
    replayCalls++;
    if (!_assetLoaded || (failOnLoad && _state.hasError)) {
      return;
    }
    if (failOnPlay) {
      _emit(
        _state.copyWith(
          status: LessonAudioStatus.error,
          errorMessage: 'Audio qayta ijro etilmadi.',
          errorCode: LessonAudioErrorCode.replayFailed,
        ),
      );
      return;
    }
    _emit(
      _state.copyWith(
        status: LessonAudioStatus.playing,
        position: Duration.zero,
        clearError: true,
      ),
    );
    _startAutoAdvanceTimer();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_disposed) return;
    seekCalls++;
    final total = _state.duration ?? simulatedDuration;
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > total ? total : position);
    _emit(_state.copyWith(position: clamped));
  }

  @override
  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    speedCalls++;
    _emit(_state.copyWith(speed: speed));
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    _loadGeneration++;
    _cancelTimer();
    _emit(
      _state.copyWith(
        status: _assetLoaded
            ? LessonAudioStatus.ready
            : LessonAudioStatus.idle,
        position: Duration.zero,
        clearError: true,
      ),
    );
  }

  void emitPosition(Duration position) {
    final total = _state.duration ?? simulatedDuration;
    final clamped = position > total ? total : position;
    _emit(_state.copyWith(position: clamped));
  }

  void emitCompleted() {
    _cancelTimer();
    _emit(
      _state.copyWith(
        status: LessonAudioStatus.completed,
        position: _state.duration ?? simulatedDuration,
      ),
    );
  }

  void emitError(String message) {
    _cancelTimer();
    _emit(
      _state.copyWith(
        status: LessonAudioStatus.error,
        errorMessage: message,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _loadGeneration++;
    _cancelTimer();
    disposeCalls++;
    await _stateController.close();
  }
}
