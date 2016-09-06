
import Foundation
import UIKit

class AppearanceNavigationController: UINavigationController, UINavigationControllerDelegate, UINavigationBarDelegate {

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        interactivePopGestureRecognizer?.enabled = false
        delegate = self
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        interactivePopGestureRecognizer?.enabled = false
        delegate = self
    }
    
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        interactivePopGestureRecognizer?.enabled = false
        delegate = self
    }
    
    convenience init() {
        self.init(nibName: nil, bundle: nil)
    }
    
    // MARK: - UINavigationControllerDelegate
    
    func navigationController(
        navigationController: UINavigationController,
        willShowViewController viewController: UIViewController, animated: Bool
        ) {
            guard let appearanceContext = viewController as? NavigationControllerAppearanceContext else {
                return
            }
            
            setNavigationBarHidden(appearanceContext.prefersNavigationControllerBarHidden(self), animated: animated)
            setToolbarHidden(appearanceContext.prefersNavigationControllerToolbarHidden(self), animated: animated)
            applyAppearance(
                appearanceContext.preferredNavigationControllerAppearance(self),
                navigationItem: viewController.navigationItem,
                animated: animated
            )
            
            // interactive gesture requires more complex logic.
            guard let coordinator = viewController.transitionCoordinator() where coordinator.isInteractive() else {
                setNeedsStatusBarAppearanceUpdate()
                return
            }
            
            coordinator.animateAlongsideTransition({ _ in }, completion: { context in
                if context.isCancelled(), let appearanceContext = self.topViewController as? NavigationControllerAppearanceContext {
                    // hiding navigation bar & toolbar within interaction completion will result into inconsistent UI state
                    self.setNavigationBarHidden(appearanceContext.prefersNavigationControllerBarHidden(self), animated: animated)
                    self.setToolbarHidden(appearanceContext.prefersNavigationControllerToolbarHidden(self), animated: animated)
                }
            })
            
            coordinator.notifyWhenInteractionEndsUsingBlock { context in
                let key = UITransitionContextFromViewControllerKey
                if context.isCancelled(),
                    let viewController = context.viewControllerForKey(key),
                    from = viewController as? NavigationControllerAppearanceContext
                {
                    // changing navigation bar & toolbar appearance within animate completion will result into UI glitch
                    self.applyAppearance(
                        from.preferredNavigationControllerAppearance(self),
                        navigationItem: viewController.navigationItem,
                        animated: true
                    )
                }
            }
    }
    
    // MARK: - UINavigationBarDelegate
    
    func navigationBar(navigationBar: UINavigationBar, shouldPopItem item: UINavigationItem) -> Bool {
        if self.viewControllers.count < navigationBar.items!.count {
            return true;
        }
        
        var shouldPop = true
        if let popHandlerViewController = self.topViewController as? UIViewControllerPopHandler {
            popHandlerViewController.navigationControllerWillPop(self)
            shouldPop = false
        }
        
        if (shouldPop) {
            popViewControllerAnimated(true)
            return true
        } else {
            for subview in navigationBar.subviews {
                if subview.alpha < 1 {
                    UIView.animateWithDuration(0.25) {
                        subview.alpha = 1
                    }
                }
            }
            return false;
        }
    }
    
    // MARK: - Appearance Applying
    
    private var appliedAppearance: Appearance?
    
    private func applyAppearance(appearance: Appearance?, navigationItem: UINavigationItem?, animated: Bool) {
        if appearance != nil && appearance != appliedAppearance {
            appliedAppearance = appearance
            
            appearanceApplyingStrategy.apply(appearance, toNavigationController: self, navigationItem:  navigationItem, animated: animated)
            setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    var appearanceApplyingStrategy = AppearanceApplyingStrategy() {
        didSet {
            applyAppearance(appliedAppearance, navigationItem: topViewController?.navigationItem, animated: false)
        }
    }
    
    // MARK: - Apperanace Update
    
    func updateAppearanceForViewController(viewController: UIViewController) {
        if let
            context = viewController as? NavigationControllerAppearanceContext
            where
            viewController == topViewController && transitionCoordinator() == nil
        {
            setNavigationBarHidden(context.prefersNavigationControllerBarHidden(self), animated: true)
            setToolbarHidden(context.prefersNavigationControllerToolbarHidden(self), animated: true)
            applyAppearance(
                context.preferredNavigationControllerAppearance(self),
                navigationItem: viewController.navigationItem,
                animated: true
            )
        }
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return appliedAppearance?.statusBarStyle ?? self.topViewController?.preferredStatusBarStyle()
            ?? super.preferredStatusBarStyle()
    }
    
    override func preferredStatusBarUpdateAnimation() -> UIStatusBarAnimation {
        return appliedAppearance != nil ? .Fade : super.preferredStatusBarUpdateAnimation()
    }
    
}