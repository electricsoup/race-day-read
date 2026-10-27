//
//  ICSExporter.swift
//  Race Day Ready
//
//  Turns a shot list into an .ics calendar file. Timed shots become timed events in the
//  trip's time zone (so a 5:00 AM corral shot is 5:00 AM in Florida, wherever you open it);
//  shots without a time become all-day events on their day.
//

import Foundation

enum ICSExporter {
    static func calendarText(trip: Trip, shots: [Shot]) -> String {
        var lines: [String] = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Race Day Ready//Shot List//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            "X-WR-CALNAME:" + escape(trip.displayName + " shot list")
        ]
        let stamp = utcStamp(Date())
        for shot in shots {
            guard let day = shot.dayKey, DayKey.date(day) != nil else { continue }
            lines.append("BEGIN:VEVENT")
            lines.append("UID:" + (shot.uuid?.uuidString ?? UUID().uuidString) + "@racedayready")
            lines.append("DTSTAMP:" + stamp)
            if let time = shot.time, let start = instant(day: day, time: time, in: trip.timeZone) {
                let minutes = max(5, Int(shot.durationMin == 0 ? 15 : shot.durationMin))
                lines.append("DTSTART:" + utcStamp(start))
                lines.append("DTEND:" + utcStamp(start.addingTimeInterval(TimeInterval(minutes * 60))))
            } else {
                lines.append("DTSTART;VALUE=DATE:" + day.replacingOccurrences(of: "-", with: ""))
                lines.append("DTEND;VALUE=DATE:" + DayKey.add(day, days: 1).replacingOccurrences(of: "-", with: ""))
            }
            lines.append("SUMMARY:" + escape("🎬 " + (shot.title ?? "Shot")))
            if let loc = shot.location, !loc.isEmpty { lines.append("LOCATION:" + escape(loc)) }
            lines.append("DESCRIPTION:" + escape(description(for: shot, trip: trip)))
            lines.append("END:VEVENT")
        }
        lines.append("END:VCALENDAR")
        return lines.map(fold).joined(separator: "\r\n") + "\r\n"
    }

    /// Writes the calendar to a temporary file the share sheet can hand to Calendar, Mail, AirDrop, etc.
    static func exportFile(trip: Trip, shots: [Shot], suffix: String = "") throws -> URL {
        let safeName = trip.displayName.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName)\(suffix)-shots.ics")
        try calendarText(trip: trip, shots: shots).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func description(for shot: Shot, trip: Trip) -> String {
        var parts: [String] = []
        if let hook = shot.hook, !hook.isEmpty { parts.append("Hook: " + hook) }
        if let sound = shot.sound, !sound.isEmpty { parts.append("Sound: " + sound) }
        if let how = shot.howTo, !how.isEmpty { parts.append("How: " + how) }
        if let outfit = shot.outfit {
            var line = "Outfit: " + outfit.displayTitle
            let pieces = outfit.itemList.compactMap { $0.text }
            if !pieces.isEmpty { line += " (" + pieces.joined(separator: ", ") + ")" }
            parts.append(line)
        }
        if let w = shot.whoKey, !w.isEmpty, w != Who.shared { parts.append("Who: " + trip.whoLabel(w)) }
        if let p = shot.platform, !p.isEmpty { parts.append("For: " + Platform.label(p)) }
        if let note = shot.note, !note.isEmpty { parts.append(note) }
        return parts.joined(separator: "\n")
    }

    static func instant(day: String, time: String, in zone: TimeZone) -> Date? {
        let d = day.split(separator: "-").compactMap { Int($0) }
        let t = time.split(separator: ":").compactMap { Int($0) }
        guard d.count == 3, t.count == 2 else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        return cal.date(from: DateComponents(year: d[0], month: d[1], day: d[2], hour: t[0], minute: t[1]))
    }

    private static func utcStamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return f.string(from: date)
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    /// Calendar lines must be at most 75 bytes; longer ones continue on the next line after a space.
    static func fold(_ line: String) -> String {
        var out = ""
        var count = 0
        for ch in line {
            let size = String(ch).utf8.count
            if count + size > 74 {
                out += "\r\n "
                count = 1
            }
            out.append(ch)
            count += size
        }
        return out
    }
}
