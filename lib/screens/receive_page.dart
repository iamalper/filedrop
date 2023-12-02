import 'package:flutter/foundation.dart';
import 'package:weepy/classes/receiver.dart';
import 'package:weepy/files_riverpod.dart';
import 'package:weepy/models.dart';
import '../classes/workers/worker_interface.dart';
import '../constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _UiState { loading, listening, downloading, complete, error }

class ReceivePage extends StatelessWidget {
  final bool isDark;
  const ReceivePage({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Appbars.globalAppBar(isDark: isDark),
      body: const Center(child: ReceivePageInner()),
    );
  }
}

class ReceivePageInner extends ConsumerStatefulWidget {
  const ReceivePageInner({super.key});

  @override
  ConsumerState<ReceivePageInner> createState() => _ReceivePageInnerState();
}

class _ReceivePageInnerState extends ConsumerState<ReceivePageInner>
    with SingleTickerProviderStateMixin {
  late AnimationController _downloadAnimC;
  late final _receiver = defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS
      ? IsolatedReceiver(
          onDownloadStart: () => uiStatus = _UiState.downloading,
          onAllFilesDownloaded: (files) async {
            await ref.read(filesProvider.notifier).addFiles(files);
            _files = files;
            uiStatus = _UiState.complete;
          },
          onDownloadError: (e) {
            errorMessage = e.getErrorMessage(AppLocalizations.of(context)!);
            uiStatus = _UiState.error;
          },
          onDownloadUpdatePercent: (percent) {
            _downloadAnimC.value = percent;
          })
      : Receiver(
          onDownloadStart: () => uiStatus = _UiState.downloading,
          onAllFilesDownloaded: (files) async {
            await ref.read(filesProvider.notifier).addFiles(files);
            _files = files;
            uiStatus = _UiState.complete;
          },
          onDownloadError: (e) {
            errorMessage = e.getErrorMessage(AppLocalizations.of(context)!);
            uiStatus = _UiState.error;
          },
          onDownloadUpdatePercent: (percent) {
            _downloadAnimC.value = percent;
          });
  late List<DbFile> _files;
  late String errorMessage;
  late int _code;

  ///Use [uiStatus] setter for updating state without [setState]
  var _uiStatus = _UiState.loading;

  @override
  void initState() {
    _downloadAnimC = AnimationController(vsync: this)
      ..addListener(() {
        setState(() {});
      });
    super.initState();
    _receive();
  }

  ///Setter for ui state.
  ///
  ///Don't need warp with [setState].
  set uiStatus(_UiState uiStatus) => setState(() => _uiStatus = uiStatus);

  Future<void> _receive() async {
    _code = await _receiver.listen();
    uiStatus = _UiState.listening;
  }

  @override
  void dispose() {
    _downloadAnimC.dispose();
    _receiver.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_uiStatus) {
      case _UiState.listening:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppLocalizations.of(context)!.connectionWaiting(_code),
              textAlign: TextAlign.center,
            ),
            Assets.hotspot,
          ],
        );
      case _UiState.downloading:
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(
              AppLocalizations.of(context)!.fileDownloading,
              textAlign: TextAlign.center,
            ),
            LinearProgressIndicator(
              value: _downloadAnimC.value,
              minHeight: 10,
            )
          ]),
        );
      case _UiState.complete:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.filesSaved,
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  return ListTile(
                    title: Text(file.name),
                    onTap: file.open,
                  );
                },
              ),
            )
          ],
        );
      case _UiState.loading:
        return const CircularProgressIndicator();
      case _UiState.error:
        return Text(errorMessage);
    }
  }
}
