import 'package:weepy/models.dart';

import '../classes/exceptions.dart';
import '../constants.dart';
import 'package:flutter/material.dart';
import '../classes/receive.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

class ReceivePageInner extends StatefulWidget {
  const ReceivePageInner({super.key});

  @override
  State<ReceivePageInner> createState() => _ReceivePageInnerState();
}

class _ReceivePageInnerState extends State<ReceivePageInner>
    with TickerProviderStateMixin {
  late AnimationController _downloadAnimC;
  late Receive _receive;
  late int _code;
  late List<DbFile> _files;
  late String errorMessage;
  var _uiStatus = _UiState.loading;
  set uiStatus(_UiState uiStatus) => setState(() => _uiStatus = uiStatus);
  @override
  initState() {
    _downloadAnimC = AnimationController(vsync: this)
      ..addListener(() {
        setState(() {});
      });
    _receive = Receive(
      downloadAnimC: _downloadAnimC,
      onAllFilesDownloaded: (files) {
        _files = files;
        uiStatus = _UiState.complete;
      },
    );
    _receive.listen().then((code) {
      _code = code;
      uiStatus = _UiState.listening;
    }).catchError((err) {
      if (err is FileDropException) {
        errorMessage = err.getErrorMessage(AppLocalizations.of(context)!);
        uiStatus = _UiState.error;
      } else {
        throw err;
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _downloadAnimC.dispose();
    _receive.stopListening();
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
