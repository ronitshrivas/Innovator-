import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/Innovator/models/Feed_Content_Model.dart';

class FeedContentNotifier extends StateNotifier<List<FeedContent>> {
  FeedContentNotifier() : super([]);

  /// Add a new feed content item to the list
  void addContent(FeedContent content) {
    state = [...state, content];
  }

  /// Remove a feed content item by ID
  void removeContent(String contentId) {
    state = state.where((c) => c.id != contentId).toList();
  }

  /// Update a specific feed content item
  void updateContent(String contentId, FeedContent updatedContent) {
    state = [
      for (final content in state)
        if (content.id == contentId) updatedContent else content,
    ];
  }

  /// Update a specific field in a feed content item
  void updateContentField(
    String contentId, {
    String? status,
    String? description,
    int? likes,
    bool? isLiked,
    int? comments,
    bool? isFollowed,
  }) {
    state = [
      for (final content in state)
        if (content.id == contentId)
          content.copyWith(
            status: status,
            description: description,
            likes: likes,
            isLiked: isLiked,
            comments: comments,
            isFollowed: isFollowed,
          )
        else
          content,
    ];
  }

  /// Toggle like status for a feed content
  void toggleLike(String contentId) {
    state = [
      for (final content in state)
        if (content.id == contentId)
          content.copyWith(
            isLiked: !content.isLiked,
            likes: content.isLiked ? content.likes - 1 : content.likes + 1,
          )
        else
          content,
    ];
  }

  /// Toggle follow status for a feed content author
  void toggleFollow(String contentId) {
    state = [
      for (final content in state)
        if (content.id == contentId)
          content.copyWith(isFollowed: !content.isFollowed)
        else
          content,
    ];
  }

  /// Increment comment count
  void incrementComments(String contentId) {
    state = [
      for (final content in state)
        if (content.id == contentId)
          content.copyWith(comments: content.comments + 1)
        else
          content,
    ];
  }

  /// Decrement comment count
  void decrementComments(String contentId) {
    state = [
      for (final content in state)
        if (content.id == contentId)
          content.copyWith(comments: content.comments - 1)
        else
          content,
    ];
  }

  /// Clear all feed content
  void clearAll() {
    state = [];
  }

  /// Replace entire feed list (useful for pagination)
  void setFeed(List<FeedContent> newFeed) {
    state = newFeed;
  }

  /// Append new items to feed (for infinite scroll)
  void appendFeed(List<FeedContent> newItems) {
    state = [...state, ...newItems];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── Individual Feed Content State Notifier (for single item management) ───────
// ─────────────────────────────────────────────────────────────────────────────

class SingleFeedContentNotifier extends StateNotifier<FeedContent?> {
  SingleFeedContentNotifier() : super(null);

  void setContent(FeedContent content) {
    state = content;
  }

  void updateContent(FeedContent updatedContent) {
    state = updatedContent;
  }

  void updateField({
    String? status,
    String? description,
    int? likes,
    bool? isLiked,
    int? comments,
    bool? isFollowed,
  }) {
    if (state != null) {
      state = state!.copyWith(
        status: status,
        description: description,
        likes: likes,
        isLiked: isLiked,
        comments: comments,
        isFollowed: isFollowed,
      );
    }
  }

  void toggleLike() {
    if (state != null) {
      state = state!.copyWith(
        isLiked: !state!.isLiked,
        likes: state!.isLiked ? state!.likes - 1 : state!.likes + 1,
      );
    }
  }

  void toggleFollow() {
    if (state != null) {
      state = state!.copyWith(isFollowed: !state!.isFollowed);
    }
  }

  void incrementComments() {
    if (state != null) {
      state = state!.copyWith(comments: state!.comments + 1);
    }
  }

  void decrementComments() {
    if (state != null) {
      state = state!.copyWith(comments: state!.comments - 1);
    }
  }

  void clear() {
    state = null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── Riverpod Providers ──────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

/// Main feed list provider - holds all feed content items
final feedContentProvider =
    StateNotifierProvider<FeedContentNotifier, List<FeedContent>>((ref) {
      return FeedContentNotifier();
    });

/// Single feed item provider - for viewing/editing a single post
final singleFeedContentProvider =
    StateNotifierProvider<SingleFeedContentNotifier, FeedContent?>((ref) {
      return SingleFeedContentNotifier();
    });

/// Get a specific feed content by ID
final feedContentByIdProvider = Provider.family<FeedContent?, String>((
  ref,
  contentId,
) {
  final feedList = ref.watch(feedContentProvider);
  return feedList.firstWhere(
    (c) => c.id == contentId,
    orElse: () => throw Exception('Content not found'),
  );
});

/// Total likes count provider
final totalLikesProvider = Provider<int>((ref) {
  final feedList = ref.watch(feedContentProvider);
  return feedList.fold(0, (sum, item) => sum + item.likes);
});

/// Total comments count provider
final totalCommentsProvider = Provider<int>((ref) {
  final feedList = ref.watch(feedContentProvider);
  return feedList.fold(0, (sum, item) => sum + item.comments);
});

/// Feed length provider
final feedLengthProvider = Provider<int>((ref) {
  return ref.watch(feedContentProvider).length;
});

/// Liked content filter provider
final likedContentProvider = Provider<List<FeedContent>>((ref) {
  final feedList = ref.watch(feedContentProvider);
  return feedList.where((c) => c.isLiked).toList();
});

/// Get content by author
final contentByAuthorProvider = Provider.family<List<FeedContent>, String>((
  ref,
  authorId,
) {
  final feedList = ref.watch(feedContentProvider);
  return feedList.where((c) => c.author.id == authorId).toList();
});

/// Get content by type/category
final contentByTypeProvider = Provider.family<List<FeedContent>, String>((
  ref,
  type,
) {
  final feedList = ref.watch(feedContentProvider);
  return feedList.where((c) => c.type == type).toList();
});

/// Recently created content provider
final recentContentProvider = Provider<List<FeedContent>>((ref) {
  final feedList = ref.watch(feedContentProvider);
  final sorted = List<FeedContent>.from(feedList)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted;
});

/// Search feed content provider
final searchFeedProvider = Provider.family<List<FeedContent>, String>((
  ref,
  query,
) {
  final feedList = ref.watch(feedContentProvider);
  final lowerQuery = query.toLowerCase();
  return feedList
      .where(
        (c) =>
            c.status.toLowerCase().contains(lowerQuery) ||
            c.description.toLowerCase().contains(lowerQuery) ||
            c.author.name.toLowerCase().contains(lowerQuery) ||
            c.tags.any((t) => t.toLowerCase().contains(lowerQuery)),
      )
      .toList();
});
