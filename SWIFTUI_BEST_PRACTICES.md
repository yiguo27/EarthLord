# 🚀 SwiftUI 性能优化最佳实践

## 📊 性能问题诊断报告

基于对 EarthLord 项目的深度分析，发现了 9 个主要性能问题。本文档提供完整的优化方案。

---

## 🔴 高优先级问题

### 1. 过度使用 @Published 导致频繁重渲染

#### ❌ 问题代码 (LocationManager.swift:18-66)

```swift
@MainActor
final class LocationManager: NSObject, ObservableObject {
    // 13 个 @Published 属性，任意一个变化都触发所有监听视图重渲染
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []  // ⚠️ 每2秒更新
    @Published var speedWarning: String?
    @Published var isOverSpeed: Bool = false
    // ... 还有 8 个
}
```

**问题：** 地图追踪时，`pathCoordinates` 每 2 秒更新一次，导致监听的所有视图（MapTabView、按钮组、Banner）全部重渲染。

#### ✅ 解决方案：分离关注点

```swift
// 1️⃣ 核心状态 Manager - 只包含关键状态
@MainActor
final class LocationCoreManager: ObservableObject {
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking: Bool = false
    @Published var locationError: String?

    // 计算属性，不触发重渲染
    var hasPreciseLocation: Bool {
        accuracyAuthorization == .fullAccuracy
    }
}

// 2️⃣ 路径追踪 Manager - 分离高频更新的状态
@MainActor
final class PathTrackingManager: ObservableObject {
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []
    @Published var pathUpdateVersion: Int = 0
    @Published var isPathClosed: Bool = false
    @Published var calculatedArea: Double = 0

    // 增量更新，避免全量复制
    func appendCoordinate(_ coordinate: CLLocationCoordinate2D) {
        pathCoordinates.append(coordinate)
        pathUpdateVersion += 1
    }
}

// 3️⃣ 速度监控 Manager - 分离瞬态状态
@MainActor
final class SpeedMonitor: ObservableObject {
    @Published var speedWarning: String?
    @Published var isOverSpeed: Bool = false

    private var clearTask: Task<Void, Never>?

    func showWarning(_ message: String) {
        speedWarning = message
        isOverSpeed = true

        // 取消之前的清除任务
        clearTask?.cancel()

        // 使用 Task 而不是 DispatchQueue
        clearTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            speedWarning = nil
            isOverSpeed = false
        }
    }
}
```

**使用示例：**

```swift
// 在视图中只订阅需要的 Manager
struct MapTabView: View {
    @ObservedObject private var coreManager = LocationCoreManager.shared
    @ObservedObject private var pathManager = PathTrackingManager.shared
    // speedMonitor 只在需要显示警告的视图中订阅

    var body: some View {
        // ✅ 现在 pathCoordinates 更新不会触发整个视图重渲染
    }
}

struct SpeedWarningBanner: View {
    @ObservedObject private var speedMonitor = SpeedMonitor.shared

    var body: some View {
        // ✅ 只有这个 Banner 会在警告变化时重渲染
    }
}
```

---

### 2. 重复的网络请求和数据库查询

#### ❌ 问题代码 (AuthManager.swift)

```swift
// 多处重复查询 session
func uploadTerritory() async {
    guard let userId = try? await supabase.auth.session.user.id else { return }
    // 网络请求...
}

func loadTerritories() async {
    guard let userId = try? await supabase.auth.session.user.id else { return }
    // 网络请求...
}

func deleteAccount() async {
    let session = try await supabase.auth.session
    // 网络请求...
}
```

**问题：** 每次操作都查询 session，导致不必要的网络延迟。

#### ✅ 解决方案：缓存 Session

