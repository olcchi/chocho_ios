# chocho 项目档案

更新日期：2026-06-11

## 项目一句话

`chocho` 是一个 SwiftUI iOS 图片创作工具：用户上传一张照片后，可以在照片边缘拼接扩展画布，生成或手动放置波点/素材形状，调整背景与动画效果，并导出静态 JPEG 或系统 Live Photo。

## 当前产品形态

应用当前围绕一个主编辑屏展开：

- 顶部工具栏负责上传照片和下载/保存。
- 中央是照片与扩展背景组成的拼贴画布。
- 底部是可折叠控制面板，包含「波点」「抽卡」「背景」「实况」四个 Tab。
- 无照片时显示上传占位；有照片时进入画布编辑状态。
- 画布支持拖拽、缩放、双击复位、点击添加波点，以及轨迹绘制后批量生成波点。

## 核心能力

### 照片导入

- 使用 `PhotosPicker` 选择静态图片或相册 Live Photo。
- 导入时优先通过 `PHAsset` 读取高质量关键帧。
- 如果来源是 Live Photo，会记录 `PHAsset.localIdentifier`，并尝试加载 paired video，供「原图实况」预览与导出使用。
- 导入后会应用默认波点形状、默认大小，并切换到底部「抽卡」Tab。

### 拼贴画布

- 主图保持原始比例。
- 扩展背景可以放在上、下、左、右四个方向。
- 扩展比例由 `extensionRatio` 控制，当前范围为 `0...1`。
- 画布布局以照片和最大扩展区域为稳定参考坐标系，保证波点、轨迹在缩放、导出和切换方向时尽量保持一致。
- 预览使用 SwiftUI 组合层，导出使用 Core Graphics 重新栅格化。

### 背景样式

当前背景样式定义在 `PuzzleBackgroundStyle`：

- 方格
- 条纹
- 圆点
- 半调

方格、条纹、圆点支持间距/粗细控制；半调由独立的半调背景实现与测试覆盖。

### 波点与素材

- 波点数据是模型状态，不藏在绘制层内部。
- 每个 `PuzzleDot` 包含稳定 `id`、归一化位置、颜色、尺寸和形状素材名。
- 支持基础形状、字符波点，以及资源目录里的贴纸/小物/彩纸/纽扣/水钻/布/针线等素材分类。
- 支持随机颜色或指定颜色。
- 支持撤销、重做、清空波点。
- 支持最近使用形状列表逻辑。

### 抽卡与轨迹

- 「抽卡」可以随机生成指定数量的波点。
- 开启轨迹绘制后，用户先在画布上画路径，再沿轨迹生成波点。
- 如果轨迹为空或扩展区域过窄，会通过 toast 给出中文提示。

### 实况动画

「实况」Tab 控制预览播放和导出格式。当前动画由 `LiveDotAnimation` 定义：

- 无
- 闪烁
- 呼吸
- 旋转

当前规则：

- `none` 导出普通静态 JPEG。
- 其他动画会导出 Live Photo。
- 波点动画和原图 Live Photo 运动可以共同决定导出时长。
- 波点动画作用于波点层；背景不参与动画。
- 如果用户开启「原图实况」且来源有 paired video，预览和导出帧会使用原图 Live Photo 视频帧。

### 导出与保存

导出入口在 `ContentView.shareCanvas()`：

- 静态导出：`CanvasRasterExporter.render(...)` 渲染合成图，再写入临时 JPEG。
- Live Photo 导出：生成带 asset identifier 的关键帧 JPEG，按 15fps 编码 paired MOV，再通过 `PHLivePhoto.request` 组装预览对象。
- 保存到相册通过自定义分享活动和 `CanvasPhotoLibrarySaver` 完成。
- Live Photo 临时文件会在分享/保存生命周期结束后清理，避免系统保存时文件过早删除。

### 草稿恢复

- 应用启动时，如果当前没有照片，会尝试恢复上次草稿。
- 草稿保存到 Application Support 下的 `chocho-canvas-draft` 目录。
- 草稿由 `manifest.json` 和 `photo.jpg` 组成。
- 当前草稿 manifest 版本为 `5`，支持从旧版本恢复缺省字段。
- 草稿内容包括照片、背景、扩展方向和比例、波点、轨迹、视口、实况动画、原图实况开关等。
- 编辑状态变化会延迟保存，应用进入后台/非活跃状态以及定时任务也会触发保存。

## 代码结构

### 应用入口与根屏

- `chocho/chochoApp.swift`：SwiftUI App 入口。
- `chocho/ContentView.swift`：整屏布局、状态所有权、照片加载、草稿、导出、toast、分享 sheet、底部面板摆放。

### 底部控制面板

