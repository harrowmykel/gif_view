import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:gif_view/src/gif_cache_provider.dart';
import 'package:http/http.dart' as http;

class GifLoader {
  static final GifLoader instance = GifLoader._internal();

  GifCacheProvider _cacheProvider = MemoryCacheProvider();

  final Map<String, Completer<Uint8List?>> _loadCompleters = {};

  void setCacheProvider(GifCacheProvider? provider) {
    _cacheProvider = provider ?? MemoryCacheProvider();
  }

  factory GifLoader() {
    return instance;
  }

  GifLoader._internal();

  Future<Uint8List?> fetch(ImageProvider provider) async {
    String key = _getKeyImage(provider);

    Uint8List? cache = await _cacheProvider.get(key);
    if (cache != null) {
      return cache;
    }

    if (_loadCompleters[key] != null) {
      return _loadCompleters[key]!.future;
    }

    _loadCompleters[key] = Completer();
    _load(provider, key, _loadCompleters[key]!);
    return _loadCompleters[key]!.future;
  }

  Future<void> clearCache() {
    return _cacheProvider.clear();
  }

  String _getKeyImage(ImageProvider provider) {
    if (provider is NetworkImage) {
      return provider.url;
    } else if (provider is AssetImage) {
      return provider.assetName;
    } else if (provider is MemoryImage) {
      return provider.bytes.toString().substring(0, 100);
    } else if (provider is FileImage) {
      return provider.file.path;
    } else {
      return Random().nextDouble().toString();
    }
  }

  Future<Uint8List?> _loadImageBytes(ImageProvider<Object> provider) {
    if (provider is NetworkImage) {
      final Uri resolved = Uri.base.resolve(provider.url);
      return http
          .get(resolved, headers: provider.headers)
          .then((value) => value.bodyBytes);
    }
    if (provider is AssetImage) {
      return provider.obtainKey(const ImageConfiguration()).then(
        (value) async {
          final d = await value.bundle.load(value.name);
          return d.buffer.asUint8List();
        },
      );
    }
    if (provider is FileImage) {
      return provider.file.readAsBytes();
    }
    if (provider is MemoryImage) {
      return Future.value(provider.bytes);
    }
    return Future.value(null);
  }

  void _load(
    ImageProvider<Object> provider,
    String key,
    Completer<Uint8List?> completer,
  ) async {
    try {
      Uint8List? data = await _loadImageBytes(provider);
      if (data != null) {
        _cacheProvider.set(key, data);
      }
      completer.complete(data);
      _loadCompleters.remove(key);
    } catch (e) {
      completer.completeError(e);
    }
  }
}