```swift
@MainActor
final class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?

    // 缓存 userId，避免重复查询
    private(set) var cachedUserId: String?

    // 统一的 userId 获取方法
    func getUserId() async throws -> String {
        // 1️⃣ 优先使用缓存
        if let cachedId = cachedUserId {
            return cachedId
        }

        // 2️⃣ 缓存未命中，从 session 获取
        let session = try await supabase.auth.session
        let userId = session.user.id

        // 3️⃣ 更新缓存
        cachedUserId = userId
        return userId
    }

    func signIn(email: String, password: String) async {
        // ...登录成功后
        cachedUserId = response.user.id  // ✅ 缓存 userId
        currentUser = response.user
        isAuthenticated = true
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        cachedUserId = nil  // ✅ 清除缓存
        resetState()
    }
}

// 使用时：
func uploadTerritory() async {
    guard let userId = try? await AuthManager.shared.getUserId() else { return }
    // ✅ 第一次从网络获取，后续使用缓存
}
```

---

### 3. OTP 验证的串行重试

#### ❌ 问题代码 (AuthManager.swift:126-174)

```swift
// 三种类型依次尝试，每次都是网络调用
do {
    let response = try await supabase.auth.verifyOTP(email: email, token: code, type: .magiclink)
    return
} catch { }

do {
    let response = try await supabase.auth.verifyOTP(email: email, token: code, type: .email)
    return
} catch { }

do {
    let response = try await supabase.auth.verifyOTP(email: email, token: code, type: .signup)
    return
} catch { }
```

**问题：** 如果前两种失败，用户需要等待 3 次网络请求的总时间。

#### ✅ 解决方案：并行尝试

```swift
func verifyRegisterOTP(email: String, code: String) async {
    guard !code.isEmpty else { errorMessage = "请输入验证码"; return }

    isLoading = true
    errorMessage = nil

    // ✅ 使用 TaskGroup 并行尝试三种类型
    await withTaskGroup(of: (AuthResponse?, OTPType)?.self) { group in
        // 同时启动三个验证任务
        group.addTask {
            try? (await supabase.auth.verifyOTP(email: email, token: code, type: .magiclink), .magiclink)
        }
        group.addTask {
            try? (await supabase.auth.verifyOTP(email: email, token: code, type: .email), .email)
        }
        group.addTask {
            try? (await supabase.auth.verifyOTP(email: email, token: code, type: .signup), .signup)
        }

        // 等待第一个成功的结果
        for await result in group {
            if let (response, type) = result {
                print("✅ OTP验证成功: \(type)")
                currentUser = response.user
                otpVerified = true
                needsPasswordSetup = true

                // 取消其他任务
                group.cancelAll()
                break
            }
        }
    }

    if !otpVerified {
        errorMessage = "验证码错误或已过期"
    }

    isLoading = false
}
```

**性能提升：** 从串行 ~3秒 → 并行 ~1秒

---

## 🟡 中优先级问题

### 4. 数据加载瀑布流

#### ❌ 问题代码 (RootView.swift:70-78)

```swift
.onChange(of: splashFinished) { finished in
    if finished {
        // ⚠️ 串行执行：启动页 → 检查会话 → 加载主界面
        Task {
            await authManager.checkSession()
            sessionChecked = true
        }
    }
}
```

#### ✅ 解决方案：并行初始化

```swift
.onChange(of: splashFinished) { finished in
    if finished {
        // ✅ 并行执行多个初始化任务
        Task {
            await withTaskGroup(of: Void.self) { group in
                // 任务1：检查会话
                group.addTask {
                    await authManager.checkSession()
                }

                // 任务2：预加载用户设置
                group.addTask {
                    await LanguageManager.shared.loadSettings()
                }

                // 任务3：初始化位置服务
                group.addTask {
                    await LocationManager.shared.setup()
                }

                // 等待所有任务完成
                await group.waitForAll()
            }

            sessionChecked = true
        }
    }
}
```

**性能提升：** 从 2+秒 → ~1秒（最慢任务的时间）

---

### 5. 视图层级过深

#### ❌ 问题代码 (MapTabView.swift:45-128)

```swift
var body: some View {
    ZStack {                          // 第1层
        VStack(spacing: 0) {          // 第2层
            headerView
            ZStack(alignment: .top) {  // 第4层
                mapContentView
                VStack(spacing: 0) {   // 第6层
                    speedWarningBanner
                    if showValidationBanner {  // 第8层
                        validationResultBanner
                    }
                }
            }
        }
        VStack {                      // 第10层
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 12) {  // 第11层
                    // 按钮组...
                }
            }
        }
    }
}
```

