import Foundation
import GameCore

#if canImport(CloudKit)

    import CloudKit

    /// Abgleich über CloudKit.
    ///
    /// Die Wahl fiel auf CloudKit statt Firebase: kein Serverbetrieb, keine
    /// laufenden Kosten, iCloud-Backup inklusive, und für eine App mit
    /// Altersfreigabe 4+ deutlich weniger Datenschutz-Aufwand. Der Preis ist die
    /// Bindung an Apple-Plattformen — für ein iOS-Spiel ist das keiner.
    ///
    /// **Voraussetzungen, die nicht im Code stehen:** ein Apple Developer
    /// Programm, der iCloud-Berechtigungsschein im App-Ziel und ein Feld-Index
    /// auf `lamport` im CloudKit-Dashboard. Ohne den Index liefert die Abfrage
    /// nichts, ohne Fehlermeldung.
    ///
    /// **Ungeprüft.** Dieser Adapter ist gegen keinen echten Container gelaufen —
    /// die CI hat weder Konto noch Berechtigungen. Er kompiliert, mehr ist
    /// bislang nicht bewiesen. Die Zusammenführungslogik dagegen ist vollständig
    /// getestet, und genau dort liegt das Risiko sonst.
    public struct CloudKitSyncBackend: SyncBackend {
        static let recordType = "GameEvent"

        private let containerIdentifier: String

        /// Nur die Kennung wird gehalten, nicht die Datenbank selbst: `CKDatabase`
        /// ist eine Klasse, und dieser Typ soll `Sendable` bleiben.
        public init(containerIdentifier: String) {
            self.containerIdentifier = containerIdentifier
        }

        private var database: CKDatabase {
            CKContainer(identifier: containerIdentifier).privateCloudDatabase
        }

        public func push(events: [EventEnvelope]) async throws {
            guard !events.isEmpty else { return }

            let records = events.map(Self.record(from:))

            do {
                // `.allKeys` überschreibt bestehende Sätze: Dasselbe Ereignis
                // zweimal zu schicken muss folgenlos bleiben.
                _ = try await database.modifyRecords(
                    saving: records,
                    deleting: [],
                    savePolicy: .allKeys
                )
            } catch {
                throw SyncError.backendFailure(String(describing: error))
            }
        }

        public func pull(since cursor: SyncCursor) async throws -> [EventEnvelope] {
            let predicate = NSPredicate(format: "lamport > %@", NSNumber(value: cursor.lamport))
            let query = CKQuery(recordType: Self.recordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: "lamport", ascending: true)]

            do {
                let (matches, _) = try await database.records(matching: query)
                return matches.compactMap { _, result in
                    guard let record = try? result.get() else { return nil }
                    return Self.envelope(from: record)
                }
            } catch {
                throw SyncError.backendFailure(String(describing: error))
            }
        }

        public func uploadSnapshot(_ data: Data) async throws {
            let record = CKRecord(
                recordType: "GameSnapshot",
                recordID: CKRecord.ID(recordName: "current")
            )
            record["payload"] = data as CKRecordValue
            record["savedAt"] = Date() as CKRecordValue

            do {
                _ = try await database.modifyRecords(
                    saving: [record],
                    deleting: [],
                    savePolicy: .allKeys
                )
            } catch {
                throw SyncError.backendFailure(String(describing: error))
            }
        }

        public func latestSnapshot() async throws -> Data? {
            do {
                let id = CKRecord.ID(recordName: "current")
                let record = try await database.record(for: id)
                return record["payload"] as? Data
            } catch {
                return nil
            }
        }

        // MARK: - Übersetzung

        static func record(from envelope: EventEnvelope) -> CKRecord {
            // Die Ereignis-Kennung ist zugleich der Satzname. Dadurch ist
            // zweimaliges Hochladen desselben Ereignisses derselbe Satz und
            // nicht zwei - Idempotenz aus der Datenstruktur statt aus Logik.
            let record = CKRecord(
                recordType: recordType,
                recordID: CKRecord.ID(recordName: envelope.id.uuidString)
            )
            record["type"] = envelope.type as CKRecordValue
            record["deviceID"] = envelope.deviceID.rawValue as CKRecordValue
            record["lamport"] = NSNumber(value: envelope.lamport)
            record["wallClock"] = envelope.wallClock as CKRecordValue
            record["payload"] = envelope.payload as CKRecordValue
            return record
        }

        static func envelope(from record: CKRecord) -> EventEnvelope? {
            guard let id = UUID(uuidString: record.recordID.recordName),
                let type = record["type"] as? String,
                let deviceID = record["deviceID"] as? String,
                let lamport = record["lamport"] as? NSNumber,
                let wallClock = record["wallClock"] as? Date,
                let payload = record["payload"] as? Data
            else { return nil }

            return EventEnvelope(
                id: id,
                type: type,
                deviceID: DeviceID(deviceID),
                lamport: lamport.uint64Value,
                wallClock: wallClock,
                payload: payload
            )
        }
    }

#endif
