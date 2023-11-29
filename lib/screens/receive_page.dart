import 'dart:math';

import 'package:weepy/files_riverpod.dart';
import 'package:weepy/models.dart';
import '../classes/worker_interface.dart';
import '../classes/worker_messages.dart' as commands;
import '../constants.dart';
import 'package:flutter/material.dart';
import '../classes/receiver.dart';
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
    with TickerProviderStateMixin {
  late AnimationController _downloadAnimC;
  late Receiver _receiveClass;
  final _code = Random().nextInt(8999) + 1000;
  late List<DbFile> _files;
  late String errorMessage;

  ///Use [uiStatus] setter for updating state without [setState]
  var _uiStatus = _UiState.loading;

  ///Setter for ui state.
  ///
  ///Don't need warp with [setState].
  set uiStatus(_UiState uiStatus) => setState(() => _uiStatus = uiStatus);
  @override
  initState() {
    _downloadAnimC = AnimationController(vsync: this)
      ..addListener(() {
        setState(() {});
      });
    //TODO: Instead, create Receiver inside worker and pass callbacks
    _receiveClass = Receiver(
        /*downloadAnimC: _downloadAnimC,
        onDownloadStart: () => uiStatus = _UiState.downloading,
        onAllFilesDownloaded: (files) async {
          await ref.read(filesProvider.notifier).addFiles(files);
          _files = files;
          uiStatus = _UiState.complete;
        },
        onDownloadError: (e) {
          errorMessage = e.getErrorMessage(AppLocalizations.of(context)!);
          uiStatus = _UiState.error;
        },*/
        code: _code);
    _receive();
    super.initState();
  }

  Future<void> _receive() async {
    final port = runReceiver(_receiveClass, (percent) {});
    port.listen((message) {
      switch (message) {
        case final commands.UpdatePercent percent:
          _downloadAnimC.value = percent.newPercent;
          break;
        case final commands.FiledropError e:
          if (context.mounted) {
            errorMessage =
                e.exception.getErrorMessage(AppLocalizations.of(context)!);
            uiStatus = _UiState.error;
          }
        default:
          throw Error();
      }
    });
    uiStatus = _UiState.listening;
  }

  @override
  void dispose() {
    _downloadAnimC.dispose();
    _receiveClass.stopListening();
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
