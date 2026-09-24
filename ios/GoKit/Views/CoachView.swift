import SwiftUI

struct CoachHubView: View {
    @EnvironmentObject private var store: AppStore
    private var reviewProblems: [TrainingProblem] {
        CoachCurriculum.problems.filter { store.training.review.contains($0.id) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeading(eyebrow: "教练带练", title: "看懂一手，\n自己再试一手。",
                               subtitle: "先数气，再提子、救棋、连接。下错时一起看原因，独立答对后再往前走。")
                NavigationLink {
                    CoachSessionView(problems: CoachCurriculum.guidedIDs.compactMap(CoachCurriculum.problem), guided: true)
                } label: {
                    entry(title: store.training.guidedCompleted ? "再上一遍带练课" : "第一节 · 数气与叫吃",
                          detail: "3 个步骤 · 讲解、动手、看后果", icon: "lightbulb")
                }.buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 14) {
                    Text("我的小本领").font(.headline)
                    ForEach(TrainingSkill.allCases, id: \.self) { skill in
                        let problems = CoachCurriculum.problems.filter { $0.skill == skill }
                        let count = problems.filter { store.training.mastered.contains($0.id) }.count
                        HStack {
                            Text(skill.rawValue)
                            Spacer()
                            Text("独立答对 \(count) / \(problems.count) 题").font(.subheadline).foregroundStyle(Palette.muted)
                        }
                    }
                    ProgressView(value: Double(store.training.mastered.count), total: 10)
                        .accessibilityLabel("10 道带练题中，已独立答对 \(store.training.mastered.count) 道")
                }.card()
                NavigationLink {
                    CoachSessionView(problems: Array(store.training.queue.prefix(5)))
                } label: {
                    entry(title: "练习 5 分钟", detail: "每轮 5 题 · 优先巩固错题，再练新题", icon: "timer")
                }.buttonStyle(.plain)
                NavigationLink {
                    CoachSessionView(problems: CoachCurriculum.problems)
                } label: {
                    entry(title: "完整练一遍", detail: "10 道原创题 · 数气、提子、救棋、连接", icon: "square.grid.2x2")
                }.buttonStyle(.plain)
                if !reviewProblems.isEmpty {
                    NavigationLink { CoachSessionView(problems: reviewProblems) } label: {
                        entry(title: "待巩固 · \(reviewProblems.count) 题", detail: "新一轮不看提示答对，就能移出", icon: "arrow.counterclockwise")
                    }.buttonStyle(.plain)
                }
                NavigationLink { CaptureChallengeView() } label: {
                    entry(title: "五路吃子挑战", detail: "先提掉对方棋子就赢 · 可撤回重试", icon: "flag.checkered")
                }.buttonStyle(.plain)
                Text("带练课不计独立答题进度；配套练习会记录提示与错误。教学判断来自棋盘规则，所有功能离线可用。")
                    .font(.footnote).foregroundStyle(Palette.muted).lineSpacing(4)
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.pageStyle().navigationTitle("教练带练").inlineTitle()
    }
    private func entry(title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(Palette.green).frame(width: 30)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted)
        }.card()
    }
}

