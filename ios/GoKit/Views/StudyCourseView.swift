import SwiftUI

struct StudyHubView: View {
    @EnvironmentObject private var store: AppStore
    private var next: StudyLesson {
        StudyCatalog.lessons.first { !store.studyProgress.learned.contains($0.id) }
            ?? StudyCatalog.lessons.first { store.studyProgress.needsReview($0) } ?? StudyCatalog.lessons[99]
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeading(eyebrow: "九三棋社 · 系统课程", title: "从第一手，\n到独立复盘。",
                    subtitle: "100课 · 讲解、判断、棋盘操作与实战记录。按自己的节奏学。")
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("已学 \(store.studyProgress.learned.count) / 100 课").font(.headline)
                        Spacer()
                        Text("学习 \(store.studyProgress.activeDates.count) 天").font(.caption)
                    }
                    ProgressView(value: Double(store.studyProgress.learned.count), total: 100)
                    NavigationLink(value: next.id) {
                        Label(store.studyProgress.results.isEmpty && store.studyProgress.learned.isEmpty ? "开始第 \(next.id) 课 · \(next.title)" : "继续第 \(next.id) 课 · \(next.title)", systemImage: "arrow.right")
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                    }.buttonStyle(.borderedProminent)
                    Text("学过记录保留；本轮达标按独立作答计算，提示和错题会留待复习。")
                        .font(.caption).foregroundStyle(Palette.muted)
                }.card()
                ForEach(0..<10, id: \.self) { chapter in
                    NavigationLink {
                        StudyChapterView(chapter: chapter)
                    } label: {
                        HStack(spacing: 12) {
                            Text(String(format: "%02d", chapter + 1)).font(.title2).foregroundStyle(Palette.green)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(StudyCatalog.chapterTitles[chapter]).font(.headline)
                                Text("第 \(chapter * 10 + 1)–\((chapter + 1) * 10) 课 · 含综合复习")
                                    .font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }.card()
                    }.buttonStyle(.plain)
                }
                NavigationLink { StudyPracticeView() } label: {
                    Label("教学棋盘 · 9 / 13 / 19 路", systemImage: "square.grid.3x3").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
                DisclosureGroup("专项练习与吴清源名局") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("配合主线课程使用，也可以按兴趣随时练习。")
                            .font(.caption).foregroundStyle(Palette.muted)
                        NavigationLink { CoachHubView() } label: {
                            Label("教练带练 · 数气与吃子专项", systemImage: "lightbulb")
                        }
                        NavigationLink { WuCourseHubView() } label: {
                            Label("吴清源名局观察", systemImage: "sparkles")
                        }
                    }.padding(.top, 12)
                }.card()
                NavigationLink { StudySourcesView() } label: { Text("课程依据与学习说明") }
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.pageStyle().navigationTitle("系统100课").inlineTitle()
        .navigationDestination(for: Int.self) { id in
            if (1...StudyCatalog.lessons.count).contains(id) {
                StudyLessonView(lesson: StudyCatalog.lessons[id - 1]).id(id)
            }
        }
    }
}

struct StudyChapterView: View {
    @EnvironmentObject private var store: AppStore
    let chapter: Int
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeading(eyebrow: "第 \(chapter + 1) 单元", title: StudyCatalog.chapterTitles[chapter],
                               subtitle: "先看讲解，自己作答，再把本领用到棋盘上。")
                ForEach(StudyCatalog.lessons.filter { $0.chapter == chapter }) { lesson in
                    NavigationLink { StudyLessonView(lesson: lesson).id(lesson.id) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("\(lesson.id). \(lesson.title)").font(.headline)
                                Spacer()
                                Image(systemName: store.studyProgress.passed(lesson) ? "checkmark.seal.fill" : "chevron.right")
                                    .foregroundStyle(Palette.green)
                            }
                            Text(lesson.objective).font(.subheadline).foregroundStyle(Palette.muted)
                            Text(status(lesson)).font(.caption).foregroundStyle(Palette.green)
                        }.card()
                    }.buttonStyle(.plain)
                }
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.pageStyle().navigationTitle("第 \(chapter + 1) 单元").inlineTitle()
    }
    private func status(_ lesson: StudyLesson) -> String {
        if store.studyProgress.needsReview(lesson) { return "待巩固 · \(lesson.exercises.count) 项练习" }
        if store.studyProgress.passed(lesson) { return "本轮独立作答达标" }
        if store.studyProgress.learned.contains(lesson.id) { return "已学过 · 可以再练" }
        let done = lesson.exercises.filter { store.studyProgress.results[$0.id]?.solved == true }.count
        return done > 0 ? "已完成 \(done) / \(lesson.exercises.count) 项" : "\(lesson.exercises.count) 项练习 · 可离线学习"
    }
}

