import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    if (user == null) {
      return;
    }

    final content = _postController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      await supabase.from('posts').insert({
        'user_id': user.id,
        'content': content,
      });
      _postController.clear();
    } catch (error) {
      debugPrint('Error creating post: $error');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  /// Uploads an image to Supabase Storage, then inserts a new post record with the image URL
  Future<void> _pickAndUploadImage() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;
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

      await supabase.from('posts').insert({
        'user_id': user.id,
        'content': 'Check out my new image!',
        'photos': imageUrl,
      });
    } catch (e) {
      debugPrint('Upload error: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}
