//
//  HUDOverlayView.swift
//  Penumbra
//

import SwiftUI

// MARK: - Glass-effect compatibility shim (iOS 26+ → Liquid Glass, else ultra-thin material)

private extension View {
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 0.5)
                }
        }
    }

    @ViewBuilder
    func glassCapsule() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: Capsule())
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    func glassCircle() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: Circle())
        } else {
            self.background(.ultraThinMaterial, in: Circle())
        }
    }
}

// MARK: - Root overlay

struct HUDOverlayView: View {
    @Bindable var hudState: HUDState

    var body: some View {
        ZStack {
            topBar

            // Tap instruction (pre-placement, center-bottom)
            if !hudState.hasPlacedObject {
                VStack {
                    Spacer()
                    tapInstruction
                        .padding(.bottom, 48)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Right sidebar (post-placement)
            if hudState.hasPlacedObject && hudState.showSidebar {
                HStack(spacing: 0) {
                    Spacer()
                    SidebarView(hudState: hudState)
                        .frame(width: 272)
                        .padding(.trailing, 12)
                        .padding(.vertical, 12)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: hudState.hasPlacedObject)
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: hudState.showSidebar)
    }

    // MARK: Top bar

    private var topBar: some View {
        VStack {
            HStack(alignment: .center, spacing: 10) {
                PlaneBadgeView(count: hudState.detectedPlaneCount)
                Spacer()
                if hudState.hasPlacedObject {
                    sidebarToggle
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            Spacer()
        }
    }

    private var sidebarToggle: some View {
        Button {
            hudState.showSidebar.toggle()
        } label: {
            Image(systemName: hudState.showSidebar ? "xmark" : "slider.horizontal.3")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentTransition(.symbolEffect(.replace))
        }
        .glassCircle()
    }

    // MARK: Tap instruction

    private var tapInstruction: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.tap.fill")
                .font(.body)
            Text("Tap a detected surface to place")
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .glassCapsule()
    }
}

// MARK: - Plane detection badge

private struct PlaneBadgeView: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: count > 0 ? "rectangle.on.rectangle" : "dot.radiowaves.left.and.right")
                .font(.caption.weight(.semibold))
                .symbolEffect(.pulse, isActive: count == 0)
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassCapsule()
        .animation(.easeInOut(duration: 0.2), value: count)
    }

    private var label: String {
        switch count {
        case 0:  return "Scanning…"
        case 1:  return "1 surface"
        default: return "\(count) surfaces"
        }
    }
}

// MARK: - Sidebar panel

private struct SidebarView: View {
    @Bindable var hudState: HUDState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                sidebarHeader
                materialSection
                Divider().overlay(.secondary.opacity(0.25))
                lightSection
            }
            .padding(16)
        }
        .glassCard(cornerRadius: 22)
    }

    private var sidebarHeader: some View {
        Label("Controls", systemImage: "slider.horizontal.3")
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
    }

    private var materialSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Material")
            MaterialGrid(hudState: hudState)
        }
    }

    private var lightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Lighting")
            LightControls(hudState: hudState)
        }
    }
}

// MARK: - Shared label

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Material picker

private struct MaterialGrid: View {
    @Bindable var hudState: HUDState

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(MaterialOption.allCases, id: \.self) { option in
                MaterialCell(
                    option: option,
                    isSelected: hudState.selectedMaterial == option
                ) {
                    hudState.selectedMaterial = option
                }
            }
        }
    }
}

private struct MaterialCell: View {
    let option: MaterialOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Circle()
                    .fill(option.swatchColor)
                    .frame(width: 36, height: 36)
                    .overlay {
                        if option == .reflective {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.65), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    }
                    .overlay {
                        Circle()
                            .stroke(
                                isSelected ? Color.white : Color.white.opacity(0.2),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                    }
                    .shadow(color: isSelected ? .white.opacity(0.4) : .clear, radius: 6)

                Text(option.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(isSelected ? .white.opacity(0.1) : .clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Light controls

private struct LightControls: View {
    @Bindable var hudState: HUDState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $hudState.lightMode) {
                ForEach(LightMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if hudState.lightMode == .manual {
                VStack(spacing: 10) {
                    LightSliderRow(icon: "arrow.clockwise", label: "Direction",
                                   value: $hudState.manualAzimuth,  range: 0...360)
                    LightSliderRow(icon: "sun.max.fill",    label: "Intensity",
                                   value: $hudState.manualIntensity, range: 0...1)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: hudState.lightMode)
    }
}

private struct LightSliderRow: View {
    let icon: String
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
                .tint(.white)
        }
    }
}