struct StudyLessonView: View {
    @EnvironmentObject private var store: AppStore
    let lesson: StudyLesson
    @State private var showExercises = false
    @State private var showRestart = false
    @State private var showDemo = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeading(eyebrow: "系统第 \(lesson.id) 课 / 100", title: lesson.title, subtitle: lesson.objective)
                VStack(alignment: .leading, spacing: 12) {
                    Text("一起看懂").font(.headline)
                    Text(lesson.explanation).lineSpacing(7)
                }.card()
                CoachNote(text: lesson.example)
                if let demo = lesson.demonstration {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("棋盘演练").font(.headline)
                        Text(demo.prompt).font(.subheadline).lineSpacing(4)
                        StudyBoard(board: demo.board, size: demo.size, focus: demo.focus) { _ in }
                        if demo.isBoardTask {
                            Button(store.studyProgress.results[demo.id]?.solved == true ? "回看逐手示范" : "逐手观看示范（记录为提示）", systemImage: "play.circle") {
                                var attempt = StudyAttempt(demo)
                                attempt.help(); store.recordStudy(attempt, lesson: lesson)
                                showDemo = true
                            }.buttonStyle(.bordered)
                        }
                    }.card()
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text(lesson.assessment ? "综合复习" : "现在自己试").font(.headline)
                    Text("\(lesson.exercises.count) 项练习；独立完成至少八成，并完成最后的棋盘题，记为本轮达标。看过提示仍可完成课程，稍后再独立练习。")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    PrimaryButton(title: "进入练习") { showExercises = true }
                    Button("重新独立练一轮") { showRestart = true }.font(.subheadline)
                }.card()
                VStack(alignment: .leading, spacing: 12) {
                    Text("用到实战里").font(.headline)
                    Text(lesson.application).font(.subheadline).lineSpacing(5)
                    NavigationLink { StudyPracticeView() } label: {
                        Label("打开教学棋盘与复盘笔记", systemImage: "square.grid.3x3")
                    }.buttonStyle(.bordered)
                    if let id = lesson.wuID {
                        NavigationLink { WuLessonView(lesson: WuCurriculum.lessons[id]) } label: {
                            Label("配套吴清源名局观察", systemImage: "sparkles")
                        }.buttonStyle(.bordered)
                    }
                    Toggle("已完成本课实战任务（自己记录）", isOn: Binding(
                        get: { store.studyProgress.applications.contains(lesson.id) },
                        set: { store.recordStudyApplication(lesson.id, complete: $0) }))
                        .font(.subheadline)
                    Text("实战记录单独保存，不计入独立答题正确率。")
                        .font(.caption).foregroundStyle(Palette.muted)
                }.card()
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.pageStyle().navigationTitle("第 \(lesson.id) 课").inlineTitle()
        .sheet(isPresented: $showExercises) {
            NavigationStack { StudySessionView(lesson: lesson).id(lesson.id) }.environmentObject(store)
        }
        .sheet(isPresented: $showDemo) {
            if let demo = lesson.demonstration { NavigationStack { StudyDemoView(exercise: demo) } }
        }
        .confirmationDialog("开始新一轮会重新计算本课本轮成绩，已学过的记录保留。", isPresented: $showRestart, titleVisibility: .visible) {
            Button("开始新一轮") { store.restartStudy(lesson); showExercises = true }
        }
    }
}

