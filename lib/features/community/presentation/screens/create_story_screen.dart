import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:culinary_coach_app/app/theme/app_colors.dart';
import 'package:culinary_coach_app/core/widgets/current_user_avatar.dart';
import 'package:culinary_coach_app/features/community/data/services/community_repository.dart';
import 'package:culinary_coach_app/features/community/presentation/widgets/community_emoji_picker_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _overlayController = TextEditingController();
  final _overlayScrollController = ScrollController();
  final _picker = ImagePicker();
  final _repo = CommunityRepository();

  XFile? _imageFile;
  Uint8List? _previewBytes;
  bool _submitting = false;

  bool get _canSubmit =>
      _previewBytes != null &&
      _previewBytes!.isNotEmpty &&
      !_submitting;

  @override
  void initState() {
    super.initState();
    _overlayController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _overlayController.dispose();
    _overlayScrollController.dispose();
    super.dispose();
  }

  Future<bool> _ensureGalleryPermission() async {
    if (kIsWeb) return true;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final photos = await Permission.photos.request();
        return photos.isGranted || photos.isLimited;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        final photos = await Permission.photos.request();
        if (photos.isGranted || photos.isLimited) return true;
        final storage = await Permission.storage.request();
        return storage.isGranted;
      }
    } catch (_) {
      return true;
    }
    return true;
  }

  Future<bool> _ensureCameraPermission() async {
    if (kIsWeb) return true;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android) {
        final cam = await Permission.camera.request();
        return cam.isGranted;
      }
    } catch (_) {
      return true;
    }
    return true;
  }

  Future<void> _pickFromGallery() async {
    final ok = await _ensureGalleryPermission();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Allow photo access in Settings to pick images from your gallery.',
          ),
        ),
      );
      return;
    }
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageFile = file;
        _previewBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open gallery: $e')),
      );
    }
  }

  Future<void> _pickFromCamera() async {
    final ok = await _ensureCameraPermission();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Allow camera access in Settings to take a photo.',
          ),
        ),
      );
      return;
    }
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 88,
        maxWidth: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _imageFile = file;
        _previewBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not use camera: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (_submitting || !_canSubmit) return;
    final file = _imageFile;
    final bytes = _previewBytes;
    if (file == null || bytes == null || bytes.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await _repo.createStory(
        image: file,
        textOverlay: _overlayController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, st) {
      debugPrint('createStory failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not post your story. ${e is Exception ? e.toString() : 'Please try again.'}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Story')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Sign in to create a story.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: _submitting ? null : () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'New Story',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snap) {
          final data = snap.data?.data();
          final firstName = (data?['firstName'] as String?)?.trim();
          final resolvedName = (firstName != null && firstName.isNotEmpty)
              ? firstName
              : (user.displayName?.split(' ').first ??
                  user.email?.split('@').first ??
                  'User');

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFE8C4),
                        Color(0xFFFFF6E8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.outline),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimary.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CurrentUserAvatar(
                        size: 48,
                        backgroundColor: const Color(0xFFD28E18),
                        borderColor: Colors.white.withValues(alpha: 0.65),
                        borderWidth: 2,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          resolvedName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (_previewBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            _previewBytes!,
                            fit: BoxFit.cover,
                          ),
                          if (_overlayController.text.trim().isNotEmpty)
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 24,
                              child: Text(
                                _overlayController.text,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      height: 1.25,
                                      shadows: const [
                                        Shadow(
                                          offset: Offset(0, 1),
                                          blurRadius: 6,
                                          color: Colors.black54,
                                        ),
                                      ],
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    height: 280,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: Text(
                      'Add a photo to preview your story',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: TextField(
                    controller: _overlayController,
                    scrollController: _overlayScrollController,
                    minLines: 2,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    enabled: !_submitting,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                    decoration: InputDecoration(
                      hintText: 'Write on your story (text & emojis)',
                      hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _StoryAttachmentChip(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        onTap: _submitting ? null : _pickFromGallery,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StoryAttachmentChip(
                        icon: Icons.photo_camera_rounded,
                        label: 'Camera',
                        onTap: _submitting ? null : _pickFromCamera,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: CommunityEmojiIconButton(
                        onPressed: _submitting
                            ? null
                            : () => showCommunityEmojiPickerSheet(
                                  context,
                                  textController: _overlayController,
                                  scrollController: _overlayScrollController,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Opacity(
                  opacity: (_submitting || _canSubmit) ? 1 : 0.45,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFE08B14),
                          Color(0xFFF4A32D),
                          Color(0xFFFFC266),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE08B14).withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _canSubmit ? _submit : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: _submitting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Post Story',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StoryAttachmentChip extends StatelessWidget {
  const _StoryAttachmentChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primaryDeep, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
