import CoreData
import Foundation

@MainActor
enum DemoDataService {
    private static let demoDataVersion = 3
    private static let demoDataVersionKey = "GoalTracker.demoDataVersion"

    static let sampleValueNames = [
        "Dharma",
        "Brahmacharya",
        "Health",
        "Career Excellence",
        "Family Welfare",
        "Sadhana",
        "Financial Stability",
        "Knowledge",
        "Discipline",
        "Seva",
        "Simplicity",
        "Inner Purity"
    ]

    static func seedIfEmpty(in context: NSManagedObjectContext) {
        let existingValues = (try? context.fetchAll(CoreValue.self)) ?? []
        let existingGoals = (try? context.fetchAll(Goal.self)) ?? []

        if UserDefaults.standard.integer(forKey: demoDataVersionKey) < demoDataVersion {
            guard existingValues.isEmpty && existingGoals.isEmpty || isKnownDemoData(goals: existingGoals) else {
                UserDefaults.standard.set(demoDataVersion, forKey: demoDataVersionKey)
                return
            }
            installDemoData(in: context, markInstalled: true)
            return
        }

        guard existingValues.isEmpty && existingGoals.isEmpty else { return }
        installDemoData(in: context, markInstalled: true)
    }

    static func installDemoData(in context: NSManagedObjectContext, markInstalled: Bool = true) {
        clearAllData(in: context)

        let values = sampleValueNames.map { name in
            CoreValue(context: context, name: name, valueDescription: defaultDescription(for: name))
        }

        installExpandedDemoData(values: values, in: context, markInstalled: markInstalled)
    }

    static func replaceTrackerDataPreservingValues(in context: NSManagedObjectContext) {
        let values = (try? context.fetchAll(CoreValue.self)) ?? []
        clearTrackerDataPreservingValues(in: context)
        installExpandedDemoData(values: values, in: context, markInstalled: true)
    }

