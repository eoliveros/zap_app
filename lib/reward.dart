import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import 'reward_form.dart';

class RewardScreen extends StatelessWidget {
  RewardScreen(this._testnet, this._seed, this._fee, this._max) : super();

  final bool _testnet;
  final String _seed;
  final Decimal _fee;
  final Decimal _max;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Zap Reward"),
        ),
        body: new Container(
            padding: new EdgeInsets.all(20.0),
            child: RewardForm(_testnet, _seed, _fee, _max)
        )
    );
  }
}
