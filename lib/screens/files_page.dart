import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weepy/classes/exceptions.dart';
import 'package:weepy/files_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class Dosyalar extends ConsumerStatefulWidget {
  ///Widget for listing recent files.
  const Dosyalar({
    super.key,
  });

  @override
  ConsumerState<Dosyalar> createState() => _DosyalarState();
}

class _DosyalarState extends ConsumerState<Dosyalar> {
  @override
  Widget build(BuildContext context) {
    final files = ref.watch(filesProvider);
    final filesNotifier = ref.read(filesProvider.notifier);
    return files.when(
        data: (allFiles) {
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
                        onTap: file.open,
                      );
                    },
                  ),
                ),
                TextButton(
                    onPressed: filesNotifier.clear,
                    child: Text(
                      AppLocalizations.of(context)!.clearFileHistory,
                    ))
              ],
            );
          }
        },
        error: (error, stackTrace) {
          if (error is FileDropException) {
            return Text(error.getErrorMessage(AppLocalizations.of(context)!));
          } else {
            throw error;
          }
        },
        loading: () => const Center(
              child: CircularProgressIndicator(),
            ));
  }
}
