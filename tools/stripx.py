"""duoCo StripX (MELK-* denetleyici) şeridini Mac/PC'den Bluetooth ile kontrol eder.

Protokol: docs/PROTOCOL.md

Kullanım:
  python stripx.py tara
  python stripx.py ac | kapat
  python stripx.py renk FF0000        (ya da: renk 255 0 0)
  python stripx.py parlaklik 50       (0-100)
  python stripx.py beyaz 80 20        (sıcak, soğuk; 0-100)
  python stripx.py mod 1              (dahili efekt numarası)
  python stripx.py hiz 50             (efekt hızı, 0-100)
  python stripx.py ham 7e0404010001ff00ef
"""
import asyncio
import sys

from bleak import BleakClient, BleakScanner

YAZ = "0000fff3-0000-1000-8000-00805f9b34fb"
ON_EK = "MELK"


def ac(acik):
    v = 1 if acik else 0
    return bytes([0x7E, 0x04, 0x04, v, 0x00, v, 0xFF, 0x00, 0xEF])


def renk(r, g, b):
    return bytes([0x7E, 0x07, 0x05, 0x03, r, g, b, 0x10, 0xEF])


def parlaklik(p):
    return bytes([0x7E, 0x04, 0x01, p, 0xFF, 0xFF, 0xFF, 0x00, 0xEF])


def beyaz(sicak, soguk):
    return bytes([0x7E, 0x06, 0x05, 0x02, sicak, soguk, 0xFF, 0x08, 0xEF])


def mod(n):
    return bytes([0x7E, 0x05, 0x03, n, 0x06, 0xFF, 0xFF, 0x00, 0xEF])


def hiz(n):
    return bytes([0x7E, 0x04, 0x02, n, 0xFF, 0xFF, 0xFF, 0x00, 0xEF])


async def bul():
    cihaz = await BleakScanner.find_device_by_filter(
        lambda d, ad: bool(d.name and d.name.startswith(ON_EK)), timeout=10
    )
    if not cihaz:
        sys.exit("Şerit bulunamadı. Fişte mi, telefondaki uygulama bağlı mı? (Bağlıyken görünmez.)")
    return cihaz


async def gonder(veri):
    cihaz = await bul()
    async with BleakClient(cihaz) as c:
        await c.write_gatt_char(YAZ, veri, response=False)
        await asyncio.sleep(0.2)
    print(f"{cihaz.name}: {veri.hex()}")


def hex_renk(args):
    if len(args) == 1:
        h = args[0].lstrip("#")
        return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return tuple(int(x) for x in args[:3])


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    k, a = sys.argv[1], sys.argv[2:]
    if k == "tara":
        d = asyncio.run(bul())
        print(d.name, d.address)
        return
    veri = {
        "ac": lambda: ac(True),
        "kapat": lambda: ac(False),
        "renk": lambda: renk(*hex_renk(a)),
        "parlaklik": lambda: parlaklik(int(a[0])),
        "beyaz": lambda: beyaz(int(a[0]), int(a[1])),
        "mod": lambda: mod(int(a[0])),
        "hiz": lambda: hiz(int(a[0])),
        "ham": lambda: bytes.fromhex(a[0]),
    }.get(k)
    if not veri:
        sys.exit(__doc__)
    asyncio.run(gonder(veri()))


if __name__ == "__main__":
    main()
