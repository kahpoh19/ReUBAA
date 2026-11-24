import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AgendaFilePlugin") {
      AgendaFilePlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BhpanPreviewPlugin") {
      BhpanPreviewPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ReminderNotificationPlugin") {
      ReminderNotificationPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ScheduleWidgetPlugin") {
      ScheduleWidgetPlugin.register(with: registrar)
    }
  }
}

/// 课程和待办提醒：Dart 排好时间，交给系统的本地通知按时弹出。
final class ReminderNotificationPlugin: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate {
  // 通知中心的 delegate 是弱引用，这里留一份强引用。
  private static var shared: ReminderNotificationPlugin?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "cn.edu.buaa.ubaa/notifications", binaryMessenger: registrar.messenger())
    let instance = ReminderNotificationPlugin()
    shared = instance
    registrar.addMethodCallDelegate(instance, channel: channel)
    UNUserNotificationCenter.current().delegate = instance
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    switch call.method {
    case "requestPermission":
      center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
        DispatchQueue.main.async { result(granted) }
      }
    case "replace":
      guard let args = call.arguments as? [String: Any],
        let group = args["group"] as? String,
        let items = args["items"] as? [[String: Any]]
      else {
        result(FlutterError(code: "invalid_reminders", message: "提醒参数无效", details: nil))
        return
      }
      let prefix = "\(group):"
      center.getPendingNotificationRequests { requests in
        // 先撤掉这一组旧的，再按新列表重排。
        let old = requests.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: old)
        for item in items {
          guard let id = item["id"] as? Int,
            let title = item["title"] as? String,
            let body = item["body"] as? String,
            let at = item["at"] as? Int
          else { continue }
          let date = Date(timeIntervalSince1970: Double(at) / 1000)
          if date.timeIntervalSinceNow < 1 { continue }
          let parts = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date)
          let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
          center.add(
            UNNotificationRequest(
              identifier: "\(prefix)\(id)", content: Self.content(title, body), trigger: trigger))
        }
        DispatchQueue.main.async { result(nil) }
      }
    case "show":
      guard let args = call.arguments as? [String: Any],
        let id = args["id"] as? Int,
        let title = args["title"] as? String
      else {
        result(FlutterError(code: "invalid_notification", message: "通知参数无效", details: nil))
        return
      }
      let body = args["body"] as? String ?? ""
      center.add(
        UNNotificationRequest(
          identifier: "now:\(id)", content: Self.content(title, body), trigger: nil))
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func content(_ title: String, _ body: String) -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    return content
  }

  // 应用在前台时也照常弹横幅，不然打开应用时到点的提醒看不到。
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .list, .sound])
  }
}
