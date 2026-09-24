import SwiftUI

struct PracticeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var candidate: Int?
    @State private var inspected: Int?
    @State private var showLiberties = false
    @State private var showEstimate = false
    @State private var confirmNewGame = false
    @State private var showReview = false
    @State private var message: String?
    private var position: GamePosition { store.game.position }
    private var estimate: AreaEstimate { GoEngine.estimate(position.board, size: 9) }
    private var liberties: Set<Int> {
        if let point = inspected { return GoEngine.group(position.board, at: point, size: 9).liberties }
        guard showLiberties else { return [] }
        return position.board.indices.filter { position.board[$0] == 1 }.reduce(into: Set<Int>()) {
            $0.formUnion(GoEngine.group(position.board, at: $1, size: 9).liberties)
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeading(eyebrow: "九路棋盘 · 你执黑", title: "每一手，\n都是新的开始。", subtitle: "先点交叉点预览，再确认落子。点棋子可以查看它的气。")
                NavigationLink { CaptureChallengeView() } label: {
                    Label("先练小棋盘：五路吃子挑战", systemImage: "flag.checkered")
                        .font(.subheadline).frame(maxWidth: .infinity).padding(12)
                }.buttonStyle(.bordered)
                HStack {
                    Label("黑提 \(position.captures[0])", systemImage: "circle.fill")
                    Spacer()
                    Text("已下 \(position.moves) 手").foregroundStyle(Palette.muted)
                    Spacer()
                    Label("白提 \(position.captures[1])", systemImage: "circle")
                }.font(.caption.weight(.medium)).monospacedDigit()
                BoardView(board: position.board, size: 9, liberties: liberties, lastPoint: position.lastPoint,
                          candidate: candidate, territory: showEstimate ? estimate.territory : [], onTap: select)
                if position.paused {
                    PrimaryButton(title: "继续下棋", systemImage: "play.fill") { store.resume(); resetSelection(); showEstimate = false }
                } else {
                    PrimaryButton(title: candidate.map { "落子 \(GoEngine.coordinate($0, size: 9))" } ?? "先选择一个交叉点",
                                  systemImage: "circle.fill", disabled: candidate == nil) { commit() }
                }
                CoachNote(text: message ?? position.message)
                Button {
                    if !position.paused { store.pass() }
                    resetSelection(); showEstimate = true; showReview = true
                } label: {
                    Label(position.paused ? "查看本局复盘" : "暂停并复盘", systemImage: "text.magnifyingglass")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(position.turns.isEmpty)
                HStack(spacing: 16) {
                    Button("悔棋一轮", systemImage: "arrow.uturn.backward") { store.undo(); resetSelection(); showEstimate = false }
                        .disabled(store.game.undoPositions.isEmpty)
                    Spacer()
                    Button("停一手", systemImage: "pause") { store.pass(); resetSelection(); showEstimate = true }
                        .disabled(position.paused)
                }.buttonStyle(.bordered).font(.subheadline)
                Toggle("显示黑棋的气", isOn: $showLiberties).onChange(of: showLiberties) { _, _ in inspected = nil }
                Toggle("查看地盘估算", isOn: $showEstimate)
                if showEstimate {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("当前盘面估算").font(.headline)
                        Text("黑 \(estimate.black) 点 · 白 \(estimate.white) + 6.5 贴目")
                        Text("未归属 \(estimate.neutral) 点。未自动判断死活、未移除死子，不能据此宣布胜负。")
                            .font(.footnote).foregroundStyle(Palette.muted)
                    }.card()
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("落子前，问自己").font(.headline)
                    Text("① 我有没有棋被打吃？\n② 对手有没有弱棋？\n③ 这手能连接或围地吗？").font(.subheadline).lineSpacing(9)
                }.card()
                Text("本地入门规则陪练，非职业棋力。禁自杀、禁止重复历史盘面。停一手后，陪练也会停一手供你检查。棋局自动保存，可悔最近 30 轮。")
                    .font(.footnote).foregroundStyle(Palette.muted).lineSpacing(4)
                Button("重新开局", role: .destructive) { confirmNewGame = true }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .pageStyle().navigationTitle("下一盘").inlineTitle()
        .confirmationDialog("重新开局会清空当前棋局，学习进度会保留。", isPresented: $confirmNewGame, titleVisibility: .visible) {
            Button("重新开局", role: .destructive) { store.newGame(); resetSelection(); showEstimate = false }
            Button("取消", role: .cancel) { }
        }
        .sheet(isPresented: $showReview) {
            NavigationStack { GameReviewView() }.environmentObject(store)
        }
    }
    private func resetSelection() { candidate = nil; inspected = nil; message = nil }
    private func select(_ point: Int) {
        if position.board[point] != 0 {
            candidate = nil; inspected = point
            let group = GoEngine.group(position.board, at: point, size: 9)
            message = "这块\(position.board[point] == 1 ? "黑" : "白")棋有 \(group.stones.count) 颗子、\(group.liberties.count) 口气。" + (group.liberties.count == 1 ? "注意，正在被打吃！" : "圈出的空点就是气。")
        } else if !position.paused {
            candidate = point; inspected = nil
            message = "准备落在 \(GoEngine.coordinate(point, size: 9))。想清楚后，点「落子」确认。"
        }
    }
    private func commit() {
        guard let point = candidate else { return }
        do { try store.play(point); resetSelection(); showEstimate = false; TouchFeedback.move() }
        catch { message = error.localizedDescription; candidate = nil }
    }
}

