import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  // Collection references - use these consistently throughout the class
  CollectionReference get stories => _firestore.collection('stories');
  CollectionReference get lightNovels => _firestore.collection('lightNovels');
  CollectionReference get comics => _firestore.collection('comics');
  CollectionReference get users => _firestore.collection('users');

  // Update content
  Future<void> updateContent(
    String contentId,
    String contentType,
    Map<String, dynamic> contentData,
  ) async {
    try {
      await _firestore
          .collection(contentType)
          .doc(contentId)
          .update(contentData);
    } catch (e) {
      throw Exception('Failed to update content: $e');
    }
  }

  // Create content
  Future<String> createContent(
    String contentType,
    Map<String, dynamic> contentData,
  ) async {
    try {
      print('FirebaseService: Creating content in collection: $contentType');
      final collection = _firestore.collection(contentType);
      final docRef = await collection.add(contentData);
      print('FirebaseService: Content created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e, stackTrace) {
      print('FirebaseService ERROR in createContent: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to create content: $e');
    }
  }

  // Get next chapter number - FIXED to use correct collection path
  Future<int> getNextChapterNumber(String contentId, String contentType) async {
    final chaptersCollection = _firestore
        .collection(contentType) // Use the correct collection type
        .doc(contentId)
        .collection('chapters');

    final querySnapshot =
        await chaptersCollection
            .orderBy(
              'chapterNumber',
              descending: true,
            ) // Use chapterNumber as the field name
            .limit(1)
            .get();

    if (querySnapshot.docs.isNotEmpty) {
      final lastChapterNumber =
          querySnapshot.docs.first.data()['chapterNumber'] as int;
      return lastChapterNumber + 1;
    } else {
      return 1; // Start with chapter 1 if no chapters exist
    }
  }

  // Update chapter - FIXED to use correct collection path
  Future<void> updateChapter(
    String contentId,
    String contentType,
    String chapterId,
    Map<String, dynamic> chapterData,
  ) async {
    try {
      await _firestore
          .collection(contentType) // Use the correct collection type
          .doc(contentId)
          .collection('chapters')
          .doc(chapterId)
          .update(chapterData);
    } catch (e) {
      throw Exception('Failed to update chapter: $e');
    }
  }

  // Get featured content
  Future<List<Map<String, dynamic>>> getFeaturedItems() async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection('featured')
              .orderBy('date', descending: true)
              .limit(5)
              .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting featured items: $e');
      return [];
    }
  }

  // Get content by type (stories, light novels, comics)
  Future<List<Map<String, dynamic>>> getContentByType(String type) async {
    try {
      QuerySnapshot snapshot =
          await _firestore
              .collection(type)
              .orderBy('publishedDate', descending: true)
              .limit(20)
              .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting $type: $e');
      return [];
    }
  }

  // Get popular content
  Future<List<Map<String, dynamic>>> getPopularContent() async {
    try {
      // Get popular content across all types sorted by read count
      QuerySnapshot storiesSnap =
          await stories.orderBy('reads', descending: true).limit(3).get();
      QuerySnapshot novelsSnap =
          await lightNovels.orderBy('reads', descending: true).limit(3).get();
      QuerySnapshot comicsSnap =
          await comics.orderBy('reads', descending: true).limit(3).get();

      List<Map<String, dynamic>> result = [];

      // Process all three collections
      for (var doc in storiesSnap.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['type'] = 'stories';
        result.add(data);
      }

      for (var doc in novelsSnap.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['type'] = 'lightNovels';
        result.add(data);
      }

      for (var doc in comicsSnap.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['type'] = 'comics';
        result.add(data);
      }

      // Sort combined results by reads
      result.sort((a, b) => (b['reads'] as num).compareTo(a['reads'] as num));
      return result.take(6).toList();
    } catch (e) {
      print('Error getting popular content: $e');
      return [];
    }
  }

  // Get new releases - FIXED to query the specific collections instead of collectionGroup
  Future<List<Map<String, dynamic>>> getNewReleases() async {
    try {
      final DateTime oneWeekAgo = DateTime.now().subtract(
        const Duration(days: 7),
      );
      List<Map<String, dynamic>> result = [];

      // Query each collection type instead of using collectionGroup
      for (String contentType in ['stories', 'lightNovels', 'comics']) {
        QuerySnapshot snapshot =
            await _firestore
                .collection(contentType)
                .where('publishedDate', isGreaterThan: oneWeekAgo)
                .orderBy('publishedDate', descending: true)
                .limit(4)
                .get();

        for (var doc in snapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          data['type'] = contentType; // Add the content type
          result.add(data);
        }
      }

      // Sort by publish date and limit to 4 items
      result.sort((a, b) {
        Timestamp aTime = a['publishedDate'] as Timestamp;
        Timestamp bTime = b['publishedDate'] as Timestamp;
        return bTime.compareTo(aTime);
      });

      return result.take(4).toList();
    } catch (e) {
      print('Error getting new releases: $e');
      return [];
    }
  }

  // Add chapter - FIXED to use correct collection path
  Future<void> addChapter(
    String contentId,
    String contentType,
    Map<String, dynamic> chapterData,
  ) async {
    try {
      await _firestore
          .collection(contentType) // Use the correct collection type
          .doc(contentId)
          .collection('chapters')
          .add(chapterData);
    } catch (e) {
      throw Exception('Failed to add chapter: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      await users.doc(userId).update(data);
    } catch (e) {
      throw Exception('Failed to update user profile: $e');
    }
  }

  // Get user data
  Future<Map<String, dynamic>> getUserData(String userId) async {
    try {
      final userDoc = await users.doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      } else {
        throw Exception('User not found');
      }
    } catch (e) {
      throw Exception('Error fetching user data: $e');
    }
  }

  // Check if a user is following another user
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      final followingDoc =
          await users
              .doc(currentUserId)
              .collection('following')
              .doc(targetUserId)
              .get();

      return followingDoc.exists;
    } catch (e) {
      print('Error checking following status: $e');
      return false;
    }
  }

  // Get followers count
  Future<int> getFollowersCount(String userId) async {
    try {
      final snapshot = await users.doc(userId).collection('followers').get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting followers count: $e');
      return 0;
    }
  }

  // Get user content - FIXED to query multiple collections
  Future<List<Map<String, dynamic>>> getUserContent(String userId) async {
    try {
      List<Map<String, dynamic>> result = [];

      // Query each content type collection for items by this author
      for (String contentType in ['stories', 'lightNovels', 'comics']) {
        QuerySnapshot querySnapshot =
            await _firestore
                .collection(contentType)
                .where('authorId', isEqualTo: userId)
                .get();

        for (var doc in querySnapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          data['type'] = contentType;
          result.add(data);
        }
      }

      return result;
    } catch (e) {
      print('Error fetching user content: $e');
      return [];
    }
  }

  // Get saved content
  Future<List<Map<String, dynamic>>> getSavedContent(String userId) async {
    try {
      final savedContentSnapshot =
          await users.doc(userId).collection('savedContent').get();

      List<Map<String, dynamic>> result = [];

      // For each saved content reference, fetch the actual content
      for (var doc in savedContentSnapshot.docs) {
        Map<String, dynamic> savedData = doc.data();
        String contentType = savedData['contentType'];
        String contentId = savedData['contentId'];

        DocumentSnapshot contentDoc =
            await _firestore.collection(contentType).doc(contentId).get();

        if (contentDoc.exists) {
          Map<String, dynamic> data = contentDoc.data() as Map<String, dynamic>;
          data['id'] = contentDoc.id;
          data['type'] = contentType;
          result.add(data);
        }
      }

      return result;
    } catch (e) {
      print('Error fetching saved content: $e');
      return [];
    }
  }

  // Get following authors
  Future<List<Map<String, dynamic>>> getFollowingAuthors(String userId) async {
    try {
      final querySnapshot =
          await users.doc(userId).collection('followingAuthors').get();

      List<Map<String, dynamic>> authors = [];

      // Fetch full user details for each followed author
      for (var doc in querySnapshot.docs) {
        String authorId = doc.id;
        DocumentSnapshot authorDoc = await users.doc(authorId).get();

        if (authorDoc.exists) {
          Map<String, dynamic> data = authorDoc.data() as Map<String, dynamic>;
          data['id'] = authorDoc.id;
          authors.add(data);
        }
      }

      return authors;
    } catch (e) {
      print('Error fetching following authors: $e');
      return [];
    }
  }

  // Follow author
  Future<void> followAuthor(String currentUserId, String authorId) async {
    try {
      // Add to author's followers collection
      await users.doc(authorId).collection('followers').doc(currentUserId).set({
        'followedAt': FieldValue.serverTimestamp(),
      });

      // Add to user's following collection
      await users.doc(currentUserId).collection('following').doc(authorId).set({
        'followedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error following author: $e');
    }
  }

  // Unfollow author
  Future<void> unfollowAuthor(String currentUserId, String authorId) async {
    try {
      // Remove from author's followers
      await users
          .doc(authorId)
          .collection('followers')
          .doc(currentUserId)
          .delete();

      // Remove from user's following
      await users
          .doc(currentUserId)
          .collection('following')
          .doc(authorId)
          .delete();
    } catch (e) {
      throw Exception('Error unfollowing author: $e');
    }
  }

  // Get user's reading progress
  Future<List<Map<String, dynamic>>> getContinueReading(String userId) async {
    try {
      QuerySnapshot snapshot =
          await users
              .doc(userId)
              .collection('readingProgress')
              .orderBy('lastReadTimestamp', descending: true)
              .limit(3)
              .get();

      List<Map<String, dynamic>> progressItems =
          snapshot.docs.map((doc) {
            return doc.data() as Map<String, dynamic>;
          }).toList();

      // Get the full content details for each progress item
      List<Map<String, dynamic>> result = [];
      for (var progress in progressItems) {
        String contentType = progress['contentType'];
        String contentId = progress['contentId'];

        DocumentSnapshot contentDoc =
            await _firestore.collection(contentType).doc(contentId).get();

        if (contentDoc.exists) {
          Map<String, dynamic> data = contentDoc.data() as Map<String, dynamic>;
          data['progress'] = progress['progress'];
          data['chapter'] = progress['chapter'];
          data['id'] = contentDoc.id;
          data['type'] = contentType;
          result.add(data);
        }
      }

      return result;
    } catch (e) {
      print('Error getting reading progress: $e');
      return [];
    }
  }

  // Upload content (story, light novel, comic)
  Future<String?> uploadContent({
    required String contentType,
    required String title,
    required String authorId,
    required String authorName,
    required String description,
    required List<String> genres,
    required String content,
    File? coverImage,
  }) async {
    try {
      // Upload cover image if provided
      String coverUrl = '';
      if (coverImage != null) {
        String coverPath = 'covers/${_uuid.v4()}.jpg';
        await _storage.ref(coverPath).putFile(coverImage);
        coverUrl = await _storage.ref(coverPath).getDownloadURL();
      }

      // Create the content document in the appropriate collection
      DocumentReference docRef = await _firestore.collection(contentType).add({
        'title': title,
        'authorId': authorId,
        'authorName': authorName,
        'description': description,
        'genres': genres,
        'content': content,
        'coverUrl': coverUrl,
        'reads': 0,
        'likes': 0,
        'publishedDate': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      print('Error uploading content: $e');
      return null;
    }
  }

  // Update reading progress
  Future<void> updateReadingProgress({
    required String userId,
    required String contentId,
    required String contentType,
    required double progress,
    required String chapter,
  }) async {
    try {
      await users.doc(userId).collection('readingProgress').doc(contentId).set({
        'contentId': contentId,
        'contentType': contentType,
        'progress': progress,
        'chapter': chapter,
        'lastReadTimestamp': FieldValue.serverTimestamp(),
      });

      // Increment the read counter for the content
      await _firestore.collection(contentType).doc(contentId).update({
        'reads': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error updating reading progress: $e');
    }
  }

  // Get content by genre
  Future<List<Map<String, dynamic>>> getContentByGenre(String genre) async {
    try {
      List<Map<String, dynamic>> result = [];

      // Query all content types with the specified genre
      for (String type in ['stories', 'lightNovels', 'comics']) {
        QuerySnapshot snapshot =
            await _firestore
                .collection(type)
                .where('genres', arrayContains: genre)
                .limit(10)
                .get();

        for (var doc in snapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          data['type'] = type;
          result.add(data);
        }
      }

      return result;
    } catch (e) {
      print('Error getting content by genre: $e');
      return [];
    }
  }
}
