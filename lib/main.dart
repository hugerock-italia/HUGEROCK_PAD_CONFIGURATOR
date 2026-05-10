//==========================================================================
// 🏍️ TRIP MASTER RALLY - MAIN SCREEN
// ➜ KEYBOARD HANDLER INTEGRATO
// ➜ CAP MISURATO DA BNO055 SUL TRIPMASTER (non più inviato dall'app)
// ➜ FOREGROUND SERVICE GPS RIMOSSO (non serve più per CAP)
// ➜ FOCUS NODE CONTROLLABILE - Dialog può prendere il focus
// ➜ LISTENER BLE PER DISCONNESSIONE AUTOMATICA
// 🎙️ Data: Aprile 2026 - v3.0 BNO055
//==========================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import 'ble_manager.dart';
import 'diagnostics_screen.dart';
import 'config_screen.dart';
import 'keyboard_handler.dart';
import 'background_isolate.dart';
import 'app_colors.dart';

void main() {
  runApp(const TripMasterApp());
}

class TripMasterApp extends StatelessWidget {
  const TripMasterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TripMaster Rally',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.sandMedium, brightness: Brightness.light),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // ═══════════════════════════════════════════════════════════════════════════════════════════════════
  // VARIABILI BLE
  // ═══════════════════════════════════════════════════════════════════════════════════════════════════
  final BLEManager bleManager = BLEManager();
  bool isConnected = false;
  bool isScanning = false;
  String connectionStatus = "DISCONNECTED";
  String deviceName = "TripMaster-Rally";
  String errorMessage = "";

  StreamSubscription? _bleConnectionSubscription;

  // ═══════════════════════════════════════════════════════════════════════════════════════════════════
  // KEYBOARD HANDLER
  // ═══════════════════════════════════════════════════════════════════════════════════════════════════
  late KeyboardHandler keyboardHandler;
  String lastCommandStatus = "";

  // ═══════════════════════════════════════════════════════════════════════════════════════════════════
  // BACKGROUND ISOLATE
  // ═══════════════════════════════════════════════════════════════════════════════════════════════════
  late BackgroundIsolateManager bgIsolate;

  // ➜ FOCUS NODE CONTROLLABILE per il RawKeyboardListener
  late FocusNode mainKeyboardFocusNode;

  // ═══════════════════════════════════════════════════════════════════════════════════════════════════
  // STATO RICALIBRAZIONE IMU
  // ═══════════════════════════════════════════════════════════════════════════════════════════════════
  bool _recalSent = false; // feedback visivo temporaneo dopo invio RECAL

  @override
  void initState() {
    super.initState();
    print("🏍️ MainScreen inizializzato");

    // ➜ Inizializza FocusNode controllabile
    mainKeyboardFocusNode = FocusNode();

    // ➜ Inizializza Background Isolate
    bgIsolate = BackgroundIsolateManager();
    bgIsolate.start();

    // ➜ Attiva Wakelock
    WakelockPlus.enable();
    print("🔋 Wakelock attivato");

    // ➜ Inizializza KeyboardHandler
    keyboardHandler = KeyboardHandler(bleManager: bleManager);
    keyboardHandler.loadKeyBindingsFromStorage();

    keyboardHandler.onStatusChanged = (status) {
      setState(() {
        lastCommandStatus = status;
      });
      print("➜ Callback status ricevuto: $status");
      bgIsolate.sendCommand(status);
    };

    keyboardHandler.onCommandReceived = (command) {
      print("➜ Callback comando ricevuto: $command");
    };

    // ✅ Setup listener per disconnessione BLE
    _setupBleDisconnectionListener();
  }

  @override
  void dispose() {
    print("🏍️ MainScreen dispose");

    _bleConnectionSubscription?.cancel();

    keyboardHandler.dispose();
    mainKeyboardFocusNode.dispose();
    bgIsolate.stop();
    WakelockPlus.disable();

    bleManager.disconnect();

    super.dispose();
  }

