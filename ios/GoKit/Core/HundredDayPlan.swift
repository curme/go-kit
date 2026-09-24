import Foundation

enum HundredDayAction {
    case lesson(Int)
    case training([String])
    case capture
    case practice
    case review
    case wu(Int)
}

enum HundredDayTaskKind: String {
    case learn = "今日棋理"
    case drill = "专项训练"
    case play = "落盘巩固"

    var icon: String {
        switch self {
        case .learn: return "book.closed"
        case .drill: return "scope"
        case .play: return "square.grid.3x3"
        }
    }
}

struct HundredDayTask: Identifiable {
    let id: String
    let kind: HundredDayTaskKind
    let title: String
    let detail: String
    let minutes: Int
    let action: HundredDayAction
}

struct HundredDayStage: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let days: ClosedRange<Int>
    let icon: String
}

struct HundredDayDay: Identifiable {
    let id: Int
    let stageID: Int
    let theme: String
    let coachLine: String
    let tasks: [HundredDayTask]

    var totalMinutes: Int { tasks.reduce(0) { $0 + $1.minutes } }
}

enum HundredDayPlan {
    static let storageKey = "go-kit.native-hundred-days.v1"

    static let stages = [
        HundredDayStage(id: 0, title: "先学会吃子", subtitle: "数气、打吃、提子与救棋", days: 1...7, icon: "circle.grid.cross"),
        HundredDayStage(id: 1, title: "把对杀算清", subtitle: "比较气、制造先手与寻找要点", days: 8...28, icon: "bolt"),
        HundredDayStage(id: 2, title: "认出死活要点", subtitle: "真眼、假眼、常见眼形与劫活", days: 29...42, icon: "eye"),
        HundredDayStage(id: 3, title: "学会围地数目", subtitle: "边界、归属、效率与基础官子", days: 43...49, icon: "square.dashed"),
        HundredDayStage(id: 4, title: "手筋、定式与布局", subtitle: "连接、攻击、方向与全局选择", days: 50...70, icon: "point.3.connected.trianglepath.dotted"),
        HundredDayStage(id: 5, title: "九路实战与复盘", subtitle: "完整对局、关键手与重新下", days: 71...90, icon: "arrow.trianglehead.2.clockwise.rotate.90"),
        HundredDayStage(id: 6, title: "十九路与名局启蒙", subtitle: "走向大棋盘，跟名局学习全局", days: 91...100, icon: "sparkles")
    ]

    private static let themes: [[String]] = [
        ["交叉点与气", "封住最后一口气", "整块棋一起提", "被打吃先救棋", "边角的气更少", "连接以后共享气", "吃子阶段小测"],
        ["先数双方的气", "长气与紧气", "先手打吃", "有眼杀无眼", "公气怎么计算", "先提还是先逃", "对杀前先找弱棋"],
        ["两个真眼", "识破假眼", "直三的要点", "曲三的要点", "方四与关键点", "扩大自己的眼位", "缩小对方的眼位"],
        ["围住才算地", "边界必须完整", "空地与未归属点", "角、边、中腹的效率", "数黑白双方的地", "先手官子", "地盘阶段小测"],
        ["守住断点", "虎口与竹节", "征子先看全盘", "枷吃与倒扑", "从宽处开局", "急场大于大场", "攻击为了获利"],
        ["落子前十秒", "最弱的一块先走", "三个候选点", "读清下一手", "暂停以后看全盘", "找出本局关键手", "从错误之前重下", "比较实地与厚势", "先手与后手", "自己说出复盘结论"],
        ["十九路先占角", "角边中腹的次序", "开局不要贴线爬", "一手棋照顾全盘", "厚势不要围小空", "该守还是该转身", "播放一段吴清源名局", "观察双方最弱的棋", "从名局提出候选点", "完成百日回顾"]
    ]

    private static let lessonPools: [[Int]] = [
        [0, 1, 2, 3, 8, 9, 11],
        [1, 8, 9, 10, 11, 12, 13, 23, 24, 25, 26, 27],
        [5, 14, 15, 28, 29, 30, 31, 32, 33, 34, 35],
        [7, 18, 19, 36, 42, 43],
        Array(20...27) + Array(36...43),
        Array(36...47),
        [36, 37, 38, 39, 40, 41, 42, 44, 45, 46, 47]
    ]

    static let days: [HundredDayDay] = (1...100).map(makeDay)

    static func stage(for day: Int) -> HundredDayStage {
        stages.first { $0.days.contains(day) } ?? stages[0]
    }

    static func day(_ id: Int) -> HundredDayDay? { days.first { $0.id == id } }

    private static func makeDay(_ number: Int) -> HundredDayDay {
        let stage = stage(for: number)
        let offset = number - stage.days.lowerBound
        let stageThemes = themes[stage.id]
        let theme = stageThemes[offset % stageThemes.count]
        let lessonPool = lessonPools[stage.id]
        let lessonID = lessonPool[offset % lessonPool.count]
        let lesson = Curriculum.lessons[lessonID]
        let prefix = String(format: "day-%03d", number)

        let lessonTask = HundredDayTask(
            id: "\(prefix)-learn", kind: .learn,
            title: "第 \(lesson.id + 1) 课 · \(lesson.title)",
            detail: "围绕“\(theme)”学习一条能立刻使用的棋理。",
            minutes: 5, action: .lesson(lessonID)
        )
        let drillTask = makeDrill(stage: stage, offset: offset, prefix: prefix, lessonID: lessonID)
        let playTask = makePlay(stage: stage, offset: offset, prefix: prefix)
        return HundredDayDay(
            id: number, stageID: stage.id, theme: theme,
            coachLine: coachLine(stageID: stage.id), tasks: [lessonTask, drillTask, playTask]
        )
    }

