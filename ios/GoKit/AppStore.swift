import Foundation
import Combine

private struct SavedLearning: Codable {
    var version = 1
    var progress: LearningProgress
    var game: PracticeGame
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var progress = LearningProgress()
    @Published private(set) var game = PracticeGame()
    @Published private(set) var training = TrainingProgress()
    @Published private(set) var captureGame = CaptureGame()
    @Published private(set) var wuProgress = WuLearningProgress()
    @Published private(set) var hundredDayProgress = HundredDayProgress()
    @Published private(set) var studyProgress = StudyProgress()
    @Published private(set) var studyRecords: [StudyRecord] = []
    @Published private(set) var studyPractice = StudyPractice()
    @Published var storageNotice: String?
    private let defaults: UserDefaults
    private let key = "go-kit.native-learning.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadCoach()
        loadWu()
        loadHundredDay()
        loadStudy()
        guard let data = defaults.data(forKey: key) else { return }
        do {
            let saved = try JSONDecoder().decode(SavedLearning.self, from: data)
            guard saved.version == 1, Self.valid(saved.game.position),
                  saved.game.undoPositions.allSatisfy(Self.valid) else {
                storageNotice = "保存记录的版本或棋盘格式无法读取，本次从初始状态开始。"
                return
            }
            progress = saved.progress
            let ids = Set(Curriculum.lessons.map(\.id))
            progress.completed.formIntersection(ids)
            progress.mistakes.formIntersection(ids)
            if !ids.contains(progress.lastLesson) { progress.lastLesson = 0 }
            game = saved.game
        } catch { storageNotice = "上次的本机记录无法读取，本次从初始状态开始。" }
    }

    nonisolated private static func valid(_ position: GamePosition) -> Bool {
        position.board.count == 81 && position.board.allSatisfy { (0...2).contains($0) }
            && position.captures.count == 2 && position.captures.allSatisfy { $0 >= 0 }
            && position.moves >= 0
            && (position.lastPoint == nil || (0..<81).contains(position.lastPoint!))
            && position.history.contains(GoEngine.hash(position.board))
            && position.turns.allSatisfy {
                $0.ply > 0 && $0.ply <= position.moves && ($0.color == 1 || $0.color == 2)
                    && (0..<81).contains($0.point) && $0.board.count == 81
                    && $0.board.allSatisfy { (0...2).contains($0) }
                    && $0.captured.allSatisfy { (0..<81).contains($0) }
            }
    }

    func opened(_ lesson: Lesson) { progress.lastLesson = lesson.id; save() }
    func record(_ attempt: LessonAttempt) {
        if attempt.madeMistake { progress.recordMistake(attempt.lesson.id) }
        if attempt.solved { progress.complete(attempt.lesson.id, independently: attempt.independently) }
        save()
    }
    func play(_ point: Int) throws { try game.play(point); save() }
    func pass() { game.pass(); save() }
    func resume() { game.resume(); save() }
    func undo() { game.undo(); save() }
    func retry(beforeTurn index: Int) { game.retry(beforeTurn: index); save() }
    func newGame() { game = PracticeGame(); save() }
    func recordTraining(_ attempt: TrainingAttempt) { training.record(attempt); save() }
    func completeGuidedTraining() { training.guidedCompleted = true; save() }
    func playCapture(_ point: Int) throws { try captureGame.play(point); save() }
    func passCapture() { captureGame.pass(); save() }
    func undoCapture() { captureGame.undo(); save() }
    func newCaptureGame() { captureGame = CaptureGame(); save() }
    func completeWuLesson(_ id: Int) { wuProgress.complete(id); save() }
    func setHundredDayTask(_ task: HundredDayTask, completed: Bool) {
        hundredDayProgress.setCompleted(completed, taskID: task.id)
        save()
    }
    func recordStudy(_ attempt: StudyAttempt, lesson: StudyLesson) {
        studyProgress.record(attempt, lesson: lesson); save()
    }
    func restartStudy(_ lesson: StudyLesson) { studyProgress.restart(lesson); save() }
    func recordStudyApplication(_ id: Int, complete: Bool) {
        if complete { studyProgress.applications.insert(id) } else { studyProgress.applications.remove(id) }
        save()
    }
    func updateStudyPractice(_ value: StudyPractice) {
        guard value.isValid else { return }
        studyPractice = value; save()
    }
    @discardableResult func archiveStudyPractice(_ game: StudyPractice) -> Bool {
        guard game.isValid, !game.turns.isEmpty, studyRecords.count < 10 else { return false }
        studyRecords.insert(StudyRecord(game: game), at: 0); save(); return true
    }
    func removeStudyRecord(_ id: UUID) { studyRecords.removeAll { $0.id == id }; save() }
    private func loadStudy() {
        if let data = defaults.data(forKey: "go-kit.study-records.v1") {
            do {
                let value = try JSONDecoder().decode([StudyRecord].self, from: data)
                guard value.count <= 10, value.allSatisfy({ $0.game.isValid }) else { throw CocoaError(.coderReadCorrupt) }
                studyRecords = value
            } catch { storageNotice = "保存的教学棋谱无法读取，当前棋局与课程记录仍可使用。" }
        }
        if let data = defaults.data(forKey: StudyCatalog.storageKey) {
            do {
                let value = try JSONDecoder().decode(StudyProgress.self, from: data)
                guard value.version == 1 else { throw CocoaError(.coderReadCorrupt) }
                studyProgress = value; studyProgress.sanitize()
            } catch { storageNotice = "新版课程记录无法读取，已从初始进度开始；旧课程记录保留。" }
        }
        if let data = defaults.data(forKey: "go-kit.study-practice.v1") {
            do {
                let value = try JSONDecoder().decode(StudyPractice.self, from: data)
                guard value.isValid else { throw CocoaError(.coderReadCorrupt) }
                studyPractice = value
            } catch { storageNotice = "教学棋盘记录无法读取，课程进度不受影响。" }
        }
    }
    private func loadCoach() {
        guard let data = defaults.data(forKey: "go-kit.native-coach.v1") else { return }
        do {
            let saved = try JSONDecoder().decode(SavedCoach.self, from: data)
            guard saved.version == 1, saved.capture.isValid else {
                storageNotice = "教练带练记录无法读取，已重置带练记录；原入门课程记录不受影响。"
                return
            }
            training = saved.progress; training.sanitize(); captureGame = saved.capture
        } catch { storageNotice = "教练带练记录无法读取，已从初始状态开始。" }
    }
    private func loadWu() {
        guard let data = defaults.data(forKey: WuCurriculum.storageKey) else { return }
        do { wuProgress = try WuCurriculum.decode(data) }
        catch { storageNotice = "吴清源启蒙课记录无法读取，已重置；其他学习记录不受影响。" }
    }
    private func loadHundredDay() {
        guard let data = defaults.data(forKey: HundredDayPlan.storageKey) else { return }
        do {
            hundredDayProgress = try JSONDecoder().decode(HundredDayProgress.self, from: data)
            hundredDayProgress.sanitize()
        } catch { storageNotice = "百日计划记录无法读取，已重置；其他学习记录不受影响。" }
    }
    func save() {
        do {
            let data = try JSONEncoder().encode(SavedLearning(progress: progress, game: game))
            defaults.set(data, forKey: key)
            let coachData = try JSONEncoder().encode(SavedCoach(progress: training, capture: captureGame))
            defaults.set(coachData, forKey: "go-kit.native-coach.v1")
            defaults.set(try WuCurriculum.encode(wuProgress), forKey: WuCurriculum.storageKey)
            defaults.set(try JSONEncoder().encode(hundredDayProgress), forKey: HundredDayPlan.storageKey)
            defaults.set(try JSONEncoder().encode(studyProgress), forKey: StudyCatalog.storageKey)
            defaults.set(try JSONEncoder().encode(studyRecords), forKey: "go-kit.study-records.v1")
            defaults.set(try JSONEncoder().encode(studyPractice), forKey: "go-kit.study-practice.v1")
        } catch { storageNotice = "本次记录没有保存成功，请暂时不要退出 App。" }
    }
}