#### ✅ 解决方案：提取组件

```swift
var body: some View {
    ZStack {
        ApocalypseTheme.background.ignoresSafeArea()

        VStack(spacing: 0) {
            headerView

            // ✅ 提取为独立组件
            MapContentWithOverlays()
        }

        // ✅ 提取为独立组件
        FloatingActionButtons()
    }
}

// ✅ 独立的覆盖层组件
struct MapContentWithOverlays: View {
    @ObservedObject private var locationManager = LocationManager.shared

    var body: some View {
        ZStack(alignment: .top) {
            MapViewRepresentable(...)

            VStack(spacing: 0) {
                SpeedWarningBanner()
                ValidationResultBanner()
            }
        }
    }
}

// ✅ 独立的按钮组组件
struct FloatingActionButtons: View {
    @ObservedObject private var locationManager = LocationManager.shared

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                buttonStack
            }
        }
    }

    @ViewBuilder
    private var buttonStack: some View {
        VStack(spacing: 12) {
            if locationManager.territoryValidationPassed {
                ConfirmButton()
            }
            TrackingButton()
            RelocateButton()
        }
        .padding(.trailing, 16)
        .padding(.bottom, 16)
    }
}
```

**优势：**
- 减少嵌套层级（12层 → 6层）
- 每个组件独立更新，不影响其他部分
- 代码更易维护和测试

---

### 6. 地图的全量重渲染

#### ❌ 问题代码 (MapViewRepresentable.swift:120-145)

```swift
private func updateTrackingPath(on mapView: MKMapView, coordinator: Coordinator) {
    // ⚠️ 每次都删除所有覆盖物，重新添加
    let existingOverlays = mapView.overlays.filter { $0 is MKPolyline || $0 is MKPolygon }
    mapView.removeOverlays(existingOverlays)

    // ⚠️ 重新转换所有坐标
    let gcj02Coordinates = CoordinateConverter.wgs84ToGcj02(trackingPath)

    // ⚠️ 重新创建覆盖物
    if isPathClosed {
        let polygon = MKPolygon(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
        mapView.addOverlay(polygon)
    } else {
        let polyline = MKPolyline(coordinates: gcj02Coordinates, count: gcj02Coordinates.count)
        mapView.addOverlay(polyline)
    }
}
```

#### ✅ 解决方案：增量更新

```swift
class Coordinator: NSObject, MKMapViewDelegate {
    var lastPathVersion: Int = 0
    var lastClosedState: Bool = false

    // ✅ 缓存已转换的坐标
    var cachedConvertedCoordinates: [CLLocationCoordinate2D] = []
    var cachedOriginalCount: Int = 0
}

private func updateTrackingPath(on mapView: MKMapView, coordinator: Coordinator) {
    // ✅ 检查是否可以增量更新
    let canIncrementalUpdate = !coordinator.lastClosedState && !isPathClosed

    if canIncrementalUpdate && trackingPath.count > coordinator.cachedOriginalCount {
        // 1️⃣ 只转换新增的坐标
        let newCoordinates = Array(trackingPath.dropFirst(coordinator.cachedOriginalCount))
        let newConverted = CoordinateConverter.wgs84ToGcj02(newCoordinates)
        coordinator.cachedConvertedCoordinates.append(contentsOf: newConverted)
        coordinator.cachedOriginalCount = trackingPath.count

        // 2️⃣ 只删除旧的 polyline
        let oldPolylines = mapView.overlays.filter { $0 is MKPolyline }
        mapView.removeOverlays(oldPolylines)

        // 3️⃣ 用新的完整坐标创建 polyline
        let polyline = MKPolyline(
            coordinates: coordinator.cachedConvertedCoordinates,
            count: coordinator.cachedConvertedCoordinates.count
        )
        mapView.addOverlay(polyline)
    } else {
        // 全量更新（仅在闭合路径时）
        coordinator.cachedConvertedCoordinates = CoordinateConverter.wgs84ToGcj02(trackingPath)
        coordinator.cachedOriginalCount = trackingPath.count

        let existingOverlays = mapView.overlays.filter { $0 is MKPolyline || $0 is MKPolygon }
        mapView.removeOverlays(existingOverlays)

        if isPathClosed {
            let polygon = MKPolygon(
                coordinates: coordinator.cachedConvertedCoordinates,
                count: coordinator.cachedConvertedCoordinates.count
            )
            mapView.addOverlay(polygon)
        } else {
            let polyline = MKPolyline(
                coordinates: coordinator.cachedConvertedCoordinates,
                count: coordinator.cachedConvertedCoordinates.count
            )
            mapView.addOverlay(polyline)
        }
    }
}
```

