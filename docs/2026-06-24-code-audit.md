# chocho 代码审查与优化建议

> 扫描日期：2026-06-24
> 范围：`chocho/` 下 38 个 Swift 源文件 + `chochoTests/` 19 个测试文件
> 方式：静态只读分析（未跑 Simulator、未做 benchmark 实测）

## 总览

整体代码卫生良好：**无 TODO/FIXME/HACK、无 print 调试残留、无 `try!`/`as!`/`fatalError`**，命名领域前缀（`Canvas*` / `Puzzle*` / `DotShape*`）一致，导出链路有意识地用 `nonisolated` + `Task.detached` 把重活移出主线程，动画数学（`DotMotionSample`）已在预览/导出间共享。

主要问题集中在三类：

1. **几个会影响用户数据正确性与流畅度的具体 bug / 隐患**（草稿不同步、实况帧主线程阻塞、并发写入）。
2. **四个"上帝文件"**（`BottomSheetPanel` 2457 行、`PuzzleCanvasModel` 2083 行、`ContentView` 1772 行、`PuzzleCanvasView` 1518 行）导致可维护性下降。
3. **预览/导出双轨绘制实现**带来的长期一致性风险，以及散落的魔法数字、死代码、测试缺口。

下面按优先级（P0 最高）给出问题与解决方案。每条标注了关键位置，便于直接定位。

---

## P0 — 正确性 / 数据安全（应尽快修）

### P0-1 撤销 / 重做 / 清空波点后草稿不保存

- **现象**：`applyPuzzleDots` 会调用 `scheduleCanvasDraftSave()`（`ContentView.swift:1340`），但 `clearCanvasContent`（1287）、`undoCanvasChange`（1300）、`redoCanvasChange`（1312）都没有。
- **影响**：用户 undo/redo/清空后若立即杀进程，恢复出来的草稿仍是旧波点；只能靠 30s 定时或进后台兜底，存在用户数据丢失体感。
- **方案**：在这三个方法末尾统一加 `scheduleCanvasDraftSave()`；更稳妥的做法是把「凡是修改 `puzzleDots` 的路径」收敛到单一入口（见 P2-1 的 editor model），由该入口统一触发保存。

### P0-2 视口平移 / 缩放未持久化

- **现象**：`viewportOffset` / `viewportScale` 更新在 `ContentView.swift:1657-1690`，但草稿 observer（197-261）未监听这两项。
- **影响**：用户调整画面位置 / 缩放后，仅在下一次其他操作或进后台时才被保存，冷启动恢复后视口可能回退。
- **方案**：viewport 变更结束时（手势 end）调用 `scheduleCanvasDraftSave()`，或纳入 dirty-flag 机制（见 P1-3）。

### P0-3 实况帧解码在主线程同步阻塞

- **现象**：`CanvasSourceLiveVideo.frame(at:)` 内部走 `generateCGImage` → `SourceLiveFrameRequest.wait()` → `semaphore.wait()`（`CanvasSourceLiveVideo.swift:109-115, 167-172`）。该方法由 `PuzzleCanvasView.swift:325` 在 `TimelineView` 的 ~60fps 渲染路径上同步调用。
- **影响**：每帧用信号量阻塞主线程等待 `generateCGImagesAsynchronously` 回调，缓存命中阈值仅 `0.012s`（89 行），60fps 下大量 miss → 主线程卡顿、掉帧。
- **方案**：
  - 用 `AVPlayerItemVideoOutput` 或 `AVAssetImageGenerator` 的异步预取，提前解出下一帧放入 ring buffer，渲染时只读缓存不阻塞；
  - 至少把 `DispatchSemaphore + 回调` 这种「async 转 sync」反模式改为后台预取，主线程拿不到帧就用上一帧 / 静态原图兜底；
  - 长期把 generator 封进 `actor`，去掉 `@unchecked Sendable`（155 行）。

### P0-4 草稿持久化并发写入无串行化

- **现象**：定时 autosave、debounce save、进后台 save 各自起 `Task { await CanvasDraftStore.save(...) }`（`ContentView.swift:180-185, 1396-1445`），`CanvasDraftStore.save` 内部用 `Task.detached` 写 manifest + photo（`CanvasDraftStore.swift:294-305`）。多个写入可交错。
- **影响**：manifest.json 与 photo.jpg 是两个独立 `.atomic` 写、非同一事务（339-340），并发或中途崩溃可能造成两者不一致。
- **方案**：
  - 把 `CanvasDraftStore` 改为 `actor`，让 save 天然串行；或维护一个串行写队列 / `pendingSave` 合并（新 save 取消未完成的旧 save）。
  - 写入改为「先写 `draft.tmp/` 完整目录，再 `replaceItemAt` 原子替换目录」，保证 manifest 与 photo 同时生效。

