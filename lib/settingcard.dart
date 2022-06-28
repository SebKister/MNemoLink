import 'package:flutter/material.dart';
import 'package:flutter/material.dart';

class SettingCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String subtitle;
  final Widget actionWidget;

  const SettingCard(
      {this.name = "",
      this.subtitle = "",
      this.icon = Icons.add,
      this.actionWidget = const Text("Action")});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: Icon(icon),
            title: Text(name),
            subtitle: Text(subtitle),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[actionWidget],
          ),
        ],
      ),
    );
  }
}

class SettingActionButton extends StatelessWidget {
  final String actionText;
  final void Function() callback;

  const SettingActionButton(this.actionText, this.callback);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      child: Text(actionText),
      onPressed: callback,
    );
  }
}

class SettingActionRadioList extends StatelessWidget {
  final String actionText;
  final Map<String, int> actionmap;
  final void Function(int? i)? callback;

  const SettingActionRadioList(this.actionText, this.actionmap, this.callback);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: actionmap.keys
          .map((String k) => Radio<int>(
              key: null,
              groupValue: 2,
              value: actionmap.putIfAbsent(k, () => 0),
              onChanged: callback))
          .toList(),
    );
  }
}
