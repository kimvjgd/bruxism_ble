import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceScreen extends StatefulWidget {
  DeviceScreen({Key? key, required this.device}) : super(key: key);
  final BluetoothDevice device;

  @override
  _DeviceScreenState createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  String stateText = 'Connecting';
  String connectButtonText = 'Disconnect';
  BluetoothDeviceState deviceState = BluetoothDeviceState.disconnected;
  StreamSubscription<BluetoothDeviceState>? _stateListener;
  List<BluetoothService> bluetoothService = [];
  String displayedValue = ''; // 화면에 표시할 값
  FlutterBluePlus flutterBlue = FlutterBluePlus.instance;

  @override
  initState() {
    super.initState();
    _stateListener = widget.device.state.listen((event) {
      if (deviceState != event) {
        setBleConnectionState(event);
      }
    });
    connect();
  }

  @override
  void dispose() {
    _stateListener?.cancel();
    disconnect();
    super.dispose();
  }

  setBleConnectionState(BluetoothDeviceState event) {
    switch (event) {
      case BluetoothDeviceState.disconnected:
        stateText = 'Disconnected';
        connectButtonText = 'Connect';
        break;
      case BluetoothDeviceState.disconnecting:
        stateText = 'Disconnecting';
        break;
      case BluetoothDeviceState.connected:
        stateText = 'Connected';
        connectButtonText = 'Disconnect';
        break;
      case BluetoothDeviceState.connecting:
        stateText = 'Connecting';
        break;
    }
    deviceState = event;
    setState(() {});
  }

  Future<bool> connect() async {
    Future<bool>? returnValue;
    setState(() {
      stateText = 'Connecting';
    });

    await widget.device.connect(autoConnect: false).timeout(
      Duration(milliseconds: 15000),
      onTimeout: () {
        returnValue = Future.value(false);
        setBleConnectionState(BluetoothDeviceState.disconnected);
      },
    ).then((data) async {
      bluetoothService.clear();
      if (returnValue == null) {
        List<BluetoothService> bleServices = await widget.device.discoverServices();
        setState(() {
          bluetoothService = bleServices;
        });

        for (BluetoothService service in bleServices) {
          for (BluetoothCharacteristic c in service.characteristics) {
            if (c.properties.notify && c.descriptors.isNotEmpty) {
              if (!c.isNotifying) {
                try {
                  await c.setNotifyValue(true);
                  c.value.listen((value) {
                    processTempInfo(value); // 수신한 데이터 처리
                  });
                } catch (e) {
                  print('Error enabling notify for ${c.uuid}: $e');
                }
              }
            }
          }
        }
        returnValue = Future.value(true);
      }
    });

    return returnValue ?? Future.value(false);
  }

  void disconnect() {
    try {
      setState(() {
        stateText = 'Disconnecting';
      });
      widget.device.disconnect();
    } catch (e) {}
  }

  // ASCII 코드 리스트를 문자열로 변환 후 정수 변환
  void processTempInfo(List<int> tempInfo) {
    String receivedString = String.fromCharCodes(tempInfo).trim();
    print("Received String: $receivedString");

    int? intValue = int.tryParse(receivedString);
    if (intValue != null) {
      setState(() {
        displayedValue = intValue.toString();
      });
      print("Converted Integer Value: $intValue");
    } else {
      print("Conversion to integer failed");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Device Data"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Connection State: $stateText',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            Text(
              'Received Value: $displayedValue',
              style: TextStyle(color: Colors.red, fontSize: 30),
            ),
            SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {
                if (deviceState == BluetoothDeviceState.connected) {
                  disconnect();
                } else if (deviceState == BluetoothDeviceState.disconnected) {
                  connect();
                }
              },
              child: Text(connectButtonText),
            ),
          ],
        ),
      ),
    );
  }
}
