//
//  OnboardingViewController.swift
//  LumenLink
//
//  Onboarding flow with permission prompts.
//

import UIKit

final class OnboardingViewController: UIViewController {
    var onComplete: ((UIWindow?) -> Void)?

    private let pageControl = UIPageControl()
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let nextButton = UIButton(type: .system)
    private var pages: [UIView] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupPages()
        setupUI()
    }

    private func setupPages() {
        let titles = [
            "Welcome to LumenLink",
            "VPN Tunnel",
            "Discovery & Permissions"
        ]
        let descriptions = [
            "Resilient connectivity when you need it most. LumenLink helps you stay connected during outages and emergencies.",
            "LumenLink creates a secure VPN tunnel to reach gateways. You'll need to grant VPN permission when connecting.",
            "For gateway discovery, location permission helps find nearby gateways. Battery optimization should be disabled for reliable background operation."
        ]
        for (i, title) in titles.enumerated() {
            let page = makePage(title: title, description: descriptions[i])
            pages.append(page)
        }
    }

    private func makePage(title: String, description: String) -> UIView {
        let container = UIView()
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        let descLabel = UILabel()
        descLabel.text = description
        descLabel.font = .systemFont(ofSize: 16)
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0
        descLabel.textColor = .secondaryLabel
        container.addSubview(titleLabel)
        container.addSubview(descLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            descLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            descLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24)
        ])
        return container
    }

    private func setupUI() {
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        pages.forEach { stackView.addArrangedSubview($0) }

        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        pageControl.translatesAutoresizingMaskIntoConstraints = false

        nextButton.setTitle("Next", for: .normal)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        nextButton.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(stackView)
        view.addSubview(scrollView)
        view.addSubview(pageControl)
        view.addSubview(nextButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 300),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, multiplier: CGFloat(pages.count)),
            pageControl.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 16),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nextButton.topAnchor.constraint(equalTo: pageControl.bottomAnchor, constant: 24),
            nextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        pages.forEach { $0.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true }
    }

    @objc private func nextTapped() {
        if pageControl.currentPage == pages.count - 1 {
            requestPermissionsAndFinish()
        } else {
            pageControl.currentPage += 1
            scrollView.setContentOffset(CGPoint(x: CGFloat(pageControl.currentPage) * view.bounds.width, y: 0), animated: true)
            nextButton.setTitle(pageControl.currentPage == pages.count - 1 ? "Get Started" : "Next", for: .normal)
        }
    }

    private func requestPermissionsAndFinish() {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = CLLocationManager().authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        if status == .notDetermined {
            CLLocationManager().requestWhenInUseAuthorization()
        }
        UserDefaults.standard.set(true, forKey: "onboarding_complete")
        onComplete?(view.window)
    }
}

import CoreLocation

extension OnboardingViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        pageControl.currentPage = Int(scrollView.contentOffset.x / scrollView.bounds.width)
        nextButton.setTitle(pageControl.currentPage == pages.count - 1 ? "Get Started" : "Next", for: .normal)
    }
}
