import 'package:flutter/material.dart';

class SettingCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String subtitle;
  final Widget actionWidget;
  final bool locked;

  const SettingCard(
      {this.name = "",
      this.subtitle = "",
      this.icon = Icons.add,
      this.actionWidget = const Text("Action"),
      this.locked = false});

  @override
  Widget build(BuildContext context) {
    return Card(
        child: Container(
          color: (locked) ?Colors.black12:Colors.transparent,
      padding: const EdgeInsets.fromLTRB(20, 10, 0, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: Icon(icon),
            title: Text(name),
            subtitle: Text(subtitle),
          ),
          (locked)
              ? const Text("")
              : Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[actionWidget],
                ),
        ],
      ),
    ));
  }
}

class SettingActionButton extends StatelessWidget {
  final String actionText;
  final void Function() callback;

  const SettingActionButton(this.actionText, this.callback);

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: callback,
      child: Text(actionText),
    );
  }
}

class SettingWifiActionButton extends StatelessWidget {
  final String actionText;
  final void Function(String e, String f) callback;

  const SettingWifiActionButton(this.actionText, this.callback);

  @override
  Widget build(BuildContext context) {
    TextEditingController controllerName = TextEditingController();
    TextEditingController controllerPasswd = TextEditingController();

    return Container(
      padding: const EdgeInsets.only(left: 100),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            child: Text(actionText),
            onPressed: () => callback(
                controllerName.value.text, controllerPasswd.value.text),
          ),
          Container(
            padding: const EdgeInsets.only(left: 20),
            width: 200,
            height: 80,
            child: TextFormField(
              controller: controllerName,
              decoration: const InputDecoration(
                labelText: "Name",
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 20),
            width: 200,
            height: 80,
            child: TextFormField(
              controller: controllerPasswd,
              decoration: const InputDecoration(
                labelText: "Password",
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingActionRadioList extends StatelessWidget {
  final String actionText;
  final Map<String, int> actionMap;
  final void Function(int? i)? callback;
  final int selectedValue;

  const SettingActionRadioList(
      this.actionText, this.actionMap, this.callback, this.selectedValue);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: actionMap.keys
          .map((String k) => Row(
                children: [
                  Radio<int>(
                    key: null,
                    groupValue: selectedValue,
                    value: actionMap.putIfAbsent(k, () => 0),
                    onChanged: callback,
                  ),
                  Text(k),
                ],
              ))
          .toList(),
    );
  }
}

class SettingWifiList extends StatelessWidget {
  final List<String> wifiNets;
  final void Function(String? i)? callback;

  const SettingWifiList(this.wifiNets, this.callback);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: wifiNets
          .map((String k) => Row(
                children: [
                  IconButton(
                    onPressed: () {
                      callback!(k);
                    },
                    icon: const Icon(Icons.delete),
                  ),
                  Text(k),
                ],
              ))
          .toList(),
    );
  }
}