    private static func installExpandedDemoData(
        values: [CoreValue],
        in context: NSManagedObjectContext,
        markInstalled: Bool
    ) {
        let now = Date()
        let calendar = Calendar.current

        func date(daysFromToday days: Int, hour: Int = 9) -> Date {
            let day = calendar.date(byAdding: .day, value: days, to: now) ?? now
            let start = calendar.startOfDay(for: day)
            return calendar.date(byAdding: .hour, value: hour, to: start) ?? start
        }

        func value(_ name: String) -> CoreValue? {
            values.first { $0.name == name }
        }

        @discardableResult
        func task(
            _ name: String,
            milestone: Milestone,
            priority: TaskPriority,
            status: TaskStatus,
            type: TaskType,
            description: String,
            estimatedMinutes: Int,
            resultNotes: String = ""
        ) -> TaskItem {
            TaskItem(
                context: context,
                name: name,
                milestone: milestone,
                priority: priority,
                status: status,
                taskType: type,
                taskDescription: description,
                estimatedMinutes: estimatedMinutes,
                resultNotes: resultNotes
            )
        }

        @discardableResult
        func standaloneTask(
            _ name: String,
            priority: TaskPriority,
            status: TaskStatus,
            type: TaskType,
            description: String,
            estimatedMinutes: Int,
            resultNotes: String = "",
            createdDaysFromToday: Int
        ) -> TaskItem {
            let created = date(daysFromToday: createdDaysFromToday, hour: 8)
            return TaskItem(
                context: context,
                name: name,
                milestone: nil,
                priority: priority,
                status: status,
                taskType: type,
                taskDescription: description,
                estimatedMinutes: estimatedMinutes,
                resultNotes: resultNotes,
                createdAt: created,
                updatedAt: created
            )
        }

        @discardableResult
        func addSession(
            task: TaskItem,
            label: String,
            expectedMinutes: Int,
            actualMinutes: Int,
            status: SessionStatus,
            daysFromToday: Int?,
            notes: String
        ) -> WorkSession {
            let sessionMoment = daysFromToday.map { date(daysFromToday: $0, hour: 10) }
            return WorkSession(
                context: context,
                task: task,
                sessionLabel: label,
                estimatedMinutes: expectedMinutes,
                actualMinutes: actualMinutes,
                expectedResult: label,
                whatText: "Focused execution for \(task.name)",
                whenText: sessionMoment.map { DateUtils.displayDate($0) } ?? "Planned next focus block",
                whyText: task.milestone?.goal?.antiGoal.isEmpty == false ? "Avoid \(task.milestone?.goal?.antiGoal ?? "drift")" : "Move the task forward with clarity.",
                howText: "Single-task, timer-led, no context switching.",
                howMuchText: Formatters.minutes(expectedMinutes),
                status: status,
                sessionDate: sessionMoment,
                sessionNotes: notes,
                createdAt: sessionMoment ?? date(daysFromToday: 1, hour: 8)
            )
        }

        let backendGoal = Goal(
            context: context,
            name: "Become FAANG-level Backend Engineer through disciplined deep work",
            priority: .high,
            startDate: date(daysFromToday: -30),
            endDate: date(daysFromToday: 270),
            progress: 0,
            antiGoal: "Scattered preparation and ego-driven comparison",
            sacrifice: "Entertainment, unfocused browsing, and late-night drift",
            coreValues: [value("Career Excellence"), value("Knowledge"), value("Discipline"), value("Dharma")].compactMap { $0 }
        )

        let strengthGoal = Goal(
            context: context,
            name: "Build strong body and prana for steady sadhana",
            priority: .high,
            startDate: date(daysFromToday: -18),
            endDate: date(daysFromToday: 180),
            progress: 0,
            antiGoal: "Sedentary lifestyle and tamasic routine",
            sacrifice: "Laziness, irregular food, and screen-led evenings",
            coreValues: [value("Health"), value("Brahmacharya"), value("Discipline")].compactMap { $0 }
        )

        let sadhanaGoal = Goal(
            context: context,
            name: "Stabilize daily sadhana and inner purity",
            priority: .high,
            startDate: date(daysFromToday: -7),
            endDate: date(daysFromToday: 120),
            progress: 0,
            antiGoal: "Mechanical practice without attention",
            sacrifice: "Late nights and scattered mornings",
            coreValues: [value("Sadhana"), value("Inner Purity"), value("Dharma")].compactMap { $0 }
        )

        let financeGoal = Goal(
            context: context,
            name: "Practice disciplined financial stability and simplicity",
            priority: .medium,
            startDate: date(daysFromToday: 14),
            endDate: date(daysFromToday: 210),
            progress: 0,
            antiGoal: "Untracked spending and reactive money decisions",
            sacrifice: "Impulse purchases and lifestyle creep",
            coreValues: [value("Financial Stability"), value("Simplicity")].compactMap { $0 }
        )

        let sevaGoal = Goal(
            context: context,
            name: "Serve family through Dharma and steady presence",
            priority: .medium,
            startDate: date(daysFromToday: -45),
            endDate: date(daysFromToday: 90),
            progress: 0,
            antiGoal: "Being physically present but mentally absent",
            sacrifice: "Low-value screen time during family hours",
            coreValues: [value("Family Welfare"), value("Seva"), value("Dharma")].compactMap { $0 }
        )

        let brahmacharyaGoal = Goal(
            context: context,
            name: "Preserve Brahmacharya through clean digital restraint",
            priority: .high,
            startDate: date(daysFromToday: -12),
            endDate: date(daysFromToday: 100),
            progress: 0,
            antiGoal: "Leaking attention through impulse and stimulation",
            sacrifice: "Cheap dopamine, random scrolling, and careless evenings",
            coreValues: [value("Brahmacharya"), value("Inner Purity"), value("Discipline"), value("Simplicity")].compactMap { $0 }
        )

        let knowledgeGoal = Goal(
            context: context,
            name: "Convert Knowledge into lived Dharma and useful skill",
            priority: .medium,
            startDate: date(daysFromToday: 7),
            endDate: date(daysFromToday: 160),
            progress: 0,
            antiGoal: "Collecting information without practice",
            sacrifice: "Passive consumption and shallow curiosity",
            coreValues: [value("Knowledge"), value("Dharma"), value("Simplicity")].compactMap { $0 }
        )

        let devotionGoal = Goal(
            context: context,
            name: "Build devotional deep work operating rhythm",
            priority: .high,
            startDate: date(daysFromToday: -3),
            endDate: date(daysFromToday: 180),
            progress: 0,
            antiGoal: "Busy motion without inner offering",
            sacrifice: "Context switching and noisy mornings",
            coreValues: [value("Dharma"), value("Sadhana"), value("Discipline")].compactMap { $0 }
        )

        let writingGoal = Goal(
            context: context,
            name: "Publish disciplined engineering learning essays",
            priority: .medium,
            startDate: date(daysFromToday: 20),
            endDate: date(daysFromToday: 220),
            progress: 0,
            antiGoal: "Private learning with no clear output",
            sacrifice: "Perfectionism and endless draft hoarding",
            coreValues: [value("Knowledge"), value("Career Excellence"), value("Simplicity")].compactMap { $0 }
        )

        let systemsGoal = Goal(
            context: context,
            name: "Simplify home and digital operating system",
            priority: .low,
            startDate: date(daysFromToday: -20),
            endDate: date(daysFromToday: 130),
            progress: 0,
            antiGoal: "Cluttered environment causing scattered attention",
            sacrifice: "Unused tools, duplicate systems, and visual noise",
            coreValues: [value("Simplicity"), value("Discipline"), value("Inner Purity")].compactMap { $0 }
        )

        let hiringSignalGoal = Goal(
            context: context,
            name: "Prepare humble high-signal hiring presence",
            priority: .medium,
            startDate: date(daysFromToday: -2),
            endDate: date(daysFromToday: 160),
            progress: 0,
            antiGoal: "Inflated self-presentation without proof",
            sacrifice: "Vague claims and unreviewed portfolio gaps",
            coreValues: [value("Career Excellence"), value("Dharma"), value("Knowledge")].compactMap { $0 }
        )

        let backendCompleted = Milestone(context: context, name: "Build Swift concurrency foundation", goal: backendGoal, startDate: date(daysFromToday: -30), endDate: date(daysFromToday: -21), progress: 0)
        let backendFoundations = Milestone(context: context, name: "Master backend fundamentals as craft tapas", goal: backendGoal, startDate: date(daysFromToday: -20), endDate: date(daysFromToday: 30), progress: 0)
        let backendPortfolio = Milestone(context: context, name: "Ship production-grade portfolio API service", goal: backendGoal, startDate: date(daysFromToday: 31), endDate: date(daysFromToday: 90), progress: 0)
        let backendInterview = Milestone(context: context, name: "Complete focused interview tapas sprint", goal: backendGoal, startDate: date(daysFromToday: 91), endDate: date(daysFromToday: 140), progress: 0)
        let backendCaseStudy = Milestone(context: context, name: "Publish disciplined backend case study", goal: backendGoal, startDate: date(daysFromToday: 141), endDate: date(daysFromToday: 270), progress: 0)

        let strengthCompleted = Milestone(context: context, name: "Clean up sleep, hydration, and food rhythm", goal: strengthGoal, startDate: date(daysFromToday: -18), endDate: date(daysFromToday: -11), progress: 0)
        let strengthPractice = Milestone(context: context, name: "Establish daily strength and prana practice", goal: strengthGoal, startDate: date(daysFromToday: -10), endDate: date(daysFromToday: 45), progress: 0)
        let mobilityBreath = Milestone(context: context, name: "Build mobility, breath, and nervous system baseline", goal: strengthGoal, startDate: date(daysFromToday: 46), endDate: date(daysFromToday: 90), progress: 0)
        let enduranceReset = Milestone(context: context, name: "Complete sattvic endurance reset", goal: strengthGoal, startDate: date(daysFromToday: 91), endDate: date(daysFromToday: 180), progress: 0)

        let sadhanaMorning = Milestone(context: context, name: "Stabilize morning japa and reading", goal: sadhanaGoal, startDate: date(daysFromToday: -7), endDate: date(daysFromToday: 120), progress: 0)
        let financeBudget = Milestone(context: context, name: "Create simple budget and savings dharma", goal: financeGoal, startDate: date(daysFromToday: 14), endDate: date(daysFromToday: 210), progress: 0)
        let familyPresence = Milestone(context: context, name: "Create protected family seva blocks", goal: sevaGoal, startDate: date(daysFromToday: -45), endDate: date(daysFromToday: 90), progress: 0)
        let digitalRestraint = Milestone(context: context, name: "Establish clean phone and browser boundaries", goal: brahmacharyaGoal, startDate: date(daysFromToday: -12), endDate: date(daysFromToday: 100), progress: 0)
        let knowledgePractice = Milestone(context: context, name: "Build a study-to-practice knowledge cycle", goal: knowledgeGoal, startDate: date(daysFromToday: 7), endDate: date(daysFromToday: 160), progress: 0)
        let devotionMorning = Milestone(context: context, name: "Design morning devotion and deep work launch", goal: devotionGoal, startDate: date(daysFromToday: -3), endDate: date(daysFromToday: 70), progress: 0)
        let devotionEvening = Milestone(context: context, name: "Close each day with clean reflection and shutdown", goal: devotionGoal, startDate: date(daysFromToday: 71), endDate: date(daysFromToday: 180), progress: 0)
        let writingPipeline = Milestone(context: context, name: "Create essay pipeline from study to publish", goal: writingGoal, startDate: date(daysFromToday: 20), endDate: date(daysFromToday: 110), progress: 0)
        let writingPublication = Milestone(context: context, name: "Publish first three backend essays", goal: writingGoal, startDate: date(daysFromToday: 111), endDate: date(daysFromToday: 220), progress: 0)
        let homeSystem = Milestone(context: context, name: "Simplify physical workspace and routines", goal: systemsGoal, startDate: date(daysFromToday: -20), endDate: date(daysFromToday: 55), progress: 0)
        let digitalSystem = Milestone(context: context, name: "Unify notes, files, and browser boundaries", goal: systemsGoal, startDate: date(daysFromToday: 56), endDate: date(daysFromToday: 130), progress: 0)
        let hiringNarrative = Milestone(context: context, name: "Clarify resume, portfolio, and proof narrative", goal: hiringSignalGoal, startDate: date(daysFromToday: -2), endDate: date(daysFromToday: 75), progress: 0)
        let hiringPractice = Milestone(context: context, name: "Run mock loops and feedback cycles", goal: hiringSignalGoal, startDate: date(daysFromToday: 76), endDate: date(daysFromToday: 160), progress: 0)

        let completedDisciplineGoal = Goal(
            context: context,
            name: "Complete 21-day morning discipline reset",
            priority: .low,
            startDate: date(daysFromToday: -70),
            endDate: date(daysFromToday: -50),
            progress: 0,
            antiGoal: "Starting the day reactive and phone-led",
            sacrifice: "Late-night browsing and unfocused first hour",
            coreValues: [value("Discipline"), value("Sadhana"), value("Inner Purity")].compactMap { $0 }
        )
        let completedDisciplineMilestone = Milestone(context: context, name: "Finish morning reset cycle", goal: completedDisciplineGoal, startDate: date(daysFromToday: -70), endDate: date(daysFromToday: -50), progress: 0)

        let overdueAdminGoal = Goal(
            context: context,
            name: "Close overdue personal admin loops",
            priority: .medium,
            startDate: date(daysFromToday: -90),
            endDate: date(daysFromToday: -12),
            progress: 0,
            antiGoal: "Avoidance creating background anxiety",
            sacrifice: "Comfortable delay and vague reminders",
            coreValues: [value("Discipline"), value("Financial Stability"), value("Simplicity")].compactMap { $0 }
        )
        let overdueAdminMilestone = Milestone(context: context, name: "Resolve overdue documents and payments", goal: overdueAdminGoal, startDate: date(daysFromToday: -90), endDate: date(daysFromToday: -12), progress: 0)

        let unplannedClarityGoal = Goal(
            context: context,
            name: "Clarify next long-term seva direction",
            priority: .low,
            startDate: date(daysFromToday: -25),
            endDate: date(daysFromToday: 95),
            progress: 0,
            antiGoal: "Choosing commitments from guilt or excitement",
            sacrifice: "Rushing into new projects before clarity",
            coreValues: [value("Seva"), value("Dharma"), value("Simplicity")].compactMap { $0 }
        )
        let unplannedClarityMilestone = Milestone(context: context, name: "Draft seva direction options", goal: unplannedClarityGoal, startDate: date(daysFromToday: -10), endDate: date(daysFromToday: 70), progress: 0)

        let futurePilgrimageGoal = Goal(
            context: context,
            name: "Prepare future pilgrimage discipline",
            priority: .low,
            startDate: date(daysFromToday: 45),
            endDate: date(daysFromToday: 140),
            progress: 0,
            antiGoal: "Treating sacred travel as tourism or impulse",
            sacrifice: "Unplanned spending and casual preparation",
            coreValues: [value("Sadhana"), value("Dharma"), value("Simplicity")].compactMap { $0 }
        )
        let futurePilgrimageMilestone = Milestone(context: context, name: "Plan pilgrimage with restraint and clarity", goal: futurePilgrimageGoal, startDate: date(daysFromToday: 45), endDate: date(daysFromToday: 140), progress: 0)

        let backendDesign = task("Design distributed systems architecture", milestone: backendFoundations, priority: .high, status: .active, type: .deep, description: "Write service boundaries, data flow, failure modes, and API contracts.", estimatedMinutes: 120)
        let databaseIndexing = task("Implement database indexing practice", milestone: backendFoundations, priority: .high, status: .active, type: .deep, description: "Build query examples, profile slow paths, and write notes.", estimatedMinutes: 90)
        task("Finish concurrency notes", milestone: backendFoundations, priority: .medium, status: .completed, type: .deep, description: "Summarize async, backpressure, cancellation, and race prevention.", estimatedMinutes: 75, resultNotes: "Core concurrency notes completed.")
        task("Read one backend design chapter", milestone: backendFoundations, priority: .medium, status: .notStarted, type: .shallow, description: "Read and extract ten useful implementation points.", estimatedMinutes: 45)

        let apiTask = task("Build API service vertical slice", milestone: backendPortfolio, priority: .high, status: .active, type: .deep, description: "Create auth, persistence, background worker, observability, and tests.", estimatedMinutes: 150)
        task("Write service README", milestone: backendPortfolio, priority: .medium, status: .notStarted, type: .shallow, description: "Document setup, architecture, endpoints, and tradeoffs.", estimatedMinutes: 55)
        task("Add integration tests", milestone: backendPortfolio, priority: .high, status: .active, type: .deep, description: "Test happy path, failure path, and persistence boundaries.", estimatedMinutes: 100)

        let interviewTask = task("Practice system design whiteboard", milestone: backendInterview, priority: .high, status: .active, type: .deep, description: "Run one timed design drill and identify missing reasoning.", estimatedMinutes: 90)
        task("Review rate limiting patterns", milestone: backendInterview, priority: .medium, status: .completed, type: .deep, description: "Compare token bucket, leaky bucket, fixed window, and sliding window.", estimatedMinutes: 60, resultNotes: "Patterns summarized.")
        task("Create interview gap list", milestone: backendInterview, priority: .medium, status: .active, type: .shallow, description: "List weak concepts and turn them into next tasks.", estimatedMinutes: 35)
        task("Draft case study outline", milestone: backendCaseStudy, priority: .medium, status: .notStarted, type: .deep, description: "Outline problem, constraints, architecture, failure handling, and metrics.", estimatedMinutes: 80)
        task("Finish actor isolation exercises", milestone: backendCompleted, priority: .high, status: .completed, type: .deep, description: "Complete practice examples.", estimatedMinutes: 60, resultNotes: "Exercises complete.")
        task("Summarize structured concurrency", milestone: backendCompleted, priority: .medium, status: .completed, type: .deep, description: "Write concise notes.", estimatedMinutes: 45, resultNotes: "Notes complete.")

        let strengthTask = task("Complete strength training A", milestone: strengthPractice, priority: .high, status: .active, type: .shallow, description: "Squat, push, hinge, carry, and breath cooldown.", estimatedMinutes: 45)
        task("Track protein and water", milestone: strengthPractice, priority: .medium, status: .active, type: .shallow, description: "Record intake and note energy quality.", estimatedMinutes: 15)
        task("Define weekly training template", milestone: strengthPractice, priority: .medium, status: .completed, type: .deep, description: "Create simple repeatable training week.", estimatedMinutes: 50, resultNotes: "Template complete.")
        let breathTask = task("Complete mobility and breath reset", milestone: mobilityBreath, priority: .medium, status: .active, type: .shallow, description: "Hips, thoracic spine, nasal breathing, and slow exhale set.", estimatedMinutes: 35)
        task("Log morning HRV and sleep quality", milestone: mobilityBreath, priority: .low, status: .notStarted, type: .shallow, description: "Capture baseline before training.", estimatedMinutes: 10)
        task("Run zone two baseline test", milestone: enduranceReset, priority: .medium, status: .notStarted, type: .shallow, description: "Measure easy pace and breathing.", estimatedMinutes: 40)
        task("Finish hydration reset checklist", milestone: strengthCompleted, priority: .medium, status: .completed, type: .shallow, description: "Set water and electrolyte routine.", estimatedMinutes: 20, resultNotes: "Checklist complete.")
        task("Set sleep cutoff routine", milestone: strengthCompleted, priority: .medium, status: .completed, type: .shallow, description: "Define lights-out and device cutoff.", estimatedMinutes: 25, resultNotes: "Routine complete.")

        let japaTask = task("Complete 30-minute japa block", milestone: sadhanaMorning, priority: .high, status: .active, type: .deep, description: "Silent focused japa before phone or work.", estimatedMinutes: 30)
        task("Read one dharmic text passage", milestone: sadhanaMorning, priority: .medium, status: .notStarted, type: .deep, description: "Read, reflect, and capture one principle.", estimatedMinutes: 25)
        task("Create monthly budget sheet", milestone: financeBudget, priority: .medium, status: .notStarted, type: .deep, description: "List categories, rules, and savings targets.", estimatedMinutes: 75)
        task("Schedule family call block", milestone: familyPresence, priority: .medium, status: .active, type: .shallow, description: "Protect one phone-free block and note followups.", estimatedMinutes: 30)
        let digitalBoundaryTask = task("Set clean phone and browser boundaries", milestone: digitalRestraint, priority: .high, status: .active, type: .shallow, description: "Remove impulse paths, block low-value sites, and define allowed windows.", estimatedMinutes: 25)
        task("Write evening energy audit", milestone: digitalRestraint, priority: .medium, status: .notStarted, type: .deep, description: "Review where attention leaked and what boundary must improve.", estimatedMinutes: 20)
        task("Complete one study-to-practice note", milestone: knowledgePractice, priority: .medium, status: .notStarted, type: .deep, description: "Convert one reading into a principle, action, and result check.", estimatedMinutes: 55)
        task("Review one Dharma principle for work", milestone: knowledgePractice, priority: .medium, status: .completed, type: .deep, description: "Connect a principle to daily engineering conduct.", estimatedMinutes: 35, resultNotes: "Linked right effort to uninterrupted deep work.")

        let morningOfferingTask = task("Write morning sankalpa before first work block", milestone: devotionMorning, priority: .high, status: .active, type: .deep, description: "Clarify the day as offering, then name the one deep work target.", estimatedMinutes: 20)
        task("Prepare desk and scripture before sleep", milestone: devotionMorning, priority: .medium, status: .active, type: .shallow, description: "Set book, notebook, water, and device boundary for the next morning.", estimatedMinutes: 15)
        task("Create no-phone first hour rule", milestone: devotionMorning, priority: .high, status: .notStarted, type: .shallow, description: "Remove morning phone trigger and define allowed exceptions.", estimatedMinutes: 20)
        task("Write daily shutdown reflection", milestone: devotionEvening, priority: .medium, status: .notStarted, type: .deep, description: "Record what was aligned, what leaked, and what must improve tomorrow.", estimatedMinutes: 25)
        task("Review completed sessions before dinner", milestone: devotionEvening, priority: .medium, status: .notStarted, type: .shallow, description: "Look at actual minutes and close open loops.", estimatedMinutes: 15)
        task("Plan one act of seva for tomorrow", milestone: devotionEvening, priority: .low, status: .notStarted, type: .shallow, description: "Choose one concrete helpful action without overthinking.", estimatedMinutes: 10)

        let essayOutlineTask = task("Outline backend scaling essay", milestone: writingPipeline, priority: .high, status: .active, type: .deep, description: "Turn recent backend study into a clear essay structure.", estimatedMinutes: 80)
        task("Create reusable essay checklist", milestone: writingPipeline, priority: .medium, status: .active, type: .shallow, description: "Define outline, draft, technical review, edit, publish steps.", estimatedMinutes: 35)
        task("Extract five diagrams from portfolio service", milestone: writingPipeline, priority: .medium, status: .notStarted, type: .deep, description: "Make diagrams that prove system understanding.", estimatedMinutes: 70)
        task("Publish API observability essay", milestone: writingPublication, priority: .high, status: .notStarted, type: .deep, description: "Publish a concise essay on logs, metrics, traces, and alert boundaries.", estimatedMinutes: 120)
        task("Publish database indexing essay", milestone: writingPublication, priority: .medium, status: .notStarted, type: .deep, description: "Explain one slow-query journey with before and after evidence.", estimatedMinutes: 100)
        task("Publish concurrency lessons essay", milestone: writingPublication, priority: .medium, status: .notStarted, type: .deep, description: "Explain actor isolation and cancellation lessons from practice.", estimatedMinutes: 100)

        let deskResetTask = task("Remove visual clutter from desk", milestone: homeSystem, priority: .medium, status: .active, type: .shallow, description: "Keep only laptop, notebook, water, and one active book.", estimatedMinutes: 30)
        task("Define weekly reset checklist", milestone: homeSystem, priority: .medium, status: .notStarted, type: .shallow, description: "Create one list for desk, room, files, calendar, and food prep.", estimatedMinutes: 40)
        task("Set fixed place for training gear", milestone: homeSystem, priority: .low, status: .completed, type: .shallow, description: "Remove friction before workouts.", estimatedMinutes: 20, resultNotes: "Gear basket ready.")
        task("Merge scattered notes into one vault", milestone: digitalSystem, priority: .high, status: .active, type: .deep, description: "Move active notes into one system and archive old duplicates.", estimatedMinutes: 120)
        task("Clean downloads and desktop", milestone: digitalSystem, priority: .medium, status: .notStarted, type: .shallow, description: "Delete or file every loose item.", estimatedMinutes: 35)
        task("Create browser profiles for work and study", milestone: digitalSystem, priority: .medium, status: .notStarted, type: .shallow, description: "Separate deep work from personal browsing.", estimatedMinutes: 30)

        let resumeTask = task("Rewrite resume around proof and outcomes", milestone: hiringNarrative, priority: .high, status: .active, type: .deep, description: "Use evidence from projects, incidents, scale, and decisions.", estimatedMinutes: 100)
        task("Record portfolio walkthrough script", milestone: hiringNarrative, priority: .medium, status: .notStarted, type: .deep, description: "Write a crisp explanation of architecture and tradeoffs.", estimatedMinutes: 75)
        task("Update LinkedIn with sober signal", milestone: hiringNarrative, priority: .low, status: .notStarted, type: .shallow, description: "Make profile specific, factual, and non-inflated.", estimatedMinutes: 45)
        task("Run backend mock interview one", milestone: hiringPractice, priority: .high, status: .notStarted, type: .deep, description: "Practice with timer and write feedback after.", estimatedMinutes: 90)
        task("Run behavioral story review", milestone: hiringPractice, priority: .medium, status: .notStarted, type: .deep, description: "Prepare stories for conflict, ambiguity, ownership, and learning.", estimatedMinutes: 75)
        task("Create follow-up improvement backlog", milestone: hiringPractice, priority: .medium, status: .notStarted, type: .shallow, description: "Turn feedback into concrete next tasks.", estimatedMinutes: 35)

        let inboxCaptureTask = standaloneTask("Process loose inbox captures", priority: .high, status: .active, type: .shallow, description: "Clear paper, notes, and quick captures into the right tracker place.", estimatedMinutes: 25, createdDaysFromToday: 0)
        let billTask = standaloneTask("Pay electricity and internet bills", priority: .high, status: .active, type: .shallow, description: "Pay bills and record confirmation numbers.", estimatedMinutes: 20, createdDaysFromToday: -1)
        let callParentTask = standaloneTask("Call parents with full attention", priority: .medium, status: .active, type: .shallow, description: "Call without multitasking and ask what support is needed.", estimatedMinutes: 30, createdDaysFromToday: -2)
        standaloneTask("Book annual health check appointment", priority: .medium, status: .notStarted, type: .shallow, description: "Find slot, book appointment, add prep notes.", estimatedMinutes: 20, createdDaysFromToday: -3)
        let expenseTask = standaloneTask("Reconcile this week expenses", priority: .medium, status: .active, type: .shallow, description: "Categorize spending and notice leaks.", estimatedMinutes: 30, createdDaysFromToday: -4)
        standaloneTask("Buy groceries for sattvic week", priority: .medium, status: .notStarted, type: .shallow, description: "Buy simple food for training and steady energy.", estimatedMinutes: 40, createdDaysFromToday: -5)
        standaloneTask("Repair backpack zipper", priority: .low, status: .notStarted, type: .shallow, description: "Find repair shop or replace zipper pull.", estimatedMinutes: 20, createdDaysFromToday: -6)
        standaloneTask("Clean laptop keyboard and screen", priority: .low, status: .completed, type: .shallow, description: "Clean tools used for deep work.", estimatedMinutes: 15, resultNotes: "Laptop cleaned.", createdDaysFromToday: -7)
        standaloneTask("Archive old screenshots", priority: .low, status: .notStarted, type: .shallow, description: "Delete irrelevant screenshots and file useful evidence.", estimatedMinutes: 25, createdDaysFromToday: -8)
        standaloneTask("Send insurance document to folder", priority: .medium, status: .notStarted, type: .shallow, description: "Move policy PDF to finance archive.", estimatedMinutes: 10, createdDaysFromToday: -9)
        standaloneTask("Review tomorrow calendar", priority: .medium, status: .active, type: .shallow, description: "Remove collisions and prepare the first work block.", estimatedMinutes: 15, createdDaysFromToday: -10)
        standaloneTask("Write gratitude message to mentor", priority: .low, status: .notStarted, type: .deep, description: "Send a sincere note with one specific learning.", estimatedMinutes: 20, createdDaysFromToday: -11)
        standaloneTask("Renew password manager audit", priority: .medium, status: .notStarted, type: .deep, description: "Review weak passwords and remove unused accounts.", estimatedMinutes: 60, createdDaysFromToday: -12)
        standaloneTask("Prepare clothes and bag for gym", priority: .low, status: .completed, type: .shallow, description: "Remove morning workout friction.", estimatedMinutes: 10, resultNotes: "Bag ready.", createdDaysFromToday: -13)
        standaloneTask("Clear phone photos into albums", priority: .low, status: .notStarted, type: .shallow, description: "Delete noise and save important family photos.", estimatedMinutes: 35, createdDaysFromToday: -14)
        standaloneTask("Plan weekend seva errand", priority: .medium, status: .notStarted, type: .shallow, description: "Choose one useful family or community errand.", estimatedMinutes: 20, createdDaysFromToday: -15)
        standaloneTask("Check tax document checklist", priority: .medium, status: .notStarted, type: .deep, description: "Confirm missing statements and create collection list.", estimatedMinutes: 45, createdDaysFromToday: -16)
        standaloneTask("Clean reading queue", priority: .low, status: .notStarted, type: .shallow, description: "Keep only the next three useful reads.", estimatedMinutes: 20, createdDaysFromToday: -17)
        standaloneTask("Update emergency contact sheet", priority: .medium, status: .notStarted, type: .shallow, description: "Refresh family, doctor, insurance, and key accounts.", estimatedMinutes: 30, createdDaysFromToday: -18)
        standaloneTask("Do one focused room reset", priority: .low, status: .completed, type: .shallow, description: "Reset one room to quiet order.", estimatedMinutes: 25, resultNotes: "Room reset complete.", createdDaysFromToday: -19)

        let completedResetTasks = [
            task("Wake before sunrise for reset cycle", milestone: completedDisciplineMilestone, priority: .medium, status: .completed, type: .shallow, description: "Maintain a clean wake time through the full reset cycle.", estimatedMinutes: 20, resultNotes: "Wake rhythm completed."),
            task("Complete morning water, prayer, and desk setup", milestone: completedDisciplineMilestone, priority: .medium, status: .completed, type: .shallow, description: "Perform the non-negotiable morning launch before any phone use.", estimatedMinutes: 25, resultNotes: "Morning launch stabilized."),
            task("Record daily discipline proof", milestone: completedDisciplineMilestone, priority: .low, status: .completed, type: .shallow, description: "Write one proof note per day after completing the morning reset.", estimatedMinutes: 15, resultNotes: "Proof notes finished.")
        ]

        let overdueAdminTasks = [
            task("Submit pending reimbursement claim", milestone: overdueAdminMilestone, priority: .high, status: .notStarted, type: .shallow, description: "Collect receipts, submit claim, and save confirmation.", estimatedMinutes: 35),
            task("Resolve old bank statement mismatch", milestone: overdueAdminMilestone, priority: .medium, status: .active, type: .deep, description: "Compare statement, ledger, and receipts; document the correction.", estimatedMinutes: 60),
            task("Close dormant subscription account", milestone: overdueAdminMilestone, priority: .medium, status: .notStarted, type: .shallow, description: "Cancel subscription, export invoice history, and remove card.", estimatedMinutes: 20)
        ]

        task("Interview seva mentors for direction", milestone: unplannedClarityMilestone, priority: .medium, status: .notStarted, type: .deep, description: "Ask two mentors where service would be useful and sustainable.", estimatedMinutes: 50)
        task("Write seva criteria before choosing", milestone: unplannedClarityMilestone, priority: .medium, status: .notStarted, type: .deep, description: "Define time, skill, emotional, and family constraints before committing.", estimatedMinutes: 45)
        task("Research pilgrimage constraints calmly", milestone: futurePilgrimageMilestone, priority: .medium, status: .notStarted, type: .deep, description: "Collect dates, budget, family constraints, and sadhana expectations before planning.", estimatedMinutes: 60)
        task("Create simple preparation checklist", milestone: futurePilgrimageMilestone, priority: .low, status: .notStarted, type: .shallow, description: "List documents, physical preparation, reading, and budget without over-planning.", estimatedMinutes: 35)

        let expansionMilestones = [
            backendFoundations,
            backendPortfolio,
            backendInterview,
            backendCaseStudy,
            strengthPractice,
            mobilityBreath,
            enduranceReset,
            sadhanaMorning,
            financeBudget,
            familyPresence,
            digitalRestraint,
            knowledgePractice,
            devotionMorning,
            devotionEvening,
            writingPipeline,
            writingPublication,
            homeSystem,
            digitalSystem,
            hiringNarrative,
            hiringPractice,
            unplannedClarityMilestone
        ]

        let expansionTemplates: [(String, TaskPriority, TaskType, String)] = [
            ("Clarify next concrete output", .high, .deep, "Define one useful output, acceptance criteria, and the reason it matters."),
            ("Execute one focused work block", .high, .deep, "Complete one uninterrupted block and leave visible evidence of progress."),
            ("Review quality and remove defects", .medium, .deep, "Inspect the output for gaps, weak assumptions, and avoidable mistakes."),
            ("Document learning and next action", .medium, .shallow, "Write the result, lesson, and next action in a compact note."),
            ("Prepare materials and environment", .low, .shallow, "Collect inputs, clean the workspace, and remove friction before work.")
        ]

        var expansionTasks: [TaskItem] = []
        for (milestoneIndex, milestone) in expansionMilestones.enumerated() {
            for (templateIndex, template) in expansionTemplates.enumerated() {
                let item = task(
                    "\(template.0) - \(milestone.name)",
                    milestone: milestone,
                    priority: template.1,
                    status: .notStarted,
                    type: template.2,
                    description: template.3,
                    estimatedMinutes: 25 + ((milestoneIndex + templateIndex) % 5) * 15
                )
                expansionTasks.append(item)
            }
        }

        let standaloneBacklogNames = [
            "Scan and file medical reports",
            "Prepare one-week sattvic meal plan",
            "Review passwords for critical accounts",
            "Clean one cloud storage folder",
            "Call utility provider about billing error",
            "Write one sincere apology note if needed",
            "Plan next book purchase with restraint",
            "Clear old downloads from phone",
            "Prepare travel document folder",
            "Review insurance nominee details",
            "Create one-page emergency plan",
            "Organize work receipts for tax",
            "Schedule dental cleaning",
            "Donate unused clothes respectfully",
            "Close two stale browser tabs groups",
            "Review monthly subscriptions",
            "Prepare simple weekly grocery list",
            "Clean inbox to zero actionable messages",
            "Update important document index",
            "Choose next seva errand"
        ]

        for (index, name) in standaloneBacklogNames.enumerated() {
            standaloneTask(
                name,
                priority: index % 3 == 0 ? .high : (index % 3 == 1 ? .medium : .low),
                status: .notStarted,
                type: index % 4 == 0 ? .deep : .shallow,
                description: "Standalone household or personal system task for testing filtered focus and standalone task behavior.",
                estimatedMinutes: 15 + (index % 6) * 10,
                createdDaysFromToday: -20 - index
            )
        }

        let sessionSeeds: [(TaskItem, Int, String, String, String, String, String, String, SessionStatus, Int?, String)] = [
            (backendDesign, 95, "Finish service boundary diagram", "Architecture sketch", "Morning deep work", "Clarity before code", "Single editor, docs open, no browser drift", "95 focused minutes", .completed, 0, "Service boundaries and failure paths written."),
            (apiTask, 75, "Implement auth and persistence path", "API vertical slice", "Afternoon implementation", "Portfolio needs visible shipped work", "Tests first, then implementation", "75 focused minutes", .partial, 0, "Auth path started; persistence next."),
            (databaseIndexing, 80, "Profile one slow query and fix index", "Indexing practice", "Yesterday morning", "Backend excellence requires database intuition", "Explain plan, index, rerun benchmark", "80 minutes", .completed, -1, "Index reduced query time in demo."),
            (strengthTask, 45, "Complete training A with clean form", "Strength practice", "Evening block", "Body and prana support deep work", "Full warmup, slow reps, no ego lifting", "45 minutes", .completed, -1, "Energy improved after cooldown."),
            (breathTask, 30, "Finish mobility reset", "Mobility and breath", "Lunch reset", "Keep body available for long work", "Timer on, nasal breathing, slow exhale", "30 minutes", .partial, -2, "Hips done, breath block shorter."),
            (interviewTask, 90, "Run one design drill", "System design practice", "Morning deep work", "Interview clarity needs recall under time", "Whiteboard, timer, critique notes", "90 minutes", .completed, -3, "Rate limiter design completed."),
            (backendDesign, 110, "Write failure-mode table", "Failure analysis", "Morning block", "Resilience is a senior backend signal", "List failures, mitigations, monitoring", "110 minutes", .completed, -5, "Added retries, DLQ, timeout notes."),
            (apiTask, 60, "Add integration test skeleton", "Testing slice", "Evening work", "Confidence comes from executable proof", "One endpoint at a time", "60 minutes", .partial, -6, "Skeleton created."),
            (strengthTask, 42, "Complete training A repeat", "Strength practice", "Evening block", "Consistency compounds", "Same template, better form", "42 minutes", .completed, -7, "Form felt stronger."),
            (japaTask, 30, "Complete clean japa block", "Japa", "Before work", "Devotion anchors attention", "Phone outside room", "30 minutes", .completed, -8, "Calm start."),
            (breathTask, 35, "Complete full reset", "Mobility and breath", "Morning reset", "Stable body for stable work", "Full sequence", "35 minutes", .completed, -10, "Full sequence done."),
            (digitalBoundaryTask, 25, "Tighten one digital boundary", "Attention restraint", "Evening cleanup", "Brahmacharya protects tomorrow's energy", "Block one leak and remove one trigger", "25 minutes", .completed, -4, "Removed two impulse paths."),
            (interviewTask, 0, "Prepare next system design prompt", "Design drill prep", "Tomorrow morning", "Keep overdue sprint moving", "Choose prompt and rubric", "Not started", .notStarted, nil, ""),
            (morningOfferingTask, 20, "Write sankalpa and name one deep target", "Morning offering", "Before first work block", "Begin from devotion, not urgency", "Notebook first, no phone", "20 minutes", .completed, -2, "Sankalpa written and work target clear."),
            (essayOutlineTask, 65, "Finish essay outline", "Backend scaling outline", "Deep work block", "Teaching reveals gaps", "Outline sections and examples", "65 minutes", .partial, -1, "Main spine complete; needs diagrams."),
            (deskResetTask, 30, "Clear desk for deep work", "Physical reset", "Evening reset", "Environment shapes attention", "Remove everything not needed tomorrow", "30 minutes", .completed, -3, "Desk now minimal."),
            (resumeTask, 70, "Rewrite proof bullets", "Resume proof work", "Morning focus", "Hiring signal must be factual", "Rewrite top project bullets", "70 minutes", .partial, -4, "Two project bullets improved."),
            (inboxCaptureTask, 25, "Process loose captures", "Standalone cleanup", "Today admin block", "Open loops leak attention", "Sort into tracker, archive, or delete", "25 minutes", .completed, 0, "Inbox cleared."),
            (billTask, 20, "Pay bills", "Standalone admin", "Evening admin", "Avoid avoidable mental drag", "Pay and record confirmations", "20 minutes", .completed, -1, "Bills paid."),
            (callParentTask, 30, "Call parents", "Standalone seva", "Evening call", "Family presence is Dharma", "Phone away from laptop", "30 minutes", .partial, -1, "Called briefly; follow up tomorrow."),
            (expenseTask, 30, "Reconcile expenses", "Standalone finance", "Weekly review", "Money discipline supports freedom", "Categorize and note leaks", "30 minutes", .completed, -5, "Expenses categorized.")
        ]

        for seed in sessionSeeds {
            let sessionMoment = seed.9.map { date(daysFromToday: $0, hour: 10) }
            _ = WorkSession(
                context: context,
                task: seed.0,
                sessionLabel: seed.2,
                estimatedMinutes: seed.0.estimatedMinutesValue,
                actualMinutes: seed.1,
                expectedResult: seed.2,
                whatText: seed.3,
                whenText: seed.4,
                whyText: seed.5,
                howText: seed.6,
                howMuchText: seed.7,
                status: seed.8,
                sessionDate: sessionMoment,
                sessionNotes: seed.10,
                createdAt: sessionMoment ?? date(daysFromToday: 1, hour: 8)
            )
        }

        for item in completedResetTasks {
            addSession(
                task: item,
                label: "Complete proof for \(item.name)",
                expectedMinutes: max(item.estimatedMinutesValue, 20),
                actualMinutes: max(item.estimatedMinutesValue, 20),
                status: .completed,
                daysFromToday: -55,
                notes: "Completed as part of the morning discipline reset."
            )
        }

        addSession(task: overdueAdminTasks[1], label: "Start bank mismatch review", expectedMinutes: 60, actualMinutes: 35, status: .partial, daysFromToday: -16, notes: "Found two possible mismatches; needs final reconciliation.")

        for (index, item) in expansionTasks.enumerated() {
            switch index % 5 {
            case 0:
                addSession(task: item, label: "Completed focus block \(index + 1)", expectedMinutes: item.estimatedMinutesValue, actualMinutes: item.estimatedMinutesValue, status: .completed, daysFromToday: -((index % 18) + 1), notes: "Completed cleanly.")
            case 1:
                addSession(task: item, label: "Partial focus block \(index + 1)", expectedMinutes: item.estimatedMinutesValue, actualMinutes: max(10, item.estimatedMinutesValue / 2), status: .partial, daysFromToday: -((index % 12) + 1), notes: "Started; needs one more block.")
            case 2:
                addSession(task: item, label: "Completed first pass \(index + 1)", expectedMinutes: item.estimatedMinutesValue, actualMinutes: max(15, item.estimatedMinutesValue - 5), status: .completed, daysFromToday: -((index % 10) + 1), notes: "First pass complete.")
                addSession(task: item, label: "Remaining refinement \(index + 1)", expectedMinutes: 20, actualMinutes: 0, status: .notStarted, daysFromToday: nil, notes: "")
            case 3:
                addSession(task: item, label: "Planned focus block \(index + 1)", expectedMinutes: item.estimatedMinutesValue, actualMinutes: 0, status: .notStarted, daysFromToday: nil, notes: "")
            default:
                break
            }
        }

        _ = ValidationService.clampMilestonesToGoalDateRanges([
            backendGoal,
            strengthGoal,
            sadhanaGoal,
            financeGoal,
            sevaGoal,
            brahmacharyaGoal,
            knowledgeGoal,
            devotionGoal,
            writingGoal,
            systemsGoal,
            hiringSignalGoal,
            completedDisciplineGoal,
            overdueAdminGoal,
            unplannedClarityGoal,
            futurePilgrimageGoal
        ])
        _ = TaskStatusService.refreshAllStoredStatuses(in: context)
        try? context.save()
        UserDefaults.standard.set(markInstalled ? demoDataVersion : 0, forKey: demoDataVersionKey)
    }

