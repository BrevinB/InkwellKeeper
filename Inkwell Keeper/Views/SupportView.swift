//
//  SupportView.swift
//  Inkwell Keeper
//
//  View for supporting the developer and accessing help resources
//

import SwiftUI
import StoreKit

struct SupportView: View {
    @State private var showingTipJar = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Support the Developer
                    supportDeveloperSection

                    // Help & Resources
                    helpResourcesSection

                    // Feedback
                    feedbackSection
                }
                .padding()
            }
            .background(LorcanaBackground())
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingTipJar) {
                TipJarView()
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.lorcanaGold)

            Text("Thank You!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Ink Well Keeper is built with passion by an independent developer. Your support helps keep the app running and growing.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.6))
        )
    }

    private var supportDeveloperSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(.lorcanaGold)
                Text("Support Development")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text("Help keep Ink Well Keeper free and ad-free for everyone!")
                .font(.subheadline)
                .foregroundColor(.gray)

            // Tip Jar
            Button(action: {
                showingTipJar = true
            }) {
                HStack {
                    Image(systemName: "heart.circle.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Leave a Tip")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Support with a one-time tip")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.lorcanaGold.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.lorcanaGold, lineWidth: 2)
                        )
                )
            }

            // Share the App
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.lorcanaGold)
                    Text("Share with Friends")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }

                Text("Tell other Lorcana players about Inkwell Keeper!")
                    .font(.caption)
                    .foregroundColor(.gray)

                Button(action: shareApp) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share App")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.lorcanaGold)
                    .cornerRadius(10)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.lorcanaDark.opacity(0.4))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.6))
        )
    }

    private var helpResourcesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.lorcanaGold)
                Text("Help & Resources")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            // FAQ
            NavigationLink(destination: Text("FAQ Coming Soon").foregroundColor(.white)) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.lorcanaGold)
                    Text("Frequently Asked Questions")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.lorcanaDark.opacity(0.6))
                )
            }

            // Tutorial
            NavigationLink(destination: OnboardingView(onImportTap: {})) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.lorcanaGold)
                    Text("App Tutorial")
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.lorcanaDark.opacity(0.6))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.6))
        )
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.lorcanaGold)
                Text("Feedback")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text("Have a suggestion or found a bug? Let me know!")
                .font(.subheadline)
                .foregroundColor(.gray)

            // Email Contact
            Button(action: sendEmail) {
                HStack {
                    Image(systemName: "envelope")
                    Text("Send Feedback")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                )
            }

            // Rate on App Store
            Button(action: rateApp) {
                HStack {
                    Image(systemName: "star.fill")
                    Text("Rate on App Store")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.yellow.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.yellow, lineWidth: 1)
                        )
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.6))
        )
    }

    // MARK: - Actions

    private func shareApp() {
        let message = "Check out Ink Well Keeper - the best Lorcana collection tracker!"
        let appURL = URL(string: "https://apps.apple.com/us/app/ink-well-keeper/id6754206379")!

        let activityVC = UIActivityViewController(
            activityItems: [message, appURL],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(activityVC, animated: true)
        }
    }

    private func sendEmail() {
        let email = "brevbot2@gmail.com"
        let subject = "Ink Well Keeper Feedback"
        let body = "Hi! I have feedback about Ink Well Keeper:\n\n"

        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func rateApp() {
        // Use StoreKit's native review prompt
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
}

#Preview {
    SupportView()
}
