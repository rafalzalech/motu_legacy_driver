import Foundation
import IOKit

private func u16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
    UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
}

private func u32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
    UInt32(bytes[offset]) | (UInt32(bytes[offset + 1]) << 8) |
        (UInt32(bytes[offset + 2]) << 16) | (UInt32(bytes[offset + 3]) << 24)
}

private func u64(_ bytes: [UInt8], _ offset: Int) -> UInt64 {
    UInt64(u32(bytes, offset)) | (UInt64(u32(bytes, offset + 4)) << 32)
}

private func put<T: FixedWidthInteger>(_ value: T, into bytes: inout [UInt8], at offset: Int) {
    var little = value.littleEndian
    withUnsafeBytes(of: &little) { raw in
        bytes.replaceSubrange(offset..<(offset + raw.count), with: raw)
    }
}

private func callStruct(_ connection: io_connect_t,
                        selector: UInt32,
                        input: [UInt8] = [],
                        capacity: Int = 65_536) -> [UInt8]? {
    var output = [UInt8](repeating: 0, count: capacity)
    var outputSize = output.count
    let result = input.withUnsafeBytes { inputRaw in
        output.withUnsafeMutableBytes { outputRaw in
            IOConnectCallStructMethod(connection,
                                      selector,
                                      input.isEmpty ? nil : inputRaw.baseAddress,
                                      input.count,
                                      outputRaw.baseAddress,
                                      &outputSize)
        }
    }
    guard result == KERN_SUCCESS else {
        fputs(String(format: "selector %u failed: 0x%08x\n", selector,
                     UInt32(bitPattern: result)), stderr)
        return nil
    }
    return Array(output.prefix(outputSize))
}

private func cString(_ bytes: [UInt8], offset: Int, length: Int) -> String {
    let slice = bytes[offset..<(offset + length)].prefix { $0 != 0 }
    return String(decoding: slice, as: UTF8.self)
}

private func printDevices(_ connection: io_connect_t) -> UInt16? {
    print("=== ASFW discovered devices ===")
    guard let bytes = callStruct(connection, selector: 16, capacity: 4_096),
          bytes.count >= 8 else {
        print("No discovery response.")
        return nil
    }
    let count = Int(u32(bytes, 0))
    print("count=\(count)")
    var motuNode: UInt16?
    var offset = 8
    for _ in 0..<count {
        guard offset + 152 <= bytes.count else {
            print("Truncated device response.")
            return motuNode
        }
        let guid = u64(bytes, offset)
        let vendor = u32(bytes, offset + 8)
        let model = u32(bytes, offset + 12)
        let generation = u32(bytes, offset + 16)
        let node = bytes[offset + 20]
        let state = bytes[offset + 21]
        let unitCount = Int(bytes[offset + 22])
        let vendorName = cString(bytes, offset: offset + 24, length: 64)
        let modelName = cString(bytes, offset: offset + 88, length: 64)
        print(String(format: "guid=0x%016llx vendor=0x%06x model=0x%06x node=%u gen=%u state=%u name=%@ %@",
                     guid, vendor, model, node, generation, state,
                     vendorName as NSString, modelName as NSString))
        if vendor == 0x0001f2 {
            motuNode = UInt16(node)
        }
        offset += 152
        for unitIndex in 0..<unitCount {
            guard offset + 160 <= bytes.count else {
                print("Truncated unit response.")
                return motuNode
            }
            let specifier = u32(bytes, offset)
            let version = u32(bytes, offset + 4)
            let unitState = bytes[offset + 12]
            let unitVendor = cString(bytes, offset: offset + 32, length: 64)
            let product = cString(bytes, offset: offset + 96, length: 64)
            print(String(format: "  unit=%d specifier=0x%06x version=0x%06x state=%u name=%@ %@",
                         unitIndex, specifier, version, unitState,
                         unitVendor as NSString, product as NSString))
            offset += 160
        }
    }
    return motuNode
}

private func readQuadlet(_ connection: io_connect_t,
                         node: UInt16,
                         address: UInt64) -> UInt32? {
    var input: [UInt64] = [
        UInt64(node),
        (address >> 32) & 0xffff,
        address & 0xffff_ffff,
        4
    ]
    var handle: UInt64 = 0
    var handleCount: UInt32 = 1
    let issue = input.withUnsafeMutableBufferPointer { ptr in
        IOConnectCallScalarMethod(connection, 8, ptr.baseAddress,
                                  UInt32(ptr.count), &handle, &handleCount)
    }
    guard issue == KERN_SUCCESS else {
        fputs(String(format: "read issue failed at 0x%012llx: 0x%08x\n",
                     address, UInt32(bitPattern: issue)), stderr)
        return nil
    }

    let deadline = Date().addingTimeInterval(2)
    while Date() < deadline {
        var scalarInput: [UInt64] = [handle]
        var scalarOutput: [UInt64] = [0, 0, 0]
        var scalarOutputCount: UInt32 = 3
        var payload = [UInt8](repeating: 0, count: 4)
        var payloadSize = payload.count
        let result = scalarInput.withUnsafeMutableBufferPointer { inPtr in
            scalarOutput.withUnsafeMutableBufferPointer { outPtr in
                payload.withUnsafeMutableBytes { payloadPtr in
                    IOConnectCallMethod(connection, 12,
                                        inPtr.baseAddress, UInt32(inPtr.count),
                                        nil, 0,
                                        outPtr.baseAddress, &scalarOutputCount,
                                        payloadPtr.baseAddress, &payloadSize)
                }
            }
        }
        if result == KERN_SUCCESS {
            guard scalarOutput[0] == 0, scalarOutput[2] == 0,
                  payloadSize == 4 else {
                fputs(String(format: "read transaction failed at 0x%012llx: status=%llu rcode=%llu len=%d\n",
                             address, scalarOutput[0], scalarOutput[2], payloadSize), stderr)
                return nil
            }
            return (UInt32(payload[0]) << 24) | (UInt32(payload[1]) << 16) |
                   (UInt32(payload[2]) << 8) | UInt32(payload[3])
        }
        if result != kIOReturnNotFound {
            fputs(String(format: "read result failed at 0x%012llx: 0x%08x\n",
                         address, UInt32(bitPattern: result)), stderr)
            return nil
        }
        Thread.sleep(forTimeInterval: 0.05)
    }
    fputs(String(format: "read timed out at 0x%012llx\n", address), stderr)
    return nil
}

