import SwiftUI

struct StudyPracticeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var candidate: Int?
    @State private var proposedSize = 9
    @State private var confirmNew = false
    @State private var feedback = ""
    private var game: StudyPractice { store.studyPractice }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeading(eyebrow: "\(game.size) 路教学棋盘", title: "把想法，\n下到棋盘上。",
                    subtitle: "同机轮流执黑白，可独自摆棋或与朋友对弈。九路自动陪练仍在「下一盘」。")
                HStack {
                    Text(game.paused ? "双方停手 · 确认终局" : "轮到\(game.turn == 1 ? "黑" : "白")棋")
                    Spacer(); Text("\(game.turns.count) 手").monospacedDigit()
                }.font(.headline)
                StudyBoard(board: game.board, size: game.size, focus: game.dead, candidate: candidate, candidateColor: game.turn,
                           last: game.turns.last?.point) { point in
                    if game.paused { var value = game; value.toggleDead(point); store.updateStudyPractice(value) }
                    else if game.board[point] == 0 { candidate = point }
                }
                if !game.paused {
                    PrimaryButton(title: candidate.map { "\(game.turn == 1 ? "黑" : "白")棋落在 \(GoEngine.coordinate($0, size: game.size))" } ?? "先选择一个交叉点",
                                  disabled: candidate == nil || game.turns.count >= 1200) {
                        guard let point = candidate else { return }
                        do { var value = game; try value.play(point); store.updateStudyPractice(value); feedback = ""; candidate = nil }
                        catch { feedback = error.localizedDescription; candidate = nil }
                    }
                    Button("停一手") { var value = game; value.pass(); store.updateStudyPractice(value); candidate = nil }
                        .buttonStyle(.bordered).disabled(game.turns.count >= 1200)
                    if game.turns.count >= 1200 { CoachNote(text: "达到本次练习的1200手上限，请保存复盘笔记后重新开局。") }
                } else {
                    CoachNote(text: "先双方确认死活，点击整块死子标记或取消。橙圈只是你的标记；有分歧就继续下棋验证。面积按活子加围空计算，本教学局不贴目。")
                    Text("按当前标记估算：黑 \(game.score.black) · 白 \(game.score.white) · 未归属 \(game.score.neutral)")
                        .font(.headline)
                    Toggle("双方已确认死活与边界", isOn: Binding(get: { game.confirmed }, set: { flag in
                        var value = game; value.confirmed = flag; store.updateStudyPractice(value)
                    }))
                    if game.confirmed { Text("本次人工确认已保存。计分依赖上述死子标记；这是教学记录。").font(.caption) }
                    Button("有争议，继续下棋") { var value = game; value.resume(); store.updateStudyPractice(value); candidate = nil }
                        .buttonStyle(.bordered)
                }
                if !feedback.isEmpty { CoachNote(text: feedback, isError: true) }
                Button("撤回一手", systemImage: "arrow.uturn.backward") {
                    var value = game; value.undo(); store.updateStudyPractice(value); candidate = nil
                }.disabled(game.turns.isEmpty).buttonStyle(.bordered)
                NavigationLink { StudyReplayView(game: game) } label: {
                    Label("逐手回看 · 从关键手重下", systemImage: "backward.end")
                }.buttonStyle(.bordered).disabled(game.turns.isEmpty)
                Button("保存这盘棋和笔记") {
                    feedback = store.archiveStudyPractice(game) ? "已保存至教学棋谱。" : "未保存：需要至少一手棋，且最多保留10份棋谱。可先在棋谱列表删除不需要的记录。"
                }.buttonStyle(.bordered)
                NavigationLink { StudyRecordsView() } label: {
                    Label("我的教学棋谱（\(store.studyRecords.count) / 10）", systemImage: "books.vertical")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("自己的复盘笔记").font(.headline)
                    Text("我原来想做什么？漏看哪一手？重新下会怎样？").font(.caption).foregroundStyle(Palette.muted)
                    TextEditor(text: Binding(get: { game.reflection }, set: { text in
                        var value = game; value.reflection = String(text.prefix(4000)); store.updateStudyPractice(value)
                    })).frame(minHeight: 120).accessibilityLabel("复盘笔记")
                    Text("棋局与笔记自动保存在本机；新开棋局会替换它们。").font(.caption).foregroundStyle(Palette.muted)
                }.card()
                VStack(alignment: .leading, spacing: 12) {
                    Text("新开教学棋局").font(.headline)
                    Picker("棋盘大小", selection: $proposedSize) {
                        ForEach([9,13,19], id: \.self) { Text("\($0)路").tag($0) }
                    }.pickerStyle(.segmented)
                    Button("开始新局", role: .destructive) { confirmNew = true }
                }.card()
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.pageStyle().navigationTitle("教学棋盘").inlineTitle()
        .confirmationDialog("新局会替换当前教学棋盘和复盘笔记，课程进度保留。", isPresented: $confirmNew, titleVisibility: .visible) {
            Button("新开 \(proposedSize) 路棋局", role: .destructive) {
                store.updateStudyPractice(StudyPractice(size: proposedSize)); candidate = nil; feedback = ""
            }
        }
        .onAppear { proposedSize = game.size }
    }
}


