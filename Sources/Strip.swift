import CoreBluetooth
import Observation
import QuartzCore
import SwiftUI

/// MELK-* denetleyicinin paketleri (bkz. docs/PROTOCOL.md).
enum Packet {
    static func power(_ on: Bool) -> Data {
        let v: UInt8 = on ? 1 : 0
        return Data([0x7E, 0x04, 0x04, v, 0x00, v, 0xFF, 0x00, 0xEF])
    }
    /// Tek paketle anında değişir. Bu çip art arda hızlı gelen paketlerde titrer, akıcı animasyon çipin kendi modlarından.
    static func color(_ c: RGB) -> Data {
        let (r, g, b) = c.ledBytes
        return Data([0x7E, 0x07, 0x05, 0x03, r, g, b, 0x10, 0xEF])
    }
    static func brightness(_ p: Int) -> Data { Data([0x7E, 0x04, 0x01, UInt8(clamping: p), 0xFF, 0xFF, 0xFF, 0x00, 0xEF]) }
    static func mode(_ m: Int) -> Data { Data([0x7E, 0x05, 0x03, UInt8(clamping: m), 0x06, 0xFF, 0xFF, 0x00, 0xEF]) }
    static func speed(_ s: Int) -> Data { Data([0x7E, 0x04, 0x02, UInt8(clamping: s), 0xFF, 0xFF, 0xFF, 0x00, 0xEF]) }
}

enum Source: Equatable {
    case solid
    case hardware(Int)

    var key: String {
        switch self {
        case .solid: "solid"
        case .hardware(let m): "hw:\(m)"
        }
    }

    init(key: String) {
        let p = key.split(separator: ":").map(String.init)
        if p.first == "hw", p.count == 2, let m = Int(p[1]) { self = .hardware(m) } else { self = .solid }
    }
}

enum Link: Equatable {
    case bluetoothOff, unauthorized, scanning, connecting, connected(String)
}

