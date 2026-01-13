import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Create window
        window = UIWindow(windowScene: windowScene)

        // Set root view controller
        let mainViewController = MainViewController()
        let navigationController = UINavigationController(rootViewController: mainViewController)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()

        // Handle Quick Action if launched via shortcut
        if let shortcutItem = connectionOptions.shortcutItem {
            handleQuickAction(shortcutItem)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        handleQuickAction(shortcutItem)
        completionHandler(true)
    }

    private func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) {
        if shortcutItem.type.hasSuffix("StartVoiceAgent") {
            // Navigate to voice agent and start conversation
            if let navController = window?.rootViewController as? UINavigationController,
               let mainVC = navController.topViewController as? MainViewController {
                mainVC.startVoiceConversation()
            }
        }
    }
}
