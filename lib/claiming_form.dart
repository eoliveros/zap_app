import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flushbar/flushbar.dart';
import 'package:decimal/decimal.dart';

import 'libzap.dart';
import 'qrwidget.dart';
import 'merchant.dart';
import 'sending_form.dart';

class ClaimingForm extends StatefulWidget {
  final Decimal _amountDec;
  final String _seed;
  final int _amount;
  final int _fee;
  final String _attachment;

  ClaimingForm(this._amountDec, this._seed, this._amount, this._fee, this._attachment) : super();

  @override
  ClaimingFormState createState() {
    return ClaimingFormState();
  }
}

class ClaimingFormState extends State<ClaimingForm> {
  bool _init = false;
  bool _checking = true;
  String _uri;
  Timer _timer;
  ClaimCode _claimCode = ClaimCode(amount: Decimal.fromInt(0), token: "", secret: "");

  Future check(Timer timer) async {
    if (!_checking || !_init)
      return;
    var addr = await merchantCheck(_claimCode);
    if (addr != null) {
      _timer.cancel();
      setState(() {
       _checking = false; 
      });
      var libzap = LibZap();
      var spendTx = libzap.transactionCreate(widget._seed, addr, widget._amount, widget._fee, widget._attachment);
      if (spendTx.success) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SendingForm(spendTx)),
        );
      }
      else
        Flushbar(title: "Failed to create Tx", message: ":(", duration: Duration(seconds: 2),)
          ..show(context);
    }
  }

  @override
  void initState() {
    super.initState();
    // create claim code
    merchantRegister(widget._amountDec, widget._amount).then((value) {
      _claimCode = value;
      if (_claimCode == null) {
        setState(() {
          _checking = false;
        });
        Flushbar(title: "Failed to create claim code", message: ":(", duration: Duration(seconds: 2),)
          ..show(context);
        return;
      }
      // create uri
      var uri = claimCodeUri(_claimCode);
      setState(() {
        _uri = uri;
        _init = true;
      });
      _timer = Timer.periodic(Duration(seconds: 1), check);
    });
  }

  @override
  Widget build(BuildContext context) {
  return Material(
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children:
            <Widget>[
              Visibility(
                visible: _checking,
                child: CircularProgressIndicator(),
              ),
              Visibility(visible: _checking, child: Container(padding: const EdgeInsets.only(top: 20.0))),
              Visibility(
                visible: _init,
                child: Text(_claimCode.token),
              ),
              Visibility(
                visible: _init,
                child: QrWidget(_uri, size: 260, version: 6),
              ),
              Visibility(visible: _checking, child: Container(padding: const EdgeInsets.only(top: 20.0))),
              Visibility(
                visible: _checking && _init,
                child: Text("Waiting for customer confirmation..."),
              ),
              Visibility(visible: !_checking, child: Container(padding: const EdgeInsets.only(top: 20.0))),
              Visibility(
                  visible: !_checking,
                  child: RaisedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.close),
                      label: Text('Close'))
              ),
          ],
        ),
      ),
    );
  }
}