  //==========================================================================
  // METODO: Setup disconnessione BLE
  //==========================================================================
  void _setupBleDisconnectionListener() {
    print("📡 Configurazione listener disconnessione BLE...");

    _bleConnectionSubscription = FlutterBluePlus.events.onConnectionStateChanged.listen((event) {
      print("📡 EVENTO BLE: ${event.device.name} - ${event.connectionState}");

      if (event.device.name.contains("TripMaster") &&
          event.connectionState == BluetoothConnectionState.disconnected) {
        print("🔴 DISCONNESSIONE RILEVATA - Aggiornamento UI");

        setState(() {
          isConnected = false;
          connectionStatus = "DISCONNECTED";
          errorMessage = "Device disconnected";
          _recalSent = false;
        });

        bgIsolate.sendCommand("DISCONNECTED");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ TripMaster disconnected"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  //==========================================================================
  // METODO: Permessi Bluetooth
  //==========================================================================
  Future<bool> requestBluetoothPermissions() async {
    try {
      print("📶 Richiesta permessi Bluetooth...");

      PermissionStatus bluetoothStatus = await Permission.bluetooth.request();
      PermissionStatus bluetoothScanStatus = await Permission.bluetoothScan.request();
      PermissionStatus bluetoothConnectStatus = await Permission.bluetoothConnect.request();
      await Permission.location.request();

      return !bluetoothStatus.isDenied &&
          !bluetoothScanStatus.isDenied &&
          !bluetoothConnectStatus.isDenied;
    } catch (e) {
      print("❌ Errore richiesta permessi: $e");
      return false;
    }
  }

  //==========================================================================
  // METODO: Connetti / Disconnetti
  //==========================================================================
  Future<void> handleConnect() async {
    try {
      if (isConnected) {
        print("🔌 Disconnessione dal TripMaster...");
        await bleManager.disconnect();

        setState(() {
          isConnected = false;
          connectionStatus = "DISCONNECTED";
          _recalSent = false;
        });

        bgIsolate.sendCommand("DISCONNECTED");
      } else {
        print("🔍 Ricerca TripMaster...");

        setState(() {
          isScanning = true;
          connectionStatus = "SCANNING";
        });

        bool hasPermissions = await requestBluetoothPermissions();
        if (!hasPermissions) {
          setState(() {
            isScanning = false;
            errorMessage = "Bluetooth permissions not granted";
          });
          return;
        }

        List<ScanResult> results = await bleManager.scanForDevices();

        BluetoothDevice? target;
        for (var result in results) {
          if (result.device.name.contains("TripMaster")) {
            target = result.device;
            break;
          }
        }

        if (target == null) {
          setState(() {
            isScanning = false;
            errorMessage = "TripMaster not found";
            connectionStatus = "NOT FOUND";
          });
          return;
        }

        print("📡 Connessione a ${target.name}...");

        bool success = await bleManager.connectToDevice(target);

        if (success) {
          setState(() {
            isConnected = true;
            isScanning = false;
            connectionStatus = "CONNECTED ✓";
            errorMessage = "";
            deviceName = target!.name;
            _recalSent = false;
          });

          bgIsolate.sendCommand("CONNECTED");
          print("✓ Connesso!");
        } else {
          setState(() {
            isScanning = false;
            errorMessage = "Connection error";
            connectionStatus = "ERROR";
          });
        }
      }
    } catch (e) {
      print("❌ Errore: $e");

      setState(() {
        isScanning = false;
        errorMessage = "Error: $e";
      });
    }
  }

  //==========================================================================
  // METODO: Forza ricalibrazione IMU (invia "RECAL" al TripMaster)
  //==========================================================================
  Future<void> _sendRecalibration() async {
    if (!isConnected) return;

    print("🧭 Invio comando RECAL al TripMaster...");

    bool success = await bleManager.sendCommand("RECAL");

    setState(() {
      _recalSent = success;
    });

    if (success) {
      print("✓ RECAL inviato");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🧭 Ricalibrazione BNO055 avviata"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      // Reset feedback visivo dopo 3 secondi
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() { _recalSent = false; });
      });
    } else {
      print("❌ Errore invio RECAL");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Errore invio comando calibrazione"),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  //==========================================================================
  // BUILD
  //==========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: Row(
          children: [
            Image.asset(
              'assets/kat_adv_logo.png',
              height: 60,
            ),
            const SizedBox(width: 16),
            const Text(
              'KAT ADV TRIPMASTER RALLY',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.sandMedium,
        elevation: 0,
      ),
      body: RawKeyboardListener(
        focusNode: mainKeyboardFocusNode,
        onKey: (RawKeyEvent event) {
          if (mainKeyboardFocusNode.hasFocus) {
            print("🎹 Evento tastiera ricevuto");

            TripCommand command = keyboardHandler.recognizeCommand(event);

            if (command != TripCommand.none) {
              print("✓ Comando riconosciuto: $command");
              keyboardHandler.processCommand(command);
            }
          }
        },
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // ═══════════════════════════════════════════════════════════════════════════════════════════════════
                // SEZIONE 1: Status Bluetooth
                // ═══════════════════════════════════════════════════════════════════════════════════════════════════
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green[50] : Colors.red[50],
                    border: Border.all(
                      color: isConnected ? Colors.green : Colors.red,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        size: 50,
                        color: isConnected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        connectionStatus,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isConnected ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Device: $deviceName',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      if (errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'Error: $errorMessage',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ═══════════════════════════════════════════════════════════════════════════════════════════════════
                // SEZIONE 2: Ultimo comando ricevuto
                // ═══════════════════════════════════════════════════════════════════════════════════════════════════
                if (lastCommandStatus.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.amber[100],
                      border: Border.all(
                        color: Colors.amber,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.amber[700],
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Last: $lastCommandStatus',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.amber[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 40),

                // ═══════════════════════════════════════════════════════════════════════════════════════════════════
                // SEZIONE 3: Bottone CONNECT
                // ═══════════════════════════════════════════════════════════════════════════════════════════════════
                SizedBox(
                  width: double.infinity,
                  height: 100,
                  child: ElevatedButton(
                    onPressed: isScanning ? null : handleConnect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected
                          ? AppColors.sandMedium
                          : AppColors.sandMedium.withOpacity(0.7),
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: isScanning
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            isConnected
                                ? "CONNECTED ✓"
                                : "CONNECT KAT-ADV TRIPPY",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // ═══════════════════════════════════════════════════════════════════════════════════════════════════
                // SEZIONE 4: Bottone FORZA CALIBRAZIONE BNO055
                // ═══════════════════════════════════════════════════════════════════════════════════════════════════
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: isConnected ? _sendRecalibration : null,
                    icon: Icon(
                      _recalSent ? Icons.check_circle : Icons.compass_calibration,
                      size: 28,
                    ),
                    label: Text(
                      _recalSent ? 'CALIBRAZIONE AVVIATA ✓' : 'FORZA CALIBRAZIONE BNO055',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected
                          ? (_recalSent ? Colors.green[600] : Colors.orange[700])
                          : Colors.grey[300],
                      foregroundColor: isConnected ? Colors.white : Colors.grey[600],
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ═══════════════════════════════════════════════════════════════════════════════════════════════════
                // SEZIONE 5: Bottoni CONFIG e DIAGNOSTICS
                // ═══════════════════════════════════════════════════════════════════════════════════════════════════
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isConnected
                            ? () async {
                                mainKeyboardFocusNode.unfocus();

                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ConfigScreen(
                                      bleManager: bleManager,
                                      keyboardHandler: keyboardHandler,
                                    ),
                                  ),
                                );

                                mainKeyboardFocusNode.requestFocus();
                                print("✓ Ritorno da ConfigScreen, focus ripristinato");
                              }
                            : null,
                        icon: const Icon(Icons.settings),
                        label: const Text('Config'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isConnected ? AppColors.sandMedium : Colors.grey[300],
                          foregroundColor: isConnected ? Colors.white : Colors.grey[600],
                          disabledBackgroundColor: Colors.grey[300],
                          disabledForegroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isConnected
                            ? () {
                                mainKeyboardFocusNode.unfocus();

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DiagnosticsScreen(
                                      bleManager: bleManager,
                                    ),
                                  ),
                                ).then((_) {
                                  mainKeyboardFocusNode.requestFocus();
                                  print("✓ Ritorno da DiagnosticsScreen, focus ripristinato");
                                });
                              }
                            : null,
                        icon: const Icon(Icons.bug_report),
                        label: const Text('Diagnostics'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          disabledBackgroundColor: Colors.grey[300],
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // ═══════════════════════════════════════════════════════════════════════════════════════════════════
                // SEZIONE 6: Versione App
                // ═══════════════════════════════════════════════════════════════════════════════════════════════════
                Text(
                  'v3.0 - TripMaster Rally BNO055',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}