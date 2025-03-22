import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stattrak/models/Post.dart';
import 'package:stattrak/providers/post_provider.dart';




class CreatePostWidget extends StatefulWidget {
  const CreatePostWidget({Key? key}) : super(key: key);

  @override
  State<CreatePostWidget> createState() => _CreatePostWidgetState();
}

class _CreatePostWidgetState extends State<CreatePostWidget> {
  final _postController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _postController,
          decoration: const InputDecoration(
            hintText: "What's on your mind?",
          ),
          maxLines: null,
        ),
        const SizedBox(height: 8),

        ElevatedButton(
          onPressed: _isSubmitting ? null : _createPost,
          child: const Text('Post'),
        ),
        const SizedBox(height: 8),

        ElevatedButton(
          onPressed: _isSubmitting ? null : _pickAndUploadImage,
          child: const Text('Upload Image'),
        ),
      ],
    );
  }

  /// Inserts a text-only post into the `posts` table
  Future<void> _createPost() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final content = _postController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await supabase.from('posts').insert({
        'user_id': user.id,
        'content': content,
      }).select();

      // Grab inserted post data
      final insertedPost = response.first;

      // Add to local provider
      final postProvider = context.read<PostProvider>();
      postProvider.addPost(
        Post(
          username: user.userMetadata?['full_name'] ?? 'Unknown',
          date: DateTime.now(),
          location: 'Bulacan', // or fetch user location if available
          title: content,
          distance: 0.0,
          elevation: 0.0,
          imageUrls: [],
          likes: 0,
        ),
      );

      _postController.clear();
    } catch (error) {
      debugPrint('Error creating post: $error');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  /// Uploads an image to Supabase Storage, then inserts a new post record
  /// with BOTH the user-entered text and the image URL.
  Future<void> _pickAndUploadImage() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // CHANGED: Grab the text from the controller
    final content = _postController.text.trim();
    if (content.isEmpty) {
      // If you want to allow empty text, remove this check
      debugPrint("No text entered!");
      return;
    }

    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isSubmitting = true);

    try {
      final fileBytes = await pickedFile.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

      await supabase.storage
          .from('post-images')
          .uploadBinary(
        fileName,
        fileBytes,
        fileOptions: FileOptions(cacheControl: '3600', upsert: false),
      );

      final imageUrl = supabase.storage
          .from('post-images')
          .getPublicUrl(fileName);

      final response = await supabase.from('posts').insert({
        'user_id': user.id,
        'content': content,
        'photos': [imageUrl],
      }).select();

      final postProvider = context.read<PostProvider>();
      postProvider.addPost(
        Post(
          username: user.userMetadata?['full_name'] ?? 'Unknown',
          date: DateTime.now(),
          location: 'Bulacan',
          title: content,
          distance: 0.0,
          elevation: 0.0,
          imageUrls: [imageUrl],
          likes: 0,
        ),
      );

      _postController.clear();

    } catch (e) {
      debugPrint('Upload error: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}
