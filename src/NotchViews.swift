import SwiftUI

// MARK: - Custom Animatable Modifiers

struct VisorFlipModifier: AnimatableModifier {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees((1.0 - progress) * -75.0),
                axis: (x: 1.0, y: 0.0, z: 0.0),
                anchor: .top,
                perspective: 0.45
            )
            .opacity(min(1.0, progress * 1.6))
    }
}

struct LiquidMorphModifier: AnimatableModifier {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    
    func body(content: Content) -> some View {
        let p = max(0.0, min(1.0, progress))
        let scaleX = 0.42 + (0.58 * pow(p, 0.7))
        let scaleY = 0.20 + (0.80 * pow(p, 1.2))
        return content
            .scaleEffect(x: scaleX, y: scaleY, anchor: .top)
            .opacity(min(1.0, p * 1.5))
    }
}

// Iconic Apple Window Minimization Genie Effect
struct GenieGeometryEffect: GeometryEffect {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let w = size.width
        let h = size.height
        let p = max(0.001, min(1.0, progress))
        let centerX = w / 2.0
        
        // Top narrows into the camera notch opening first (suction neck)
        let topHalfWidth = mix(15.0, w / 2.0, pow(p, 1.85))
        // Bottom stays wider as it trails upwards (the classic flared genie skirt)
        let bottomHalfWidth = mix(2.0, w / 2.0, pow(p, 0.45))
        
        // Vertical non-linear suction stretch
        let topY = mix(-32.0, 0.0, p)
        let bottomY = mix(0.0, h, pow(p, 0.70))
        
        let x0 = centerX - topHalfWidth
        let y0 = topY
        let x1 = centerX + topHalfWidth
        let y1 = topY
        let x2 = centerX + bottomHalfWidth
        let y2 = bottomY
        let x3 = centerX - bottomHalfWidth
        let y3 = bottomY
        
        let dx1 = x1 - x2
        let dx2 = x3 - x2
        let sx = x0 - x1 + x2 - x3
        let dy1 = y1 - y2
        let dy2 = y3 - y2
        let sy = y0 - y1 + y2 - y3
        
        let z = dx1 * dy2 - dy1 * dx2
        guard abs(z) > 0.0001 else {
            return ProjectionTransform(CGAffineTransform(scaleX: CGFloat(p), y: CGFloat(p)))
        }
        let g = (sx * dy2 - sy * dx2) / z
        let h_val = (dx1 * sy - dy1 * sx) / z
        
        let a = x1 - x0 + g * x1
        let b = x3 - x0 + h_val * x3
        let c = x0
        let d = y1 - y0 + g * y1
        let e = y3 - y0 + h_val * y3
        let f = y0
        
        var cat = CATransform3DIdentity
        cat.m11 = a / w
        cat.m12 = d / w
        cat.m14 = g / w
        cat.m21 = b / h
        cat.m22 = e / h
        cat.m24 = h_val / h
        cat.m41 = c
        cat.m42 = f
        cat.m44 = 1.0
        
        return ProjectionTransform(cat)
    }
    
    private func mix(_ a: CGFloat, _ b: CGFloat, _ t: Double) -> CGFloat {
        return a + CGFloat(t) * (b - a)
    }
}

struct GenieModifier: AnimatableModifier {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }
    
    func body(content: Content) -> some View {
        content
            .modifier(GenieGeometryEffect(progress: progress))
            .opacity(min(1.0, progress * 1.5))
    }
}

// MARK: - Animation Styles

enum AnimationStyle: String, CaseIterable, Identifiable {
    case genie = "Genie"
    case visorFlip = "3D Visor"
    case elasticPop = "Bouncy"
    case liquidMorph = "Liquid"
    case slideShutter = "Shutter"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    
    var shortName: String {
        switch self {
        case .genie: return "Genie"
        case .visorFlip: return "3D Visor"
        case .elasticPop: return "Bouncy"
        case .liquidMorph: return "Liquid"
        case .slideShutter: return "Shutter"
        }
    }
    
    var description: String {
        switch self {
        case .genie: return "Apple Window Minimization Funnel"
        case .visorFlip: return "Spatial 3D Perspective Flip"
        case .elasticPop: return "Playful Spring Overshoot Bounce"
        case .liquidMorph: return "Dynamic Island Liquid Stretch"
        case .slideShutter: return "Clean Rapid Vertical Slide"
        }
    }
    
    var iconName: String {
        switch self {
        case .genie: return "sparkles.rectangle.stack"
        case .visorFlip: return "cube.transparent"
        case .elasticPop: return "sparkles"
        case .liquidMorph: return "drop.fill"
        case .slideShutter: return "arrow.down.to.line"
        }
    }
    
