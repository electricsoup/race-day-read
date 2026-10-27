//
//  PrepView.swift
//  Race Day Ready
//
//  Before the trip: things to do (with due dates counted back from the trip),
//  things to buy, and things to make. Buying or making something marks it "Have it"
//  on the packing list.
//

import SwiftUI
import CoreData

struct PrepView: View {
    @ObservedObject var trip: Trip
    var meKey: String
    @FetchRequest private var tasks: FetchedResults<PrepTask>
    @FetchRequest private var items: FetchedResults<PackItem>
    @EnvironmentObject private var toasts: ToastCenter
    @Environment(\.palette) private var palette
    @Environment(\.canEdit) private var canEdit

    enum Mode: String, CaseIterable, Identifiable {
        case todo = "To do", buy = "To buy", make = "To make"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .todo
    @State private var editingTask: TaskEditorTarget?
    @State private var editingItem: PackItem?
    @State private var showTemplates = false
    @State private var showDone = false

    init(trip: Trip, meKey: String) {
        self.trip = trip
        self.meKey = meKey
        let pred = NSPredicate(format: "trip == %@", trip)
        _tasks = FetchRequest(sortDescriptors: [NSSortDescriptor(key: "dueDay", ascending: true), NSSortDescriptor(key: "createdAt", ascending: true)], predicate: pred)
        _items = FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)], predicate: pred)
    }

    var body: some View {
        List {
            Section {
                Picker("Show", selection: $mode) {
                    ForEach(Mode.allCases) { Text(label(for: $0)).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            switch mode {
            case .todo: todoSections
            case .buy: statusSection(.buy)
            case .make: statusSection(.make)
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $editingTask) { target in
            TaskEditor(trip: trip, task: target.task, defaultWho: trip.person(meKey) != nil ? meKey : Who.shared)
        }
        .sheet(item: $editingItem) { item in
            ItemEditor(trip: trip, item: item, draft: ItemDraft(item))
        }
        .sheet(isPresented: $showTemplates) {
            PrepTemplatesView(trip: trip)
        }
    }

    private func label(for m: Mode) -> String {
        switch m {
        case .todo:
            let n = tasks.filter { !$0.done }.count
            return n > 0 ? "To do (\(n))" : "To do"
        case .buy:
            let n = items.filter { $0.statusValue == .buy }.count
            return n > 0 ? "To buy (\(n))" : "To buy"
        case .make:
            let n = items.filter { $0.statusValue == .make }.count
            return n > 0 ? "To make (\(n))" : "To make"
        }
    }

    // MARK: To do

    @ViewBuilder
    private var todoSections: some View {
        let today = DayKey.today
        let open = tasks.filter { !$0.done }
        let overdue = open.filter { ($0.dueDay ?? "") != "" && ($0.dueDay ?? "") < today }
        let upcoming = open.filter { ($0.dueDay ?? "") >= today }
        let undated = open.filter { ($0.dueDay ?? "").isEmpty }
        let done = tasks.filter { $0.done }

        if tasks.isEmpty {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Before you go").font(.display(22, weight: .heavy)).textCase(.uppercase).foregroundStyle(palette.accent)
                    Text("Reservations, shoe break-in, pet sitters, alarms. Start from a list of common race-weekend to-dos, or add your own.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if canEdit {
                        Button { showTemplates = true } label: { Label("Pick from common to-dos", systemImage: "checklist") }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        if canEdit {
            Section {
                HStack {
                    Button { editingTask = TaskEditorTarget(task: nil) } label: { Label("Add a to-do", systemImage: "plus") }
                        .buttonStyle(.borderless)
                    Spacer()
                    if !tasks.isEmpty {
                        Button { showTemplates = true } label: { Label("Common to-dos", systemImage: "checklist") }
                            .buttonStyle(.borderless)
                    }
                }
                .font(.subheadline)
            }
        }
        if !overdue.isEmpty { taskSection("Overdue", overdue) }
        if !upcoming.isEmpty { taskSection("Coming up", upcoming) }
        if !undated.isEmpty { taskSection("Any time before you go", undated) }
        if !done.isEmpty {
            Section {
                if showDone { ForEach(done) { taskRow($0) } }
            } header: {
                Button { showDone.toggle() } label: {
                    HStack {
                        Text("Done (\(done.count))")
                        Spacer()
                        Image(systemName: showDone ? "chevron.down" : "chevron.right").font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func taskSection(_ title: String, _ list: [PrepTask]) -> some View {
        Section(title) { ForEach(list) { taskRow($0) } }
    }

    private func taskRow(_ task: PrepTask) -> some View {
        TaskRow(task: task, trip: trip) { editingTask = TaskEditorTarget(task: task) }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if canEdit {
                    Button(role: .destructive) { removeTask(task) } label: { Label("Delete", systemImage: "trash") }
                    Button { editingTask = TaskEditorTarget(task: task) } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                }
            }
            .contextMenu {
                Button { editingTask = TaskEditorTarget(task: task) } label: { Label("Edit", systemImage: "pencil") }
                if canEdit { Button(role: .destructive) { removeTask(task) } label: { Label("Delete", systemImage: "trash") } }
            }
    }

    private func removeTask(_ task: PrepTask) {
        let title = task.title ?? "to-do"
        let due = task.dueDay, who = task.whoKey ?? Who.shared, note = task.note ?? "", done = task.done
        Persistence.shared.delete(task)
        toasts.show("Removed \"\(title)\"", actionLabel: "Undo") { [trip] in
            let t = Persistence.shared.addTask(to: trip, title: title, due: due, who: who, note: note)
            t.done = done
            Persistence.shared.save()
        }
    }

    // MARK: To buy / To make

    @ViewBuilder
    private func statusSection(_ status: ItemStatus) -> some View {
        let list = items.filter { $0.statusValue == status }
        Section {
            if list.isEmpty {
                Text(status == .buy
                     ? "Nothing to buy. Mark an item \"To buy\" on the packing list and it shows up here."
                     : "Nothing to make. Mark an item \"To make\" (like a costume piece you're sewing) and it shows up here.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(list) { item in
                HStack(alignment: .top, spacing: 10) {
                    Button {
                        item.statusValue = .own
                        Persistence.shared.save()
                        toasts.show(status == .buy ? "Marked \"\(item.text ?? "")\" as bought" : "Marked \"\(item.text ?? "")\" as made", actionLabel: "Undo") {
                            item.statusValue = status
                            Persistence.shared.save()
                        }
                    } label: {
                        Image(systemName: "circle").font(.title3).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canEdit)
                    .accessibilityLabel(status == .buy ? "Mark bought" : "Mark made")
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.text ?? "") + Text(item.qty > 1 ? "  ×\(item.qty)" : "").foregroundColor(.secondary)
                        FlowLayout(spacing: 5) {
                            WhoTag(whoKey: item.whoKey, trip: trip)
                            InfoChip(text: Starters.categoryTitle(item.categoryKey))
                            if let o = item.outfit { InfoChip(text: o.label, systemImage: "tshirt") }
                        }
                        if let n = item.note, !n.isEmpty { Text(n).font(.caption).foregroundStyle(.secondary) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { editingItem = item }
                }
            }
        } footer: {
            if !list.isEmpty {
                Text(status == .buy ? "Tap the circle when you've bought it. It stays on your packing list as \"Have it.\""
                                    : "Tap the circle when it's done. It stays on your packing list as \"Have it.\"")
            }
        }
    }
}

struct TaskEditorTarget: Identifiable {
    let id = UUID()
    var task: PrepTask?
}

struct TaskRow: View {
    @ObservedObject var task: PrepTask
    var trip: Trip
    var onEdit: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.canEdit) private var canEdit

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                task.done.toggle()
                Persistence.shared.save()
            } label: {
                Image(systemName: task.done ? "checkmark.circle.fill" : "circle").font(.title3)
                    .foregroundStyle(task.done ? palette.accent : Color.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(!canEdit)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title ?? "").strikethrough(task.done).foregroundStyle(task.done ? .secondary : .primary)
                FlowLayout(spacing: 5) {
                    if let due = task.dueDay, !due.isEmpty {
                        InfoChip(text: dueLabel(due), systemImage: "calendar")
                    }
                    if let w = task.whoKey, w != Who.shared, trip.person(w) != nil { WhoTag(whoKey: w, trip: trip) }
                }
                if let n = task.note, !n.isEmpty { Text(n).font(.caption).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)
        }
    }

    private func dueLabel(_ due: String) -> String {
        let before = DayKey.between(due, trip.arrive)
        let when = before > 0 ? "\(before) day\(before == 1 ? "" : "s") before you go" : (before == 0 ? "travel day" : "during the trip")
        return "Due " + DayKey.format(due, "MMM d") + " · " + when
    }
}

struct TaskEditor: View {
    @ObservedObject var trip: Trip
    var task: PrepTask?
    var defaultWho: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.canEdit) private var canEdit

    @State private var title = ""
    @State private var hasDue = true
    @State private var due = Date()
    @State private var who = Who.shared
    @State private var note = ""
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What needs doing", text: $title, axis: .vertical)
                    Picker("Whose", selection: $who) {
                        ForEach(trip.peopleList) { Text($0.displayName).tag($0.key) }
                        Text("Everyone").tag(Who.shared)
                    }
                }
                Section {
                    Toggle("Due date", isOn: $hasDue)
                    if hasDue {
                        DatePicker("Due", selection: $due, displayedComponents: .date)
                        let before = DayKey.between(DayKey.key(fromLocal: due), trip.arrive)
                        Text(before > 0 ? "\(before) day\(before == 1 ? "" : "s") before you travel" : "On or after your travel day")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Note") { TextField("Optional", text: $note, axis: .vertical) }
            }
            .disabled(!canEdit)
            .navigationTitle(task == nil ? "Add a to-do" : "Edit to-do")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(task == nil ? "Add" : "Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || !canEdit)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let task {
            title = task.title ?? ""
            hasDue = !(task.dueDay ?? "").isEmpty
            due = DayKey.localDate(task.dueDay ?? DayKey.add(trip.arrive, days: -7))
            who = task.whoKey ?? Who.shared
            note = task.note ?? ""
        } else {
            who = defaultWho
            due = DayKey.localDate(DayKey.add(trip.arrive, days: -7))
        }
    }

    private func save() {
        let dueKey = hasDue ? DayKey.key(fromLocal: due) : nil
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let task {
            task.title = t
            task.dueDay = dueKey
            task.whoKey = who
            task.note = note
        } else {
            Persistence.shared.addTask(to: trip, title: t, due: dueKey, who: who, note: note)
        }
        Persistence.shared.save()
        dismiss()
    }
}

struct PrepTemplatesView: View {
    @ObservedObject var trip: Trip
    @Environment(\.dismiss) private var dismiss
    @State private var picked: Set<String> = Set(Starters.prepTemplates.map { $0.title })

    private var existing: Set<String> {
        Set(((trip.tasks as? Set<PrepTask>) ?? []).map { normalized($0.title) })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Starters.prepTemplates) { t in
                        let already = existing.contains(normalized(t.title))
                        Button {
                            if picked.contains(t.title) { picked.remove(t.title) } else { picked.insert(t.title) }
                        } label: {
                            HStack(alignment: .top) {
                                Image(systemName: already ? "checkmark.circle" : (picked.contains(t.title) ? "checkmark.circle.fill" : "circle"))
                                    .foregroundStyle(already ? Color.secondary : Color.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.title).foregroundStyle(already ? .secondary : .primary)
                                    Text(already ? "Already on your list" : "Due \(DayKey.format(DayKey.add(trip.arrive, days: -t.daysBefore), "MMM d")) · \(t.daysBefore) day\(t.daysBefore == 1 ? "" : "s") before"
                                         + (t.perPerson && trip.travelers.count > 1 ? " · one for each person" : ""))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(already)
                    }
                } footer: {
                    Text("Due dates count back from your arrival day. Ones that have already passed are marked overdue so nothing slips.")
                }
            }
            .navigationTitle("Common to-dos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") { add() } }
            }
        }
    }

    private func add() {
        let p = Persistence.shared
        let have = existing
        for t in Starters.prepTemplates where picked.contains(t.title) && !have.contains(normalized(t.title)) {
            let due = DayKey.add(trip.arrive, days: -t.daysBefore)
            if t.perPerson && trip.travelers.count > 1 {
                for person in trip.travelers { p.addTask(to: trip, title: t.title, due: due, who: person.key) }
            } else {
                p.addTask(to: trip, title: t.title, due: due)
            }
        }
        p.save()
        dismiss()
    }
}
