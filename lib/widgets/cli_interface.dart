import 'package:flutter/material.dart';

/// Command Line Interface widget for device communication
class CLIInterface extends StatelessWidget {
  final bool serialBusy;
  final List<String> cliHistory;
  final ScrollController cliScrollController;
  final Function(String) onExecuteCLICommand;
  final VoidCallback onScrollDown;

  const CLIInterface({
    super.key,
    required this.serialBusy,
    required this.cliHistory,
    required this.cliScrollController,
    required this.onExecuteCLICommand,
    required this.onScrollDown,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        // Command input bar
        AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 0, 0),
                  child: TextFormField(
                    showCursor: true,
                    onFieldSubmitted: serialBusy ? null : onExecuteCLICommand,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: "Command",
                      hintText: '[Enter Command or type help]',
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Color(0x00000000),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(4.0),
                          topRight: Radius.circular(4.0),
                        ),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Color(0x00000000),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(4.0),
                          topRight: Radius.circular(4.0),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white30,
        ),
        
        // CLI output area
        Expanded(
          child: Scaffold(
            backgroundColor: Colors.black,
            floatingActionButton: FloatingActionButton.small(
              onPressed: onScrollDown,
              child: const Icon(Icons.arrow_downward),
            ),
            body: Container(
              decoration: const BoxDecoration(color: Colors.black),
              child: ListView(
                controller: cliScrollController,
                padding: const EdgeInsets.all(20),
                shrinkWrap: true,
                scrollDirection: Axis.vertical,
                children: cliHistory
                    .where((e) => e.length >= 2)
                    .map((e) => _buildCLIHistoryItem(e))
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCLIHistoryItem(String historyItem) {
    final prefix = historyItem.substring(0, 2);
    final content = historyItem.substring(2);
    
    Color textColor;
    switch (prefix) {
      case "a:": // Answer
        textColor = Colors.white70;
        break;
      case "c:": // Command
        textColor = Colors.yellow;
        break;
      default: // Error
        textColor = Colors.red;
        break;
    }

    return RichText(
      text: TextSpan(
        text: content,
        style: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }
}