import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart' hide Key;
import 'package:decimal/decimal.dart';
import 'package:encrypt/encrypt.dart';
import 'package:base58check/base58.dart';

import 'libzap.dart';
import 'merchant.dart';

//
// We do our own uri parsing until dart has better struct/fixed-size-array support in ffi
//

const NO_ERROR = 0;
const INVALID_WAVES_URI = 1;
const INVALID_ASSET_ID = 2;
const INVALID_CLAIMCODE_URI = 3;

String parseUriParameter(String input, String token) {
  token = token + '=';
  if (input.length > token.length && input.substring(0, token.length).toLowerCase() == token)
    return input.substring(token.length);
  return null;
}

class WavesRequest {
  final String address;
  final String assetId;
  final Decimal amount;
  final String attachment;
  final int error;

  WavesRequest(this.address, this.assetId, this.amount, this.attachment, this.error);
}

WavesRequest parseWavesUri(bool testnet, String uri) {
  var address = '';
  var assetId = '';
  var amount = Decimal.fromInt(0);
  var attachment = '';
  int error = NO_ERROR;
  if (uri.length > 8 && uri.substring(0, 8).toLowerCase() == 'waves://') {
    var parts = uri.substring(8).split('?');
    if (parts.length == 2) {
      address = parts[0];
      parts = parts[1].split('&');
      for (var part in parts) {
        var res = parseUriParameter(part, 'asset');
        if (res != null) assetId = res;
        res = parseUriParameter(part, 'amount');
        if (res != null) amount = Decimal.parse(res) / Decimal.fromInt(100);
        res = parseUriParameter(part, attachment);
        if (res != null) attachment = res;
      }
    }
    var zapAssetId = testnet ? LibZap.TESTNET_ASSET_ID : LibZap.MAINNET_ASSET_ID;
    if (assetId != zapAssetId) {
      address = '';
      error = INVALID_ASSET_ID;
    }
  }
  else
    error = INVALID_WAVES_URI;
  return WavesRequest(address, assetId, amount, attachment, error);
}

class ClaimCodeResult {
  final ClaimCode code;
  final int error;

  ClaimCodeResult(this.code, this.error);
}

ClaimCodeResult parseClaimCodeUri(String uri) {
  var token = '';
  var secret = '';
  var amount = Decimal.fromInt(0);
  int error = NO_ERROR;
  if (uri.length > 10 && uri.substring(0, 10).toLowerCase() == 'claimcode:') {
    var parts = uri.substring(10).split('?');
    if (parts.length == 2) {
      token = parts[0];
      parts = parts[1].split('&');
      for (var part in parts) {
        var res = parseUriParameter(part, 'secret');
        if (res != null) secret = res;
        res = parseUriParameter(part, 'amount');
        if (res != null) amount = Decimal.parse(res) / Decimal.fromInt(100);
      }
    }
  }
  else
    error = INVALID_CLAIMCODE_URI;
  return ClaimCodeResult(ClaimCode(amount: amount, token: token, secret: secret), error);
}

String parseRecipientOrWavesUri(bool testnet, String data) {
  var libzap = LibZap();
  if (libzap.addressCheck(data))
    return data;                // return input, user can use this data as an address
  var result = parseWavesUri(testnet, data);
  if (result.error == NO_ERROR)
    return result.address;      // return address part of waves uri, user should call parseWavesUri directly for extra details
  return null;                  // return null, data is not usable/valid
}

void showAlertDialog(BuildContext context, String msg) {
  var alert= AlertDialog(
    content: new Row(
        children: [
            CircularProgressIndicator(),
            Container(margin: EdgeInsets.only(left: 10), child: Text(msg)),
        ],),
  );
  showDialog(barrierDismissible: false,
    context:context,
    builder:(BuildContext context){
      return alert;
    },
  );
}

Future<void> alert(BuildContext context, String title, String msg) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: <Widget>[
          FlatButton(
            child: Text("Ok"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<String> askString(BuildContext context, String title, String value) {
  final formKey = GlobalKey<FormState>();
  final txtController = new TextEditingController();
  txtController.text = value;

  void submit() {
    if (formKey.currentState.validate()) {
      Navigator.pop(context, txtController.text);
    }
  }

  Widget buildForm(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextFormField(
            controller: txtController,
            keyboardType: TextInputType.text,
            validator: (value) {
              if (value.isEmpty) {
                return 'Please enter a value';
              }
              return null;
            },
          ),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                RaisedButton.icon(
                    onPressed: () { Navigator.pop(context); },
                    icon: Icon(Icons.cancel),
                    label: Text('Cancel')),
                RaisedButton.icon(
                    onPressed: submit,
                    icon: Icon(Icons.send),
                    label: Text('Submit')),
              ]
          ),
        ],
      ),
    );
  }

  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: buildForm(context),
      );
    },
  );
}