    private static func makeDrill(stage: HundredDayStage, offset: Int, prefix: String, lessonID: Int) -> HundredDayTask {
        switch stage.id {
        case 0:
            let pools = [["count-center", "capture-one"], ["count-edge", "capture-corner"],
                         ["count-group", "capture-pair"], ["rescue-one", "rescue-corner"]]
            return HundredDayTask(id: "\(prefix)-drill", kind: .drill, title: "数气与提子练习",
                                  detail: "完成 2 道五路小棋盘题，先数气再落子。", minutes: 6,
                                  action: .training(pools[offset % pools.count]))
        case 1:
            let ids = ["count-group", "capture-one", "capture-pair", "rescue-one", "rescue-corner", "connect-center", "connect-edge"]
            let picked = (0..<3).map { ids[(offset + $0) % ids.count] }
            return HundredDayTask(id: "\(prefix)-drill", kind: .drill, title: "对杀基本功",
                                  detail: "完成 3 道数气、提子、救棋或连接题。", minutes: 8,
                                  action: .training(picked))
        case 2:
            let id = lessonPools[2][(offset + 1) % lessonPools[2].count]
            return HundredDayTask(id: "\(prefix)-drill", kind: .drill, title: "死活换形再判断",
                                  detail: "再练一个相关眼形，找双方的关键点。", minutes: 6,
                                  action: .lesson(id))
        case 3:
            return HundredDayTask(id: "\(prefix)-drill", kind: .drill, title: "打开地盘估算",
                                  detail: "在九路棋盘走几手，观察归属点怎样变化。", minutes: 8,
                                  action: .practice)
        case 4:
            let id = lessonPools[4][(offset + 5) % lessonPools[4].count]
            return HundredDayTask(id: "\(prefix)-drill", kind: .drill, title: "手筋与方向复习",
                                  detail: "换一道棋形，先提出三个候选点再作答。", minutes: 7,
                                  action: .lesson(id))
        case 5:
            return HundredDayTask(id: "\(prefix)-drill", kind: .drill, title: "复习待巩固内容",
                                  detail: "优先重做答错或使用过提示的课程和练习。", minutes: 7,
                                  action: .review)
        default:
            let wuID = offset % WuCurriculum.lessons.count
            return HundredDayTask(id: "\(prefix)-drill", kind: .drill, title: "名局观察 · \(WuCurriculum.lessons[wuID].theme)",
                                  detail: "播放开局片段，观察棋子如何在全盘呼应。", minutes: 8,
                                  action: .wu(wuID))
        }
    }

    private static func makePlay(stage: HundredDayStage, offset: Int, prefix: String) -> HundredDayTask {
        switch stage.id {
        case 0, 1:
            return HundredDayTask(id: "\(prefix)-play", kind: .play, title: "五路吃子挑战",
                                  detail: "下一局先提子获胜，落子前检查双方最后一口气。", minutes: 8,
                                  action: .capture)
        case 6 where offset % 2 == 0:
            let wuID = (offset + 3) % WuCurriculum.lessons.count
            return HundredDayTask(id: "\(prefix)-play", kind: .play, title: "十九路名局跟摆",
                                  detail: "播放另一局历史片段，并用一句话说出全盘方向。", minutes: 10,
                                  action: .wu(wuID))
        default:
            return HundredDayTask(id: "\(prefix)-play", kind: .play, title: "九路实战与复盘",
                                  detail: "至少完成一轮落子，暂停后查看关键手和地盘。", minutes: 12,
                                  action: .practice)
        }
    }

    private static func coachLine(stageID: Int) -> String {
        [
            "今天只盯一件事：每次落子前先数气。",
            "对杀不是比谁胆大，而是把双方的气一口一口算清。",
            "死活先找眼位，再找双方都想占的要点。",
            "地盘要有完整边界；还会被冲破的空，先别急着数。",
            "先看全盘最急的地方，再决定局部该不该继续。",
            "一盘棋最有价值的时刻，是下完以后找到可以重来的一手。",
            "十九路很大，仍然从气、连接、强弱和方向这些基本功开始。"
        ][stageID]
    }
}

struct HundredDayProgress: Codable, Equatable {
    private(set) var completedTaskIDs: Set<String> = []

    mutating func setCompleted(_ completed: Bool, taskID: String) {
        if completed { completedTaskIDs.insert(taskID) }
        else { completedTaskIDs.remove(taskID) }
    }

    func isTaskComplete(_ task: HundredDayTask) -> Bool { completedTaskIDs.contains(task.id) }

    func isDayComplete(_ day: HundredDayDay) -> Bool {
        !day.tasks.isEmpty && day.tasks.allSatisfy { completedTaskIDs.contains($0.id) }
    }

    var completedDays: Int { HundredDayPlan.days.filter(isDayComplete).count }

    var currentDay: Int {
        HundredDayPlan.days.first { !isDayComplete($0) }?.id ?? 100
    }

    var currentStreak: Int {
        let finished = Set(HundredDayPlan.days.filter(isDayComplete).map(\.id))
        var cursor = completedDays == 100 ? 100 : max(0, currentDay - 1)
        var result = 0
        while cursor > 0, finished.contains(cursor) { result += 1; cursor -= 1 }
        return result
    }

    mutating func sanitize() {
        let valid = Set(HundredDayPlan.days.flatMap(\.tasks).map(\.id))
        completedTaskIDs.formIntersection(valid)
    }
}