private func printMotuRegisters(_ connection: io_connect_t, node: UInt16) {
    print("\n=== MOTU read-only register snapshot ===")
    let base: UInt64 = 0xffff_f000_0000
    let registers: [(String, UInt64)] = [
        ("iso_comm", 0x0b00),
        ("packet_format", 0x0b10),
        ("clock_status", 0x0b14),
        ("input_output_config", 0x0c04)
    ]
    for (name, offset) in registers {
        if let value = readQuadlet(connection, node: node, address: base + offset) {
            print(String(format: "%@ [0x%04llx] = 0x%08x",
                         name as NSString, offset, value))
        }
    }
}

private func printFilteredLogs(_ connection: io_connect_t,
                               title: String,
                               filter: String,
                               lookback: UInt64 = 100) {
    print("\n=== \(title) ===")
    var request = [UInt8](repeating: 0, count: 72)
    if let stats = callStruct(connection, selector: 1012, capacity: 4_096),
       stats.count >= 16 {
        let latest = u64(stats, 8)
        put(latest > lookback ? latest - lookback : 0, into: &request, at: 0)
    }
    put(UInt32.max, into: &request, at: 8) // every category
    put(UInt32(4), into: &request, at: 12) // through debug
    put(UInt32(500), into: &request, at: 16)
    for (index, byte) in Array(filter.utf8.prefix(47)).enumerated() {
        request[24 + index] = byte
    }

    guard let bytes = callStruct(connection, selector: 1011,
                                 input: request, capacity: 4_096),
          bytes.count >= 40 else {
        print("No log response.")
        return
    }
    let recordCount = Int(u32(bytes, 0))
    let latestSequence = u64(bytes, 16)
    print("matching_records=\(recordCount) latest_sequence=\(latestSequence)")
    var offset = 40
    for _ in 0..<recordCount {
        guard offset + 20 <= bytes.count else { break }
        let sequence = u64(bytes, offset)
        let category = bytes[offset + 16]
        let level = bytes[offset + 17]
        let messageLength = Int(u16(bytes, offset + 18))
        let messageStart = offset + 20
        guard messageStart + messageLength <= bytes.count else { break }
        let message = String(decoding: bytes[messageStart..<(messageStart + messageLength)],
                             as: UTF8.self)
        print("[\(sequence)] category=\(category) level=\(level) \(message)")
        offset = messageStart + messageLength
    }
}

guard let matching = IOServiceNameMatching("ASFWDriver") else {
    fatalError("Could not create ASFW service match")
}
let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
guard service != 0 else {
    fatalError("ASFWDriver service is not present")
}
defer { IOObjectRelease(service) }

var connection: io_connect_t = 0
let openResult = IOServiceOpen(service, mach_task_self_, 0, &connection)
guard openResult == KERN_SUCCESS else {
    fatalError(String(format: "Could not open ASFWDriver: 0x%08x",
                      UInt32(bitPattern: openResult)))
}
defer { IOServiceClose(connection) }

let motuNode = printDevices(connection)
if let motuNode {
    printMotuRegisters(connection, node: motuNode)
}
printFilteredLogs(connection, title: "MOTU/Core Audio driver log", filter: "Audio")
printFilteredLogs(connection, title: "Preferred stereo graph log", filter: "Preferred stereo",
                  lookback: 1_000)
printFilteredLogs(connection, title: "Preferred stereo ADK result", filter: "SetPreferredChannels",
                  lookback: 1_000)
printFilteredLogs(connection, title: "Core Audio stream-start log", filter: "Start",
                  lookback: 1_000)
printFilteredLogs(connection, title: "Transmit fatal log", filter: "TxProducerFatal",
                  lookback: 1_000)
printFilteredLogs(connection, title: "Transmit alignment log", filter: "TxAlign",
                  lookback: 1_000)
printFilteredLogs(connection, title: "Core Audio stop counters", filter: "STOPIO",
                  lookback: 1_000)
printFilteredLogs(connection, title: "Playback payload stop counters", filter: "STOPPAYLOAD",
                  lookback: 1_000)
printFilteredLogs(connection, title: "Payload writer anomalies", filter: "PayloadWriter",
                  lookback: 1_000)
printFilteredLogs(connection, title: "Payload writer counters", filter: "ADK writer",
                  lookback: 1_000)
printFilteredLogs(connection, title: "Transmit packet counters", filter: "snapshot/tx",
                  lookback: 1_000)
printFilteredLogs(connection, title: "Duplex lifecycle log", filter: "FSM",
                  lookback: 1_000)
printFilteredLogs(connection, title: "UltraLite direct-bus fallback log", filter: "no IRM",
                  lookback: 1_000)
printFilteredLogs(connection, title: "Isochronous resource manager log", filter: "IRM",
                  lookback: 1_000)
printFilteredLogs(connection, title: "Device classification log", filter: "Device upsert")
