package com.arianesline.mnemolink;

import com.fazecast.jSerialComm.SerialPort;

import java.io.IOException;
import java.time.LocalDateTime;

public class MnemoLinkLauncher {


    public static void main(String[] args) throws IOException {


        SerialPort[] ports = SerialPort.getCommPorts();
        if (ports.length >= 0) {

            for (SerialPort port : ports) {
                if (port.getDescriptivePortName().contains("USB Serial Device") || port.getDescriptivePortName().contains("USB Serial Port") || port.getDescriptivePortName().contains("MNemo") || port.getDescriptivePortName().contains("MCP2221") || port.getSystemPortName().contains("tty.usbmodem")) {
                    SerialPort comPort = port;
                    comPort.openPort();
                    comPort.setBaudRate(9600);

                    var command = "connection";
                    var commandnl = command + '\n';
                    comPort.writeBytes(commandnl.getBytes(), commandnl.length());

                    comPort.closePort();
                }
            }
            //  writeTimeOndevice();
        }

        ProcessBuilder builder = new ProcessBuilder("./Release/mnemolink.exe");
        builder.start();
    }


}