> 备注（已核实，非问题）：`CanvasDraftStore.save` 是 `nonisolated async`，按 Swift 并发语义（SE-0338）其 `jpegData` 编码运行在协作线程池而非主线程，**不会**阻塞主线程，无需改动这一点。

---

## P1 — 高价值结构与性能优化

### P1-1 拆分四个"上帝文件"

| 文件 | 行数 | 问题 | 拆分建议 |
| --- | --- | --- | --- |
| `BottomSheetPanel.swift` | 2457 | 壳层 + 4 个 Tab + 共享控件 + 背景 Canvas 预览 + 波点形状网格 + Header 历史按钮全在一起 | 按 Tab / 层级拆：`BottomSheetPanelMetrics`、`...Components`、`LivePanelControls`、`DotPanelControls`、`StylePanelControls`、`BackgroundPanelControls`；`CanvasHistoryControls` 移到独立文件（它实际属于 Header 域） |
| `PuzzleCanvasModel.swift` | 2083 | 布局 + 交互坐标 + 动画 + dot 工厂 + collage 采样 + 历史栈混在一起 | 拆 `PuzzleCanvasLayout`、`PuzzleCanvasCoordinate`、`LiveDotAnimation`、`PuzzleDotCollage`、`PuzzleBackgroundMetrics` |
| `ContentView.swift` | 1772 | ~55 个 `@State`、21 个 `onChange`、30+ 业务方法 | 见 P2-1（抽 Observable 模型 + Coordinator） |
| `PuzzleCanvasView.swift` | 1518 | 预览绘制 + dot 布局 + trace | 把纯绘制逻辑（`PuzzleBackgroundCanvasDrawing`、dot plan）下沉为可测试单元 |

### P1-2 实况预览改用 `TimelineView` 驱动，删除 60fps 轮询 `@State`

- **现象**：`ContentView.swift:655-664` 起了一个 `while` 循环每 `1/60s` 写一次 `livePreviewProgress`，每秒触发 60 次整个 `ContentView` diff；而 `PuzzleCanvasView` 已有 `livePreviewPlaybackStart` 可驱动 `TimelineView`（见 AGENTS.md）。
- **方案**：删除 `livePreviewProgress` 轮询，进度统一由 `TimelineView` + `playbackStart` 派生，避免高频刷新整棵视图树。

### P1-3 草稿保存增加 dirty-flag + 拖动期间不保存

- **现象**：
  - 30s 定时无条件 `persistCanvasDraft()`（`ContentView.swift:180-186`），即使无变更也重复 JPEG 编码 + 磁盘 IO。
  - 拖动波点的 `previewSelectedDotEdit`（1082-1088）每帧都 `scheduleCanvasDraftSave()`。
- **方案**：model 维护 `isDirty`，保存后清除，定时器仅在 dirty 时保存；preview 阶段不保存，仅在 `commitSelectedDotEdit` / 手势结束时保存。草稿 JPEG 质量可用更低的 `0.85`（当前与导出共用 `0.92`，`CanvasDraftStore.swift:260`）以减小 IO。

### P1-4 相册「最近照片」全量加载

- **现象**：`RecentPhotoPickerView.swift:175-191` 用 `PHAsset.fetchAssets` 无 `fetchLimit`，把全部资源 enumerate 进数组。
- **影响**：相册很大时初始化慢、内存高。
- **方案**：加 `PHFetchOptions.fetchLimit` 或分页（如每页 200），缩略图用 `PHCachingImageManager` 并在滚动时取消离屏请求。

### P1-5 统一导出快照类型，消除三份重复

- **现象**：`CanvasExportSnapshot`（`CanvasExportSnapshot.swift:4-40`）、`CanvasLivePhotoExporter.Snapshot`（47-82）、`ContentView` 内手工构造的第三份（`ContentView.swift:1514-1533`）字段几乎相同。
- **方案**：统一为单一 `CanvasExportSnapshot`，`CanvasLivePhotoExporter` 直接接收它，删除中间手工拼装。

### P1-6 Live Photo / 拼贴导出分层缓存，避免逐帧全量重渲染

- **现象**：Live Photo 导出 ~45 帧，每帧走 `CanvasRasterExporter.render` → `CanvasStyledPhotoRenderer.renderSync` 全 pipeline（`CanvasLivePhotoExporter.swift:280-331`、`CanvasRasterExporter.swift:32-48`），styled 主图（Y2K/ASCII）每帧重算；拼贴波点每个 dot 还可能触发离屏 bitmap 合成（`drawMirrorCollageContent` 等）。
- **方案**：分层渲染——静态层（背景 + styled base 主图）只渲染一次缓存为 bitmap，每帧只合成「会动的 dots + 实况帧」；extension 背景 bitmap 与 asset mask 按 `layout/style/assetName+size` 键缓存。

