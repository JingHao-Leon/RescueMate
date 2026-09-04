// 用法: swift Scripts/make_icon.swift
// 用 CoreGraphics 生成 1024x1024 App 图标（红底白十字 + SOS 圆点），无需第三方依赖。
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// 背景：红色对角渐变
let gradient = CGGradient(colorsSpace: colorSpace,
                          colors: [CGColor(red: 0.93, green: 0.20, blue: 0.18, alpha: 1),
                                   CGColor(red: 0.72, green: 0.07, blue: 0.09, alpha: 1)] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 0, y: CGFloat(size)),
                       end: CGPoint(x: CGFloat(size), y: 0),
                       options: [])

// 白色救援十字
let center = CGFloat(size) / 2
let barWidth: CGFloat = 168
let barLength: CGFloat = 600
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fill(CGRect(x: center - barWidth / 2, y: center - barLength / 2, width: barWidth, height: barLength))
ctx.fill(CGRect(x: center - barLength / 2, y: center - barWidth / 2, width: barLength, height: barWidth))

// 顶部 "SOS" 白字
let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 190, nil)
let attributes: [CFString: Any] = [kCTFontAttributeName: font,
                                   kCTForegroundColorAttributeName: CGColor(red: 0.86, green: 0.13, blue: 0.12, alpha: 1)]
let attributed = CFAttributedStringCreate(nil, "SOS" as CFString, attributes as CFDictionary)!
let line = CTLineCreateWithAttributedString(attributed)
let lineBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
ctx.textPosition = CGPoint(x: center - lineBounds.width / 2, y: center + barWidth / 2 + 130)
CTLineDraw(line, ctx)

let image = ctx.makeImage()!

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let output = scriptDir.deletingLastPathComponent()
    .appendingPathComponent("RescueMate/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png")
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    FileHandle.standardError.write("图标写入失败".data(using: .utf8)!)
    exit(1)
}
print("已生成: \(output.path)")