    var inAnimation: Animation {
        switch self {
        case .genie:
            return .spring(response: 0.36, dampingFraction: 0.78)
        case .visorFlip:
            return .spring(response: 0.28, dampingFraction: 0.78)
        case .elasticPop:
            return .spring(response: 0.38, dampingFraction: 0.58)
        case .liquidMorph:
            return .spring(response: 0.30, dampingFraction: 0.74)
        case .slideShutter:
            return .spring(response: 0.20, dampingFraction: 0.85)
        }
    }
    
    var outAnimation: Animation {
        switch self {
        case .genie:
            return .easeInOut(duration: 0.28)
        case .visorFlip:
            return .spring(response: 0.18, dampingFraction: 0.92)
        case .elasticPop:
            return .spring(response: 0.16, dampingFraction: 0.88)
        case .liquidMorph:
            return .spring(response: 0.18, dampingFraction: 0.92)
        case .slideShutter:
            return .spring(response: 0.11, dampingFraction: 0.96)
        }
    }
    
    var transition: AnyTransition {
        switch self {
        case .genie:
            return .modifier(active: GenieModifier(progress: 0), identity: GenieModifier(progress: 1))
        case .visorFlip:
            return .modifier(active: VisorFlipModifier(progress: 0), identity: VisorFlipModifier(progress: 1))
        case .elasticPop:
            return .scale(scale: 0.50, anchor: .top).combined(with: .move(edge: .top)).combined(with: .opacity)
        case .liquidMorph:
            return .modifier(active: LiquidMorphModifier(progress: 0), identity: LiquidMorphModifier(progress: 1))
        case .slideShutter:
            return .move(edge: .top).combined(with: .opacity)
        }
    }
}

// MARK: - Shared Island State

class IslandState: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var isPinned: Bool = false
    @Published var selectedStyle: AnimationStyle {
        didSet {
            UserDefaults.standard.set(selectedStyle.rawValue, forKey: "notch_animation_style")
        }
    }
    
    init() {
        let saved = UserDefaults.standard.string(forKey: "notch_animation_style") ?? ""
        self.selectedStyle = AnimationStyle(rawValue: saved) ?? .genie
    }
}

enum TooltipPlacement {
    case top
    case bottom
}

// MARK: - macOS Dock-Style Floating Tooltip

struct DockTooltip: View {
    let text: String
    var anchor: UnitPoint = .top
    
    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                ZStack {
                    // Solid obsidian deep black capsule
                    Capsule()
                        .fill(Color(red: 0.06, green: 0.06, blue: 0.08).opacity(0.98))
                    
                    // Glass specular sheen on top half
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.16), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.18)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
            )
            .shadow(color: Color.black.opacity(0.75), radius: 6, x: 0, y: 3)
            .shadow(color: Color.black.opacity(0.40), radius: 2, x: 0, y: 1)
            .fixedSize()
            .allowsHitTesting(false)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.82, anchor: anchor).combined(with: .opacity),
                removal: .scale(scale: 0.82, anchor: anchor).combined(with: .opacity)
            ))
    }
}

// MARK: - Header Icon Button with Instant Dock Tooltip

struct HeaderIconButton: View {
    let icon: String
    var size: CGFloat = 12
    var weight: Font.Weight = .semibold
    var isHighlighted: Bool = false
    var isHovered: Bool = false
    var defaultColor: Color = .gray
    var highlightedColor: Color = .cyan
    let tooltipText: String
    var tooltipPlacement: TooltipPlacement = .bottom
    var tooltipOffsetX: CGFloat = 0
    var rotationDegrees: Double = 0
    let action: () -> Void
    let onHover: (Bool) -> Void
    
    private var iconColor: Color {
        if isHighlighted { return highlightedColor }
        if isHovered { return .white }
        return defaultColor
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: weight))
                .foregroundColor(iconColor)
                .rotationEffect(.degrees(rotationDegrees))
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .overlay(alignment: tooltipPlacement == .top ? .top : .bottom) {
            if isHovered {
                DockTooltip(
                    text: tooltipText,
                    anchor: tooltipPlacement == .top ? .bottom : .top
                )
                .offset(
                    x: tooltipOffsetX,
                    y: tooltipPlacement == .top ? -24 : 22
                )
                .zIndex(100)
            }
        }
    }
}

// MARK: - Style Pill Button with Tooltip

struct StylePillButton: View {
    let style: AnimationStyle
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void
    let onHover: (Bool) -> Void
    
    private var textColor: Color {
        if isSelected { return .cyan }
        if isHovered { return .white }
        return .gray
    }
    
    private var bgFill: Color {
        if isSelected { return Color.cyan.opacity(0.25) }
        return Color.white.opacity(0.06)
    }
    
