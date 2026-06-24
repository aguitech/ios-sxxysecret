import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @State private var detail: ProjectDetail?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    // Stats grid
                    if let detail = detail {
                        statsGrid(detail: detail)
                            .padding(.horizontal, 20)

                        membersSection(detail: detail)
                            .padding(.horizontal, 20)

                        tasksSection(detail: detail)
                            .padding(.horizontal, 20)

                        commentsSection(detail: detail)
                            .padding(.horizontal, 20)
                    } else if isLoading {
                        ProgressView().tint(Theme.gold)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let err = error {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.error)
                            .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Detalle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            do {
                self.detail = try await APIClient.shared.projectDetail(id: project.id)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.title)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    if let client = project.client {
                        HStack(spacing: 6) {
                            Image(systemName: "building.2.fill")
                                .foregroundStyle(Theme.gold)
                            Text(client.company ?? client.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                }
                Spacer()
                Pill(text: project.statusLabel, color: statusColor(project.status))
            }

            if let desc = project.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Progreso general")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .textCase(.uppercase)
                    Spacer()
                    Text("\(project.progress)%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.gold)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.bgSecondary)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.gold)
                            .frame(width: geo.size.width * CGFloat(project.progress) / 100)
                    }
                }
                .frame(height: 8)
            }

            // Budget / dates
            HStack(spacing: 12) {
                if let budget = project.budget {
                    MetaPill(icon: "dollarsign.circle.fill", label: "Presupuesto", value: formatMoney(budget))
                }
                if let start = project.startDate {
                    MetaPill(icon: "calendar.badge.plus", label: "Inicio", value: start.formatted(date: .abbreviated, time: .omitted))
                }
                if let end = project.endDate {
                    MetaPill(icon: "calendar.badge.minus", label: "Fin", value: end.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }
    }

    // MARK: - Stats grid
    private func statsGrid(detail: ProjectDetail) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(title: "Tareas", value: "\(detail.stats.totalTasks)", icon: "checklist", color: Theme.info)
                StatCard(title: "Progreso", value: "\(detail.stats.weightedProgress)%", icon: "chart.line.uptrend.xyaxis", color: Theme.gold)
            }
            HStack(spacing: 12) {
                StatCard(title: "Vencidas", value: "\(detail.stats.overdue)", icon: "exclamationmark.triangle.fill", color: Theme.error)
                StatCard(title: "Miembros", value: "\(detail.stats.membersCount)", icon: "person.2.fill", color: Theme.accent)
            }
            // Status breakdown
            HStack(spacing: 8) {
                StatusCountPill(label: "Pendientes", count: detail.stats.byStatus.pendiente, color: Theme.warning)
                StatusCountPill(label: "En curso", count: detail.stats.byStatus.en_curso, color: Theme.info)
                StatusCountPill(label: "Hechas", count: detail.stats.byStatus.hecho, color: Theme.success)
            }
        }
    }

    // MARK: - Members
    private func membersSection(detail: ProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Miembros")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(detail.memberStats.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.gold.opacity(0.15))
                    .clipShape(Capsule())
            }

            if detail.memberStats.isEmpty {
                Text("Sin miembros asignados")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Theme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 8) {
                    ForEach(detail.memberStats) { ms in
                        MemberRow(memberStat: ms)
                    }
                }
            }
        }
    }

    // MARK: - Tasks (grouped by status)
    private func tasksSection(detail: ProjectDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tareas")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(detail.tasks.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.gold.opacity(0.15))
                    .clipShape(Capsule())
            }

            if detail.tasks.isEmpty {
                Text("Sin tareas asignadas")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Theme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Group by status
                let grouped = Dictionary(grouping: detail.tasks) { $0.status }
                let order = ["pendiente", "en_curso", "hecho"]
                let labels: [String: String] = [
                    "pendiente": "Pendientes",
                    "en_curso": "En curso",
                    "hecho": "Hechas"
                ]
                ForEach(order, id: \.self) { key in
                    if let items = grouped[key], !items.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(statusColor(key))
                                    .frame(width: 8, height: 8)
                                Text(labels[key] ?? key)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Theme.textSecondary)
                                    .textCase(.uppercase)
                                Spacer()
                                Text("\(items.count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            VStack(spacing: 6) {
                                ForEach(items.prefix(10)) { task in
                                    TaskRow(task: task)
                                }
                                if items.count > 10 {
                                    Text("+ \(items.count - 10) más")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.textTertiary)
                                        .padding(.top, 4)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Comments
    private func commentsSection(detail: ProjectDetail) -> some View {
        Group {
            if !detail.recentComments.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Comentarios recientes")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(detail.recentComments.count)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Theme.gold.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    VStack(spacing: 8) {
                        ForEach(detail.recentComments.prefix(5)) { c in
                            CommentRow(comment: c)
                        }
                    }
                }
            }
        }
    }

    // MARK: - helpers
    private func statusColor(_ s: String) -> Color {
        switch s {
        case "activo", "hecho": return Theme.success
        case "en_curso": return Theme.info
        case "pendiente", "pausado": return Theme.warning
        case "cancelado": return Theme.error
        case "completado": return Theme.info
        default: return Theme.textTertiary
        }
    }

    private func formatMoney(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "MXN"
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "$\(Int(v))"
    }
}

// MARK: - Member row
struct MemberRow: View {
    let memberStat: MemberStat

    var initials: String {
        let parts = memberStat.user.name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.gold.opacity(0.2))
                    .frame(width: 44, height: 44)
                Text(initials)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.gold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(memberStat.user.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                if let email = memberStat.user.email {
                    Text(email)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Pill(text: memberStat.role.capitalized, color: Theme.gold)
                Text("\(memberStat.tasksCompleted)/\(memberStat.tasksOwned) hechas")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(12)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Status count pill
struct StatusCountPill: View {
    let label: String
    let count: Int
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Meta pill (in header)
struct MetaPill: View {
    let icon: String
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Theme.gold)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .textCase(.uppercase)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Comment row
struct CommentRow: View {
    let comment: Comment

    var initials: String {
        let parts = comment.author.name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    var timeAgo: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: comment.createdAt, relativeTo: .now)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Theme.gold.opacity(0.2))
                    .frame(width: 34, height: 34)
                Text(initials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.gold)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.author.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(timeAgo)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                }
                if !comment.taskTitle.isEmpty {
                    Text("💬 \(comment.taskTitle)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.gold)
                }
                Text(comment.text)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(4)
            }
        }
        .padding(12)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
