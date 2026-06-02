# 挑战闹钟 App Icon 生成记录

## 当前选用

- App 中文名：挑战闹钟
- App 英文名：Challenge Alarm
- 当前编译进 App 的图标：`/Users/alfie/Developer/AlarmClockApp/Assets.xcassets/AppIcon.appiconset/AppIcon-waist-hands-1024.png`
- 当前候选图目录：`/Users/alfie/Developer/AlarmClockApp/DesignAssets/AppIconCandidates/2026-06-02-mascot-actions/`
- 原始四宫格生成图：`/Users/alfie/.codex/generated_images/019e8810-2fb2-78d2-990c-d367d86e0720/ig_0d341372d7635ec7016a1ed1761d208194a5e4659de12226e9.png`
- Canva 可编辑分层版：<https://www.canva.com/d/SEktDV2SXMPObxW>
- Canva 只读预览版：<https://www.canva.com/d/tkEUv6yGFDHoej6>

## 方向约束

这个 logo 的核心不是“普通闹钟”，而是一个有压迫感但可爱的闹钟 IP：

- 圆脸闹钟拟人角色
- 叉腰、挑眉、坏笑，像在说“不完成挑战，别想关闹钟”
- 暖橙色逆光
- 深紫黑色被子/被褥前景，必须保留柔软褶皱和材质
- 深蓝紫金属闹钟外壳
- 适合 iOS 圆角方形 App Icon

## 可复用提示词

```text
Using the visible reference image as the strict style and composition reference, create one 2x2 contact sheet containing four iOS rounded-square app icon variants. The four icons must look like the SAME original bottom-right alarm-clock mascot icon from the reference image. Preserve everything except the mascot's arm/leg pose.

CRITICAL CONSISTENCY REQUIREMENTS:
- Keep the exact warm orange sunrise/bedside backlight glow from the reference.
- Keep the exact dark purple quilt / blanket / bedding texture in the foreground: soft folds, plush fabric, purple shadows, orange rim light. Do not replace it with clouds, floor, mountains, plain gradient, desk, or abstract shapes.
- Keep the same rounded-square iOS app icon crop, same camera angle, same close-up scale, same composition, same dark-to-orange background, same glossy navy-purple metal alarm body, same cream clock face, same angry eyebrows, same mischievous smile, same black shiny eyes, same twin bells, same thick cartoon limbs, same premium 3D cartoon rendering.
- No text, no Chinese characters, no watermark, no new logo system, no shield, no sunrise badge, no different mascot design.
- Only change the action/pose. The scene, lighting, bedding, material, palette, character proportions, and icon framing must remain consistent across all four.

Four pose variants:
1. Top-left: arms akimbo / hands on hips, bossy confident stance, both feet planted on the same purple blanket.
2. Top-right: one hand holds the same dark challenge card with glowing checkmark and lightning bolt, other hand on hip, card position similar to original.
3. Bottom-left: one hand points firmly toward the viewer, other hand curled at side, feet still planted on the blanket.
4. Bottom-right: one fist raised in a small victory pose, the other arm bent, same determined expression, same bedding and glow.

Make each icon visually consistent enough to be a pose sheet for the exact same app mascot IP, not four redesigns.
```

## 后续修改建议

如果继续改图标，优先保持：

- 被褥质感不变
- 橙色逆光不变
- 闹钟脸、眉毛、笑容比例不变
- iOS 图标构图不变

只改动作或手里拿的挑战道具。不要让模型重新设计背景，否则一致性会散。

## 分层版本说明

当前 Canva 分层版来自 1024 PNG 的 Magic Layers 转换，适合做轻量编辑：

- 调整局部颜色
- 微调元素位置
- 添加/删除简单图形
- 导出新 PNG

它不是原生 3D 或手绘源文件，复杂结构例如闹钟金属反光、被褥褶皱、脸部高光，可能仍会以合并图层或近似图层存在。大改动作时，优先继续用上面的提示词生成，再把最终图转成可编辑版。
