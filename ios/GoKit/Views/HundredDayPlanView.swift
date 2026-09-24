import SwiftUI

struct HundredDayPlanView: View {
    @EnvironmentObject private var store: AppStore
    private var current: HundredDayDay { HundredDayPlan.day(store.hundredDayProgress.currentDay)! }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeading(eyebrow: "九三百日入门计划",
                               title: "每天三件事，\n把棋真正下会。",
                               subtitle: "不锁日期，按自己的节奏完成。棋理、专项题和实战缺一不可。")

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("当前 · 第 \(current.id) 天").font(.caption.weight(.semibold)).foregroundStyle(Palette.green)
                            Text(current.theme).font(.title2.weight(.semibold))
                        }
                        Spacer()
                        Text("\(store.hundredDayProgress.completedDays) / 100")
                            .font(.headline).monospacedDigit()
                    }
                    ProgressView(value: Double(store.hundredDayProgress.completedDays), total: 100)
                        .accessibilityLabel("百日计划已完成 \(store.hundredDayProgress.completedDays) 天")
                    HStack {
                        Label("约 \(current.totalMinutes) 分钟", systemImage: "clock")
                        Spacer()
                        Label("连续闯关 \(store.hundredDayProgress.currentStreak) 天", systemImage: "flame")
                    }.font(.caption).foregroundStyle(Palette.muted)
                    NavigationLink { HundredDayView(day: current) } label: {
                        Label(store.hundredDayProgress.isDayComplete(current) ? "回看今天" : "开始今日训练",
                              systemImage: "arrow.right")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    }.buttonStyle(.borderedProminent)
                }.card()

                VStack(alignment: .leading, spacing: 12) {
                    Text("今天练什么").font(.title3.weight(.semibold))
                    ForEach(current.tasks) { task in
                        HStack(spacing: 12) {
                            Image(systemName: store.hundredDayProgress.isTaskComplete(task) ? "checkmark.circle.fill" : task.kind.icon)
                                .frame(width: 28).foregroundStyle(Palette.green)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title).font(.subheadline.weight(.semibold))
                                Text("\(task.kind.rawValue) · \(task.minutes) 分钟")
                                    .font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                        }.padding(.vertical, 4)
                    }
                }.card()

                Text("七段成长路线").font(.title3.weight(.semibold))
                VStack(spacing: 12) {
                    ForEach(HundredDayPlan.stages) { stage in
                        NavigationLink { HundredDayStageView(stage: stage) } label: {
                            stageRow(stage)
                        }.buttonStyle(.plain)
                    }
                }
                CoachNote(text: "计划会复用现有 48 课、带练题、五路挑战、九路实战和吴清源启蒙课。完成任务后回到当天页面打勾，系统就会推进。")
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .pageStyle().navigationTitle("百日计划").inlineTitle()
    }

    private func stageRow(_ stage: HundredDayStage) -> some View {
        let stageDays = HundredDayPlan.days.filter { stage.days.contains($0.id) }
        let completed = stageDays.filter(store.hundredDayProgress.isDayComplete).count
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Palette.sage).frame(width: 46, height: 46)
                Image(systemName: completed == stageDays.count ? "checkmark" : stage.icon)
            }.foregroundStyle(Palette.green)
            VStack(alignment: .leading, spacing: 5) {
                Text("第 \(stage.days.lowerBound)–\(stage.days.upperBound) 天 · \(stage.title)").font(.headline)
                Text(stage.subtitle).font(.caption).foregroundStyle(Palette.muted)
            }
            Spacer()
            Text("\(completed)/\(stageDays.count)").font(.caption).monospacedDigit().foregroundStyle(Palette.muted)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted)
        }.card()
    }
}

struct HundredDayStageView: View {
    @EnvironmentObject private var store: AppStore
    let stage: HundredDayStage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeading(eyebrow: "第 \(stage.days.lowerBound)–\(stage.days.upperBound) 天",
                               title: stage.title, subtitle: stage.subtitle)
                ForEach(HundredDayPlan.days.filter { stage.days.contains($0.id) }) { day in
                    NavigationLink { HundredDayView(day: day) } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(Palette.sage).frame(width: 42, height: 42)
                                if store.hundredDayProgress.isDayComplete(day) { Image(systemName: "checkmark") }
                                else { Text("\(day.id)").font(.subheadline.weight(.semibold)).monospacedDigit() }
                            }.foregroundStyle(Palette.green)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day.theme).font(.headline)
                                Text("3 项任务 · 约 \(day.totalMinutes) 分钟").font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted)
                        }.card()
                    }.buttonStyle(.plain)
                }
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .pageStyle().navigationTitle(stage.title).inlineTitle()
    }
}

struct HundredDayView: View {
    @EnvironmentObject private var store: AppStore
    let day: HundredDayDay

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeading(eyebrow: "百日计划 · 第 \(day.id) 天",
                               title: day.theme, subtitle: "三项都完成，今天才算过关。预计 \(day.totalMinutes) 分钟。")
                CoachNote(text: day.coachLine)
                ForEach(day.tasks) { task in taskCard(task) }
                if store.hundredDayProgress.isDayComplete(day) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("第 \(day.id) 天完成", systemImage: "checkmark.seal.fill")
                            .font(.title3.weight(.semibold)).foregroundStyle(Palette.green)
                        Text(day.id == 100 ? "百日路线已经走完。回到棋盘继续下、继续复盘，这才是新的开始。" : "很好。下一天已经准备好，按自己的节奏继续。")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                        if let next = HundredDayPlan.day(day.id + 1) {
                            NavigationLink { HundredDayView(day: next) } label: {
                                Label("进入第 \(next.id) 天", systemImage: "arrow.right")
                                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                            }.buttonStyle(.borderedProminent)
                        }
                    }.card()
                }
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .pageStyle().navigationTitle("第 \(day.id) 天").inlineTitle()
    }

    private func taskCard(_ task: HundredDayTask) -> some View {
        let done = store.hundredDayProgress.isTaskComplete(task)
        return VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: task.kind.icon).font(.title3).foregroundStyle(Palette.green).frame(width: 28)
                VStack(alignment: .leading, spacing: 5) {
                    Text(task.kind.rawValue).font(.caption.weight(.semibold)).foregroundStyle(Palette.green)
                    Text(task.title).font(.headline)
                    Text(task.detail).font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(3)
                }
                Spacer()
                Text("\(task.minutes) 分").font(.caption).foregroundStyle(Palette.muted)
            }
            NavigationLink { destination(for: task.action) } label: {
                Label(done ? "再练一次" : "开始练习", systemImage: "arrow.up.right")
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
            }.buttonStyle(.bordered)
            Button {
                store.setHundredDayTask(task, completed: !done)
                if !done { TouchFeedback.success() }
            } label: {
                Label(done ? "已完成，点此撤销" : "练完了，标记完成",
                      systemImage: done ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10)
            }.buttonStyle(.borderedProminent)
        }.card()
    }

    @ViewBuilder private func destination(for action: HundredDayAction) -> some View {
        switch action {
        case .lesson(let id):
            if let lesson = Curriculum.lessons.first(where: { $0.id == id }) { LessonView(lesson: lesson) }
        case .training(let ids):
            CoachSessionView(problems: ids.compactMap(CoachCurriculum.problem))
        case .capture:
            CaptureChallengeView()
        case .practice:
            PracticeView()
        case .review:
            ReviewView()
        case .wu(let id):
            if let lesson = WuCurriculum.lessons.first(where: { $0.id == id }) { WuLessonView(lesson: lesson) }
        }
    }
}
