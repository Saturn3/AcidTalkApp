import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// Impedisce ad App Nap di rallentare la sincronizzazione quando la finestra è chiusa.
  private var activity: NSObjectProtocol?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    activity = ProcessInfo.processInfo.beginActivity(
      options: [.userInitiatedAllowingIdleSystemSleep],
      reason: "AcidTalk riceve messaggi e notifiche anche a finestra chiusa")
    super.applicationDidFinishLaunching(notification)
  }

  /// Chiudere la finestra non chiude l'app (come Slack): resta nel Dock e continua a ricevere
  /// messaggi e notifiche. Per uscire: menu AcidTalk > Esci oppure Cmd+Q.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  /// Clic sull'icona nel Dock con la finestra chiusa: la riapre.
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      for window in sender.windows where window is MainFlutterWindow {
        window.makeKeyAndOrderFront(self)
      }
      sender.activate(ignoringOtherApps: true)
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