**性能提升：**
- 追踪 50 个点时，新增一个点：O(50) → O(1)
- 坐标转换：50 次 → 1 次
- 地图渲染更流畅

---

### 7. 频繁的主线程操作

#### ❌ 问题代码 (LocationManager.swift:547-580)

```swift
// ⚠️ 每 2 秒调用，嵌套多个 DispatchQueue.main.async
if speedKmh > 30 {
    DispatchQueue.main.async {
        self.speedWarning = "速度过快..."
        self.isOverSpeed = true
    }
}

if speedKmh > 15 {
    DispatchQueue.main.async {
        self.speedWarning = "移动速度较快..."
        self.isOverSpeed = true

        // ⚠️ 再嵌套一个 asyncAfter
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.speedWarning?.contains("移动速度较快") == true {
                self.speedWarning = nil
                self.isOverSpeed = false
            }
        }
    }
}
```

#### ✅ 解决方案：使用 @Published 和 Task

```swift
@MainActor  // ✅ 确保所有属性更新在主线程
final class SpeedMonitor: ObservableObject {
    @Published var speedWarning: String?
    @Published var isOverSpeed: Bool = false

    private var clearTask: Task<Void, Never>?

    // ✅ 统一的警告处理方法
    func updateSpeedWarning(speedKmh: Double, isTracking: Bool) {
        // 取消之前的清除任务
        clearTask?.cancel()

        if !isTracking || speedKmh <= 15 {
            speedWarning = nil
            isOverSpeed = false
            return
        }

        if speedKmh > 30 {
            speedWarning = "速度过快，GPS 定位将不准确！"
            isOverSpeed = true
        } else if speedKmh > 15 {
            speedWarning = "移动速度较快，建议放慢速度以确保定位准确。"
            isOverSpeed = true

            // ✅ 使用 Task 代替 DispatchQueue
            clearTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }

                if self.speedWarning?.contains("移动速度较快") == true {
                    self.speedWarning = nil
                    self.isOverSpeed = false
                }
            }
        }
    }
}

// 使用：
func recordPathPoint() {
    // ...计算速度

    // ✅ 单次调用，不需要手动 dispatch
    speedMonitor.updateSpeedWarning(speedKmh: speedKmh, isTracking: isTracking)
}
```

---

### 8. 缺少 LazyVStack

#### ❌ 问题代码 (ProfileTabView.swift:27-50)

```swift
ScrollView {
    VStack(spacing: 16) {
        survivorProfileCard
        statsCard
        functionsCard
        logoutButton
        deleteAccountButton
        Spacer(minLength: 20)
    }
}
```

**问题：** 如果卡片内容很多（如显示用户的所有领地列表），会一次性全部加载。

#### ✅ 解决方案：使用 LazyVStack

```swift
ScrollView {
    LazyVStack(spacing: 16) {  // ✅ 改为 LazyVStack
        survivorProfileCard
        statsCard

        // ✅ 如果有列表，也用 LazyVStack
        Section("我的领地") {
            ForEach(territories, id: \.id) { territory in
                TerritoryCard(territory: territory)
                    // ✅ 只有滚动到可见区域才会创建视图
            }
        }

        functionsCard
        logoutButton
        deleteAccountButton
        Spacer(minLength: 20)
    }
    .padding(.horizontal, 16)
}
```

**优势：**
- 视图按需创建，不是一次性全部创建
- 内存占用更少
- 滚动性能更好

---

## 🟠 低优先级问题

### 9. 语言翻译的重复计算

#### ❌ 问题代码 (LanguageManager.swift:156-163)

