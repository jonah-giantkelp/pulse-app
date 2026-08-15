import SwiftUI

struct ConcertsView: View {
    enum Mode: String, CaseIterable {
        case list = "LIST"
        case calendar = "CALENDAR"
    }

    @EnvironmentObject private var events: EventStore
    @State private var mode: Mode = .list

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                HStack {
                    PulseWordmark()
                    Spacer()
                    Text("\(events.events.count) UPCOMING")
                        .font(.mono(10))
                        .kerning(1)
                        .foregroundStyle(Color.pulseTextMuted)
                }

                modeToggle
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            switch mode {
            case .list: eventList
            case .calendar: CalendarModeView(events: events.events)
            }
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(Mode.allCases, id: \.self) { m in
                Button {
                    mode = m
                } label: {
                    Text(m.rawValue)
                        .font(.mono(11, .bold))
                        .kerning(1.5)
                        .foregroundStyle(mode == m ? Color.pulseBg : Color.pulseTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(mode == m ? Color.pulseAccent : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.pulseBorderLight, lineWidth: 1)
        )
    }

    private var eventList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if events.isLoading {
                    LoadingState()
                } else if events.events.isEmpty {
                    if let error = events.loadError {
                        EmptyState(icon: "exclamationmark.triangle", message: error)
                    } else {
                        EmptyState(icon: "waveform", message: "No upcoming events for your artists")
                    }
                } else {
                    GroupedEventList(events: events.events)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        // Unstructured task: SwiftUI tears the .refreshable task down when the
        // view re-renders mid-pull, which used to cancel the request itself.
        .refreshable { await Task { await events.load() }.value }
    }
}

/// The day-grouped event list shared by the Concerts and Liked tabs.
struct GroupedEventList: View {
    let events: [Event]

    var body: some View {
        ForEach(listRows) { row in
            switch row {
            case .day(let day, let dayEvents):
                PulseSectionHeader(text: PulseFormat.day(day))
                    .padding(.top, 10)
                ForEach(dayEvents) { event in
                    EventCard(event: event, showDate: false)
                }
            case .run(let runEvents):
                PulseSectionHeader(
                    text: PulseFormat.dayRange(runEvents.first!.date, runEvents.last!.date)
                )
                .padding(.top, 10)
                EventRunCard(events: runEvents)
            }
        }
    }

    private enum ListRow: Identifiable {
        case day(Date, [Event])
        case run([Event])

        var id: String {
            switch self {
            case .day(let day, _): "day-\(day.timeIntervalSince1970)"
            case .run(let events): "run-\(events.first?.id.uuidString ?? "")"
            }
        }
    }

    /// Days as usual, except runs of consecutive days that each hold exactly
    /// one event by the same single artist — those collapse into one row
    /// ("6–7 AUG").
    private var listRows: [ListRow] {
        let calendar = Calendar.current
        var rows: [ListRow] = []
        var run: [Event] = []

        func flushRun() {
            if run.count >= 2 {
                rows.append(.run(run))
            } else if let only = run.first {
                rows.append(.day(calendar.startOfDay(for: only.date), [only]))
            }
            run = []
        }

        for group in EventStore.byDay(events) {
            guard group.events.count == 1,
                  let event = group.events.first,
                  let soloArtist = event.artists?.first, event.artists?.count == 1 else {
                flushRun()
                rows.append(.day(group.day, group.events))
                continue
            }
            if let last = run.last,
               last.artists?.first?.artistId == soloArtist.artistId,
               let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last.date)),
               nextDay == group.day {
                run.append(event)
            } else {
                flushRun()
                run = [event]
            }
        }
        flushRun()
        return rows
    }
}

/// Collapsed "N nights" card for a same-artist run — tap to unpack the
/// individual nights.
struct EventRunCard: View {
    let events: [Event]
    @State private var expanded = false

    private var artist: EventArtist? { events.first?.artists?.first }

