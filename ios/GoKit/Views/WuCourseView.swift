import SwiftUI

struct WuCourseHubView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeading(eyebrow: "名局启蒙 · 8 课",
                               title: "跟着吴清源，\n学习看全盘。",
                               subtitle: "从已核对的历史棋谱中截取开局片段，训练方向、转身与全局意识。")
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("启蒙进度", systemImage: "sparkles")
                        Spacer()
                        Text("\(store.wuProgress.completed.count) / \(WuCurriculum.lessons.count) 课")
                            .monospacedDigit()
                    }.font(.subheadline.weight(.medium))
                    ProgressView(value: Double(store.wuProgress.completed.count),
                                 total: Double(WuCurriculum.lessons.count))
                }.card()

                CoachNote(text: "棋盘和对局资料来自已关联的历史主线棋谱；问题、解释和主题是九三棋社面向初学者的教学改编，不是《吴清源自选百局》的原文评注。")

                ForEach(WuCurriculum.lessons) { lesson in
                    NavigationLink { WuLessonView(lesson: lesson) } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12).fill(Palette.sage).frame(width: 44, height: 44)
                                if store.wuProgress.completed.contains(lesson.id) {
                                    Image(systemName: "checkmark")
                                } else {
                                    Text(String(format: "%02d", lesson.id + 1))
                                        .font(.system(.title3, design: .serif))
                                }
                            }.foregroundStyle(Palette.green)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(lesson.title).font(.headline)
                                Text("自选百局第 \(lesson.bookNumber) 局 · \(lesson.theme)")
                                    .font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.muted)
                        }.card()
                    }.buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("资料说明").font(.headline)
                    Text("当前本地资料含完整 100 局目录，32 局已与公开历史棋谱关联。本课程只选用其中 8 局；不会用未核实棋谱替代书中对局。")
                        .font(.footnote).foregroundStyle(Palette.muted).lineSpacing(4)
                }.card()
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .pageStyle().navigationTitle("吴清源启蒙课").inlineTitle()
    }
}

struct WuLessonView: View {
    @EnvironmentObject private var store: AppStore
    let lesson: WuLesson
    @State private var shownMoves: Int
    @State private var selectedAnswer: Int?
    @State private var solved = false
    @State private var feedback = "先播放棋谱片段，再回答本课问题。"
    @State private var feedbackIsError = false

    init(lesson: WuLesson) {
        self.lesson = lesson
        _shownMoves = State(initialValue: lesson.focusMove)
    }

    private var position: (board: [Int], lastPoint: Int?) { lesson.position(after: shownMoves) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeading(eyebrow: "启蒙第 \(lesson.id + 1) 课 / \(WuCurriculum.lessons.count)",
                               title: lesson.theme, subtitle: lesson.intro)

                VStack(alignment: .leading, spacing: 7) {
                    Text("《吴清源自选百局》第 \(lesson.bookNumber) 局").font(.headline)
                    Text("\(lesson.date) · 黑：\(lesson.black) · 白：\(lesson.white)")
                    Text("结果：\(lesson.result)")
                    Text(lesson.sourceStatus).font(.caption).foregroundStyle(Palette.muted)
                }.font(.subheadline).card()

                BoardView(board: position.board, size: 19, lastPoint: position.lastPoint) { _ in }

                VStack(spacing: 12) {
                    HStack {
                        Button("上一手", systemImage: "chevron.left") { shownMoves = max(0, shownMoves - 1) }
                            .disabled(shownMoves == 0)
                        Spacer()
                        Text(shownMoves == 0 ? "初始局面" : "第 \(shownMoves) 手")
                            .font(.subheadline.weight(.medium)).monospacedDigit()
                        Spacer()
                        Button("下一手", systemImage: "chevron.right") {
                            shownMoves = min(lesson.moves.count, shownMoves + 1)
                        }.disabled(shownMoves == lesson.moves.count)
                    }.buttonStyle(.bordered)
                    Slider(value: Binding(get: { Double(shownMoves) },
                                          set: { shownMoves = Int($0.rounded()) }),
                           in: 0...Double(lesson.moves.count), step: 1)
                        .accessibilityLabel("棋谱播放进度")
                    Button("回到本课观察手数：第 \(lesson.focusMove) 手") { shownMoves = lesson.focusMove }
                        .font(.footnote)
                }.card()

                Text(lesson.prompt).font(.headline).lineSpacing(4)
                VStack(spacing: 10) {
                    ForEach(lesson.options.indices, id: \.self) { index in
                        Button { answer(index) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Text(String(Array("ABC")[index])).font(.headline).foregroundStyle(Palette.green)
                                Text(lesson.options[index]).frame(maxWidth: .infinity, alignment: .leading)
                                if selectedAnswer == index {
                                    Image(systemName: solved ? "checkmark.circle.fill" : "arrow.uturn.backward")
                                }
                            }
                            .padding(16)
                            .background(selectedAnswer == index ? Palette.sage : Palette.paper,
                                        in: RoundedRectangle(cornerRadius: 14))
                        }.buttonStyle(.plain).disabled(solved)
                    }
                }
                CoachNote(text: feedback, isError: feedbackIsError)
                if solved {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("本课棋理").font(.headline)
                        Text(lesson.takeaway).font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(4)
                    }.card()
                }
                Text("本课讲解为九三棋社教学改编，只使用历史棋谱事实与开局片段，不复刻书中评注。")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .pageStyle().navigationTitle(lesson.title).inlineTitle()
    }

    private func answer(_ index: Int) {
        selectedAnswer = index
        if index == lesson.answer {
            solved = true; feedbackIsError = false
            feedback = lesson.explanation
            store.completeWuLesson(lesson.id)
            TouchFeedback.success()
        } else {
            feedbackIsError = true
            feedback = "再播放一次本课片段，先确认棋盘上的事实，再比较三个答案。"
            TouchFeedback.move()
        }
    }
}