struct CoachSessionView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var problems: [TrainingProblem]
    private let guided: Bool
    @State private var index = 0
    @State private var attempt: TrainingAttempt
    @State private var candidate: Int?
    @State private var finished = false
    @State private var independentCount = 0
    init(problems: [TrainingProblem], guided: Bool = false) {
        let safeProblems = problems.isEmpty ? CoachCurriculum.problems : problems
        _problems = State(initialValue: safeProblems); self.guided = guided
        _attempt = State(initialValue: TrainingAttempt(safeProblems[0]))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if finished { completion }
                else {
                    HStack {
                        Text(guided ? "跟教练走一遍" : attempt.problem.skill.rawValue).font(.subheadline).foregroundStyle(Palette.green)
                        Spacer()
                        Text("\(index + 1) / \(problems.count)").font(.subheadline).monospacedDigit()
                    }
                    ProgressView(value: Double(index), total: Double(problems.count))
                        .accessibilityLabel("第 \(index + 1) 题，共 \(problems.count) 题")
                    Text(attempt.problem.title).font(.system(.title2, design: .serif).weight(.semibold))
                    if guided { CoachNote(text: guidance) }
                    Text(attempt.problem.prompt).font(.headline).lineSpacing(4)
                    Text("橙色圈标出本题关注的棋子。").font(.caption).foregroundStyle(Palette.muted)
                    BoardView(board: attempt.board, size: 5, selected: attempt.marked,
                              liberties: attempt.liberties, lastPoint: attempt.lastPoint, candidate: candidate) { point in
                        guard !attempt.solved, !attempt.needsRetry, attempt.problem.skill != .liberties,
                              attempt.board[point] == 0 else { return }
                        candidate = point
                    }
                    responseControls
                    CoachNote(text: attempt.feedback, isError: attempt.needsRetry)
                        .accessibilityAddTraits(.updatesFrequently)
                    if attempt.needsRetry {
                        if attempt.demonstration != nil && !attempt.demonstrated {
                            Button("演示白棋下一手", systemImage: "play.circle") {
                                attempt.demonstrate(); candidate = nil
                            }.buttonStyle(.bordered)
                        }
                        PrimaryButton(title: "回到题目再试一次", systemImage: "arrow.uturn.backward") {
                            attempt.retry(); candidate = nil
                        }
                    } else if attempt.solved {
                        if !guided && !attempt.independent {
                            Text("本题已练过，仍需巩固。换一轮独立答对后移出待巩固列表。")
                                .font(.footnote).foregroundStyle(Palette.muted)
                        }
                        PrimaryButton(title: index + 1 == problems.count ? "完成这一轮" : "继续下一题") { advance() }
                    } else {
                        Button("给我一点提示", systemImage: "lightbulb") {
                            attempt.help(); record()
                        }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                    }
                }
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.id(index).pageStyle().navigationTitle(guided ? "数气与叫吃" : "带练习题").inlineTitle()
    }
    @ViewBuilder private var responseControls: some View {
        if !attempt.solved && !attempt.needsRetry {
            if attempt.problem.skill == .liberties {
                HStack(spacing: 12) {
                    ForEach(attempt.problem.options, id: \.self) { value in
                        Button("\(value) 口气") { attempt.answer(value); record() }
                            .buttonStyle(.bordered).frame(maxWidth: .infinity)
                    }
                }
            } else {
                PrimaryButton(title: candidate.map { "确认落子 \(GoEngine.coordinate($0, size: 5))" } ?? "先点一个空交叉点",
                              systemImage: "circle.fill", disabled: candidate == nil) {
                    if let point = candidate { attempt.play(point); candidate = nil; record() }
                }
            }
        }
    }
    private var guidance: String {
        switch attempt.problem.skill {
        case .liberties: return "棋子上下左右的相邻空点叫作气。斜着的空点不算，被棋子占住的点也不算。请先自己数一数。"
        case .capture: return "现在换你执黑进攻。白子只剩一口气，封住它，白子就会被提走。"
        case .rescue: return "换个角度：黑子自己被叫吃了。先沿最后一口气跑出去。也可以故意下在别处，看看教练演示会发生什么。"
        case .connect: return "相邻的同色棋连成一块，一起共享气。试着把它们连接起来。"
        }
    }
    private var completion: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "checkmark.seal").font(.largeTitle).foregroundStyle(Palette.green)
            Text(guided ? "带练课完成了" : "这一轮练习完成了").font(.title2.weight(.semibold))
            Text(guided ? "你练过了数气、提子和救棋。接下来做独立练习，看看换个棋形还能不能认出来。" :
                    "完成 \(problems.count) 题，其中 \(independentCount) 题独立答对。用过提示或答错的题，会留到下一轮继续巩固。")
                .font(.body).lineSpacing(5)
            PrimaryButton(title: "回到教练带练") { dismiss() }
        }.card()
    }
    private func record() {
        if !guided { store.recordTraining(attempt) }
        if attempt.solved { TouchFeedback.success() } else { TouchFeedback.move() }
    }
    private func advance() {
        guard attempt.solved, !finished else { return }
        if attempt.independent { independentCount += 1 }
        if index + 1 == problems.count {
            if guided { store.completeGuidedTraining() }
            finished = true
        } else {
            index += 1; attempt = TrainingAttempt(problems[index]); candidate = nil
        }
    }
}

