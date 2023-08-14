import '../constants.dart';
import 'package:flutter/material.dart';
import '../classes/receive.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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

  late int _code;
  late Future<void> _receiveFuture;
  int _uiStatus = 0;
  set uiStatus(int uiStatus) => setState(() => _uiStatus = uiStatus);
  @override
  initState() {
    _downloadAnimC = AnimationController(vsync: this)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (_uiStatus != 2) {
          uiStatus = 2; //Downloading
        }
        if (status == AnimationStatus.completed) {
          if (Receive.files.isNotEmpty) {
            uiStatus = 3; //Completed
          } else {
            uiStatus = 6; //Error
          }
        }
      });

    _receiveFuture = Receive.listen(downloadAnimC: _downloadAnimC).then((code) {
      _code = code;
      uiStatus = 1;
    }).catchError((err) {
      switch (err) {
        case "ip error":
          uiStatus = 4;
          break;
        case "Permission denied":
          uiStatus = 5;
          break;
        case "web":
          uiStatus = 7;
          break;
        default:
          throw err;
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _downloadAnimC.dispose();
    _receiveFuture.ignore();
    Receive.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_uiStatus) {
      case 1:
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
      case 2:
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
      case 3:
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
                itemCount: Receive.files.length,
                itemBuilder: (context, index) {
                  final file = Receive.files[index];
                  return ListTile(
                    title: Text(file.name),
                    onTap: file.fileType != null ? () => file.open() : null,
                  );
                },
              ),
            )
          ],
        );
      case 4:
        return Text(
          AppLocalizations.of(context)!.notConnectedToNetwork,
          textAlign: TextAlign.center,
        );
      case 5:
        return Text(
          AppLocalizations.of(context)!.noStoragePermission,
          textAlign: TextAlign.center,
        );
      case 6:
        return Text(
          AppLocalizations.of(context)!.unknownError,
          textAlign: TextAlign.center,
        );
      default:
        return const CircularProgressIndicator();
    }
  }
}
