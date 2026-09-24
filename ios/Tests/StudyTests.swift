import Foundation

extension EngineTests {
    @MainActor static func runStudyTests() throws {
        let lessons = StudyCatalog.lessons
        check(lessons.map(\.id) == Array(1...100), "System course has stable 100 IDs")
        check(lessons.filter(\.assessment).count == 10, "Ten cumulative assessments")
        check(lessons.flatMap(\.exercises).count == 650, "550 knowledge checks plus 100 board tasks")
        check(Set(lessons.flatMap(\.exercises).map(\.id)).count == 650, "Unique exercise storage keys")
        var progress = StudyProgress()
        for lesson in lessons {
            check(!lesson.explanation.isEmpty && !lesson.application.contains("；K"), "Lesson content present and no authoring shorthand")
            check(lesson.exercises.count == (lesson.assessment ? 11 : 6), "Exercise counts")
            for exercise in lesson.exercises {
                if !exercise.board.isEmpty {
                    check(exercise.board.count == exercise.size * exercise.size, "Diagram dimensions \(exercise.id)")
                    for p in exercise.board.indices where exercise.board[p] != 0 {
                        check(!GoEngine.group(exercise.board, at: p, size: exercise.size).liberties.isEmpty, "No dead initial group \(exercise.id)")
                    }
                }
                var attempt = StudyAttempt(exercise)
                if exercise.isBoardTask {
                    for branch in exercise.branches {
                        var b = exercise.board
                        var history: Set<String> = [GoEngine.hash(b)]
                        for (i, p) in branch.enumerated() {
                            do {
                                b = try GoEngine.play(b, at: p, color: i % 2 + 1, size: exercise.size, history: history).board
                            } catch { fatalError("Illegal authored line \(exercise.id), move \(i) at \(p): \(error)") }
                            check(!history.contains(GoEngine.hash(b)), "No repeated diagram position")
                            history.insert(GoEngine.hash(b))
                        }
                    }
                    for p in stride(from: 0, to: exercise.branches[0].count, by: 2) { attempt.play(exercise.branches[0][p]) }
                } else {
                    check(exercise.options.indices.contains(exercise.answer), "Answer is selectable")
                    var wrong = StudyAttempt(exercise); wrong.answer(1 - exercise.answer)
                    check(wrong.mistake && !wrong.solved, "Wrong answer remains incomplete")
                    wrong.answer(exercise.answer)
                    check(wrong.solved && !wrong.independent, "Correcting same attempt doesn't erase mistake")
                    attempt.answer(exercise.answer)
                }
                check(attempt.solved && attempt.independent, "Exercise can finish independently: \(exercise.id)")
                progress.record(attempt, lesson: lesson)
            }
            check(progress.passed(lesson) && !progress.needsReview(lesson), "Independent complete lesson passes")
        }
        check(progress.learned.count == 100 && progress.activeDates.count == 1, "Completion and distinct learning days")
        let ladder = StudyDiagrams.task(for: 21)!
        var read = StudyAttempt(ladder)
        read.play(13)
        check(read.played == [13,17] && !read.solved && read.board[12] == 2, "Ladder needs continuation after reply")
        read.play(22); read.play(19); read.play(24)
        check(read.solved && [12,17,18,23].allSatisfy { read.board[$0] == 0 }, "Ladder actually captures four stones")
        let connectFailure = StudyDiagrams.task(for: 26)!
        for branch in connectFailure.branches {
            var b = connectFailure.board
            for (i,p) in branch.enumerated() { b = try GoEngine.play(b, at: p, color: i % 2 + 1, size: 5).board }
            check(b[1] == 0, "Both connecting and declining fail to save original white B5")
        }
        let snapback = StudyDiagrams.task(for: 28)!
        var snap = StudyAttempt(snapback); snap.play(0)
        check(snap.board[0] == 0 && snap.board[1] == 2 && !snap.solved, "Sacrifice is captured before recapture")
        snap.play(0)
        check(snap.solved && [1,5,6].allSatisfy { snap.board[$0] == 0 }, "Snapback captures three, not a ko repetition")
        var wrongMove = StudyAttempt(StudyDiagrams.task(for: 3)!)
        wrongMove.play(0)
        check(wrongMove.mistake && wrongMove.played.isEmpty && wrongMove.board == wrongMove.exercise.board, "Wrong legal move preserves retry position")
        wrongMove.play(7)
        check(!wrongMove.solved && wrongMove.played.isEmpty, "Occupied move rejected")
        let lesson = lessons[0]
        var afterCompletion = StudyAttempt(lesson.exercises.last!); afterCompletion.help()
        progress.record(afterCompletion, lesson: lesson)
        check(progress.passed(lesson) && !progress.needsReview(lesson), "Reading demo after completion does not downgrade earned result")
        progress.restart(lesson)
        var hinted = StudyAttempt(lesson.exercises[0]); hinted.help()
        progress.record(hinted, lesson: lesson)
        let resumed = StudyAttempt(hinted.exercise, prior: progress.results[hinted.exercise.id])
        check(resumed.hinted, "Hint survives exiting interrupted question")
        progress.restart(lesson)
        check(progress.learned.contains(1) && !progress.passed(lesson) && progress.needsReview(lesson), "Restart preserves learned and review debt")
        for ex in lesson.exercises {
            var a = StudyAttempt(ex)
            if ex.isBoardTask { a.play(12) } else { a.answer(ex.answer) }
            progress.record(a, lesson: lesson)
        }
        check(progress.passed(lesson) && !progress.needsReview(lesson), "New independent round clears review")
        progress.results["unknown"] = StudyResult(solved: true)
        progress.learned.insert(101); progress.review.insert(101); progress.lastLesson = 999
        progress.sanitize()
        check(progress.results["unknown"] == nil && !progress.learned.contains(101) && !progress.review.contains(101) && progress.lastLesson == 1, "Stale course data sanitized")
        let encoded = try JSONEncoder().encode(progress)
        let decodedProgress = try JSONDecoder().decode(StudyProgress.self, from: encoded)
        check(decodedProgress.learned.count == 100, "Progress round-trip")
        for size in [9,13,19] {
            var game = StudyPractice(size: size)
            try game.play(0); try game.play(size + 1); try game.play(1)
            check(game.isValid && game.turn == 2 && game.turns.count == 3, "Teaching board alternation \(size)")
            game.pass(); game.pass()
            check(game.paused && game.passes == 2, "Two passes enters adjudication")
            game.toggleDead(0)
            check(game.dead == [0,1], "Dead group marked together")
            game.confirmed = true; game.toggleDead(1)
            check(game.dead.isEmpty && !game.confirmed, "Changed dead marking invalidates confirmation")
            game.resume(); try game.play(2)
            check(!game.paused && game.board[2] == 2 && game.isValid, "Resume after dispute allows move")
            game.undo()
            check(game.board[2] == 0 && game.turn == 2, "Undo restores prior board and turn")
            let data = try JSONEncoder().encode(game)
            let decodedGame = try JSONDecoder().decode(StudyPractice.self, from: data)
            check(decodedGame.isValid, "Practice round-trip")
            game.board[3] = 3
            check(!game.isValid, "Corrupt board rejected")
        }
        let suite = "GoKit.StudyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppStore(defaults: defaults)
        store.recordStudy(hinted, lesson: lesson)
        store.recordStudyApplication(1, complete: true)
        var game = StudyPractice(size: 13); try game.play(42); game.reflection = "先检查弱棋。"
        store.updateStudyPractice(game)
        var legacy = LessonAttempt(Curriculum.lessons[0]); legacy.tap(12); store.record(legacy)
        let restored = AppStore(defaults: defaults)
        check(restored.studyProgress.needsReview(lesson) && restored.studyProgress.applications == [1], "Study and application persistence")
        check(restored.studyPractice.board[42] == 1 && restored.studyPractice.reflection == game.reflection, "Practice and notes persisted")
        check(restored.progress.completed == store.progress.completed, "Legacy learning not replaced")
        check(restored.archiveStudyPractice(game), "Archive a played game")
        let saved = AppStore(defaults: defaults)
        check(saved.studyRecords.count == 1 && saved.studyRecords[0].game.reflection == game.reflection, "Archive reload includes notes")
        var fork = game; fork.retry(after: 0)
        check(fork.board == GoEngine.empty(13) && fork.turn == 1 && fork.turns.isEmpty && fork.isValid, "Retry before first move")
        check(game.board[42] == 1 && saved.studyRecords[0].game.board[42] == 1, "Replay fork does not mutate archived source")
        check(fork.position(at: 3) == GoEngine.empty(13), "Empty replay clamps out-of-range ply")
        for _ in 0..<9 { check(saved.archiveStudyPractice(game), "Archive has room") }
        check(!saved.archiveStudyPractice(game) && saved.studyRecords.count == 10, "Full archive preserves older records")
        saved.removeStudyRecord(saved.studyRecords[0].id)
        check(saved.studyRecords.count == 9 && saved.archiveStudyPractice(game), "Explicit archive removal frees one slot")
        defaults.set(Data("corrupt".utf8), forKey: StudyCatalog.storageKey)
        check(AppStore(defaults: defaults).storageNotice != nil, "Corrupt new-course progress is reported")
    }
}
