/// Recovery is distinct from ordinary due-time observation. A new process must
/// never infer a warm return merely from its first `resumed` lifecycle event.
enum RestRecovery { observe, coldHistory, warmCurrent, settingsRefresh }
