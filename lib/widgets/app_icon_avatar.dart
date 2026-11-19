import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../state/app_library.dart';
import 'app_avatar.dart';

/// Shows the app's real launcher icon when it's actually installed on the
/// device (fetched once via [AppLibrary.installedIcon]), falling back to
/// the generic colored-initials [AppAvatar] while that's loading, if it
/// comes back empty, or if there's no package name to look up at all.
class AppIconAvatar extends StatefulWidget {
  final AppLibrary library;
  final String? packageName;
  final String name;
  final String initials;
  final double size;

  const AppIconAvatar({
    super.key,
    required this.library,
    required this.packageName,
    required this.name,
    required this.initials,
    this.size = 44,
  });

  @override
  State<AppIconAvatar> createState() => _AppIconAvatarState();
}

class _AppIconAvatarState extends State<AppIconAvatar> {
  Future<Uint8List?>? _iconFuture;

  @override
  void initState() {
    super.initState();
    final packageName = widget.packageName;
    if (packageName != null && packageName.trim().isNotEmpty) {
      _iconFuture = widget.library.installedIcon(packageName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final future = _iconFuture;
    if (future == null) {
      return AppAvatar(
        name: widget.name,
        initials: widget.initials,
        size: widget.size,
      );
    }
    return FutureBuilder<Uint8List?>(
      future: future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return AppAvatar(
            name: widget.name,
            initials: widget.initials,
            size: widget.size,
          );
        }
        return ClipOval(
          child: Image.memory(
            bytes,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}