Future<String> askSetMnemonicPassword(BuildContext context) async {
  final formKey = GlobalKey<FormState>();
  final pwController = new TextEditingController();
  final pw2Controller = new TextEditingController();

  void submit() {
    if (formKey.currentState.validate()) {
      Navigator.pop(context, pwController.text);
    }
  }

  Widget buildForm(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextFormField(
            controller: pwController,
            obscureText: true,
            keyboardType: TextInputType.text,
            decoration: new InputDecoration(labelText: 'Password'),
            validator: (value) {
              if (value.isEmpty) {
                return 'Please enter a value';
              }
              return null;
            },
          ),
          TextFormField(
            controller: pw2Controller,
            obscureText: true,
            keyboardType: TextInputType.text,
            decoration: new InputDecoration(labelText: 'Password Again'),
            validator: (value) {
              if (value.isEmpty) {
                return 'Please enter a value';
              }
              if (value != pwController.text) {
                return 'Passwords must match';
              }
              return null;
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              RaisedButton.icon(
                  onPressed: () { Navigator.pop(context); },
                  icon: Icon(Icons.cancel),
                  label: Text('Cancel')),
              RaisedButton.icon(
                  onPressed: submit,
                  icon: Icon(Icons.lock),
                  label: Text('Submit')),
            ]
          ),
        ],
      ),
    );
  }

  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Create password to protect your mnemonic"),
        content: buildForm(context),
      );
    },
  );
}

Future<String> askMnemonicPassword(BuildContext context) async {
  final formKey = GlobalKey<FormState>();
  final pwController = new TextEditingController();

  void submit() {
    if (formKey.currentState.validate()) {
      Navigator.pop(context, pwController.text);
    }
  }

  Widget buildForm(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextFormField(
            controller: pwController,
            obscureText: true,
            keyboardType: TextInputType.text,
            decoration: new InputDecoration(labelText: 'Password'),
            validator: (value) {
              if (value.isEmpty) {
                return 'Please enter a value';
              }
              return null;
            },
          ),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                RaisedButton.icon(
                    onPressed: () { Navigator.pop(context); },
                    icon: Icon(Icons.cancel),
                    label: Text('Cancel')),
                RaisedButton.icon(
                    onPressed: submit,
                    icon: Icon(Icons.lock),
                    label: Text('Submit')),
              ]
          ),
        ],
      ),
    );
  }

  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Enter password to decrypt your mnemonic"),
        content: buildForm(context),
      );
    },
  );
}

Future<bool> askInvalidMnemonicOk(BuildContext context) async {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Mnemonic is not valid, is this ok?"),
        content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              RaisedButton.icon(
                  onPressed: () { Navigator.pop(context, false); },
                  icon: Icon(Icons.cancel),
                  label: Text('No')),
              RaisedButton.icon(
                  onPressed: () { Navigator.pop(context, true); },
                  icon: Icon(Icons.check),
                  label: Text('Yes')),
            ]
          ),
      );
    },
  );
}

class EncryptedMnemonic {
  String encryptedMnemonic;
  String iv;
  EncryptedMnemonic(this.encryptedMnemonic, this.iv);
}

Key padKey256(Key key) {
  var bytes = List<int>();
  for (var byte in key.bytes)
    bytes.add(byte);
  while (bytes.length < 256/8)
    bytes.add(0);
  return Key(Uint8List.fromList(bytes));
}

EncryptedMnemonic encryptMnemonic(String mnemonic, String password) {
  final key = padKey256(Key.fromUtf8(password));
  final random = Random.secure();
  final ivData = Uint8List.fromList(List<int>.generate(16, (i) => random.nextInt(256)));
  final iv = IV(ivData);

  final encrypter = Encrypter(AES(key));
  final encrypted = encrypter.encrypt(mnemonic, iv: iv);

  return EncryptedMnemonic(encrypted.base64, iv.base64);
}

String decryptMnemonic(String encryptedMnemonicBase64, String ivBase64, String password) {
  final key = padKey256(Key.fromUtf8(password));
  final iv = IV.fromBase64(ivBase64);

  final encrypter = Encrypter(AES(key));
  try {
    return encrypter.decrypt64(encryptedMnemonicBase64, iv: iv);
  }
  catch (ex) {
    return null;
  }
}

const String _bitcoinAlphabet =
    "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
String base58decode(String input) {
  Base58Codec codec = const Base58Codec(_bitcoinAlphabet);
  var decoded = codec.decode(input);
  return String.fromCharCodes(decoded);
}