    var body: some View {
        VStack(spacing: 8) {
            PulseCard {
                HStack(alignment: .center, spacing: 12) {
                    if let artist {
                        ArtistAvatar(url: artist.imageUrl, name: artist.name, size: 38)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(artist?.name ?? events.first!.title)
                            .font(.mono(14, .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(events.count) NIGHTS")
                            .font(.mono(10))
                            .kerning(1)
                            .foregroundStyle(Color.pulseTextFaint)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.pulseTextMuted)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.snappy) { expanded.toggle() }
            }

            if expanded {
                ForEach(events) { event in
                    EventCard(event: event)
                        .padding(.leading, 12)
                }
            }
        }
    }
}

// MARK: - Calendar mode

struct CalendarModeView: View {
    let events: [Event]

    @State private var displayedMonth = Calendar.current.startOfMonth(for: Date())
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var slideFrom: Edge = .trailing

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    private func events(on day: Date) -> [Event] {
        events.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                monthHeader
                    // The month label snaps — only the grid slide animates
                    .transaction { $0.animation = nil }

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(weekdays.enumerated()), id: \.offset) { _, day in
                        Text(day)
                            .font(.mono(10))
                            .foregroundStyle(Color.pulseTextFaint)
                    }
                    ForEach(Array(monthCells.enumerated()), id: \.offset) { _, cell in
                        if let day = cell {
                            dayCell(day)
                        } else {
                            Color.clear.frame(height: 36)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .id(displayedMonth) // new month slides in from the swipe side
                .transition(.push(from: slideFrom))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 25)
                        .onEnded { value in
                            // Horizontal-dominant swipes only, so vertical scroll wins otherwise
                            guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                            slideFrom = value.translation.width < 0 ? .trailing : .leading
                            withAnimation(.snappy) {
                                shiftMonth(value.translation.width < 0 ? 1 : -1)
                            }
                        }
                )
                .clipped()

                let dayEvents = events(on: selectedDay)
                VStack(alignment: .leading, spacing: 12) {
                    PulseSectionHeader(text: PulseFormat.day(selectedDay))
                    if dayEvents.isEmpty {
                        Text("NO EVENTS")
                            .font(.mono(11))
                            .kerning(1)
                            .foregroundStyle(Color.pulseTextFaint)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(dayEvents) { event in
                            EventCard(event: event, showDate: false)
                        }
                    }
                }
                .padding(.top, 8)
                // Don't animate the list on month slides / day taps — but leave
                // other transactions (e.g. the event sheet dismissal) alone.
                .animation(nil, value: displayedMonth)
                .animation(nil, value: selectedDay)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                slideFrom = .leading
                withAnimation(.snappy) { shiftMonth(-1) }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(Color.pulseAccent)
                    .frame(width: 40, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text(PulseFormat.monthYear.string(from: displayedMonth).uppercased())
                .font(.mono(13, .bold))
                .kerning(2)
                .foregroundStyle(.white)
            Spacer()
            Button {
                slideFrom = .trailing
                withAnimation(.snappy) { shiftMonth(1) }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.pulseAccent)
                    .frame(width: 40, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        let hasEvents = !events(on: day).isEmpty

        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.mono(12, isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.pulseBg : (isToday ? Color.pulseAccent : .white))
                Circle()
                    .fill(hasEvents ? (isSelected ? Color.pulseBg : Color.pulseAccent) : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(isSelected ? Color.pulseAccent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isToday && !isSelected ? Color.pulseAccent : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// Days of the displayed month with leading nils to align the first
    /// weekday (Monday-first grid), padded to a constant 6 rows so the
    /// content below never jumps between months.
    private var monthCells: [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: displayedMonth) // 1 = Sunday
        let leading = (firstWeekday + 5) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: displayedMonth))
        }
        while cells.count < 42 {
            cells.append(nil)
        }
        return cells
    }

    private func shiftMonth(_ delta: Int) {
        if let shifted = Calendar.current.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = shifted
        }
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}
