import SwiftUI

struct LearnView: View {
    var body: some View { StudyHubView() }
}

// Retained for legacy content compatibility; the learning and review tabs use StudyCatalog.
struct LessonView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var attempt: LessonAttempt
    @State private var showLiberties = false
    init(lesson: Lesson) { _attempt = State(initialValue: LessonAttempt(lesson)) }
    private var lesson: Lesson { attempt.lesson }
    private var liberties: Set<Int> {
        guard showLiberties else { return [] }
        return attempt.board.indices.filter { attempt.board[$0] == 1 }.reduce(into: Set<Int>()) {
            $0.formUnion(GoEngine.group(attempt.board, at: $1, size: lesson.size).liberties)
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeading(eyebrow: "第 \(lesson.id + 1) 课 / \(Curriculum.lessons.count)", title: lesson.headline, subtitle: lesson.intro)
                CoachNote(text: lesson.rule)
                Text(lesson.task).font(.headline).lineSpacing(4)
                BoardView(board: attempt.board, size: lesson.size, selected: attempt.selected,
                          liberties: liberties, hints: attempt.usedHint || lesson.id == 0 ? lesson.target : [],
                          lastPoint: attempt.solved && lesson.kind == .move ? attempt.selected.first : nil) { point in
                    attempt.tap(point); record()
                }
                if lesson.kind == .quiz {
                    VStack(spacing: 10) {
                        ForEach(lesson.options.indices, id: \.self) { index in
                            Button { attempt.answer(index); record() } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Text(String(Array("ABC")[index])).font(.headline).foregroundStyle(Palette.green)
                                    Text(lesson.options[index]).frame(maxWidth: .infinity, alignment: .leading)
                                    if attempt.selectedAnswer == index {
                                        Image(systemName: attempt.solved ? "checkmark.circle.fill" : "arrow.uturn.backward")
                                    }
                                }.padding(16).background(attempt.selectedAnswer == index ? Palette.sage : Palette.paper, in: RoundedRectangle(cornerRadius: 14))
                            }.buttonStyle(.plain).disabled(attempt.solved)
                        }
                    }
                }
                CoachNote(text: attempt.feedback, isError: attempt.feedbackIsError)
                if attempt.solved {
                    if !attempt.independently {
                        Text("本课已完成。稍后去复习页独立答对一次，就能移出待巩固列表。")
                            .font(.footnote).foregroundStyle(Palette.muted)
                    }
                    let isLastLesson = lesson.id == Curriculum.lessons.last?.id
                    PrimaryButton(title: isLastLesson ? "完成课程，返回学堂" : "继续下一课") {
                        if isLastLesson { dismiss() }
                        else {
                            let next = Curriculum.lessons[lesson.id + 1]
                            attempt = LessonAttempt(next); showLiberties = false
                            store.opened(next)
                        }
                    }
                } else {
                    Button { attempt.help(); store.record(attempt) } label: {
                        Label("给我一点提示", systemImage: "lightbulb").frame(maxWidth: .infinity).padding(14)
                    }.buttonStyle(.bordered)
                }
                HStack {
                    Button("重新练习", systemImage: "arrow.counterclockwise") {
                        attempt = LessonAttempt(lesson); showLiberties = false
                    }
                    Spacer()
                    Button(showLiberties ? "隐藏气" : "查看气", systemImage: "circle.dotted") {
                        showLiberties.toggle()
                        if showLiberties { attempt.usedHint = true }
                    }
                }.font(.subheadline).buttonStyle(.borderless).padding(.vertical, 8)
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }
        .id(lesson.id).pageStyle().navigationTitle(lesson.title).inlineTitle()
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } } }
        .onAppear { store.opened(lesson) }
    }
    private func record() {
        store.record(attempt)
        if attempt.solved { TouchFeedback.success() } else { TouchFeedback.move() }
    }
}
