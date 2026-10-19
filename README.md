# Şerit

A macOS menu bar app for Bluetooth LED strips that use the **duoCo StripX** app (controllers that show up as `MELK-*`).

I didn't want to pick up my phone every time I changed the color of the strip on my desk, so I figured out the protocol and wrote this.

The UI is in Turkish (*şerit* means strip).

## Features

- Color wheel and presets
- 12 hand-picked effects plus all ~200 built-in modes of the controller, grouped
- Brightness and effect speed
- Auto-connects to the strip, reconnects when it drops
- Menu bar icon follows the strip color
- Launch at login

The animations run on the controller itself, so they are smooth. See [docs/PROTOCOL.md](docs/PROTOCOL.md) for why the app doesn't stream colors.

## Requirements

- macOS 26 (Tahoe) on Apple Silicon
- Xcode 26 or newer, only for building (tested with Xcode 27)

## Build

```sh
./build.sh
open ~/Applications/Şerit.app
```

On first launch macOS asks for Bluetooth permission. Close the duoCo app on your phone first; the controller only accepts one connection.

## Command line

`tools/stripx.py` does the same over the terminal (needs `pip install bleak`):

```sh
python3 tools/stripx.py renk FF0000     # color
python3 tools/stripx.py parlaklik 40     # brightness
python3 tools/stripx.py mod 199          # built-in mode
python3 tools/stripx.py kapat            # off (ac = on)
```

## Supported devices

Tested with a MELK-OA21. Other `MELK-*` controllers should work for color, power, brightness and modes. Scenes and the built-in microphone are not supported yet.

## License

MIT