---

## P2 — 架构与一致性

### P2-1 `ContentView` 引入 Observable 模型 + Coordinator，收敛状态与业务

- **现象**：`ContentView` 是 God View + 隐式 Coordinator：约 55 个 `@State`、照片导入 / Vision 主体识别 / 风格预览编排 / 草稿捕获恢复 / 导出管线 / 波点编辑+Undo 全在 View 内（具体方法见 `ContentView.swift:713-891, 446-511, 1345-1591, 893-1100`）。
- **方案**：按域拆出 `@Observable` 模型与服务：
  - `CanvasDocument`（image / dots / trace / viewport）
  - `StylePipeline`（滤镜 + 预览缓存，把现在挂在 `@State` 的 `y2kCCDFilterCache` / `asciiArtCache` 移进来）
  - `PuzzleDotsEditor`（编辑 + undo/redo 历史 + 选中态 reconcile，顺带修掉 P0-1）
  - `ExportCoordinator` / `DraftAutosaveController` / `ImportService` / `SubjectOutlineService`
  - `ContentView` 只留布局与 sheet/cover 呈现状态。

### P2-2 Feature Session 模式泛型化

- **现象**：trace / photoCompression / y2kCCD / asciiArt 各有一套 `begin/confirm/cancel/remove` + snapshot 变量，几乎同构（`ContentView.swift:1166-1263`），`BottomSheetPanel.swift:353-428` 还有 9 个同构的 dismiss 包装函数。
- **方案**：抽象 `FeatureSession<Value>` 或 `enum ActivePanelFeature`，统一管理 snapshot 与回滚；面板侧用 `enum PanelFeature: { title, menuIcon, usesInlineActionRow }` 表驱动，减少分支与重复。

### P2-3 抽取预览/导出共享的"几何 + 绘制决策"层

- **现象**：背景图案（grid/stripes/polkaDots）、波点、拼贴 mirror 各有两套实现——预览用 SwiftUI `GraphicsContext`，导出用 `CGContext`（`PuzzleCanvasView.swift:945-1217` vs `CanvasRasterExporter.swift:208-464`），`DotCenterIndexFilter` 甚至被复制了两份。
- **影响**：双轨是技术约束（SwiftUI `.opacity()` 与 `CGContext` 行为不同，AGENTS.md 已说明），但绘制逻辑复制过多，长期容易 preview/export 不一致。
- **方案**：把「几何（返回 `Path`/`[CGRect]`）+ 动画 + 绘制决策」收敛到 Model 层（如 `DotRenderPlan`、背景几何协议），预览与导出各保留一个 thin adapter 消费同一输出；`DotCenterIndexFilter` 合并到一处。

### P2-4 收敛 props drilling

- **现象**：`ContentView → BottomSheetPanel → PanelContentCard → StylePanelControls` 传递 12+ 个 closure，中间层无逻辑；`BottomSheetDotControls` 里塞了风格 Tab 的状态（`photoCompression` / `y2kCCDFilterSettings` / `asciiArtSettings`），命名与内容不符（`BottomSheetPanelControls.swift:4-17`）。
- **方案**：拆出 `BottomSheetStyleControls`（或把 bag 改名 `BottomSheetCanvasControls`）；feature session 回调用 P2-2 的 Coordinator / Environment 注入替代逐层透传。

### P2-5 删除死代码

- `PuzzleDotCollageColor.displayColor` / `backgroundColor` halftone 分支会「渲染整张半调 surface 再取色」，但**全仓库无调用方**（`PuzzleCanvasModel.swift:1709-1862`）——删除或移出热点路径。
- `PanelEditModeToggle`（`BottomSheetPanel.swift:584-623`）定义但未使用；`isDotEditingEnabled`、`isTraceVisible`（controls bag 中）、`onCancel`（`Y2KCCDFilterControlsPanel` / `ASCIIArtControlsPanel`）等传入但从不读取——删除或接线。
- `Color+Theme.swift` 中 `brandSecondary` / `chart1-5` / `sidebar*` / `destructive` 等 token 零引用；`AboutContent` 的 `developerName` / `developerWebsiteURL` 未使用——删除或落地使用。
- `chocho/Assets.xcassets/public/sw.js` 是 Web Push Service Worker，与 iOS App 无关——确认是否误入 target 并移除。

### P2-6 错误处理：别再静默吞掉

