import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:base_sdk/src/di/injection.dart';
import 'package:base_sdk/src/application/like/like_notifier.dart';
import 'package:base_sdk/src/application/like/like_state.dart';

final likeProvider = StateNotifierProvider<LikeNotifier, LikeState>(
  (ref) => LikeNotifier(shopsRepository),
);
