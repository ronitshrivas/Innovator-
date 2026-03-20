import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/Innovator/models/Feed_Content_Model.dart';
import 'package:innovator/Innovator/providers/feed_content_providers.dart';

/// Example 1: Display entire feed list using Riverpod
class FeedListView extends ConsumerWidget {
  const FeedListView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the entire feed list
    final feedList = ref.watch(feedContentProvider);

    return ListView.builder(
      itemCount: feedList.length,
      itemBuilder: (context, index) {
        final content = feedList[index];
        return FeedItemCard(contentId: content.id);
      },
    );
  }
}

/// Example 2: Feed item card with like/follow buttons
class FeedItemCard extends ConsumerWidget {
  final String contentId;

  const FeedItemCard({required this.contentId, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get specific content by ID
    try {
      final content = ref.watch(feedContentByIdProvider(contentId));

      return Card(
        margin: const EdgeInsets.all(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author info
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage:
                        (content?.author.picture ?? '').isNotEmpty
                            ? NetworkImage(content!.author.picture)
                            : null,
                    child:
                        (content?.author.picture ?? '').isEmpty
                            ? Text(content!.author.name[0])
                            : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content?.author.name ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        content?.createdAt.toString() ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (content != null)
                    FollowButton(contentId: contentId, content: content),
                ],
              ),
              const SizedBox(height: 12),
              // Content
              Text(content?.status ?? ''),
              const SizedBox(height: 12),
              // Stats and actions
              Row(
                children: [
                  if (content != null)
                    LikeButton(contentId: contentId, content: content),
                  const Spacer(),
                  Text('${content?.comments ?? 0} Comments'),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return const Text('Content not found');
    }
  }
}

/// Example 3: Like button with Riverpod state management
class LikeButton extends ConsumerWidget {
  final String contentId;
  final FeedContent content;

  const LikeButton({required this.contentId, required this.content, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        // Toggle like in the feed provider
        ref.read(feedContentProvider.notifier).toggleLike(contentId);
      },
      child: Row(
        children: [
          Icon(
            Icons.favorite,
            color: content.isLiked ? Colors.red : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 4),
          Text('${content.likes}'),
        ],
      ),
    );
  }
}

/// Example 4: Follow button with Riverpod state management
class FollowButton extends ConsumerWidget {
  final String contentId;
  final FeedContent content;

  const FollowButton({required this.contentId, required this.content, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () {
        ref.read(feedContentProvider.notifier).toggleFollow(contentId);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: content.isFollowed ? Colors.grey : Colors.blue,
      ),
      child: Text(content.isFollowed ? 'Following' : 'Follow'),
    );
  }
}

/// Example 5: Search functionality using Riverpod
class FeedSearchView extends ConsumerStatefulWidget {
  const FeedSearchView({Key? key}) : super(key: key);

  @override
  ConsumerState<FeedSearchView> createState() => _FeedSearchViewState();
}

class _FeedSearchViewState extends ConsumerState<FeedSearchView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search posts...',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              final results = ref.watch(searchFeedProvider(_searchQuery));
              return ListView.builder(
                itemCount: results.length,
                itemBuilder:
                    (context, index) => ListTile(
                      title: Text(results[index].status),
                      subtitle: Text(results[index].author.name),
                    ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Example 6: Display stats using providers
class FeedStatsWidget extends ConsumerWidget {
  const FeedStatsWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalLikes = ref.watch(totalLikesProvider);
    final totalComments = ref.watch(totalCommentsProvider);
    final feedLength = ref.watch(feedLengthProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          children: [
            Text(
              feedLength.toString(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text('Posts'),
          ],
        ),
        Column(
          children: [
            Text(
              totalLikes.toString(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text('Likes'),
          ],
        ),
        Column(
          children: [
            Text(
              totalComments.toString(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text('Comments'),
          ],
        ),
      ],
    );
  }
}

/// Example 7: Filtering by category
class FeedByTypeView extends ConsumerWidget {
  final String contentType;

  const FeedByTypeView({required this.contentType, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredContent = ref.watch(contentByTypeProvider(contentType));

    return ListView.builder(
      itemCount: filteredContent.length,
      itemBuilder:
          (context, index) => ListTile(
            title: Text(filteredContent[index].status),
            subtitle: Text(filteredContent[index].type),
          ),
    );
  }
}

/// Example 8: CRUD operations
class FeedManagementService {
  static void addNewContent(WidgetRef ref, FeedContent content) {
    ref.read(feedContentProvider.notifier).addContent(content);
  }

  static void deleteContent(WidgetRef ref, String contentId) {
    ref.read(feedContentProvider.notifier).removeContent(contentId);
  }

  static void updateContent(
    WidgetRef ref,
    String contentId,
    FeedContent updatedContent,
  ) {
    ref
        .read(feedContentProvider.notifier)
        .updateContent(contentId, updatedContent);
  }

  static void updateField(
    WidgetRef ref,
    String contentId, {
    String? status,
    String? description,
    int? likes,
    bool? isLiked,
    int? comments,
    bool? isFollowed,
  }) {
    ref
        .read(feedContentProvider.notifier)
        .updateContentField(
          contentId,
          status: status,
          description: description,
          likes: likes,
          isLiked: isLiked,
          comments: comments,
          isFollowed: isFollowed,
        );
  }

  static void clearAllFeed(WidgetRef ref) {
    ref.read(feedContentProvider.notifier).clearAll();
  }

  static void replaceFeed(WidgetRef ref, List<FeedContent> newFeed) {
    ref.read(feedContentProvider.notifier).setFeed(newFeed);
  }

  static void appendToFeed(WidgetRef ref, List<FeedContent> newItems) {
    ref.read(feedContentProvider.notifier).appendFeed(newItems);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── MIGRATION GUIDE ─────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
/*
## How to migrate from setState to Riverpod:

### Old Way (with setState):
```dart
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  List<FeedContent> feedList = [];

  void addContent(FeedContent content) {
    setState(() {
      feedList.add(content);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: feedList.length,
      itemBuilder: (context, index) => Text(feedList[index].status),
    );
  }
}
```

### New Way (with Riverpod):
```dart
class MyWidget extends ConsumerWidget {
  const MyWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedList = ref.watch(feedContentProvider);

    return ListView.builder(
      itemCount: feedList.length,
      itemBuilder: (context, index) => Text(feedList[index].status),
    );
  }
}

// To add content:
ref.read(feedContentProvider.notifier).addContent(content);
```

## Key Benefits:
1. No need to manage widget lifecycle
2. Automatic rebuild when state changes
3. Easy to share state across widgets
4. Better testability
5. Less boilerplate code
6. Built-in caching and invalidation
*/