/// Şeride sadece tek tek komut gider (renk, mod, parlaklık); akıcı animasyonu çipin kendi modları yapar.
/// Paneldeki önizleme ve renk geçişleri yalnızca ekranda canlandırılır.
@Observable
final class StripController: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var link: Link = .scanning
    private(set) var isOn: Bool
    private(set) var hue: Double
    private(set) var saturation: Double
    private(set) var brightness: Double
    private(set) var source: Source
    private(set) var hwSpeed: Double
    /// Panelde gösterilen şerit rengi (önizleme, 30 fps).
    private(set) var liveColor: RGB = .black
    /// Menü ikonu ve ortam ışığı için seyrek güncellenen renk.
    private(set) var iconColor: RGB

    var baseColor: RGB { .hsv(hue, saturation, 1) }
    var isConnected: Bool { if case .connected = link { true } else { false } }

    var statusText: String {
        switch link {
        case .bluetoothOff: "Bluetooth kapalı"
        case .unauthorized: "Bluetooth izni yok"
        case .scanning: "Şerit aranıyor…"
        case .connecting: "Bağlanıyor…"
        case .connected(let n): n
        }
    }

    @ObservationIgnored private var central: CBCentralManager!
    @ObservationIgnored private var peripheral: CBPeripheral?
    @ObservationIgnored private var writeChar: CBCharacteristic?
    @ObservationIgnored private var deviceName = "Şerit"
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var fade: Fade?
    @ObservationIgnored private var queue: [Data] = []
    @ObservationIgnored private var pendingColor: RGB?
    @ObservationIgnored private var pendingBrightness: Int?
    @ObservationIgnored private var pendingSpeed: Int?
    @ObservationIgnored private var lastColorSend: Double = 0
    @ObservationIgnored private var lastBrightnessSend: Double = 0
    @ObservationIgnored private var lastSpeedSend: Double = 0
    @ObservationIgnored private var frame = 0
    @ObservationIgnored private let defaults = UserDefaults.standard

    /// Sürüklerken iki paket arası en kısa süre: daha sık gelince çip titriyor.
    private static let dragInterval = 0.1

    private struct Fade {
        var from: RGB
        var start: Double
        var duration: Double
    }

    private static let service = CBUUID(string: "FFF0")
    private static let writeUUID = CBUUID(string: "FFF3")

    override init() {
        let d = UserDefaults.standard
        d.register(defaults: ["isOn": true, "hue": 0.76, "saturation": 1.0, "brightness": 100.0,
                              "source": "solid", "hwSpeed": 50.0])
        isOn = d.bool(forKey: "isOn")
        hue = d.double(forKey: "hue")
        saturation = d.double(forKey: "saturation")
        brightness = d.double(forKey: "brightness")
        source = Source(key: d.string(forKey: "source") ?? "solid")
        hwSpeed = d.double(forKey: "hwSpeed")
        iconColor = .hsv(d.double(forKey: "hue"), d.double(forKey: "saturation"), 1)
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: Eylemler

    func togglePower() { setPower(!isOn) }

    func setPower(_ on: Bool) {
        guard on != isOn else { return }
        startFade(on ? 0.9 : 0.6)
        isOn = on
        enqueue(Packet.power(on))
        if on {
            switch source {
            case .solid: enqueue(Packet.color(baseColor))
            case .hardware(let m): enqueue(Packet.mode(m))
            }
        }
        save()
    }

    /// smooth: hazır renge tıklama (ekranda uzun geçiş); sürüklerken kısa takip.
    func pickColor(hue h: Double, saturation s: Double, smooth: Bool) {
        startFade(smooth || source != .solid ? 0.7 : 0.1)
        hue = h
        saturation = s
        source = .solid
        if isOn {
            pendingColor = baseColor
        } else {
            setPower(true)
        }
        save()
    }

    func startHardware(_ m: Int) {
        startFade(0.6)
        source = .hardware(m)
        pendingColor = nil
        if !isOn {
            isOn = true
            enqueue(Packet.power(true))
        }
        enqueue(Packet.mode(m))
        pendingSpeed = Int(hwSpeed.rounded())
        save()
    }

    func setBrightness(_ v: Double) {
        brightness = v
        pendingBrightness = Int(v.rounded())
        save()
    }

    func setHWSpeed(_ v: Double) {
        hwSpeed = v
        pendingSpeed = Int(v.rounded())
        save()
    }

    // MARK: Önizleme ve gönderim

    private func startFade(_ d: Double) {
        fade = Fade(from: liveColor, start: CACurrentMediaTime(), duration: d)
    }

    /// Ekrandaki şeridin o anki rengi: düz renk ya da çipteki modun yaklaşık önizlemesi.
    private func previewColor(_ now: Double) -> RGB {
        guard isOn else { return .black }
        switch source {
        case .solid: return baseColor
        case .hardware(let m):
            let t = now * (0.3 + hwSpeed / 50)
            return EffectKind.forMode(m)?.color(t) ?? .hsv(t / 8, 1, 1)
        }
    }

    private func tick() {
        let now = CACurrentMediaTime()
        frame += 1
        var out = previewColor(now)
        if let f = fade {
            let p = min(1, (now - f.start) / f.duration)
            out = f.from.mix(out, p < 0.5 ? 4 * p * p * p : 1 - pow(-2 * p + 2, 3) / 2)
            if p >= 1 { fade = nil }
        }
        if out != liveColor { liveColor = out }
        if frame % 15 == 0 || fade != nil, isOn, out.distance(iconColor) > 0.02 { iconColor = out }
        flush(now)
    }

    private func flush(_ now: Double) {
        guard let p = peripheral, let c = writeChar, isConnected else { return }
        func send(_ d: Data) -> Bool {
            guard p.canSendWriteWithoutResponse else { return false }
            p.writeValue(d, for: c, type: .withoutResponse)
            return true
        }
        while let d = queue.first, send(d) { queue.removeFirst() }
        if let col = pendingColor, now - lastColorSend >= Self.dragInterval, send(Packet.color(col)) {
            pendingColor = nil
            lastColorSend = now
        }
        if let b = pendingBrightness, now - lastBrightnessSend >= Self.dragInterval, send(Packet.brightness(b)) {
            pendingBrightness = nil
            lastBrightnessSend = now
        }
        if let s = pendingSpeed, now - lastSpeedSend >= Self.dragInterval, send(Packet.speed(s)) {
            pendingSpeed = nil
            lastSpeedSend = now
        }
    }

    private func enqueue(_ d: Data) { queue.append(d) }

    private func save() {
        defaults.set(isOn, forKey: "isOn")
        defaults.set(hue, forKey: "hue")
        defaults.set(saturation, forKey: "saturation")
        defaults.set(brightness, forKey: "brightness")
        defaults.set(source.key, forKey: "source")
        defaults.set(hwSpeed, forKey: "hwSpeed")
    }

    // MARK: Bluetooth

    private func connectOrScan() {
        guard central.state == .poweredOn else { return }
        if peripheral == nil, let s = defaults.string(forKey: "peripheral"), let id = UUID(uuidString: s),
           let p = central.retrievePeripherals(withIdentifiers: [id]).first {
            adopt(p)
        }
        if let p = peripheral {
            link = .connecting
            central.connect(p)
        } else {
            link = .scanning
        }
        central.scanForPeripherals(withServices: nil)
    }

    private func adopt(_ p: CBPeripheral) {
        peripheral = p
        p.delegate = self
        if let n = p.name { deviceName = n }
    }

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        switch c.state {
        case .poweredOn: connectOrScan()
        case .unauthorized: link = .unauthorized
        default: link = .bluetoothOff
        }
    }

    func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral,
                        advertisementData ad: [String: Any], rssi: NSNumber) {
        let name = (ad[CBAdvertisementDataLocalNameKey] as? String) ?? p.name ?? ""
        guard name.hasPrefix("MELK") else { return }
        c.stopScan()
        adopt(p)
        deviceName = name
        link = .connecting
        c.connect(p)
    }

    func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        c.stopScan()
        p.discoverServices([Self.service])
    }

    func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) { retry() }

    func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) { retry() }

    private func retry() {
        writeChar = nil
        link = .scanning
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.connectOrScan() }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        for s in p.services ?? [] where s.uuid == Self.service {
            p.discoverCharacteristics([Self.writeUUID], for: s)
        }
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        guard let c = s.characteristics?.first(where: { $0.uuid == Self.writeUUID }) else { return }
        writeChar = c
        defaults.set(p.identifier.uuidString, forKey: "peripheral")
        let short = deviceName.split(separator: " ").first.map(String.init) ?? deviceName
        link = .connected(short)
    }
}