    static func clearAllData(in context: NSManagedObjectContext) {
        delete(WorkSession.self, in: context)
        delete(TaskItem.self, in: context)
        delete(Milestone.self, in: context)
        delete(Goal.self, in: context)
        delete(CoreValue.self, in: context)

        try? context.save()
    }

    static func clearTrackerDataPreservingValues(in context: NSManagedObjectContext) {
        delete(WorkSession.self, in: context)
        delete(TaskItem.self, in: context)
        delete(Milestone.self, in: context)
        delete(Goal.self, in: context)

        try? context.save()
    }

    private static func delete<T: NSManagedObject>(_ type: T.Type, in context: NSManagedObjectContext) {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        guard let items = try? context.fetch(request) else { return }
        items.forEach { context.delete($0) }
    }

    private static func isKnownDemoData(goals: [Goal]) -> Bool {
        let names = Set(goals.map(\.name))
        return names.contains("Become FAANG-level Backend Engineer through disciplined deep work") &&
            names.contains("Build strong body and prana for steady sadhana") &&
            names.contains("Stabilize daily sadhana and inner purity")
    }

    private static func defaultDescription(for name: String) -> String {
        switch name {
        case "Dharma": "Choose the right action and keep life aligned with duty."
        case "Brahmacharya": "Conserve attention, energy, and intention."
        case "Health": "Build strength, prana, and daily physical steadiness."
        case "Career Excellence": "Do excellent work with skill, depth, and consistency."
        case "Family Welfare": "Protect, support, and uplift family life."
        case "Sadhana": "Return every day to practice, prayer, and self-mastery."
        case "Financial Stability": "Use money with discipline, clarity, and responsibility."
        case "Knowledge": "Study deeply and convert learning into lived intelligence."
        case "Discipline": "Keep promises to the self through repeatable action."
        case "Seva": "Let useful work serve others without ego."
        case "Simplicity": "Remove clutter so the essential becomes visible."
        case "Inner Purity": "Act from clarity, restraint, and clean intention."
        default: ""
        }
    }
}