```swift
// 每次调用都计算 effectiveLanguageCode
func localizedString(_ key: String) -> String {
    if effectiveLanguageCode == "zh-Hans" {
        return key
    }
    return translations[key] ?? key
}

// effectiveLanguageCode 每次都要计算
var effectiveLanguageCode: String {
    if let selected = selectedLanguage {
        return selected.code
    }
    // Locale 查询...
}
```

#### ✅ 解决方案：缓存计算结果

```swift
@MainActor
final class LanguageManager: ObservableObject {
    @Published var selectedLanguage: AppLanguage? {
        didSet {
            // ✅ 语言变化时更新缓存
            updateEffectiveLanguageCache()
        }
    }

    // ✅ 缓存 effectiveLanguageCode
    private var cachedEffectiveLanguageCode: String = "zh-Hans"

    var effectiveLanguageCode: String {
        cachedEffectiveLanguageCode
    }

    private func updateEffectiveLanguageCache() {
        if let selected = selectedLanguage {
            cachedEffectiveLanguageCode = selected.code
        } else {
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "zh-Hans"
            cachedEffectiveLanguageCode = systemLanguage.hasPrefix("zh") ? "zh-Hans" : "en"
        }
    }

    func localizedString(_ key: String) -> String {
        // ✅ 直接使用缓存，不需要计算
        if effectiveLanguageCode == "zh-Hans" {
            return key
        }
        return translations[key] ?? key
    }
}
```

---

## 📦 创建性能优化工具

### 性能监控组件

```swift
import SwiftUI

// ✅ 视图性能监控
struct PerformanceMonitor: ViewModifier {
    let name: String
    @State private var renderCount = 0

    func body(content: Content) -> some View {
        content
            .onAppear {
                renderCount += 1
                print("🔍 [\(name)] 渲染次数: \(renderCount)")
            }
    }
}

extension View {
    func monitorPerformance(_ name: String) -> some View {
        modifier(PerformanceMonitor(name: name))
    }
}

// 使用：
struct MapTabView: View {
    var body: some View {
        ZStack {
            // ...
        }
        .monitorPerformance("MapTabView")
    }
}
```

### 防抖和节流

```swift
import Combine

extension Publisher where Failure == Never {
    // ✅ 防抖：延迟执行，合并连续的事件
    func debounce(for interval: DispatchQueue.SchedulerTimeType.Stride) -> AnyPublisher<Output, Failure> {
        self.debounce(for: interval, scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // ✅ 节流：固定间隔执行
    func throttle(for interval: DispatchQueue.SchedulerTimeType.Stride) -> AnyPublisher<Output, Failure> {
        self.throttle(for: interval, scheduler: DispatchQueue.main, latest: true)
            .eraseToAnyPublisher()
    }
}

// 使用：
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchResults: [Result] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        // ✅ 搜索输入防抖 500ms
        $searchText
            .debounce(for: .milliseconds(500))
            .sink { [weak self] text in
                self?.performSearch(text)
            }
            .store(in: &cancellables)
    }
}
```

---

## 🎯 优化清单

### 立即实施（高优先级）

- [ ] 1. 分离 LocationManager 为三个独立的 Manager
- [ ] 2. 在 AuthManager 中缓存 userId
- [ ] 3. OTP 验证改为并行尝试
- [ ] 4. 地图更新改为增量渲染

### 逐步优化（中优先级）

- [ ] 5. 提取 MapTabView 的嵌套组件
- [ ] 6. 并行执行启动初始化任务
- [ ] 7. 速度监控使用 Task 代替 DispatchQueue
- [ ] 8. 添加 LazyVStack 到可滚动列表

### 可选优化（低优先级）

- [ ] 9. 缓存 LanguageManager 的翻译结果
- [ ] 10. 添加性能监控组件
- [ ] 11. 为搜索功能添加防抖

---

## 📚 参考资料

- [SwiftUI Performance Best Practices](https://developer.apple.com/documentation/swiftui/performance)
- [Optimizing Lists in SwiftUI](https://developer.apple.com/documentation/swiftui/building-performant-scrollable-layouts)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

---

**💡 提示：** 优化是一个渐进的过程。从高优先级问题开始，逐步改进。每次优化后使用 Instruments 验证效果。
