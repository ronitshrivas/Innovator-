import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:innovator/Innovator/constant/app_colors.dart';
import 'package:innovator/Innovator/screens/Search/search_provider.dart';
import 'package:innovator/Innovator/screens/chatrrom/screen/chatlistscreen.dart';
import 'package:innovator/Innovator/screens/show_Specific_Profile/Show_Specific_Profile.dart';
import 'package:innovator/Innovator/widget/CustomizeFAB.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSuggestedUsersExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);
    final unreadCount = ref.watch(chatUnreadCountProvider);
    return Scaffold(
      backgroundColor: AppColors.whitecolor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(right: 10, left: 10),
          child: Column(
            children: [
              _buildSimpleHeader(),
              _buildSimpleSearchBar(notifier),
              Expanded(child: _buildContent(searchState, notifier)),
            ],
          ),
        ),
      ),
      floatingActionButton: CountBadgeFAB(
        count: unreadCount, // ← real-time total
        gifAsset: 'animation/chaticon.gif',
        backgroundColor: Colors.transparent,
        onPressed: () {
          ref.read(mutualFriendsProvider.notifier).refresh();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChatListScreen()),
          ).then((_) {
            ref.invalidate(mutualFriendsProvider);
            //ref.read(mutualFriendsProvider.notifier).refresh();
          });
        },
      ),
    );
  }

  Widget _buildSimpleHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: AppColors.whitecolor,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.search,
              color: AppColors.whitecolor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Find People',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'Discover and connect with others',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleSearchBar(SearchNotifier notifier) {
    return SearchBar(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(Colors.grey[100]!),
      hintText: 'Search for people...',
      controller: _searchController,
      onChanged: (value) {
        notifier.search(value);
      },
      onTap: () {
        _searchController.clear();
        notifier.fetchSuggested();
        setState(() {});
      },
      leading: const Icon(Icons.search, color: Colors.grey),
    );
  }

  Widget _buildContent(SearchState searchState, SearchNotifier notifier) {
    if (searchState.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 16),
            Text('Loading...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  searchState.isSearching
                      ? 'Search Results'
                      : 'Suggested People',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                if (!searchState.isSearching)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSuggestedUsersExpanded = !_isSuggestedUsersExpanded;
                      });
                    },
                    child: Text(
                      _isSuggestedUsersExpanded ? 'Show Less' : 'See All',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildUserList(searchState)),
        ],
      ),
    );
  }

  Widget _buildUserList(SearchState searchState) {
    final users =
        searchState.isSearching || _isSuggestedUsersExpanded
            ? searchState.users
            : searchState.users.take(3).toList();

    if (searchState.isSearching && users.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        return _buildUserCard(users[index]);
      },
    );
  }

  Widget _buildUserCard(SearchUser user) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SpecificUserProfilePage(userId: user.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          Row(
            children: [
              _buildSearchAvatar(user),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(thickness: 2, color: Colors.grey[300], height: 20),
        ],
      ),
    );
  }

  // NetworkImage instead of FileImage — avatar URL comes straight from API
  Widget _buildSearchAvatar(SearchUser user) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.grey[300],
      backgroundImage: user.avatar != null ? NetworkImage(user.avatar!) : null,
      child:
          user.avatar == null
              ? Text(
                user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.whitecolor,
                ),
              )
              : null,
    );
  }
}
