# MELK BLE protocol

Notes for the Bluetooth LED controllers that advertise as `MELK-*` (MELK-OA, OB, OC, OE, OT, TX) and ship with the duoCo StripX app. Same family as the well known ELK-BLEDOM controllers.

## Connection

- Service `0000fff0-0000-1000-8000-00805f9b34fb`
- Write characteristic `0000fff3-0000-1000-8000-00805f9b34fb` (write without response)
- No pairing, no handshake, no encryption.
- The controller accepts a single connection. While the phone app is connected it stops advertising.

## Packets

Every packet is 9 bytes: `7e <len> <cmd> ... ef`.

| Command | Bytes | Notes |
|---|---|---|
| Power | `7e 04 04 VV 00 VV ff 00 ef` | `VV` = `01` on, `00` off |
| RGB color | `7e 07 05 03 RR GG BB 10 ef` | |
| Music frame | `7e 07 05 03 RR GG BB 20 ef` | What the app streams in music mode. The controller renders it through its own moving pattern. |
| Brightness | `7e 04 01 PP ff ff ff 00 ef` | `PP` 0-100 |
| Built-in mode | `7e 05 03 NN 06 ff ff 00 ef` | `NN` mode number, see `Sources/Modes.swift` |
| Mode speed | `7e 04 02 SS ff ff ff 00 ef` | `SS` 0-100 |
| White (warm/cold) | `7e 06 05 02 WW CC ff 08 ef` | CCT controllers, untested |
| Scene | `7e 05 31 NN 07 ff ff 01 ef` | Only on MELK-OC / OT, untested |
| Clock | `7e 07 83 hh mm ss dd ff ef` | untested |

## Things that did not work

Tested on a MELK-OA with an addressable strip:

- **Streaming colors from the computer flickers.** Sending color packets at 20-60 per second makes the strip flicker; each packet restarts the controller's own transition. The same happens when streaming brightness. Single packets change cleanly and instantly.
- The `20` variant does not flicker, but the controller turns it into a spinning multi-color pattern instead of a solid color.
- Other values in that byte (`00`, `01`, `30`, `80`) flicker as well, with colors rippling along the strip.

So smooth animation has to come from the built-in modes, not from the host. This app only sends single commands and keeps all transitions on screen.
