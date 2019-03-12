//
//  VoiceInputRouter.swift
//  Scout
//
//  Created by Shurupov Alex on 5/20/18.
//

import Foundation
import UIKit

class PlayerRouter {
    var onBackButtonTap: (() -> Void)?
    fileprivate var parentNavigationController: UINavigationController!
    fileprivate let assembly: PlayerAssemblyProtocol
    var playerVC: OldPlayerViewController?
    var playerOpen: Bool

    required init(with assembly: PlayerAssemblyProtocol) {
        self.assembly = assembly
        self.playerOpen = false
    }
}

extension PlayerRouter: PlayerRoutingProtocol {
    func show(from viewController: UIViewController, animated: Bool, model: ScoutArticle, fullArticle: Bool) {
        self.playerOpen = true
        self.playerVC = assembly.assemblyPlayerViewController()
        self.playerVC!.model = model
        self.playerVC!.isFullArticle = fullArticle
        self.playerVC!.backButtonDelegate = self
        self.showViewController(viewController: self.playerVC!, fromViewController: viewController, animated: animated)
    }

    func pause() {
        if self.playerOpen && self.playerVC!.playing {
            self.playerVC!.pauseButtonTapped(0)
        }
    }

    func stop() {
        if self.playerOpen {
            self.backButtonTapped()
        }
    }

    func resume() {
        if self.playerOpen && !self.playerVC!.playing {
            self.playerVC!.pauseButtonTapped(0)
        }
    }

    func playing() -> Bool {
        return self.playerOpen && self.playerVC!.playing
    }

    func increaseVolume() {
        if self.playerVC != nil {
            self.playerVC!.increaseVolume()
        }
    }

    func decreaseVolume() {
        if self.playerVC != nil {
            self.playerVC!.decreaseVolume()
        }
    }

    func setVolume(_ volume: Float) -> (Float, Float)? {
        if self.playerVC != nil {
            return self.playerVC!.setVolume(volume)
        } else {
            return nil
        }
    }

    func increaseSpeed() {
        if self.playerOpen {
            self.playerVC!.increaseSpeed()
        }
    }

    func decreaseSpeed() {
        if self.playerOpen {
            self.playerVC!.decreaseSpeed()
        }
    }

    func skip(_ seconds: Int) {
        if self.playerOpen {
            self.playerVC!.skip(seconds)
        }
    }

    // MARK: -
    // MARK: Private
    private func showViewController(viewController: UIViewController,
                                    fromViewController: UIViewController,
                                    animated: Bool) {
        if let navigationVC = fromViewController as? UINavigationController {
            if navigationVC.viewControllers.count == 0 {
                navigationVC.viewControllers = [viewController]
            } else {
                navigationVC.pushViewController(viewController, animated: animated)
            }
        } else if let navigationVC = fromViewController.navigationController {
            if navigationVC.viewControllers.count == 0 {
                navigationVC.viewControllers = [viewController]
            } else {
                navigationVC.pushViewController(viewController, animated: animated)
            }
        } else {
            print("Unsupported navigation")
        }
    }
}

extension PlayerRouter: PlayerViewControllerDelegate {
    func backButtonTapped() {
        self.playerOpen = false
        self.playerVC!.stop()
        self.onBackButtonTap!()
    }
}
