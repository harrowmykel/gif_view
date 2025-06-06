import 'package:flutter/material.dart';
import 'package:gif_view/src/git_frame.dart';

enum GifStatus {
  loading,
  playing,
  stopped,
  completed,
  paused,
  reversing,
  error,
}

class GifController extends ChangeNotifier {
  List<GifFrame> _frames = [];
  int _currentIndex = 0;
  GifStatus status = GifStatus.loading;
  Object? exception;

  VoidCallback? _onFinish;
  VoidCallback? _onStart;
  ValueChanged<int>? _onFrame;

  bool _autoPlay = true;
  bool _loop = true;
  bool _inverted = false;

  int get index => _currentIndex;

  bool _isDisposed = false;

  void init({
    bool autoPlay = true,
    bool loop = true,
    bool inverted = false,
    VoidCallback? onStart,
    VoidCallback? onFinish,
    ValueChanged<int>? onFrame,
  }) {
    _autoPlay = autoPlay;
    _loop = loop;
    _inverted = inverted;
    _onStart = onStart;
    _onFinish = onFinish;
    _onFrame = onFrame;
  }

  void _run() {
    switch (status) {
      case GifStatus.playing:
      case GifStatus.reversing:
        _runNextFrame();
        break;

      // completed gifs should show the last frame
      case GifStatus.completed:
        _currentIndex = _frames.isEmpty ? 0 : _frames.length - 1;
        break;
      case GifStatus.stopped:
        _currentIndex = 0;
        break;
      case GifStatus.loading:
      case GifStatus.paused:
      case GifStatus.error:
    }
  }

  void _runNextFrame() async {
    if (_isDisposed || _frames.isEmpty) {
      return;
    }
    await Future.delayed(_frames[_currentIndex].duration);

    if (_isDisposed) {
      return;
    }

    if (status == GifStatus.reversing) {
      if (_currentIndex > 0) {
        int newIndex = _currentIndex - 1;
        _currentIndex = (newIndex % _frames.length);
      } else if (_loop) {
        _currentIndex = _frames.length - 1;
      } else {
        status = GifStatus.completed;
        _onFinish?.call();
      }
    } else {
      if (_currentIndex < _frames.length - 1) {
        int newIndex = _currentIndex + 1;
        _currentIndex = (newIndex % _frames.length);
      } else if (_loop) {
        _currentIndex = 0;
      } else {
        status = GifStatus.completed;
        _onFinish?.call();
      }
    }

    _onFrame?.call(_currentIndex);

    // set current index
    _run();
    // notify listener
    notifyListeners();
  }

  GifFrame get currentFrame => _frames[_currentIndex];
  int get countFrames => _frames.length;
  bool get isReversing => status == GifStatus.reversing;
  bool get isPaused =>
      status == GifStatus.completed ||
      status == GifStatus.stopped ||
      status == GifStatus.paused;
  bool get isPlaying => status == GifStatus.playing;

  void play({bool? inverted, int? initialFrame}) {
    if (status == GifStatus.loading || _frames.isEmpty) return;
    _inverted = inverted ?? _inverted;

    if (status == GifStatus.completed ||
        status == GifStatus.stopped ||
        status == GifStatus.paused) {
      status = _inverted ? GifStatus.reversing : GifStatus.playing;

      bool isValidInitialFrame =
          initialFrame != null &&
          initialFrame > 0 &&
          initialFrame < _frames.length - 1;

      if (isValidInitialFrame) {
        _currentIndex = initialFrame;
      } else {
        _currentIndex = isReversing ? _frames.length - 1 : _currentIndex;
      }
      _onStart?.call();
      _run();
    } else {
      status = _inverted ? GifStatus.reversing : GifStatus.playing;
    }
  }

  void stop() {
    if (_isDisposed) {
      return;
    }
    status = GifStatus.stopped;
  }

  void pause() {
    if (_isDisposed) {
      return;
    }
    status = GifStatus.paused;
  }

  void seek(int index) {
    if (_frames.isEmpty || _isDisposed) return;
    _currentIndex = (index % _frames.length);
    notifyListeners();
  }

  void configure(List<GifFrame> frames, {bool updateFrames = false}) {
    exception = null;
    _frames = frames;
    if (!updateFrames || status == GifStatus.loading) {
      status = GifStatus.stopped;
      if (_autoPlay) {
        play();
      }
      notifyListeners();
    }
  }

  void error(Object e) {
    if (_isDisposed) {
      return;
    }
    exception = e;
    status = GifStatus.error;
    notifyListeners();
  }

  void loading() {
    if (_isDisposed) {
      return;
    }
    status = GifStatus.loading;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