struct CaptureChallengeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var candidate: Int?
    @State private var inspected: Int?
    @State private var message: String?
    @State private var confirmNew = false
    private var position: CapturePosition { store.captureGame.position }
    private var inspectedGroup: GoGroup? {
        inspected.map { GoEngine.group(position.board, at: $0, size: 5) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("你执黑 · 先提子就赢").font(.title2.weight(.semibold))
                Text("这是练习吃子的简化玩法。正式围棋还要比较围住的地盘。")
                    .font(.subheadline).foregroundStyle(Palette.muted)
                HStack {
                    Text(outcomeTitle).foregroundStyle(Palette.green)
                    Spacer()
                    Text("\(position.moves) / 80 手").monospacedDigit()
                }.font(.subheadline)
                BoardView(board: position.board, size: 5,
                          selected: inspectedGroup?.stones ?? position.highlighted,
                          liberties: inspectedGroup?.liberties ?? position.liberties,
                          lastPoint: position.lastPoint, candidate: candidate) { point in
                    if position.board[point] != 0 {
                        inspected = point; candidate = nil
                        let group = GoEngine.group(position.board, at: point, size: 5)
                        message = "这块\(position.board[point] == 1 ? "黑" : "白")棋有 \(group.stones.count) 颗子、\(group.liberties.count) 口气。"
                    } else if position.outcome == .playing {
                        candidate = point; inspected = nil; message = nil
                    }
                }
                if position.outcome == .playing {
                    PrimaryButton(title: candidate.map { "确认落子 \(GoEngine.coordinate($0, size: 5))" } ?? "先点一个空交叉点",
                                  systemImage: "circle.fill", disabled: candidate == nil) {
                        guard let point = candidate else { return }
                        do { try store.playCapture(point); clearSelection(); TouchFeedback.move() }
                        catch { message = error.localizedDescription; candidate = nil }
                    }
                }
                CoachNote(text: message ?? position.message)
                HStack {
                    Button("撤回一轮", systemImage: "arrow.uturn.backward") { store.undoCapture(); clearSelection() }
                        .disabled(store.captureGame.undoPositions.isEmpty)
                    Spacer()
                    Button("停一手", systemImage: "pause") { store.passCapture(); clearSelection() }
                        .disabled(position.outcome != .playing)
                }.buttonStyle(.bordered)
                Text("点棋子查看气；橙圈标出重点棋子，绿圈标出气。双方连续停一手或达到 80 手则和局。禁止自杀与重复历史盘面，可撤回最近 30 轮。陪练为本地入门算法。")
                    .font(.footnote).foregroundStyle(Palette.muted).lineSpacing(4)
                Button("重新挑战", role: .destructive) { confirmNew = true }.frame(maxWidth: .infinity)
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.pageStyle().navigationTitle("五路吃子挑战").inlineTitle()
        .confirmationDialog("重新挑战会清空本局，带练进度会保留。", isPresented: $confirmNew, titleVisibility: .visible) {
            Button("重新挑战", role: .destructive) { store.newCaptureGame(); clearSelection() }
            Button("取消", role: .cancel) { }
        }
    }
    private var outcomeTitle: String {
        switch position.outcome {
        case .playing: return "轮到黑棋"
        case .won: return "挑战成功"
        case .lost: return "白棋先提子了"
        case .draw: return "本局和棋"
        }
    }
    private func clearSelection() { candidate = nil; inspected = nil; message = nil }
}
