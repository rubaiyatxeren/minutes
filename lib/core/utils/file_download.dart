import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

import '../localization/app_localizations.dart';

/// Downloads a remote file to app storage (or reuses the cached copy)
/// and opens it with the OS's default viewer for that file type.
///
/// The cached filename is prefixed with a short hash of the URL, not
/// just the display name — two different messages can otherwise share
/// a display name (e.g. two photos both named "image.jpg") and, without
/// the hash, the second download would wrongly reuse the first file's
/// cached bytes and open the wrong content.
Future<void> downloadAndOpenFile(
  BuildContext context, {
  required String url,
  required String fileName,
}) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final urlHash = url.hashCode.toUnsigned(20).toRadixString(16);
    final filePath = '${dir.path}/${urlHash}_$safeName';
    final file = File(filePath);

    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context).downloadingFile)),
        );
      }
      await Dio().download(url, filePath);
    }

    final result = await OpenFile.open(filePath);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)
                .couldNotOpenFile('${result.message}'))),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context).downloadFailed('$e'))),
      );
    }
  }
}