- `chocho/BottomSheetPanel.swift`：可折叠底部面板、Tab、面板内容。
- `chocho/BottomSheetPanelControls.swift`：面板控制项的 binding 结构。
- `chocho/StyledSlider.swift`：自定义滑杆控件。
- `chocho/CanvasHeader.swift`：顶部上传/下载区域。

### 画布模型与预览

- `chocho/PuzzleCanvasModel.swift`：画布布局、扩展方向、背景样式、实况动画、波点工厂、轨迹、视口、历史栈等核心模型。
- `chocho/PuzzleCanvasView.swift`：SwiftUI 画布预览，组合照片、背景、轨迹和波点层。
- `chocho/PuzzleHalftoneBackground.swift`：半调背景。
- `chocho/Y2KBackgroundPalette.swift`：背景色板。

### 波点形状与资源

- `chocho/DotShapeAsset.swift`：形状分类、选择、最近使用。
- `chocho/DotShapeAssetImage.swift`：资源形状预览。
- `chocho/DotShapeDrawing.swift`：内置形状和字符波点绘制。
- `chocho/DotShapeCatalog.generated.swift`：生成的资源索引。
- `chocho/Assets.xcassets/public/shapes/`：贴纸、小物、彩纸等素材资源。

### 导入、导出、保存

- `chocho/CanvasPhotoImport.swift`：照片和 Live Photo 来源识别、关键帧导入。
- `chocho/CanvasSourceLiveVideo.swift`：来源 Live Photo paired video 帧读取。
- `chocho/CanvasRasterExporter.swift`：Core Graphics 栅格导出。
- `chocho/CanvasExportSnapshot.swift`：导出状态快照。
- `chocho/CanvasExportWriter.swift`：导出格式选择和临时 JPEG 写入。
- `chocho/CanvasLivePhotoExporter.swift`：Live Photo 关键帧、视频编码与组装。
- `chocho/CanvasLivePhotoMetadata.swift`：Live Photo 元数据写入。
- `chocho/CanvasExportProduct.swift`：分享/保存产物。
- `chocho/CanvasExportSession.swift`：导出临时文件生命周期。
- `chocho/CanvasPhotoLibrarySaver.swift`：写入相册。
- `chocho/CanvasShareSheet.swift`：UIKit 分享面板桥接。

### 草稿、加载与提示

- `chocho/CanvasDraftStore.swift`：草稿序列化、保存、恢复、迁移。
- `chocho/CanvasImageLoader.swift`：图片解码与尺寸处理。
- `chocho/CanvasToastMessage.swift`：toast 状态与展示。
- `chocho/CanvasUploadPlaceholder.swift`：空态上传 UI。

## 测试现状

当前仓库已有 `chochoTests`，覆盖范围包括：

- 画布模型与布局：`PuzzleCanvasModelTests`
- 半调背景：`PuzzleHalftoneBackgroundTests`
- 背景色板：`Y2KBackgroundPaletteTests`
- 图片加载：`CanvasImageLoaderTests`
- 照片导入：`CanvasPhotoImportTests`
- 草稿保存/恢复：`CanvasDraftStoreTests`
- 栅格导出：`CanvasRasterExporterTests`
- 导出格式与会话：`CanvasExportWriterTests`、`CanvasExportSessionTests`
- Live Photo 元数据、尺寸、保存与运动时长：`CanvasLivePhotoMetadataTests`、`CanvasLivePhotoSizingTests`、`CanvasPhotoLibrarySaverTests`、`CanvasLiveMotionTimingTests`
- toast 文案：`CanvasToastMessageTests`

Swift 源码变更后的推荐验证命令：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project chocho.xcodeproj \
  -scheme chocho \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData \
  build
```

文档变更只需确认文件存在并复读关键内容。

## 重要约束

- `ContentView` 负责全屏布局、安全区、底部面板位置和导出入口。
- `BottomSheetPanel` 只负责面板内部布局与交互，不自行忽略底部安全区。
- 实况动画的新增 case 要同时考虑预览和 Core Graphics 导出。
- 栅格导出中图片透明度不能只依赖 `CGContext.setAlpha`，绘制图片时要显式传入 alpha。
- Live Photo 临时 JPEG/MOV 必须保留到保存流程结束。
- `.build/` 和 Xcode `xcuserdata/` 属于本地生成/用户状态，不应作为源码依赖。

## 当前可继续推进的方向

- 为更多实况动画补充更细的栅格回归测试。
- 明确「原图实况」和「波点实况」同时开启时的产品文案与优先级。
- 给素材目录生成流程补充说明，避免 `DotShapeCatalog.generated.swift` 与资源目录漂移。
- 对底部面板做更多 Simulator 验证，特别是小屏、安全区、分享 sheet、相册权限弹窗。
- 如果后续功能复杂化，可以把导出、草稿或 Live Photo 来源加载进一步拆成更明确的协调对象；目前 `ContentView` 仍是主要状态协调者。