- 草稿 save/load 失败被忽略（`save` 返回的 `Bool` 未用，`ContentView.swift:1443-1445）`；导出失败只返回 `nil` 无 underlying error；Vision mask 失败 `try?` 吞掉（`ContentView.swift:1545-1547`、`CanvasLivePhotoExporter.swift:115-117`）。
- **方案**：引入 `os.Logger` + `CanvasExportError` / `DraftError` 带原因；用户可感知的失败（草稿保存失败、未检测到主体）给 toast 或降级提示。

---

## P3 — 工程化 / 可维护性（低优先级，按需）

### P3-1 集中魔法数字与字符串

散落的常量建议归入按域的 `enum`（如 `CanvasLayoutMetrics` / `CanvasTimingConstants` / `PanelTheme` / `PanelTypography` / `CanvasImagingLimits`）。高频重复值示例：

| 值 | 含义 | 出现处（示例） |
| --- | --- | --- |
| `0.42` | disabled 透明度 | `BottomSheetPanel.swift:205, 222, 619, 1855, 2025` |
| `30` / `36` | 控件行高 / 导航栏高 | 面板多处 |
| `2048` / `1280` / `1080` | 编辑 / 预览 / Live Photo 像素上限 | `CanvasImageLoader`、`CanvasSourceLiveVideo`、`CanvasLivePhotoSizing` |
| `0.92` | JPEG 质量 | `CanvasExportWriter.swift:14` |
| `30s` / `1s` / `300ms` | autosave / draft debounce / trace debounce | `CanvasDraftStore`、`ContentView` |
| `10` | 默认波点数 | `ContentView.swift:35, 691, 1756` |

UI 中文文案分散在 50+ 处，短期可建 `PanelStrings`，长期迁移到 `String(localized:)` / `.xcstrings`。

### P3-2 目录分组

所有源码平铺在 `chocho/`。建议按 feature/layer 建 Group：`App/`、`Features/Canvas|Export|Import|Filters|DotShapes/`、`UI/Components|Theme|About/`。（注意：拆 `ContentView` / `BottomSheetPanel` 比单纯建文件夹更重要。）

### P3-3 补测试 + 抽共享 TestSupport

- **缺口**：`CanvasLivePhotoExporter` 端到端、`CanvasSourceLiveVideo` 时间映射/帧缓存、`RecentPhotoPickerView` 权限/分页、`CanvasStyledPhotoRenderer` 预览管线、预览↔导出像素一致性（golden image）、collage mirror 采样、草稿并发写入。
- **重复**：`makeSolidImage` / `makeJPEGData` / `makeTestImage` 在 5+ 个测试文件各写一份 → 抽到 `chochoTests/TestSupport/`。

### P3-4 其它小项

- `CanvasExportWriter.format(source:)` 的 `source` 参数两分支都返回 `.staticJPEG`，无实际作用——删除或落地「相册 Live Photo 无动画仍导出 Live Photo」的产品逻辑；`writeTemporaryStillImage` 与 `writeTemporaryJPEG` 完全重复。
- `CanvasPhotoLibrarySaver.save(fileURL:)` 跳过权限检查，与 `save(product:)` 不一致；`performChanges` completion 的 error 被丢弃。
- 临时文件（`chocho-canvas-*.jpg`、`chocho-source-live-*.mov`）建议加启动清扫或 `TemporaryFileRegistry`，避免异常路径泄漏。
- `DotShapeAssetImage` / `CharacterDotGlyphImageCache` 缓存可加 `totalCostLimit`；`Color(hex:)` 不支持 8 位 alpha。
- `Y2KCCDFilterSettings` 含 bloom/noise/rgbShift 等参数进了 cacheKey 但 renderer 实际只用 downsample + tone + JPEG（`Y2KCCDFilterRenderer.swift:368-403`）——要么实现，要么从 settings 移除，避免「调了不生效」。

---

## 建议实施顺序

1. **第一批（P0）**：P0-1/P0-2 草稿同步（改动小、收益高）→ P0-3 实况帧异步化 → P0-4 草稿 actor 串行化。
2. **第二批（P1）**：P1-2 删 60fps 轮询、P1-3 dirty-flag、P1-4 相册分页（性能可感知）；同时启动 P1-1 文件拆分。
3. **第三批（P2）**：在拆分基础上引入 Observable 模型 + Coordinator（P2-1/P2-2/P2-4），抽共享绘制层（P2-3），清死代码（P2-5），补错误处理（P2-6）。
4. **持续（P3）**：常量集中、目录分组、补测试，随手做。

> 说明：本文档为静态分析结论，未在 Simulator 上做视觉/性能验收。落地任一改动后建议按 AGENTS.md 跑 `xcodebuild` 构建验证，涉及动画/导出/Live Photo 的改动需人工在设备上验收。
