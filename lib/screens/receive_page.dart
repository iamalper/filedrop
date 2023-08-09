import 'package:file_sharer/constants.dart';
import 'package:flutter/material.dart';
import '../classes/receive.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

late AnimationController downloadAnimC;

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
  State<ReceivePageInner> createState() => ReceivePageInnerState();
}

class ReceivePageInnerState extends State<ReceivePageInner>
    with TickerProviderStateMixin {
  late int code;
  late Future<void> receiveFuture;
  int _uiStatus = 0;
  set uiStatus(int uiStatus) => setState(() => _uiStatus = uiStatus);
  @override
  initState() {
    downloadAnimC = AnimationController(vsync: this)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (_uiStatus != 2) {
          uiStatus = 2; //dosya almaya başlıyor
        }
        if (status == AnimationStatus.completed) {
          if (files.isNotEmpty) {
            uiStatus = 3; //dosya alındı
          } else {
            uiStatus = 6;
          }
        }
      });

    receiveFuture = Receive.listen().then((code) {
      this.code = code;
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
          debugPrint("Receive hata $err");
          uiStatus = 6;
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    downloadAnimC.dispose();
    receiveFuture.ignore();
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
              AppLocalizations.of(context)!.connectionWaiting(code),
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
              value: downloadAnimC.value,
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
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
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
