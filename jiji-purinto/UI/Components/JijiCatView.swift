//
//  JijiCatView.swift
//  jiji-purinto
//
//  Animated Jiji cat component that peeks from the corner with idle animations.
//

import SwiftUI

/// Animation frame representing the current cat expression.
enum JijiFrame: String {
    /// Neutral resting pose.
    case neutral = "CatBase"
    /// Winking expression (one eye closed).
    case wink = "CatWink"
    /// Ear wiggle pose.
    case ear = "CatEar"
    /// Blink expression (both eyes closed).
    case blink = "CatBlink"
}

/// Manages the animation state and timing for Jiji cat idle animations.
///
/// Automatically triggers random idle animations (wink, ear wiggle, blink) at intervals
/// of 2-5 seconds. Animations hold briefly then return to neutral.
@MainActor
final class JijiAnimator: ObservableObject {
    /// The current animation frame to display.
    @Published private(set) var currentFrame: JijiFrame = .neutral

    /// Timer for scheduling the next idle animation.
    private var idleTimer: Timer?

    /// Duration to hold the wink animation before returning to neutral.
    private let winkHoldDuration: TimeInterval = 0.15

    /// Duration to hold the ear wiggle animation before returning to neutral.
    private let earHoldDuration: TimeInterval = 0.2

    /// Duration to hold the blink animation before returning to neutral.
    private let blinkHoldDuration: TimeInterval = 0.15

    /// Minimum interval between idle animations in seconds.
    private let minIdleInterval: TimeInterval = 2.0

    /// Maximum interval between idle animations in seconds.
    private let maxIdleInterval: TimeInterval = 5.0

    /// Starts the idle animation loop.
    ///
    /// Should be called when the view appears. Animations will trigger
    /// at random intervals until `stopAnimations()` is called.
    func startAnimations() {
        scheduleNextIdleAnimation()
    }

    /// Stops all animations and cleans up timers.
    ///
    /// Should be called when the view disappears to prevent memory leaks.
    func stopAnimations() {
        idleTimer?.invalidate()
        idleTimer = nil
        currentFrame = .neutral
    }

    /// Schedules the next idle animation with a random delay.
    private func scheduleNextIdleAnimation() {
        idleTimer?.invalidate()

        let randomInterval = TimeInterval.random(in: minIdleInterval...maxIdleInterval)

        idleTimer = Timer.scheduledTimer(withTimeInterval: randomInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.playIdleAnimation()
            }
        }
    }

    /// Plays a random idle animation (wink, ear wiggle, or blink).
    private func playIdleAnimation() {
        // Randomly choose between wink, ear, and blink
        let animations: [JijiFrame] = [.wink, .ear, .blink]
        let animation = animations.randomElement()!

        let holdDuration: TimeInterval
        switch animation {
        case .wink:
            holdDuration = winkHoldDuration
        case .ear:
            holdDuration = earHoldDuration
        case .blink:
            holdDuration = blinkHoldDuration
        case .neutral:
            holdDuration = 0
        }

        currentFrame = animation

        // Schedule return to neutral after hold duration
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) { [weak self] in
            self?.currentFrame = .neutral
            self?.scheduleNextIdleAnimation()
        }
    }

    deinit {
        idleTimer?.invalidate()
    }
}

/// An animated Jiji cat view that displays idle animations.
///
/// The cat displays a neutral pose and periodically performs idle animations
/// such as winking, blinking, or wiggling its ear. Designed to peek from a corner of the screen.
struct JijiCatView: View {
    /// The animator managing the cat's animation state.
    @StateObject private var animator = JijiAnimator()

    var body: some View {
        Image(animator.currentFrame.rawValue)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .onAppear {
                animator.startAnimations()
            }
            .onDisappear {
                animator.stopAnimations()
            }
    }
}

// MARK: - Previews

#Preview("Jiji Cat") {
    JijiCatView()
        .frame(width: 120, height: 160)
}

#Preview("Jiji Cat in Corner") {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()

        VStack {
            Spacer()
            HStack {
                Spacer()
                JijiCatView()
                    .frame(width: 120, height: 160)
                    .offset(x: 20, y: 40)
            }
        }
        .ignoresSafeArea()
    }
}
