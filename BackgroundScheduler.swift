import BackgroundTasks

enum BackgroundScheduler {
    static let refreshID = "app.autorenew.refresh"
    static let processingID = "app.autorenew.processing"

    static func register() {
        let refreshRegistered = BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshID, using: nil) {
            handle($0, budget: .seconds(25), trigger: "bgRefresh")
        }
        let processingRegistered = BGTaskScheduler.shared.register(forTaskWithIdentifier: processingID, using: nil) {
            handle($0, budget: .seconds(120), trigger: "bgProcessing")
        }
        if !refreshRegistered || !processingRegistered {
            NSLog("AutoRenew: one or more background task identifiers could not be registered.")
        }
    }

    static func schedule() {
        let refresh = BGAppRefreshTaskRequest(identifier: refreshID)
        refresh.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        do {
            try BGTaskScheduler.shared.submit(refresh)
        } catch {
            NSLog("AutoRenew: could not schedule app refresh task (%@).", error.localizedDescription)
        }

        let processing = BGProcessingTaskRequest(identifier: processingID)
        processing.requiresNetworkConnectivity = true
        processing.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 3600)
        do {
            try BGTaskScheduler.shared.submit(processing)
        } catch {
            NSLog("AutoRenew: could not schedule processing task (%@).", error.localizedDescription)
        }
    }

    private static func handle(_ task: BGTask, budget: Duration, trigger: String) {
        // Submit the next opportunity before starting work: iOS may suspend this task.
        schedule()
        let work = Task {
            await RefreshCoordinator.shared.runIfNeeded(trigger: trigger, budget: budget)
        }
        task.expirationHandler = {
            work.cancel()
        }
        Task {
            let summary = await work.value
            task.setTaskCompleted(success: summary.backgroundTaskSucceeded && !work.isCancelled)
        }
    }
}
