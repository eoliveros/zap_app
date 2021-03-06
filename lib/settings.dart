import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info/package_info.dart';
import 'package:yaml/yaml.dart';

import 'libzap.dart';
import 'prefs.dart';
import 'utils.dart';

class SettingsScreen extends StatefulWidget {
  final String _mnemonic;
  final bool _mnemonicPasswordProtectedInitial;

  SettingsScreen(this._mnemonic, this._mnemonicPasswordProtectedInitial) : super();

  @override
  _SettingsState createState() => new _SettingsState(_mnemonicPasswordProtectedInitial);
}

class _SettingsState extends State<SettingsScreen> {
  bool _mnemonicPasswordProtected;
  String _appVersion;
  String _buildNumber;
  int _libzapVersion = -1;
  bool _testnet = false;
  String _apikey;
  String _apisecret;

  _SettingsState(this._mnemonicPasswordProtected) {
    _initAppVersion();
    _libzapVersion = _getLibZapVersion();
    _initTestnet();
    _initApikey();
  }

  void _initAppVersion() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      var pubspec = await rootBundle.loadString('pubspec.yaml');
      var doc = loadYaml(pubspec);
      var version = doc["version"].toString().split("+");
      setState(() {
        _appVersion = version[0];
        _buildNumber = version[1];
      });
    }
    else {
      var packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    }
  }

  int _getLibZapVersion() {
    var libzap = LibZap();
    return libzap.version();
  }

  void _initTestnet() async {
    var testnet = await Prefs.testnetGet();
    setState(() {
      _testnet = testnet;
    });
  }

  void _initApikey() async {
    var apikey = await Prefs.apikeyGet();
    var apisecret = await Prefs.apisecretGet();
    setState(() {
      _apikey = apikey;
      _apisecret = apisecret;
    });
  }

  void _toggleTestnet() async {
    Prefs.testnetSet(!_testnet);
    setState(() {
      _testnet = !_testnet;
    });
  }

  void _addPasswordProtection() async {
    var password = await askSetMnemonicPassword(context);
    if (password != null) {
      var res = encryptMnemonic(widget._mnemonic, password);
      await Prefs.cryptoIVSet(res.iv);
      await Prefs.mnemonicSet(res.encryptedMnemonic);
      setState(() {
        _mnemonicPasswordProtected = true;
      });
    }
  }

  void _editApikey() async {
    var apikey = await askString(context, "Set Api Key", _apikey);
    if (apikey != null) {
      await Prefs.apikeySet(apikey);
      setState(() {
        _apikey = apikey;
      });
    }
  }

  void _editApisecret() async {
    var apisecret = await askString(context, "Set Api Secret", _apisecret);
    if (apisecret != null) {
      await Prefs.apisecretSet(apisecret);
      setState(() {
        _apisecret = apisecret;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: ListTile(title: Text("Version: $_appVersion"), subtitle: Text("Build: $_buildNumber")),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: ListTile(title: Text("Libzap Version: $_libzapVersion")),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: SwitchListTile(
                value: _testnet,
                title: Text("Testnet"),
                onChanged: (value) async {
                  _toggleTestnet();
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: ListTile(title: Text("Mnemonic"), subtitle: Text(widget._mnemonic), trailing: _mnemonicPasswordProtected ? Icon(Icons.lock) : Icon(Icons.lock_open),),
            ),
            Visibility(
              visible: !_mnemonicPasswordProtected,
              child: Container(
                child: ListTile(
                  title: RaisedButton.icon(label: Text("Password Protect Mnemonic"), icon: Icon(Icons.lock), onPressed: () { _addPasswordProtection(); }),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: ListTile(title: Text("Api Key"), subtitle: Text("$_apikey"), trailing: RaisedButton.icon(label: Text("Edit"), icon: Icon(Icons.edit), onPressed: () { _editApikey(); }),),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: ListTile(title: Text("Api Secret"), subtitle: Text("$_apisecret"), trailing: RaisedButton.icon(label: Text("Edit"), icon: Icon(Icons.edit), onPressed: () { _editApisecret(); }),),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: RaisedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.close),
                  label: Text('Close'))
              ),
            ],
          ),
        )
    );
  }
}