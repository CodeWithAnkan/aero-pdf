import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model State
// ─────────────────────────────────────────────────────────────────────────────

class ModelState {
  final bool isDownloaded;
  final bool isDownloading;
  final double progress; // 0.0 to 1.0
  final String? error;

  const ModelState({
    this.isDownloaded = false,
    this.isDownloading = false,
    this.progress = 0.0,
    this.error,
  });

  ModelState copyWith({
    bool? isDownloaded,
    bool? isDownloading,
    double? progress,
    String? error,
  }) {
    return ModelState(
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      error: error, // If we pass null, it clears the error
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Model Manager Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ModelManager extends StateNotifier<ModelState> {
  ModelManager() : super(const ModelState()) {
    _checkStatus();
  }

  static const String _modelFileName = 'gemma-2b-it-cpu-int4.bin';
  static const String _modelUrl = 'https://github.com/CodeWithAnkan/aero-pdf/releases/download/v1.1.0/gemma-2b-it-cpu-int4.bin';

  Future<String> get _localPath async {
    final directory = await getApplicationSupportDirectory();
    return '${directory.path}/$_modelFileName';
  }

  Future<void> _checkStatus() async {
    final path = await _localPath;
    final exists = await File(path).exists();
    state = state.copyWith(isDownloaded: exists);
  }

  CancelToken? _cancelToken;

  Future<void> downloadModel() async {
    if (state.isDownloading || state.isDownloaded) return;

    state = state.copyWith(isDownloading: true, progress: 0.0, error: null);
    _cancelToken = CancelToken();

    try {
      final savePath = await _localPath;
      final dio = Dio();

      await dio.download(
        _modelUrl,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            state = state.copyWith(progress: received / total);
          }
        },
      );

      state = state.copyWith(
        isDownloading: false,
        isDownloaded: true,
        progress: 1.0,
      );
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        state = state.copyWith(isDownloading: false, progress: 0.0);
        return;
      }
      
      String userError = 'Download failed: $e';
      if (e is DioException) {
        final status = e.response?.statusCode;
        if (status == 404) {
          userError = 'Model file not found on server (404).';
        } else if (status == 401 || status == 403) {
          userError = 'Hugging Face Authentication Required ($status). Please add an Access Token.';
        } else if (e.type == DioExceptionType.connectionTimeout) {
          userError = 'Connection timed out. Try again later.';
        } else {
          userError = 'Network error ($status): ${e.message}';
        }
      }
      state = state.copyWith(
        isDownloading: false,
        error: userError,
      );
    } finally {
      _cancelToken = null;
    }
  }

  void cancelDownload() {
    _cancelToken?.cancel();
  }

  Future<void> deleteModel() async {
    final path = await _localPath;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    state = const ModelState();
  }
}

final modelManagerProvider = StateNotifierProvider<ModelManager, ModelState>((ref) {
  return ModelManager();
});
