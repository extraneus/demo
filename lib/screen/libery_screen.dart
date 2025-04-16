// lib/screen/library_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import 'content_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  _LibraryScreenState createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Data
  List<Map<String, dynamic>> _savedContent = [];
  List<Map<String, dynamic>> _readingHistory = [];
  List<Map<String, dynamic>> _followedAuthors = [];
  List<Map<String, dynamic>> _publishedContent = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadLibraryData();
  }

  Future<void> _loadLibraryData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.currentUser != null) {
        final firebaseService = Provider.of<FirebaseService>(
          context,
          listen: false,
        );

        // Load all data in parallel
        final savedFuture = firebaseService.getSavedContent(
          authService.currentUser!.uid,
        );
        final continueFuture = firebaseService.getContinueReading(
          authService.currentUser!.uid,
        );
        final authorsFuture = firebaseService.getFollowingAuthors(
          authService.currentUser!.uid,
        );
        final publishedFuture = firebaseService.getUserContent(
          authService.currentUser!.uid,
        );

        // Wait for all futures to complete
        final results = await Future.wait([
          savedFuture,
          continueFuture,
          authorsFuture,
          publishedFuture,
        ]);

        setState(() {
          _savedContent = results[0];
          _readingHistory = results[1];
          _followedAuthors = results[2];
          _publishedContent = results[3];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading library data: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading library data: $e')));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (authService.currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Library')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.library_books, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Please log in to access your library',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Navigate to login screen
                },
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLibraryData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Reading'),
            Tab(text: 'Favorites'),
            Tab(text: 'Following'),
            Tab(text: 'My Content'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildReadingTab(),
                  _buildFavoritesTab(),
                  _buildFollowingTab(),
                  _buildMyContentTab(),
                ],
              ),
    );
  }

  Widget _buildReadingTab() {
    if (_readingHistory.isEmpty) {
      return _buildEmptyState(
        'No Reading History',
        'Start reading to see your history here',
        Icons.book,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _readingHistory.length,
        itemBuilder: (context, index) {
          final item = _readingHistory[index];
          return _buildContinueReadingItem(item);
        },
      ),
    );
  }

  Widget _buildContinueReadingItem(Map<String, dynamic> item) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _navigateToContentDetail(item),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                bottomLeft: Radius.circular(4),
              ),
              child:
                  item['coverUrl'] != null && item['coverUrl'].isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: item['coverUrl'],
                        width: 100,
                        height: 140,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => Container(
                              width: 100,
                              height: 140,
                              color: Colors.grey[300],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => Container(
                              width: 100,
                              height: 140,
                              color: Colors.grey[300],
                              child: const Icon(Icons.error),
                            ),
                      )
                      : Container(
                        width: 100,
                        height: 140,
                        color: Colors.deepPurple[200],
                        child: Center(
                          child: Text(
                            item['title'].substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By ${item['authorName']}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getContentTypeName(item['type']),
                            style: TextStyle(
                              color: Colors.deepPurple[800],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item['chapter'] ?? 'Chapter 1',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: item['progress'] ?? 0.0,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${((item['progress'] ?? 0.0) * 100).toInt()}% completed',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesTab() {
    if (_savedContent.isEmpty) {
      return _buildEmptyState(
        'No Saved Content',
        'Add content to your favorites to see them here',
        Icons.favorite,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _savedContent.length,
        itemBuilder: (context, index) {
          final item = _savedContent[index];
          return _buildContentGridItem(
            item,
            onRemove: () => _removeFromFavorites(item['id']),
          );
        },
      ),
    );
  }

  Widget _buildContentGridItem(
    Map<String, dynamic> item, {
    VoidCallback? onRemove,
  }) {
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () => _navigateToContentDetail(item),
                  child:
                      item['coverUrl'] != null && item['coverUrl'].isNotEmpty
                          ? CachedNetworkImage(
                            imageUrl: item['coverUrl'],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder:
                                (context, url) => Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            errorWidget:
                                (context, url, error) => Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.error),
                                ),
                          )
                          : Container(
                            color: Colors.deepPurple[200],
                            child: Center(
                              child: Text(
                                item['title'].substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'By ${item['authorName']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: onRemove,
                  iconSize: 20,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getContentTypeName(item['type']),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowingTab() {
    if (_followedAuthors.isEmpty) {
      return _buildEmptyState(
        'Not Following Any Authors',
        'Follow authors to see their updates here',
        Icons.people,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _followedAuthors.length,
        itemBuilder: (context, index) {
          final author = _followedAuthors[index];
          return _buildAuthorItem(author);
        },
      ),
    );
  }

  Widget _buildAuthorItem(Map<String, dynamic> author) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple[100],
          foregroundImage:
              author['profilePicture'] != null &&
                      author['profilePicture'].isNotEmpty
                  ? NetworkImage(author['profilePicture'])
                  : null,
          child:
              author['profilePicture'] == null ||
                      author['profilePicture'].isEmpty
                  ? Text(
                    author['displayName'].substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                  : null,
        ),
        title: Text(
          author['displayName'] ?? 'Unknown Author',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          author['bio'] ?? 'No bio available',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: OutlinedButton(
          onPressed: () => _unfollowAuthor(author['id']),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.deepPurple),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text('Unfollow'),
        ),
        onTap: () => _navigateToAuthorProfile(author['id']),
      ),
    );
  }

  Widget _buildMyContentTab() {
    if (_publishedContent.isEmpty) {
      return _buildEmptyState(
        'No Published Content',
        'Your published content will appear here',
        Icons.create,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadLibraryData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _publishedContent.length,
        itemBuilder: (context, index) {
          final item = _publishedContent[index];
          return _buildPublishedContentItem(item);
        },
      ),
    );
  }

  Widget _buildPublishedContentItem(Map<String, dynamic> item) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _navigateToContentDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    item['coverUrl'] != null && item['coverUrl'].isNotEmpty
                        ? CachedNetworkImage(
                          imageUrl: item['coverUrl'],
                          width: 80,
                          height: 120,
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) => Container(
                                width: 80,
                                height: 120,
                                color: Colors.grey[300],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          errorWidget:
                              (context, url, error) => Container(
                                width: 80,
                                height: 120,
                                color: Colors.grey[300],
                                child: const Icon(Icons.error),
                              ),
                        )
                        : Container(
                          width: 80,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.deepPurple[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              item['title'].substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item['title'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getContentTypeName(item['type']),
                            style: TextStyle(
                              color: Colors.deepPurple[800],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['description'] ?? 'No description',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.remove_red_eye,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item['reads'] ?? 0}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.favorite,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${item['likes'] ?? 0}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                          onPressed: () => _editContent(item),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Chapter'),
                          onPressed: () => _addChapter(item),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getContentTypeName(String type) {
    switch (type) {
      case 'stories':
        return 'Story';
      case 'lightNovels':
        return 'Light Novel';
      case 'comics':
        return 'Comic';
      default:
        return 'Content';
    }
  }

  void _navigateToContentDetail(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ContentDetailScreen(
              contentId: item['id'],
              contentType: item['type'],
            ),
      ),
    );
  }

  void _navigateToAuthorProfile(String authorId) {
    // Navigate to author profile screen
    // Implement navigation to author profile
  }

  Future<void> _removeFromFavorites(String contentId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firebaseService = Provider.of<FirebaseService>(
        context,
        listen: false,
      );

      // Find the content item to remove
      final contentItem = _savedContent.firstWhere(
        (item) => item['id'] == contentId,
      );

      // Remove from Firebase
      await firebaseService.users
          .doc(authService.currentUser!.uid)
          .collection('savedContent')
          .doc(contentId)
          .delete();

      // Update UI
      setState(() {
        _savedContent.removeWhere((item) => item['id'] == contentId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${contentItem['title']}" from favorites'),
        ),
      );
    } catch (e) {
      print('Error removing from favorites: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing from favorites: $e')),
      );
    }
  }

  Future<void> _unfollowAuthor(String authorId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final firebaseService = Provider.of<FirebaseService>(
        context,
        listen: false,
      );

      // Find the author to unfollow
      final author = _followedAuthors.firstWhere((a) => a['id'] == authorId);

      // Unfollow in Firebase
      await firebaseService.unfollowAuthor(
        authService.currentUser!.uid,
        authorId,
      );

      // Update UI
      setState(() {
        _followedAuthors.removeWhere((a) => a['id'] == authorId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unfollowed ${author['displayName']}')),
      );
    } catch (e) {
      print('Error unfollowing author: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error unfollowing author: $e')));
    }
  }

  void _editContent(Map<String, dynamic> content) {
    // Navigate to edit content screen
    // Implement navigation to content editor
  }

  void _addChapter(Map<String, dynamic> content) {
    // Navigate to add chapter screen
    // Implement navigation to chapter editor
  }
}
