//
//  OnboardingView.swift
//  Inkwell Keeper
//
//  First-time user onboarding flow
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    let onImportTap: () -> Void

    var body: some View {
        ZStack {
            // Background
            LorcanaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        completeOnboarding()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray.opacity(0.6))
                    }
                    .padding()
                }

                // Content
                TabView(selection: $currentPage) {
                    welcomePage
                        .tag(0)

                    featuresPage
                        .tag(1)

                    importPage
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                // Bottom buttons
                bottomButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 80))
                .foregroundColor(.lorcanaGold)

            VStack(spacing: 12) {
                Text("Welcome to")
                    .font(.title2)
                    .foregroundColor(.gray)

                Text("Ink Well Keeper")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("Your ultimate Disney Lorcana collection manager")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Text("Free • No Ads • No Tracking")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.6))

            Spacer()
        }
    }

    private var featuresPage: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Powerful Features")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 24) {
                featureRow(
                    icon: "viewfinder",
                    title: "Scan Cards",
                    description: "Use your camera to quickly add cards to your collection"
                )

                featureRow(
                    icon: "chart.bar.fill",
                    title: "Track Value",
                    description: "See real-time pricing and total collection value"
                )

                featureRow(
                    icon: "books.vertical.fill",
                    title: "Browse Sets",
                    description: "Explore all Lorcana sets and track your progress"
                )

                featureRow(
                    icon: "square.and.arrow.down.fill",
                    title: "Import Collections",
                    description: "Easily import from Dreamborn.ink or CSV files"
                )
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var importPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "square.and.arrow.down.fill")
                .font(.system(size: 70))
                .foregroundColor(.lorcanaGold)

            VStack(spacing: 12) {
                Text("Import Your Collection")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text("Already tracking cards on Dreamborn.ink?")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                importStep(number: 1, text: "Export your collection from Dreamborn.ink as CSV")
                importStep(number: 2, text: "Tap 'Import Now' below")
                importStep(number: 3, text: "Select your exported file")
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.1))
            )
            .padding(.horizontal, 24)

            Text("You can also add cards manually or by scanning anytime!")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Components

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.lorcanaGold)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
    }

    private func importStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.lorcanaGold)
                )

            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)

            Spacer()
        }
    }

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            if currentPage == 2 {
                // On last page, show Skip and Import Now
                Button {
                    completeOnboarding()
                } label: {
                    Text("Skip for Now")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }

                Button {
                    completeOnboarding()
                    onImportTap()
                } label: {
                    Text("Import Now")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.lorcanaGold)
                        )
                }
            } else {
                // On other pages, show Next button
                Button {
                    withAnimation {
                        currentPage += 1
                    }
                } label: {
                    Text("Next")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.lorcanaGold)
                        )
                }
            }
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        dismiss()
    }
}

#Preview {
    OnboardingView(onImportTap: {})
}
