import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  final double? initialLat;
  final double? initialLong;

  const ProfilePage({
    Key? key,
    this.initialLat,
    this.initialLong,
  }) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isLoading = false;

  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _latitude = widget.initialLat;
    _longitude = widget.initialLong;
    _fetchProfile(); // Load existing profile data
  }

  /// Fetch existing profile row from Supabase
  Future<void> _fetchProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final row = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      if (row != null) {
        _usernameController.text = row['username'] ?? '';
        _fullNameController.text = row['full_name'] ?? '';
        _avatarUrlController.text = row['avatar_url'] ?? '';
        _bioController.text = row['bio'] ?? '';
        _latitude = row['lat'];
        _longitude = row['long'];
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Let user pick an image from gallery and upload to 'avatarurl' bucket
  Future<void> _pickAndUploadAvatar() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      // 1) Read the file bytes
      final fileBytes = await pickedFile.readAsBytes();
      // 2) Create a unique filename
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

      // 3) Upload to your 'avatarurl' bucket
      await supabase.storage
          .from('avatar-url') // must match your bucket name
          .uploadBinary(
        fileName,
        fileBytes,
        fileOptions: const FileOptions(upsert: false),
      );

      // 4) Get a public URL for that file
      final publicUrl = supabase.storage
          .from('avatar-url')
          .getPublicUrl(fileName);

      // 5) Update the 'avatar_url' column in your 'profiles' table
      await supabase
          .from('profiles')
          .update({
        'avatar_url': publicUrl,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', user.id);

      // 6) Update local text field so user sees the new URL
      setState(() {
        _avatarUrlController.text = publicUrl;
      });

      debugPrint('Avatar updated successfully: $publicUrl');
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Optionally fetch geolocation to update lat/long automatically
  Future<void> _fetchLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    Position position =
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
    });
  }

  /// Update the profile in Supabase (including updated_at)
  Future<void> _updateProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final updates = {
        'username': _usernameController.text,
        'full_name': _fullNameController.text,
        'avatar_url': _avatarUrlController.text,
        'bio': _bioController.text,
        'lat': _latitude,
        'long': _longitude,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase
          .from('profiles')
          .update(updates)
          .eq('id', user.id);

      debugPrint('Profile updated successfully!');
    } catch (e) {
      debugPrint('Error updating profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Avatar Preview (if we have a URL)
            if (_avatarUrlController.text.isNotEmpty)
              Image.network(
                _avatarUrlController.text,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: _pickAndUploadAvatar,
              child: const Text('Upload Avatar'),
            ),
            const SizedBox(height: 16),

            // Other fields
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            // <-- Removed the "Avatar URL" field here
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text('Lat: ${_latitude ?? 'N/A'}'),
                ),
                Expanded(
                  child: Text('Long: ${_longitude ?? 'N/A'}'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _fetchLocation,
              child: const Text('Update Location'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _updateProfile,
              child: const Text('Save Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
