import Foundation
import EventKit
@objc(RNCalendarEvents)
class RNCalendarEvents: NSObject {
    //#MARK: Properties
    var eventStore:EKEventStore = EKEventStore()
    //#MARK:React-Native Methods
    @objc func authorizationStatus(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        let status = EKEventStore.authorizationStatus(for: EKEntityType.event)
        switch status {
        case .authorized: resolve("authorized")
        case .denied: resolve("denied")
        case .notDetermined: resolve("undetermined")
        case .restricted: resolve("restricted")
        }
    }
    @objc func authorizeEventStore(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        eventStore.requestAccess(to: .event) { granted, error in
            if let e = error {
                reject("error", "authorization request error", e)
            } else {
                resolve(granted ? "authorized" : "denied")
            }
        }
    }
    @objc func findCalendars(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        guard EKEventStore.authorizationStatus(for: .event) == .authorized else { reject("unauthorized", "Not authorized to use calendar", nil); return }
        let out = eventStore.calendars(for: .event).map() { calendar in
            return toDic(calendar: calendar)
        }
        resolve(out)
    }
    @objc func fetchAllEvents(_ startDate: Date, endDate: Date, calendars: NSArray, resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        guard EKEventStore.authorizationStatus(for: .event) == .authorized else { reject("unauthorized", "Not authorized to use calendar", nil); return }
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: eventStore.calendars(for: .event).filter() { calendar in
            return calendars.contains(calendar.calendarIdentifier)
        });
        DispatchQueue(label:"RNCalendarEvents").async() {
            let events = self.eventStore.events(matching: predicate).sorted() { $0.compareStartDate(with: $1) == .orderedAscending }
            resolve(events.map({ toDic(event: $0)}))
        }
    }
    @objc func findEventById(_ eventId:String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard EKEventStore.authorizationStatus(for: .event) == .authorized else { reject("unauthorized", "Not authorized to use calendar", nil); return }
        DispatchQueue(label:"RNCalendarEvents").async() {
            if let e = self.eventStore.event(withIdentifier: eventId) {
                resolve(toDic(event: e))
            } else {
                reject("no_event", "Did not find event " + eventId, nil)
            }
        }
    }
    @objc func saveEvent(_ title: String, settings: [String: Any], options: [String: Any], resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        guard EKEventStore.authorizationStatus(for: .event) == .authorized else { reject("unauthorized", "Not authorized to use calendar", nil); return }
        var e:EKEvent
        if let s = settings["calendarId"] as? String {
            guard let event = eventStore.event(withIdentifier: s) else {reject("no_event", "Did not find event " + s, nil); return }
            e = event
        } else {
            e = EKEvent(eventStore: eventStore)
            if let s = settings["calendarId"] as? String, let c = eventStore.calendar(withIdentifier: s) { e.calendar = c }
            else { e.calendar = eventStore.defaultCalendarForNewEvents }
            e.timeZone = TimeZone.current
        }
        e.title = title
        if let s = settings["location"] as? String { e.location = s }
        if let d = options["exceptionDate"] { e.startDate = RCTConvert.nsDate(d) }
        else if let d = settings["startDate"] { e.startDate = RCTConvert.nsDate(d) }
        if let d = settings["endDate"]  { e.endDate = RCTConvert.nsDate(d) }
        if let b = settings["allDay"] as? Bool { e.isAllDay = b }
        if let s = settings["notes"] as? String { e.notes = s }
        if let s = settings["url"] as? String { e.url = URL(string: s)}
        if let a = settings["alarms"] as? [[String:Any]] { e.alarms = a.map{
            var alarm: EKAlarm
            if let d = $0["date"]  { alarm = EKAlarm(absoluteDate: RCTConvert.nsDate(d)) }
            else if let i = $0["date"] as? Double { alarm = EKAlarm(relativeOffset: i)}
            else { alarm = EKAlarm() }
            if let d = $0["structuredLocation"] as? [String:Any] , let s = d["title"] as? String {
                alarm.structuredLocation = EKStructuredLocation(title: s)
                if let gd = d["coords"] as? [String: Double] { alarm.structuredLocation?.geoLocation = CLLocation(latitude: gd["latitude"] ?? 0, longitude: gd["longitude"] ?? 0) }
                if let f = d["radius"] as? Double { alarm.structuredLocation?.radius = f }
                if let s = d["proximity"] as? String { alarm.proximity = { ()->EKAlarmProximity in
                    switch(s) {
                    case "enter": return .enter
                    case "leave": return .leave
                    default: return .none
                    }}()}
            }
            return alarm
        }}
        if let _ = settings["attendees"] as? [[String:Any]] { reject("attendees_prohibited", "EventKit does not permit setting attendees", nil); }
        if let s = settings["recurrence"] as? String { e.recurrenceRules = [EKRecurrenceRule(recurrenceWith: {() -> EKRecurrenceFrequency in switch(s) {
            case "yearly": return .yearly
            case "monthly": return .monthly
            case "weekly": return .weekly
            case "daily": return .daily
            default: return .daily}
        }(), interval: 0, end: nil)]}
        else if let d = settings["recurrenceRule"] as? [String: Any] { e.recurrenceRules = [EKRecurrenceRule(
            recurrenceWith: { (s) -> EKRecurrenceFrequency in switch(s) {
                case "yearly": return .yearly
                case "monthly": return .monthly
                case "weekly": return .weekly
                case "daily": return .daily
                default: return .daily
            }}(d["frequency"] as? String),
            interval: d["interval"] as? Int ?? 1,
            end: d["endDate"] != nil ? EKRecurrenceEnd(end: d["endDate"] as! Date) : EKRecurrenceEnd(occurrenceCount: d["occurrence"] as? Int ?? 0))
        ]}
        if let s = settings["availability"] as? String { e.availability = {()->EKEventAvailability in switch(s) {
            case "busy": return .busy
            case "free": return .free
            case "unavailable": return .unavailable
            default: return .notSupported
        }}()}
        do {
            try eventStore.save(e, span: options["exceptionDate"] == nil ? EKSpan.futureEvents : EKSpan.thisEvent)
        } catch {
            reject("save_error", "Could not save: " + error.localizedDescription, nil)
            return
        }
        resolve(["success": e.eventIdentifier])
    }
    @objc func removeEvent(_ eventId: String, options: [String: Any], resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard EKEventStore.authorizationStatus(for: .event) == .authorized else { reject("unauthorized", "Not authorized to use calendar", nil); return }
        let futureEvents:Bool = options["futureEvents"] as? Bool ?? false
        if let exceptionDate = options["exceptionDate"]  {
            let p = eventStore.predicateForEvents(withStart: RCTConvert.nsDate(exceptionDate), end: Date.distantFuture, calendars: nil)
            DispatchQueue(label: "RNCalendarEvents").async() {
                if let e = self.eventStore.events(matching: p).first(where: { $0.eventIdentifier == eventId && $0.startDate == RCTConvert.nsDate(exceptionDate) }) {
                    do {
                        try self.eventStore.remove(e, span: futureEvents ? EKSpan.futureEvents : EKSpan.thisEvent)
                    } catch {
                        reject("remove_error", "Could not remove instance of event with id " + eventId, nil)
                        return
                    }
                    resolve(true)
                } else {
                    reject("remove_error", "Could not find event with id " + eventId, nil)
                }
            }
        } else {
            guard let e = eventStore.event(withIdentifier: eventId) else { reject("no_event", "Could not find event with id " + eventId, nil); return}
            if let success = try? eventStore.remove(e, span: futureEvents ? EKSpan.futureEvents : EKSpan.thisEvent) {
                resolve(success)
            } else {
                reject("error_removing", "Error removing event with id " + eventId, nil)
            }
        }
    }
    static func requiresMainQueueSetup() -> Bool {
        return false
    }
}
//#MARK:Private functions
func toDic(event:EKEvent) -> [String: Any] {
    var out:[String: Any] = [:]
    out["id"] = event.eventIdentifier
    out["calendarItemId"] = event.calendarItemIdentifier
    out["calendar"] = toDic(calendar: event.calendar)
    out["title"] = event.title
    out["startDate"] = event.startDate.timeIntervalSince1970 * 1000.0
    out["endDate"] = event.endDate.timeIntervalSince1970 * 1000.0
    out["occurrenceDate"] = event.occurrenceDate.timeIntervalSince1970 * 1000.0
    out["isDetached"] = event.isDetached
    out["allDay"] = event.isAllDay
    out["availability"] = { a in
        switch a {
        case .busy: return "busy"
        case .free: return "free"
        case .unavailable: return "unavailable"
        default: return "notSupported"
        }
    }(event.availability)
    if let s = event.notes { out["notes"] = s }
    if let u = event.url { out["url"] = u.absoluteString }
    if let s = event.location { out["location"] = s }
    if let attendees = event.attendees { out["attendees"] = attendees.flatMap() { toDic(participant: $0) } }
    if event.hasAlarms, let a = event.alarms {
        out["alarms"] = a.flatMap() { alarm -> [String:Any] in
            var adic:[String:Any] = [:]
            if let d = alarm.absoluteDate { adic["date"] = d }
            else  {
                adic["date"] = Date(timeInterval: alarm.relativeOffset, since: event.startDate)
            }
            if let l = alarm.structuredLocation {
                adic["strucutedLocation"] = [
                    "title": l.title,
                    "radius":  l.radius,
                    "coords": ["latitude": l.geoLocation?.coordinate.latitude, "longitude": l.geoLocation?.coordinate.longitude],
                    "proximity": {
                        switch($0) {
                        case EKAlarmProximity.enter:
                            return "enter"
                        case EKAlarmProximity.leave:
                            return "leave"
                        default:
                            return "none"
                        }}(alarm.proximity)
                    ] as [String:Any]
            }
            return adic
        }
    }
    if event.hasRecurrenceRules, let a = event.recurrenceRules, let e = a.first {
        out["recurrenceRule"] = [
            "interval": e.interval,
            "endDate": e.recurrenceEnd?.endDate ?? Date(),
            "occurrenceCount": e.recurrenceEnd?.occurrenceCount ?? 0
        ]
        out["recurrence"] = {
            switch($0) {
            case .daily: return "daily"
            case .weekly: return "weekly"
            case .monthly: return "monthly"
            case .yearly: return "yearly"
            }
        }(e.frequency)
    }
    return out
}
func toDic(calendar: EKCalendar) -> [String: Any] {
    return [
        "id": calendar.calendarIdentifier,
        "title": calendar.title,
        "allowsModifications": calendar.allowsContentModifications,
        "source": calendar.source.title,
        //"allowedAvailabilities":
        "color": calendar.cgColor.components?.flatMap() { i in
            return String(format: "%02lX", Int(i * 255.0))
            }.joined() ?? "000"
    ];
}
func toDic(participant: EKParticipant) -> [String:Any] {
    return participant.description.components(separatedBy: ";").reduce(into: [:]) { dict, pair in
        let parts = pair.components(separatedBy: "=")
        if parts[1] != "null" { dict[parts[0]] = parts[1] }
    }
}