struct StudySessionView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let lesson: StudyLesson
    @State private var index = 0
    @State private var attempt: StudyAttempt
    @State private var candidate: Int?
    @State private var initialized = false
    @State private var finished = false
    init(lesson: StudyLesson) {
        self.lesson = lesson; _attempt = State(initialValue: StudyAttempt(lesson.exercises[0]))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if finished {
                    SectionHeading(eyebrow: "第 \(lesson.id) 课 · 本轮记录已保存", title: "本课答题结果",
                        subtitle: "独立完成 \(store.studyProgress.independentCount(lesson)) / \(lesson.exercises.count) 项。")
                    CoachNote(text: store.studyProgress.passed(lesson) ? "本轮独立作答达标。把它用到实战里，过几天再检查是否仍然会做。" : "本轮尚未达到独立作答标准。答错或用过提示的内容已留在复习列表，可以再独立练一轮。")
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(lesson.exercises.indices, id: \.self) { number in
                            let exercise = lesson.exercises[number]
                            let result = store.studyProgress.results[exercise.id]
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(number + 1).").monospacedDigit()
                                Text(exercise.prompt).frame(maxWidth: .infinity, alignment: .leading)
                                Text(result?.independent == true ? "独立答对" : result?.hinted == true ? "用过提示" : result?.mistake == true ? "改正后完成" : "未完成")
                                    .foregroundStyle(result?.independent == true ? Palette.green : Palette.amber)
                            }.font(.subheadline)
                        }
                    }.card()
                    PrimaryButton(title: "返回第 \(lesson.id) 课内容", systemImage: "arrow.uturn.backward") { dismiss() }
                } else {
                    Text("第 \(index + 1) / \(lesson.exercises.count) 项").font(.caption).foregroundStyle(Palette.muted)
                    ProgressView(value: Double(index), total: Double(lesson.exercises.count))
                    Text(attempt.exercise.prompt).font(.title3.weight(.semibold)).lineSpacing(5)
                    if !attempt.board.isEmpty {
                        StudyBoard(board: attempt.board, size: attempt.exercise.size, focus: attempt.exercise.focus,
                            hints: attempt.hinted ? attempt.candidates : [], candidate: candidate, last: attempt.lastPoint) { p in
                            if attempt.exercise.isBoardTask, !attempt.solved { candidate = p }
                        }
                    }
                    if attempt.exercise.isBoardTask {
                        PrimaryButton(title: candidate.map { "确认落子 \(GoEngine.coordinate($0, size: attempt.exercise.size))" } ?? "先选交叉点",
                                      disabled: candidate == nil || attempt.solved) {
                            if let p = candidate { attempt.play(p); candidate = nil; record() }
                        }
                        Text("按题目给定路线演练；白棋使用预设应手。本题不声称穷尽所有战略选择。")
                            .font(.caption).foregroundStyle(Palette.muted)
                    } else {
                        ForEach(attempt.exercise.options.indices, id: \.self) { option in
                            Button { attempt.answer(option); record() } label: {
                                HStack(alignment: .top) {
                                    Text(String(Array("ABC")[option])).bold().foregroundStyle(Palette.green)
                                    Text(attempt.exercise.options[option]).frame(maxWidth: .infinity, alignment: .leading)
                                    if attempt.selectedAnswer == option { Image(systemName: attempt.solved ? "checkmark.circle" : "arrow.uturn.backward") }
                                }.padding(16).background(Palette.paper, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain).disabled(attempt.solved)
                        }
                    }
                    CoachNote(text: attempt.feedback, isError: attempt.mistake && !attempt.solved)
                    if attempt.solved {
                        PrimaryButton(title: nextUnsolvedIndex == nil ? "查看本课答题结果" : "继续下一题") { advance() }
                    } else {
                        Button("给我提示", systemImage: "lightbulb") { attempt.help(); record() }.buttonStyle(.bordered)
                    }
                }
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.id(finished ? "study-results" : "study-exercise")
        .pageStyle().navigationTitle(lesson.title).inlineTitle()
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("返回第 \(lesson.id) 课") { dismiss() } } }
        .onAppear {
            startIfNeeded()
        }
        .onChange(of: lesson.id) { _, _ in
            initialized = false
            startIfNeeded()
        }
    }
    private func startIfNeeded() {
        guard !initialized, let first = lesson.exercises.first else { return }
        initialized = true; finished = false
        if let i = nextUnsolvedIndex { load(i) }
        else {
            index = 0
            attempt = StudyAttempt(first)
            candidate = nil
            finished = true
        }
    }
    private func load(_ i: Int) {
        index = i; let exercise = lesson.exercises[i]
        attempt = StudyAttempt(exercise, prior: store.studyProgress.results[exercise.id]); candidate = nil
    }
    private func record() { store.recordStudy(attempt, lesson: lesson); if attempt.solved { TouchFeedback.success() } }
    private var nextUnsolvedIndex: Int? {
        lesson.exercises.firstIndex { store.studyProgress.results[$0.id]?.solved != true }
    }
    private func advance() {
        guard attempt.solved else { return }
        if let i = nextUnsolvedIndex { load(i) }
        else { finished = true }
    }
}

