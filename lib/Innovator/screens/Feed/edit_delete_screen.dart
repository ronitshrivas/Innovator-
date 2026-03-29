// EditDeletePost.dart
// Provides two independent widgets:
//   • EditPostScreen  — full-page edit screen (content text + optional new media)
//   • DeletePostDialog — confirmation bottom-sheet / dialog

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:innovator/Innovator/constant/app_colors.dart';
import 'package:innovator/Innovator/screens/Feed/Update%20Feed/API_Service.dart';

// ── Theme constant (matches the rest of the app) ─────────────────────────────
const Color _orange = Color.fromRGBO(244, 135, 6, 1);

// ─────────────────────────────────────────────────────────────────────────────
// EDIT POST SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class EditPostScreen extends StatefulWidget {
  final String postId;
  final String initialContent;

  /// Called with the updated content string when save succeeds.
  final void Function(String updatedContent)? onSuccess;

  const EditPostScreen({
    Key? key,
    required this.postId,
    required this.initialContent,
    this.onSuccess,
  }) : super(key: key);

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _contentCtrl;
  File? _selectedMedia;
  bool _isSaving = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  // ── Media picker ────────────────────────────────────────────────────────────
  Future<void> _pickMedia() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _selectedMedia = File(picked.path));
  }

  void _removeMedia() => setState(() => _selectedMedia = null);

  // ── Save ────────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMsg = 'Post content cannot be empty.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMsg = null;
    });

    final success = await ApiService.updateContent(
      widget.postId,
      text,
      mediaFile: _selectedMedia,
      context: context,
    );

    if (!mounted) return;

    if (success) {
      widget.onSuccess?.call(text);
      Navigator.pop(context, text); // return updated text to caller
    } else {
      setState(() {
        _isSaving = false;
        _errorMsg = 'Failed to update post. Please try again.';
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whitecolor,
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: AppColors.whitecolor,
        title: const Text(
          'Edit Post',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child:
                _isSaving
                    ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.whitecolor,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                    : TextButton(
                      onPressed: _save,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          color: AppColors.whitecolor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Error banner ──────────────────────────────────────────────────
            if (_errorMsg != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade600,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMsg!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _errorMsg = null),
                    ),
                  ],
                ),
              ),

            // ── Content text field ────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _contentCtrl,
                enabled: !_isSaving,
                minLines: 6,
                maxLines: 14,
                maxLength: 2000,
                style: const TextStyle(fontSize: 15, height: 1.6),
                decoration: const InputDecoration(
                  hintText: 'What\'s on your mind?',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  counterStyle: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Media section ─────────────────────────────────────────────────
            const Text(
              'Media (optional)',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),

            if (_selectedMedia != null)
              // Preview of newly selected media
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedMedia!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _removeMedia,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: AppColors.whitecolor,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              // Media picker button
              GestureDetector(
                onTap: _isSaving ? null : _pickMedia,
                child: Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(244, 135, 6, 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color.fromRGBO(244, 135, 6, 0.35),
                      style: BorderStyle.solid,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: _orange,
                        size: 32,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add / replace image',
                        style: TextStyle(
                          color: _orange,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 32),

            // ── Save button ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: AppColors.whitecolor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 2,
                ),
                child:
                    _isSaving
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.whitecolor,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DELETE POST — bottom-sheet confirmation
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a modal bottom-sheet asking the user to confirm deletion.
/// Returns true if the post was deleted, false otherwise.
Future<bool> showDeletePostSheet(
  BuildContext context, {
  required String postId,
  VoidCallback? onDeleted,
}) async {
  bool deleted = false;

  await showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.whitecolor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder:
        (ctx) => _DeleteConfirmSheet(
          postId: postId,
          onDeleted: () {
            deleted = true;
            onDeleted?.call();
            Navigator.pop(ctx);
          },
        ),
  );

  return deleted;
}

class _DeleteConfirmSheet extends StatefulWidget {
  final String postId;
  final VoidCallback onDeleted;

  const _DeleteConfirmSheet({required this.postId, required this.onDeleted});

  @override
  State<_DeleteConfirmSheet> createState() => _DeleteConfirmSheetState();
}

class _DeleteConfirmSheetState extends State<_DeleteConfirmSheet> {
  bool _isDeleting = false;

  Future<void> _confirm() async {
    setState(() => _isDeleting = true);

    final success = await ApiService.deleteFiles(
      widget.postId,
      context: context,
    );

    if (!mounted) return;

    if (success) {
      widget.onDeleted();
    } else {
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to delete post. Please try again.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Warning icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline,
                color: Colors.red.shade600,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Delete Post?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              'This action cannot be undone. The post and all its media will be permanently removed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),

            // Delete button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isDeleting ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: AppColors.whitecolor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child:
                    _isDeleting
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppColors.whitecolor,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          'Yes, Delete',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _isDeleting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
