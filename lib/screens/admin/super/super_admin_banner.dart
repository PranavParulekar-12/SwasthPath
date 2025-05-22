import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class UploadBannerScreen extends StatefulWidget {
  const UploadBannerScreen({super.key});

  @override
  _UploadBannerScreenState createState() => _UploadBannerScreenState();
}

class _UploadBannerScreenState extends State<UploadBannerScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _photoNameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _photos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPhotos();
  }

  Future<void> _fetchPhotos() async {
    try {
      final response = await _supabase.from('banner').select();
      // ignore: unnecessary_null_comparison
      if (response != null) {
        setState(() {
          _photos = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (error) {
      print('Error fetching photos: $error');
    }
  }

  Future<void> _uploadPhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final String photoName = _photoNameController.text.trim();
    if (photoName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a photo name.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload the image to Supabase storage
      final Uint8List fileBytes = await image.readAsBytes(); // Fixed
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      // ignore: unused_local_variable
      final response = await _supabase.storage
          .from('documents')
          .uploadBinary(fileName, fileBytes);

      // Get the public URL of the uploaded image
      final String imageUrl =
          _supabase.storage.from('documents').getPublicUrl(fileName);

      // Insert into the database
      await _supabase.from('banner').insert({
        'photo_name': photoName,
        'banner_url': imageUrl,
      });

      // Refresh the list
      _fetchPhotos();
      _photoNameController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo uploaded successfully!')),
      );
    } catch (e) {
      print('Error uploading photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload photo.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePhoto(String bannerUrl, String fileName) async {
    try {
      // Delete from storage
      await _supabase.storage.from('banner').remove([fileName]);

      // Delete from database
      await _supabase.from('banner').delete().eq('banner_url', bannerUrl);

      // Refresh the list
      _fetchPhotos();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo deleted successfully!')),
      );
    } catch (e) {
      print('Error deleting photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete photo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _photoNameController,
              decoration: const InputDecoration(
                labelText: 'Photo Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _uploadPhoto,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Upload Photo'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _photos.isEmpty
                  ? const Center(child: Text('No photos found.'))
                  : ListView.builder(
                      itemCount: _photos.length,
                      itemBuilder: (context, index) {
                        final photo = _photos[index];
                        final bannerUrl = photo['banner_url'];
                        final fileName = bannerUrl.split('/').last;

                        return Card(
                          child: ListTile(
                            leading: Image.network(
                              bannerUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                            title: Text(photo['photo_name']),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Image.network(bannerUrl),
                                            const SizedBox(height: 8),
                                            Text(photo['photo_name']),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    _deletePhoto(bannerUrl, fileName);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
