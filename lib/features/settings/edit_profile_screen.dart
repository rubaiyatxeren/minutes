import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/services/cloudinary_service.dart';
import '../../core/widgets/user_avatar.dart';
import '../auth/auth_service.dart';

/// Lets the signed-in user change their display name and profile photo.
/// Both propagate to `users/{uid}` in Firestore, which is what every chat
/// list and message bubble reads from — so the change shows up everywhere
/// the next time the person sends a message or is looked up.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  Uint8List? _pickedBytes;
  String? _existingPhotoUrl;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    _existingPhotoUrl = user?.photoURL;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _pickedBytes = bytes);
  }

  Future<String?> _uploadPhotoIfNeeded() async {
    if (_pickedBytes == null) return null;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    setState(() => _uploadingPhoto = true);
    try {
      // Same Cloudinary account chat media already uploads through — keeps
      // all user-generated media in one place instead of splitting it
      // between Firebase Storage and Cloudinary.
      final url = await CloudinaryService.instance.uploadImage(
        _pickedBytes!,
        folder: 'profile_photos',
        fileName: uid,
      );
      if (url == null) {
        throw Exception('Upload failed, please try again');
      }
      return url;
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.nameCantBeEmpty)));
      return;
    }
    setState(() => _saving = true);
    try {
      final newPhotoUrl = await _uploadPhotoIfNeeded();
      await context.read<AuthService>().updateProfile(
            name: name,
            photoUrl: newPhotoUrl,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.profileUpdated)));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.couldntSave('$e'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final busy = _saving || _uploadingPhoto;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.editProfile),
        actions: [
          TextButton(
            onPressed: busy ? null : _save,
            child: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.save),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: GestureDetector(
                onTap: busy ? null : _pickPhoto,
                child: Stack(
                  children: [
                    _pickedBytes != null
                        ? CircleAvatar(
                            radius: 52,
                            backgroundImage: MemoryImage(_pickedBytes!),
                          )
                        : UserAvatar(
                            name: user?.displayName ?? 'U',
                            photoUrl: _existingPhotoUrl,
                            radius: 52,
                          ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            width: 3,
                          ),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: busy ? null : _pickPhoto,
                child: Text(t.changePhoto),
              ),
            ),
            const SizedBox(height: 20),
            Text(t.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: t.yourName,
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 20),
            Text(t.email,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              enabled: false,
              controller: TextEditingController(text: user?.email ?? ''),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t.emailCantBeChanged,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 28),
            if (user?.email != null)
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        await context
                            .read<AuthService>()
                            .sendPasswordReset(user!.email!);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(t.passwordResetEmailSent)),
                        );
                      },
                icon: const Icon(Icons.lock_reset_rounded),
                label: Text(t.sendPasswordResetEmail),
              ),
          ],
        ),
      ),
    );
  }
}
