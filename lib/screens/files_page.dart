import 'package:flutter/material.dart';
import 'package:weepy/classes/exceptions.dart';
import '../models.dart';
import '../classes/database.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class Dosyalar extends StatefulWidget {
  ///Widget for listing recent files.
  const Dosyalar({
    super.key,
  });

  @override
  State<Dosyalar> createState() => _DosyalarState();
}

class _DosyalarState extends State<Dosyalar> {
  final _db = DatabaseManager();
  Future<List<DbFile>> _getFiles() async {
    await _db.open();
    return _db.files;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _getFiles(),
        builder: ((context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error;
            if (error is FileDropException) {
              return Text(error.getErrorMessage(AppLocalizations.of(context)!));
            } else {
              throw error!;
            }
          } else {
            switch (snapshot.connectionState) {
              case ConnectionState.waiting:
                return const Center(
                  child: CircularProgressIndicator(),
                );
              case ConnectionState.done:
                final allFiles = snapshot.data!;
                if (allFiles.isEmpty) {
                  return Center(
                      child: Text(
                    AppLocalizations.of(context)!.noFileHistory,
                  ));
                } else {
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: allFiles.length,
                          itemBuilder: (context, index) {
                            final file = allFiles[index];
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
                            await _db.clear();
                            await _db.close();
                            setState(() {
                              allFiles.clear();
                            });
                          },
                          child: Text(
                            AppLocalizations.of(context)!.clearFileHistory,
                          ))
                    ],
                  );
                }
              default:
                throw Error();
            }
          }
        }));
  }
}