struct GameReviewView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var insightIndex = 0

    private var insights: [ReviewInsight] { PracticeReviewer.insights(for: store.game.position) }
    private var insight: ReviewInsight? {
        guard insights.indices.contains(insightIndex) else { return insights.first }
        return insights[insightIndex]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeading(eyebrow: "本局复盘 · \(insights.count) 个关键时刻",
                               title: "把关键一手，\n再想明白。",
                               subtitle: "复盘依据气、提子与基础布局原则生成，不代表职业级胜率判断。")
                if let insight {
                    HStack {
                        Text("第 \(insight.ply) 手").font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
                        Spacer()
                        Text("\(insightIndex + 1) / \(insights.count)").font(.caption).monospacedDigit().foregroundStyle(Palette.muted)
                    }
                    Text(insight.theme.rawValue).font(.title2.weight(.semibold))
                    BoardView(board: insight.boardBefore, size: 9,
                              hints: insight.recommendedPoint.map { [$0] } ?? [],
                              candidate: insight.playedPoint) { _ in }
                    Text("半透明黑子是本局落点；绿色虚线圈是教练建议方向。")
                        .font(.caption).foregroundStyle(Palette.muted)
                    CoachNote(text: insight.explanation, isError: insight.priority >= 2)
                    if let point = insight.recommendedPoint, insight.priority > 0 {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("建议先看 \(GoEngine.coordinate(point, size: 9))").font(.headline)
                            Text("从这里重下会把当前九路棋局恢复到这一手之前。课程与错题记录不会改变。")
                                .font(.footnote).foregroundStyle(Palette.muted)
                        }.card()
                        PrimaryButton(title: "从这里重新下", systemImage: "arrow.uturn.backward") {
                            store.retry(beforeTurn: insight.turnIndex)
                            dismiss()
                        }
                    }
                    HStack(spacing: 12) {
                        Button("上一处", systemImage: "chevron.left") {
                            insightIndex = max(0, insightIndex - 1)
                        }.disabled(insightIndex == 0)
                        Spacer()
                        Button("下一处", systemImage: "chevron.right") {
                            insightIndex = min(insights.count - 1, insightIndex + 1)
                        }.disabled(insightIndex >= insights.count - 1)
                    }.buttonStyle(.bordered)
                } else {
                    CoachNote(text: "至少完成一手棋后，教练才能开始复盘。")
                }
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .pageStyle().navigationTitle("教练复盘").inlineTitle()
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } } }
    }
}