struct StudyBoard: View {
    let board: [Int]
    let size: Int
    var focus: Set<Int> = []
    var hints: Set<Int> = []
    var candidate: Int?
    var candidateColor = 1
    var last: Int?
    let onTap: (Int) -> Void
    @State private var zoom = false
    var body: some View {
        VStack(spacing: 8) {
            if zoom {
                ScrollView([.horizontal, .vertical]) {
                    BoardView(board: board, size: size, selected: focus, hints: hints, lastPoint: last,
                              candidate: candidate, candidateColor: candidateColor, onTap: onTap).frame(width: CGFloat(size + 1) * 32)
                }.frame(height: 390)
            } else {
                BoardView(board: board, size: size, selected: focus, hints: hints, lastPoint: last, candidate: candidate, candidateColor: candidateColor, onTap: onTap)
            }
            if size > 9 { Button(zoom ? "查看全盘" : "放大棋盘，可横向滑动") { zoom.toggle() }.font(.caption) }
        }
    }
}

struct StudyDemoView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: StudyExercise
    @State private var ply = 0
    @State private var variation = 0
    private var line: [Int] { exercise.branches[variation] }
    private var shown: [Int] {
        var value = exercise.board
        for (i, point) in line.prefix(ply).enumerated() {
            if let played = try? GoEngine.play(value, at: point, color: i % 2 + 1, size: exercise.size) { value = played.board }
        }
        return value
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(exercise.prompt).font(.headline)
                if exercise.branches.count > 1 {
                    Picker("参考变化", selection: Binding(get: { variation }, set: { ply = 0; variation = $0 })) {
                        ForEach(exercise.branches.indices, id: \.self) { Text("变化 \($0 + 1)").tag($0) }
                    }.pickerStyle(.segmented)
                }
                StudyBoard(board: shown, size: exercise.size, last: ply > 0 ? line[ply - 1] : nil) { _ in }
                HStack {
                    Button("上一手") { ply -= 1 }.disabled(ply == 0)
                    Spacer(); Text("\(ply) / \(line.count) 手").monospacedDigit(); Spacer()
                    Button("下一手") { ply += 1 }.disabled(ply == line.count)
                }.buttonStyle(.bordered)
                Slider(value: Binding(get: { Double(ply) }, set: { ply = Int($0) }), in: 0...Double(max(1,line.count)), step: 1)
                    .accessibilityLabel("示范手数")
                CoachNote(text: exercise.explanation)
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.pageStyle().navigationTitle("逐手演示").inlineTitle()
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("返回") { dismiss() } } }
    }
}

struct StudySourcesView: View {
    var body: some View {
        List {
            Section("课程内容") {
                Text("90节主题讲解和10节综合复习。含450道原创知识判断题、100道从主题题选取的综合复习，以及每课一项棋盘操作或观察。复用棋图不计为独立根题。")
                Text("棋盘题包括指定路线跟摆和单步操作。复杂死活的完整应手树、550道独立棋形题仍需进一步扩充；本轮达标不等同于正式棋力评级。")
            }
            Section("公开教学资料") {
                Link("日本棋院 · 围棋入门", destination: URL(string: "https://www.nihonkiin.or.jp/teach/lesson/school/")!)
                Link("日本棋院 · 吃子手筋教学范围", destination: URL(string: "https://www.nihonkiin.or.jp/publishing/books/mekimeki_tesuji.html")!)
                Link("英国围棋协会 · 教初学者", destination: URL(string: "https://britgo.org/organisers/handbook/club4")!)
                Link("英国围棋协会 · 从九路逐步进阶", destination: URL(string: "https://www.britgo.org/intro/followup")!)
            }
            Section("学习记录") {
                Text("练习与提示自动保存。重新练习会重算本轮成绩，已学记录保留。实战任务由学习者自己记录，不计入答题正确率。")
                Text("讲解与练习为九三棋社编写，未声称经过职业棋手审定。外部资料链接需要网络，课程本身可以离线使用。")
            }
        }.navigationTitle("课程说明").inlineTitle()
    }
}