struct StudyReplayView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let game: StudyPractice
    @State private var ply = 0
    @State private var confirmRetry = false
    @State private var message = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("第 \(ply) / \(game.turns.count) 手").font(.headline)
                StudyBoard(board: game.position(at: ply), size: game.size,
                    last: ply > 0 ? game.turns[ply - 1].point : nil) { _ in }
                if ply > 0 {
                    let move = game.turns[ply - 1]
                    Text("\(move.color == 1 ? "黑" : "白")：\(move.point.map { GoEngine.coordinate($0, size: game.size) } ?? "停一手")")
                }
                HStack {
                    Button("上一手") { ply -= 1 }.disabled(ply == 0)
                    Spacer()
                    Button("下一手") { ply += 1 }.disabled(ply >= game.turns.count)
                }.buttonStyle(.bordered)
                Slider(value: Binding(get: { Double(ply) }, set: { ply = Int($0) }),
                       in: 0...Double(max(1,game.turns.count)), step: 1).disabled(game.turns.isEmpty)
                    .accessibilityLabel("回看手数")
                if !game.reflection.isEmpty { CoachNote(text: game.reflection) }
                Text("停在关键着之前，先说出原来的想法，再试另一条变化。重下前会保存当前教学棋局。")
                    .font(.subheadline).foregroundStyle(Palette.muted)
                Button("从这一手之后重新下") { confirmRetry = true }.buttonStyle(.borderedProminent)
                if !message.isEmpty { CoachNote(text: message) }
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.pageStyle().navigationTitle("逐手复盘").inlineTitle()
        .confirmationDialog("重下会替换当前教学棋盘；有着手的当前棋局先保存到教学棋谱，原路线可以再看。", isPresented: $confirmRetry, titleVisibility: .visible) {
            Button("保存当前棋局并重下") {
                if !store.studyPractice.turns.isEmpty && !store.archiveStudyPractice(store.studyPractice) {
                    message = "教学棋谱已满10份。请先删除不需要的记录，再重下。"; return
                }
                var value = game; value.retry(after: ply); store.updateStudyPractice(value); dismiss()
            }
        }
    }
}

struct StudyRecordsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var remove: UUID?
    var body: some View {
        List {
            if store.studyRecords.isEmpty { Text("在教学棋盘选择「保存这盘棋和笔记」，就能在这里逐手回看。") }
            ForEach(store.studyRecords) { record in
                NavigationLink { StudyReplayView(game: record.game) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(record.game.size)路 · \(record.game.turns.count)手").font(.headline)
                        Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                        if !record.game.reflection.isEmpty { Text(record.game.reflection).font(.caption).lineLimit(2) }
                    }
                }.swipeActions { Button("删除", role: .destructive) { remove = record.id } }
            }
        }.navigationTitle("教学棋谱").inlineTitle()
        .confirmationDialog("删除这一份棋谱和笔记？当前教学棋盘不受影响。", isPresented: Binding(get: { remove != nil }, set: { if !$0 { remove = nil } }), titleVisibility: .visible) {
            Button("删除这份记录", role: .destructive) { if let id = remove { store.removeStudyRecord(id) }; remove = nil }
        }
    }
}
