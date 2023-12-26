import 'package:flutter/material.dart';

class SettingCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String subtitle;
  final Widget actionWidget;
  final bool locked;

  const SettingCard(
      {super.key,
      this.name = "",
      this.subtitle = "",
      this.icon = Icons.add,
      this.actionWidget = const Text("Action"),
      this.locked = false});

  @override
  Widget build(BuildContext context) {
    return Card(
        child: Container(
      color: (locked) ? Colors.black12 : Colors.transparent,
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
  final void Function()? callback;
  final double widthButton;
  final double heightButton;

  const SettingActionButton(this.actionText, this.callback,
      {super.key, this.widthButton = 0.0, this.heightButton = 0.0});

  const SettingActionButton.sized(
      this.actionText, this.callback, this.widthButton, this.heightButton,
      {super.key});

  @override
  Widget build(BuildContext context) {
    if (widthButton != 0.0 && heightButton != 0.0) {
      return SizedBox(
        height: heightButton,
        width: widthButton,
        child: TextButton(
          style: const ButtonStyle(alignment: AlignmentDirectional.centerStart),
          onPressed: callback,
          child: Text(actionText),
        ),
      );
    } else if (widthButton != 0.0) {
      return SizedBox(
        width: widthButton,
        child: TextButton(
          style: const ButtonStyle(alignment: AlignmentDirectional.centerStart),
          onPressed: callback,
          child: Text(actionText),
        ),
      );
    } else if (heightButton != 0.0) {
      return SizedBox(
        height: heightButton,
        child: TextButton(
          style: const ButtonStyle(alignment: AlignmentDirectional.centerStart),
          onPressed: callback,
          child: Text(actionText),
        ),
      );
    } else {
      return TextButton(
        onPressed: callback,
        child: Text(actionText),
      );
    }
  }
}

class SettingWifiActionButton extends StatelessWidget {
  final String actionText;
  final void Function(String e, String f)? callback;

  const SettingWifiActionButton(this.actionText, this.callback, {super.key});

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
            onPressed: callback == null
                ? null
                : () => callback!(
                    controllerName.value.text, controllerPasswd.value.text),
            child: Text(actionText),
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
              obscureText: true,
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
      this.actionText, this.actionMap, this.callback, this.selectedValue,
      {super.key});

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
                    value: actionMap[k]!.toInt(),
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

  const SettingWifiList(this.wifiNets, this.callback, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: wifiNets
          .map((String k) => Row(
                children: [
                  IconButton(
                    onPressed: callback == null
                        ? null
                        : () {
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
