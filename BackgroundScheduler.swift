import BackgroundTasks

enum BackgroundScheduler {
    static let refreshID = "app.autorenew.refresh"
    static let processingID = "app.autorenew.processing"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshID, using: nil) {
            handle($0, budget: .seconds(25), trigger: "bgRefresh")
        }
        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingID, using: nil) {
            handle($0, budget: .seconds(120), trigger: "bgProcessing")
        }
    }

    static func schedule() {
        let r = BGAppRefreshTaskRequest(identifier: refreshID)
        r.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        try? BGTaskScheduler.shared.submit(r)

        let p = BGProcessingTaskRequest(identifier: processingID)
        p.requiresNetworkConnectivity = true
        p.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 3600)
        try? BGTaskScheduler.shared.submit(p)
    }

    private static func handle(_ task: BGTask, budget: Duration, trigger: String) {
        schedule()
        let work = Task {
            await RefreshCoordinator.shared.runIfNeeded(trigger: trigger, budget: budget)
        }
        task.expirationHandler = { work.cancel() }
        Task {
            let summary = await work.value
            task.setTaskCompleted(success: summary.backgroundTaskSucceeded && !work.isCancelled)
        }
    }
}
