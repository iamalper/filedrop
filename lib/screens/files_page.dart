import 'package:flutter/material.dart';
import '../models.dart';
import '../classes/database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class Dosyalar extends StatefulWidget {
  ///Widget for listing recent files.
  ///
  ///if [loaded] is `false`, draws a loading animation instead of files.
  ///It should be used for determinate if database read completed or not.
  ///
  ///If [dbError] is `true`, <b>cantReadDatabase</b> string from translations will be shown instead of files.
  ///
  ///[allFiles] is the files which are about to shown in widget.
  const Dosyalar({
    super.key,
    required this.loaded,
    required this.dbError,
    required this.allFiles,
  });
  final bool loaded;
  final bool dbError;
  final List<DbFile> allFiles;
  @override
  State<Dosyalar> createState() => _DosyalarState();
}

class _DosyalarState extends State<Dosyalar> {
  @override
  Widget build(BuildContext context) {
    if (!widget.loaded) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    } else if (widget.dbError) {
      return Center(
          child: Text(AppLocalizations.of(context)!.cantReadDatabase));
    } else if (widget.allFiles.isEmpty && widget.loaded) {
      return Center(
          child: Text(
        AppLocalizations.of(context)!.noFileHistory,
      ));
    } else {
      return Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.allFiles.length,
              itemBuilder: (context, index) {
                final file = widget.allFiles[index];
                return ListTile(
                  leading: file.icon,
                  title: Text(file.name),
                  subtitle: Text(file.time.toIso8601String()),
                  onTap: () => file.open(),
                );
              },
            ),
          ),
          TextButton(
              onPressed: () async {
                final db = DatabaseManager();
                await db.open();
                await db.clear();
                await db.close();
                setState(() {
                  widget.allFiles.clear();
                });
              },
              child: Text(
                AppLocalizations.of(context)!.clearFileHistory,
              ))
        ],
      );
    }
  }
}