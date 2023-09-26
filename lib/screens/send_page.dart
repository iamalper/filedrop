import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:weepy/classes/exceptions.dart';
import 'package:weepy/files_riverpod.dart';
import '../classes/discover.dart' as discover_class; //for prevent collusion
import '../classes/sender.dart';
import '../constants.dart';
import '../models.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _UiState { scanning, select, sending, complete, error }

class SendPage extends StatelessWidget {
  final bool isDark;
  const SendPage({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: Appbars.globalAppBar(isDark: isDark),
        body: const Center(child: SendPageInner()));
  }
}

class SendPageInner extends ConsumerStatefulWidget {
  const SendPageInner({super.key});
  @override
  ConsumerState<SendPageInner> createState() => _SendPageInnerState();
}

class _SendPageInnerState extends ConsumerState<SendPageInner>
    with TickerProviderStateMixin {
  var _uiState = _UiState.scanning;
  List<Device> _ipList = [];
  late AnimationController _uploadAnimC;
  late String _errorMessage;
  late LottieBuilder animation;

  set uiState(_UiState uiState) {
    if (mounted) {
      setState(() => _uiState = uiState);
    }
  }

  @override
  void initState() {
    _uploadAnimC = AnimationController(
        vsync: this,
        debugLabel: "Upload Animation Controller",
        duration: const Duration(seconds: 1))
      ..addListener(() {
        setState(() {});
      });
    animation = Assets.upload(_uploadAnimC, (composition) {
      _uploadAnimC.duration = composition.duration;
    });
    super.initState();
    _discover();
  }

  Future<void> _discover() async {
    try {
      while (_ipList.isEmpty) {
        _ipList = await discover_class.Discover.discover();
      }
      uiState = _UiState.select;
    } on FileDropException catch (e) {
      if (context.mounted) {
        _errorMessage = e.getErrorMessage(AppLocalizations.of(context)!);
        uiState = _UiState.error;
      }
    }
  }

  @override
  void dispose() {
    _uploadAnimC.dispose();
    Sender.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_uiState) {
      case _UiState.sending:
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(AppLocalizations.of(context)!.fileUploading),
            animation,
          ]),
        );
      case _UiState.complete:
        return Text(
          AppLocalizations.of(context)!.filesSent,
          textAlign: TextAlign.center,
        );
      case _UiState.error:
        return Text(
          _errorMessage,
          textAlign: TextAlign.center,
        );
      case _UiState.scanning:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(AppLocalizations.of(context)!.scanningNetwork),
            Assets.wifi,
          ],
        );

      case _UiState.select: //network scanned
        if (_ipList.isEmpty) {
          //Obselete, discovery loops until a device found.
          return Text(
            AppLocalizations.of(context)!.noReceiverDeviceFound,
            textAlign: TextAlign.center,
          );
        } else {
          return ListView.builder(
              itemCount: _ipList.length,
              itemBuilder: (context, index) {
                final device = _ipList[index];
                return ListTile(
                  title: Text(device.code.toString()),
                  leading: const Icon(Icons.phone_android),
                  onTap: () {
                    _send(device, _uploadAnimC);
                  },
                );
              });
        }
      default:
        throw Error();
    }
  }

  Future<void> _send(Device device, AnimationController uploadAnimC) async {
    final file = await Sender.filePick();
    if (file != null) {
      uiState = _UiState.sending;
      try {
        await Sender.send(device, file, uploadAnimC: uploadAnimC);
        final filesNotifier = ref.read(filesProvider.notifier);
        await filesNotifier.addFiles(file
            .map((e) => DbFile(
                name: e.name,
                path: e.path!,
                time: DateTime.now(),
                fileStatus: DbFileStatus.upload))
            .toList());
        uiState = _UiState.complete;
      } on FileDropException catch (e) {
        if (context.mounted) {
          _errorMessage = e.getErrorMessage(AppLocalizations.of(context)!);
          uiState = _UiState.error;
        }
      }
    }
  }
}
