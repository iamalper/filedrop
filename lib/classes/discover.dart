import 'dart:convert';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools/network_tools.dart';
import '../constants.dart';
import 'package:http/http.dart' as http;
import 'package:file_sharer/models.dart';

class Discover {
  static Future<List<Device>> discover({int port = Constants.port}) async {
    final ip = await getMyIp();
    final String subnet = ip.substring(0, ip.lastIndexOf('.'));
    final client = http.Client();
    final List<Device> ips = [];
    await for (var activeHost in HostScanner.scanDevicesForSinglePort(
      subnet,
      port,
    )) {
      try {
        final response =
            await client.get(Uri.http("${activeHost.address}:$port"));
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json["mesaj"] == Constants.tanitim) {
            ips.add(Device(
                adress: activeHost.address,
                code: json["code"] as int,
                port: port));
          }
        }
      } catch (_) {
        continue;
      }
    }
    return ips;
  }

  static Future<String> getMyIp() async {
    final ip = await NetworkInfo().getWifiIP();
    if (ip == null) {
      throw "ip error";
    }
    return ip;
  }
}
