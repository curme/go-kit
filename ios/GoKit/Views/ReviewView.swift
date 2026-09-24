import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var store: AppStore
    private var mistakes: [StudyLesson] {
        StudyCatalog.lessons.filter { store.studyProgress.needsReview($0) }
    }
    private var learned: [StudyLesson] {
        StudyCatalog.lessons.filter { store.studyProgress.learned.contains($0.id) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeading(eyebrow: "温故知新", title: "想明白一手，\n就进步一点。",
                    subtitle: "围绕100课查漏补缺。答错或用过提示的课，重新独立完成后移出待巩固。")
                ForEach(mistakes) { lesson in
                    NavigationLink { StudyLessonView(lesson: lesson) } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("第 \(lesson.id) 课 · 待巩固", systemImage: "arrow.counterclockwise").font(.caption)
                            Text(lesson.title).font(.headline)
                            Text("打开课程后，选择「重新独立练一轮」。").font(.subheadline).foregroundStyle(Palette.muted)
                        }.card()
                    }.buttonStyle(.plain)
                }
                if !store.training.review.isEmpty {
                    NavigationLink {
                        CoachSessionView(problems: CoachCurriculum.problems.filter { store.training.review.contains($0.id) })
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("专项练习 · \(store.training.review.count) 题待巩固", systemImage: "arrow.counterclockwise").font(.headline)
                            Text("新一轮独立答对后移出，提示与错误会继续保留。")
                                .font(.subheadline).foregroundStyle(Palette.muted)
                        }.card()
                    }.buttonStyle(.plain)
                }
                if mistakes.isEmpty && store.training.review.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "leaf").font(.largeTitle).foregroundStyle(Palette.green)
                        Text("暂时没有待巩固的内容").font(.headline)
                        Text("继续学习100课，遇到需要再练的内容，会自动记在这里。")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                    }.card()
                }
                if !learned.isEmpty {
                    Text("回顾已学课程").font(.title3.weight(.semibold))
                    ForEach(learned) { lesson in
                        NavigationLink { StudyLessonView(lesson: lesson) } label: {
                            VStack(alignment: .leading, spacing: 9) {
                                Text("第 \(lesson.id) 课 · \(lesson.title)").font(.headline)
                                Text(lesson.objective).font(.subheadline).foregroundStyle(Palette.muted).lineSpacing(4)
                            }.card()
                        }.buttonStyle(.plain)
                    }
                }
                NavigationLink { StudyHubView() } label: {
                    Label("查看100课学习路线", systemImage: "book.closed").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
                NavigationLink { StudyRecordsView() } label: {
                    Label("回看我的教学棋谱与笔记", systemImage: "books.vertical").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered)
                NavigationLink { StudySourcesView() } label: { Text("课程依据与学习说明") }
            }.padding(20).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.pageStyle().navigationTitle("温故知新").inlineTitle()
    }
}