    private var borderStroke: Color {
        if isSelected { return Color.cyan.opacity(0.8) }
        return Color.white.opacity(0.08)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: style.iconName)
                    .font(.system(size: 8))
                Text(style.shortName)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(bgFill))
            .overlay(Capsule().strokeBorder(borderStroke, lineWidth: 0.6))
            .foregroundColor(textColor)
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .overlay(alignment: .bottom) {
            if isHovered {
                DockTooltip(text: style.description, anchor: .top)
                    .offset(y: 22)
                    .zIndex(100)
            }
        }
    }
}

// MARK: - Notch View

struct NotchView: View {
    @ObservedObject var manager: AttendanceManager
    @ObservedObject var islandState: IslandState
    var notchHeight: CGFloat = 32.0
    var onQuit: () -> Void
    
    @State private var showManualInput: Bool = false
    @State private var manualInputText: String = "09:15 AM"
    @State private var showStylePicker: Bool = false
    @State private var hoveredTooltip: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Spacer to clear the physical notch hardware
            Color.clear
                .frame(height: notchHeight)
            
            if islandState.isExpanded {
                expandedIslandView
                    .transition(islandState.selectedStyle.transition)
            }
            
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Expanded Island (Authentic macOS System Styling)
    private var expandedIslandView: some View {
        VStack(spacing: 10) {
            // Header Row
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: statusColor.opacity(0.8), radius: 3)
                    
                    Text("greytHR Attendance")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(statusBadgeText)
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.25))
                        .foregroundColor(statusColor)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // 1. Animation Style Button (bottom tooltip to avoid notch occlusion)
                    HeaderIconButton(
                        icon: "wand.and.stars",
                        size: 12,
                        weight: .semibold,
                        isHighlighted: showStylePicker,
                        isHovered: hoveredTooltip == "Animation Style",
                        tooltipText: "Animation Style",
                        tooltipPlacement: .bottom,
                        tooltipOffsetX: 0,
                        action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showStylePicker.toggle()
                                if showStylePicker { showManualInput = false }
                            }
                        },
                        onHover: { h in
                            withAnimation(.spring(response: 0.16, dampingFraction: 0.8)) {
                                if h { hoveredTooltip = "Animation Style" }
                                else if hoveredTooltip == "Animation Style" { hoveredTooltip = nil }
                            }
                        }
                    )
                    
                    // 2. Manual Time Override Button (bottom tooltip)
                    HeaderIconButton(
                        icon: "pencil.circle",
                        size: 13,
                        weight: .medium,
                        isHighlighted: showManualInput,
                        isHovered: hoveredTooltip == "Manual Swipe Time",
                        tooltipText: "Manual Swipe Time",
                        tooltipPlacement: .bottom,
                        tooltipOffsetX: 0,
                        action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showManualInput.toggle()
                                if showManualInput { showStylePicker = false }
                            }
                        },
                        onHover: { h in
                            withAnimation(.spring(response: 0.16, dampingFraction: 0.8)) {
                                if h { hoveredTooltip = "Manual Swipe Time" }
                                else if hoveredTooltip == "Manual Swipe Time" { hoveredTooltip = nil }
                            }
                        }
                    )
                    
                    // 3. Sync Button (bottom tooltip)
                    HeaderIconButton(
                        icon: "arrow.clockwise",
                        size: 12,
                        weight: .semibold,
                        isHighlighted: manager.isSyncing,
                        isHovered: hoveredTooltip == "Refresh Attendance" || hoveredTooltip == "Syncing greytHR...",
                        tooltipText: manager.isSyncing ? "Syncing greytHR..." : "Refresh Attendance",
                        tooltipPlacement: .bottom,
                        tooltipOffsetX: 0,
                        rotationDegrees: manager.isSyncing ? 360 : 0,
                        action: { manager.triggerSync() },
                        onHover: { h in
                            withAnimation(.spring(response: 0.16, dampingFraction: 0.8)) {
                                let text = manager.isSyncing ? "Syncing greytHR..." : "Refresh Attendance"
                                if h { hoveredTooltip = text }
                                else if hoveredTooltip == text { hoveredTooltip = nil }
                            }
                        }
                    )
                    .animation(manager.isSyncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: manager.isSyncing)
                    
                    // 4. Pin Button (top tooltip - clear of notch)
                    HeaderIconButton(
                        icon: islandState.isPinned ? "pin.fill" : "pin",
                        size: 12,
                        weight: .semibold,
                        isHighlighted: islandState.isPinned,
                        isHovered: hoveredTooltip == "Pin Window Open" || hoveredTooltip == "Unpin Window",
                        defaultColor: .gray,
                        highlightedColor: .yellow,
                        tooltipText: islandState.isPinned ? "Unpin Window" : "Pin Window Open",
                        tooltipPlacement: .top,
                        tooltipOffsetX: 0,
                        action: { islandState.isPinned.toggle() },
                        onHover: { h in
                            withAnimation(.spring(response: 0.16, dampingFraction: 0.8)) {
                                let text = islandState.isPinned ? "Unpin Window" : "Pin Window Open"
                                if h { hoveredTooltip = text }
                                else if hoveredTooltip == text { hoveredTooltip = nil }
                            }
                        }
                    )
                    
                    // 5. Quit Button (top tooltip - clear of notch)
                    HeaderIconButton(
                        icon: "power",
                        size: 11,
                        weight: .semibold,
                        isHighlighted: false,
                        isHovered: hoveredTooltip == "Quit GreytNotch",
                        defaultColor: .gray.opacity(0.7),
                        highlightedColor: .white,
                        tooltipText: "Quit GreytNotch",
                        tooltipPlacement: .top,
                        tooltipOffsetX: -20,
                        action: onQuit,
                        onHover: { h in
                            withAnimation(.spring(response: 0.16, dampingFraction: 0.8)) {
                                if h { hoveredTooltip = "Quit GreytNotch" }
                                else if hoveredTooltip == "Quit GreytNotch" { hoveredTooltip = nil }
                            }
                        }
                    )
                }
            }
            .zIndex(100)
            
            // Inline Animation Style Selector
            if showStylePicker {
                HStack(spacing: 4) {
                    ForEach(AnimationStyle.allCases) { style in
                        StylePillButton(
                            style: style,
                            isSelected: islandState.selectedStyle == style,
                            isHovered: hoveredTooltip == style.description,
                            action: {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                    islandState.selectedStyle = style
                                }
                            },
                            onHover: { h in
                                withAnimation(.spring(response: 0.16, dampingFraction: 0.8)) {
                                    if h { hoveredTooltip = style.description }
                                    else if hoveredTooltip == style.description { hoveredTooltip = nil }
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
                .zIndex(90)
            }
            
            if showManualInput {
                // Inline Manual Time Editor
                HStack(spacing: 8) {
                    Text("Set First Swipe:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                    
                    TextField("09:15 AM", text: $manualInputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(5)
                        .frame(width: 90)
                    
                    Button("Save") {
                        manager.setManualTime(manualInputText)
                        showManualInput = false
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.small)
                    
                    Button("Cancel") {
                        showManualInput = false
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.gray)
                }
                .padding(.vertical, 2)
            } else if !showStylePicker {
                // Swipe In / Progress / Target Out Row
                HStack(spacing: 14) {
                    // First In
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FIRST IN")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        Text(manager.data.first_in ?? "--:--")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    // Glowing Progress Bar
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 7)
                                    
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: manager.isCompleted ? [Color.green, Color.mint] : [Color.blue, Color.cyan, Color.green],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .frame(width: max(7, geo.size.width * CGFloat(manager.progress)), height: 7)
                                    .shadow(color: (manager.isCompleted ? Color.green : Color.cyan).opacity(0.6), radius: 4)
                            }
                        }
                        .frame(height: 7)
                        
                        Text("\(Int(manager.progress * 100))%")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Target Out
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("TARGET OUT (8H)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        Text(manager.data.target_out ?? "--:--")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Bottom Status Details
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text("Elapsed: \(manager.formatElapsed())")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 5) {
                        Image(systemName: manager.isCompleted ? "checkmark.seal.fill" : "clock.arrow.circlepath")
                            .font(.system(size: 11))
                            .foregroundColor(statusColor)
                        
                        Text(manager.statusMessage)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(manager.isCompleted ? .green : .white)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 380)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.135, green: 0.135, blue: 0.155).opacity(0.92)) // Consistent dark acrylic glass (zero 3D backdrop flash)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.035)) // Subtle glass luster
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5) // Authentic macOS hairline specular edge
                )
                // Default macOS System Popover / Spotlight Drop Shadow (Apple HIG calibrated)
                .shadow(color: Color.black.opacity(0.14), radius: 4, x: 0, y: 2)   // Crisp key-light contact shadow
                .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 6)  // Clean, tight ambient falloff
        )
    }
    
    // MARK: - Color & Text Helpers
    private var statusColor: Color {
        if manager.isCompleted {
            return .green
        } else if manager.data.first_in != nil {
            return .cyan
        } else {
            return .orange
        }
    }
    
    private var statusBadgeText: String {
        if manager.isCompleted {
            return "DONE 8H"
        } else if manager.data.first_in != nil {
            return "ACTIVE"
        } else {
            return "PENDING"
        }
    }
}
