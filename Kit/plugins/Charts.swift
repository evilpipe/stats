//
//  Chart.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 17/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public struct circle_segment {
    public let value: Double
    public var color: NSColor
    
    public init(value: Double, color: NSColor) {
        self.value = value
        self.color = color
    }
}

private func scaleValue(scale: Scale = .linear, value: Double, maxValue: Double, maxHeight: CGFloat) -> CGFloat {
    var value = value
    if scale == .none && value > 1 && maxValue != 0 {
        value /= maxValue
    }
    var localMaxValue = maxValue
    var y = value * maxHeight
    
    switch scale {
    case .square:
        if value > 0 {
            value = sqrt(value)
        }
        if localMaxValue > 0 {
            localMaxValue = sqrt(maxValue)
        }
    case .cube:
        if value > 0 {
            value = cbrt(value)
        }
        if localMaxValue > 0 {
            localMaxValue = cbrt(maxValue)
        }
    case .logarithmic:
        if value > 0 {
            value = log(value*100)
        }
        if localMaxValue > 0 {
            localMaxValue = log(maxValue*100)
        }
    default: break
    }
    
    if value < 0 {
        value = 0
    }
    if localMaxValue <= 0 {
        localMaxValue = 1
    }
    
    if scale != .none {
        y = (maxHeight * value)/localMaxValue
    }
    
    return y
}

private func drawToolTip(_ frame: NSRect, _ point: CGPoint, _ size: CGSize, value: String, subtitle: String? = nil) {
    let style = NSMutableParagraphStyle()
    style.alignment = .left
    var position: CGPoint = point
    let textHeight: CGFloat = subtitle != nil ? 22 : 12
    let valueOffset: CGFloat = subtitle != nil ? 11 : 1
    
    if position.x + size.width > frame.size.width+frame.origin.x {
        position.x = point.x - size.width
        style.alignment = .right
    }
    if position.y + textHeight > size.height {
        position.y = point.y - textHeight - 20
    }
    
    let box = NSBezierPath(roundedRect: NSRect(x: position.x-3, y: position.y-2, width: size.width, height: textHeight+2), xRadius: 2, yRadius: 2)
    NSColor.gray.setStroke()
    box.stroke()
    (isDarkMode ? NSColor.black : NSColor.white).withAlphaComponent(0.8).setFill()
    box.fill()
    
    var attributes = [
        NSAttributedString.Key.font: NSFont.systemFont(ofSize: 12, weight: .regular),
        NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor
    ]
    var rect = CGRect(x: position.x, y: position.y+valueOffset, width: 32, height: 12)
    var str = NSAttributedString.init(string: value, attributes: attributes)
    str.draw(with: rect)
    
    if let subtitle {
        attributes[NSAttributedString.Key.font] = NSFont.systemFont(ofSize: 9, weight: .medium)
        attributes[NSAttributedString.Key.foregroundColor] = (isDarkMode ? NSColor.white : NSColor.textColor).withAlphaComponent(0.7)
        rect = CGRect(x: position.x, y: position.y, width: size.width-8, height: 9)
        str = NSAttributedString.init(string: subtitle, attributes: attributes)
        str.draw(with: rect)
    }
}

public class LineChartView: NSView {
    public var id: String = UUID().uuidString
    
    public var points: [DoubleValue?]
    public var shadowPoints: [DoubleValue?] = []
    public var transparent: Bool = true
    public var color: NSColor = .controlAccentColor
    public var suffix: String = "%"
    public var scale: Scale
    
    private var cursor: NSPoint? = nil
    private var stop: Bool = false
    private let dateFormatter = DateFormatter()
    
    public init(frame: NSRect, num: Int, scale: Scale = .none) {
        self.points = Array(repeating: nil, count: num)
        self.scale = scale
        
        super.init(frame: frame)
        
        self.dateFormatter.dateFormat = "dd/MM HH:mm:ss"
        
        self.addTrackingArea(NSTrackingArea(
            rect: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [
                NSTrackingArea.Options.activeAlways,
                NSTrackingArea.Options.mouseEnteredAndExited,
                NSTrackingArea.Options.mouseMoved
            ],
            owner: self, userInfo: nil
        ))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let points = self.stop ? self.shadowPoints : self.points
        guard let context = NSGraphicsContext.current?.cgContext, !points.isEmpty else { return }
        context.setShouldAntialias(true)
        let maxValue = points.compactMap { $0 }.max() ?? 0
        
        let lineColor: NSColor = self.color
        var gradientColor: NSColor = self.color.withAlphaComponent(0.5)
        if !self.transparent {
            gradientColor = self.color.withAlphaComponent(0.8)
        }
        
        let offset: CGFloat = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        let height: CGFloat = self.frame.height - dirtyRect.origin.y - offset
        let xRatio: CGFloat = self.frame.width / CGFloat(points.count-1)
        
        var lines: [[CGPoint]] = []
        var line: [CGPoint] = []
        var list: [(value: DoubleValue, point: CGPoint)] = []
        
        for (i, v) in points.enumerated() {
            guard let v else {
                if !line.isEmpty {
                    lines.append(line)
                    line = []
                }
                continue
            }
            let point = CGPoint(
                x: (CGFloat(i) * xRatio) + dirtyRect.origin.x,
                y: scaleValue(scale: self.scale, value: v.value, maxValue: maxValue, maxHeight: height) + dirtyRect.origin.y + offset
            )
            line.append(point)
            list.append((value: v, point: point))
        }
        if lines.isEmpty && !line.isEmpty {
            lines.append(line)
        }
        
        var path = NSBezierPath()
        for linePoints in lines {
            if linePoints.count == 1 {
                path = NSBezierPath(ovalIn: CGRect(x: linePoints[0].x-offset, y: linePoints[0].y-offset, width: 1, height: 1))
                lineColor.set()
                path.stroke()
                gradientColor.set()
                path.fill()
                continue
            }
            
            path = NSBezierPath()
            path.move(to: linePoints[0])
            for i in 1..<linePoints.count {
                path.line(to: linePoints[i])
            }
            lineColor.set()
            path.lineWidth = offset
            path.stroke()
            
            path = path.copy() as! NSBezierPath
            path.line(to: CGPoint(x: linePoints[linePoints.count-1].x, y: 0))
            path.line(to: CGPoint(x: linePoints[0].x, y: 0))
            path.close()
            gradientColor.set()
            path.fill()
        }
        
        if let p = self.cursor, let over = list.first(where: { $0.point.x >= p.x }), let under = list.last(where: { $0.point.x <= p.x }) {
            guard p.y <= height else { return }
            
            let diffOver = over.point.x - p.x
            let diffUnder = p.x - under.point.x
            let nearest = (diffOver < diffUnder) ? over : under
            let vLine = NSBezierPath()
            let hLine = NSBezierPath()
            
            vLine.setLineDash([4, 4], count: 2, phase: 0)
            hLine.setLineDash([6, 6], count: 2, phase: 0)
            
            vLine.move(to: CGPoint(x: p.x, y: 0))
            vLine.line(to: CGPoint(x: p.x, y: height))
            vLine.close()
            
            hLine.move(to: CGPoint(x: 0, y: p.y))
            hLine.line(to: CGPoint(x: self.frame.size.width+self.frame.origin.x, y: p.y))
            hLine.close()
            
            NSColor.tertiaryLabelColor.set()
            
            vLine.lineWidth = offset
            hLine.lineWidth = offset
            
            vLine.stroke()
            hLine.stroke()
            
            let dotSize: CGFloat = 4
            let path = NSBezierPath(ovalIn: CGRect(
                x: nearest.point.x-(dotSize/2),
                y: nearest.point.y-(dotSize/2),
                width: dotSize,
                height: dotSize
            ))
            NSColor.red.set()
            path.stroke()
            
            let date = self.dateFormatter.string(from: nearest.value.ts)
            let value = "\(Int(nearest.value.value.rounded(toPlaces: 2) * 100))\(self.suffix)"
            drawToolTip(self.frame, CGPoint(x: nearest.point.x+4, y: nearest.point.y+4), CGSize(width: 78, height: height), value: value, subtitle: date)
        }
    }
    
    public override func updateTrackingAreas() {
        self.trackingAreas.forEach({ self.removeTrackingArea($0) })
        self.addTrackingArea(NSTrackingArea(
            rect: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [
                NSTrackingArea.Options.activeAlways,
                NSTrackingArea.Options.mouseEnteredAndExited,
                NSTrackingArea.Options.mouseMoved
            ],
            owner: self, userInfo: nil
        ))
        super.updateTrackingAreas()
    }
    
    public func addValue(_ value: DoubleValue) {
        self.points.remove(at: 0)
        self.points.append(value)
        
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public func addValue(_ value: Double) {
        self.addValue(DoubleValue(value))
    }
    
    public func reinit(_ num: Int = 60) {
        guard self.points.count != num else { return }
        
        if num < self.points.count {
            self.points = Array(self.points[self.points.count-num..<self.points.count])
        } else {
            let origin = self.points
            self.points = Array(repeating: nil, count: num)
            self.points.replaceSubrange(Range(uncheckedBounds: (lower: num-origin.count, upper: num)), with: origin)
        }
    }
    
    public func setScale(_ newScale: Scale) {
        self.scale = newScale
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public override func mouseEntered(with event: NSEvent) {
        self.cursor = convert(event.locationInWindow, from: nil)
        self.needsDisplay = true
    }
    
    public override func mouseMoved(with event: NSEvent) {
        self.cursor = convert(event.locationInWindow, from: nil)
        self.needsDisplay = true
    }
    
    public override func mouseDragged(with event: NSEvent) {
        self.cursor = convert(event.locationInWindow, from: nil)
        self.needsDisplay = true
    }
    
    public override func mouseExited(with event: NSEvent) {
        self.cursor = nil
        self.needsDisplay = true
    }
    
    public override func mouseDown(with: NSEvent) {
        self.shadowPoints = self.points
        self.stop = true
    }
    public override func mouseUp(with: NSEvent) {
        self.stop = false
    }
}

public class NetworkChartView: NSView {
    public var id: String = UUID().uuidString
    public var base: DataSizeBase = .byte
    public var topColor: NSColor
    public var bottomColor: NSColor
    public var points: [(Double, Double)]
    public var shadowPoints: [(Double, Double)] = []
    
    private var minMax: Bool = false
    private var scale: Scale = .none
    private var commonScale: Bool = true
    private var reverseOrder: Bool = false
    
    private var cursorToolTip: Bool = false
    private var cursor: NSPoint? = nil
    private var stop: Bool = false
    
    public init(frame: NSRect, num: Int, minMax: Bool = true, outColor: NSColor = .systemRed, inColor: NSColor = .systemBlue, toolTip: Bool = false) {
        self.minMax = minMax
        self.points = Array(repeating: (0, 0), count: num)
        self.topColor = inColor
        self.bottomColor = outColor
        self.cursorToolTip = toolTip
        super.init(frame: frame)
        
        self.addTrackingArea(NSTrackingArea(
            rect: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [
                NSTrackingArea.Options.activeAlways,
                NSTrackingArea.Options.mouseEnteredAndExited,
                NSTrackingArea.Options.mouseMoved
            ],
            owner: self, userInfo: nil
        ))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        
        var points = self.points
        if self.stop {
            points = self.shadowPoints
        }
        var topMax: Double = (self.reverseOrder ? points.map{ $0.1 }.max() : points.map{ $0.0 }.max()) ?? 0
        var bottomMax: Double = (self.reverseOrder ? points.map{ $0.0 }.max() : points.map{ $0.1 }.max()) ?? 0
        if topMax == 0 {
            topMax = 1
        }
        if bottomMax == 0 {
            bottomMax = 1
        }
        
        if !self.commonScale {
            if bottomMax > topMax {
                topMax = bottomMax
            } else {
                bottomMax = topMax
            }
        }
        
        let lineWidth = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        let zero: CGFloat = (self.frame.height/2) + self.frame.origin.y
        let xRatio: CGFloat = (self.frame.width + (lineWidth*3)) / CGFloat(points.count)
        let xCenter: CGFloat = self.frame.height/2 + self.frame.origin.y
        let height: CGFloat = self.frame.height - dirtyRect.origin.y - lineWidth
        
        let columnXPoint = { (point: Int) -> CGFloat in
            return (CGFloat(point) * xRatio) + (self.frame.origin.x - lineWidth)
        }
        
        let topYPoint = { (point: Int) -> CGFloat in
            let value = self.reverseOrder ? points[point].1 : points[point].0
            return scaleValue(scale: self.scale, value: value, maxValue: topMax, maxHeight: self.frame.height/2) + xCenter
        }
        let bottomYPoint = { (point: Int) -> CGFloat in
            let value = self.reverseOrder ? points[point].0 : points[point].1
            return xCenter - scaleValue(scale: self.scale, value: value, maxValue: bottomMax, maxHeight: self.frame.height/2)
        }
        
        let topList = points.enumerated().compactMap { (i: Int, v: (Double, Double)) -> (value: Double, point: CGPoint) in
            return (self.reverseOrder ? v.1 : v.0, CGPoint(x: columnXPoint(i), y: topYPoint(i)))
        }
        let bottomList = points.enumerated().compactMap { (i: Int, v: (Double, Double)) -> (value: Double, point: CGPoint) in
            return (self.reverseOrder ? v.0 : v.1, CGPoint(x: columnXPoint(i), y: bottomYPoint(i)))
        }
        
        let topLinePath = NSBezierPath()
        topLinePath.move(to: CGPoint(x: columnXPoint(0), y: topYPoint(0)))
        
        let bottomLinePath = NSBezierPath()
        bottomLinePath.move(to: CGPoint(x: columnXPoint(0), y: bottomYPoint(0)))
        
        for i in 1..<points.count {
            topLinePath.line(to: CGPoint(x: columnXPoint(i), y: topYPoint(i)))
            bottomLinePath.line(to: CGPoint(x: columnXPoint(i), y: bottomYPoint(i)))
        }
        
        let topColor = self.reverseOrder ? self.bottomColor : self.topColor
        let bottomColor = self.reverseOrder ? self.topColor : self.bottomColor
        
        bottomColor.setStroke()
        topLinePath.lineWidth = lineWidth
        topLinePath.stroke()
        
        topColor.setStroke()
        bottomLinePath.lineWidth = lineWidth
        bottomLinePath.stroke()
        
        context.saveGState()
        
        var underLinePath = topLinePath.copy() as! NSBezierPath
        underLinePath.line(to: CGPoint(x: columnXPoint(points.count), y: zero))
        underLinePath.line(to: CGPoint(x: columnXPoint(0), y: zero))
        underLinePath.close()
        underLinePath.addClip()
        bottomColor.withAlphaComponent(0.5).setFill()
        NSBezierPath(rect: self.frame).fill()
        
        context.restoreGState()
        context.saveGState()
        
        underLinePath = bottomLinePath.copy() as! NSBezierPath
        underLinePath.line(to: CGPoint(x: columnXPoint(points.count), y: zero))
        underLinePath.line(to: CGPoint(x: columnXPoint(0), y: zero))
        underLinePath.close()
        underLinePath.addClip()
        topColor.withAlphaComponent(0.5).setFill()
        NSBezierPath(rect: self.frame).fill()
        
        context.restoreGState()
        
        if self.minMax {
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9, weight: .light),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
            ]
            let topText = Units(bytes: Int64(topMax)).getReadableSpeed(base: self.base)
            let bottomText = Units(bytes: Int64(bottomMax)).getReadableSpeed(base: self.base)
            let topTextWidth = topText.widthOfString(usingFont: stringAttributes[NSAttributedString.Key.font] as! NSFont)
            let bottomTextWidth = bottomText.widthOfString(usingFont: stringAttributes[NSAttributedString.Key.font] as! NSFont)
            
            var rect = CGRect(x: 1, y: self.frame.height - 9, width: topTextWidth, height: 8)
            NSAttributedString.init(string: topText, attributes: stringAttributes).draw(with: rect)
            
            rect = CGRect(x: 1, y: 2, width: bottomTextWidth, height: 8)
            NSAttributedString.init(string: bottomText, attributes: stringAttributes).draw(with: rect)
        }
        
        if let p = self.cursor {
            let list = p.y > xCenter ? topList : bottomList
            if let over = list.first(where: { $0.point.x >= p.x }), let under = list.last(where: { $0.point.x <= p.x }) {
                let diffOver = over.point.x - p.x
                let diffUnder = p.x - under.point.x
                let nearest = (diffOver < diffUnder) ? over : under
                let vLine = NSBezierPath()
                let hLine = NSBezierPath()
                
                vLine.setLineDash([4, 4], count: 2, phase: 0)
                hLine.setLineDash([6, 6], count: 2, phase: 0)
                
                vLine.move(to: CGPoint(x: p.x, y: 0))
                vLine.line(to: CGPoint(x: p.x, y: height))
                vLine.close()
                
                hLine.move(to: CGPoint(x: 0, y: p.y))
                hLine.line(to: CGPoint(x: self.frame.size.width+self.frame.origin.x, y: p.y))
                hLine.close()
                
                NSColor.tertiaryLabelColor.set()
                
                vLine.lineWidth = lineWidth
                hLine.lineWidth = lineWidth
                
                vLine.stroke()
                hLine.stroke()
                
                let dotSize: CGFloat = 4
                let path = NSBezierPath(ovalIn: CGRect(
                    x: nearest.point.x-(dotSize/2),
                    y: nearest.point.y-(dotSize/2),
                    width: dotSize,
                    height: dotSize
                ))
                NSColor.red.set()
                path.stroke()
                
                let style = NSMutableParagraphStyle()
                style.alignment = .left
                var textPosition: CGPoint = CGPoint(x: nearest.point.x+4, y: nearest.point.y+4)
                
                if textPosition.x + 35 > self.frame.size.width+self.frame.origin.x {
                    textPosition.x = nearest.point.x - 55
                    style.alignment = .right
                }
                if textPosition.y + 14 > height {
                    textPosition.y = nearest.point.y - 14
                }
                
                let stringAttributes = [
                    NSAttributedString.Key.font: NSFont.systemFont(ofSize: 10, weight: .regular),
                    NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                    NSAttributedString.Key.paragraphStyle: style
                ]
                
                let rect = CGRect(x: textPosition.x, y: textPosition.y, width: 52, height: 10)
                let value = Units(bytes: Int64(nearest.value)).getReadableSpeed(base: self.base)
                let str = NSAttributedString.init(string: value, attributes: stringAttributes)
                str.draw(with: rect)
            }
        }
    }
    
    public func addValue(upload: Double, download: Double) {
        self.points.remove(at: 0)
        self.points.append((upload, download))
        
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public func reinit(_ num: Int = 60) {
        guard self.points.count != num else { return }
        
        if num < self.points.count {
            self.points = Array(self.points[self.points.count-num..<self.points.count])
        } else {
            let origin = self.points
            self.points = Array(repeating: (0, 0), count: num)
            self.points.replaceSubrange(Range(uncheckedBounds: (lower: origin.count, upper: num)), with: origin)
        }
    }
    
    public func setScale(_ newScale: Scale, _ commonScale: Bool) {
        self.scale = newScale
        self.commonScale = commonScale
        
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public func setReverseOrder(_ newValue: Bool) {
        self.reverseOrder = newValue
        
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public func setColors(in inColor: NSColor? = nil, out outColor: NSColor? = nil) {
        var needUpdate: Bool = false
        
        if let newColor = inColor, self.topColor != newColor {
            self.topColor = newColor
            needUpdate = true
        }
        if let newColor = outColor, self.bottomColor != newColor {
            self.bottomColor = newColor
            needUpdate = true
        }
        
        if needUpdate && self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public override func mouseEntered(with event: NSEvent) {
        guard self.cursorToolTip else { return }
        self.cursor = convert(event.locationInWindow, from: nil)
        self.needsDisplay = true
    }
    
    public override func mouseMoved(with event: NSEvent) {
        guard self.cursorToolTip else { return }
        self.cursor = convert(event.locationInWindow, from: nil)
        self.needsDisplay = true
    }
    
    public override func mouseDragged(with event: NSEvent) {
        guard self.cursorToolTip else { return }
        self.cursor = convert(event.locationInWindow, from: nil)
        self.needsDisplay = true
    }
    
    public override func mouseExited(with event: NSEvent) {
        guard self.cursorToolTip else { return }
        self.cursor = nil
        self.needsDisplay = true
    }
    
    public override func mouseDown(with: NSEvent) {
        guard self.cursorToolTip else { return }
        self.shadowPoints = self.points
        self.stop = true
    }
    public override func mouseUp(with: NSEvent) {
        guard self.cursorToolTip else { return }
        self.stop = false
    }
}

public class PieChartView: NSView {
    public var id: String = UUID().uuidString
    
    private var filled: Bool = false
    private var drawValue: Bool = false
    private var nonActiveSegmentColor: NSColor = NSColor.lightGray
    
    private var value: Double? = nil
    private var segments: [circle_segment] = []
    
    public init(frame: NSRect, segments: [circle_segment], filled: Bool = false, drawValue: Bool = false) {
        self.filled = filled
        self.drawValue = drawValue
        self.segments = segments
        
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ rect: CGRect) {
        let arcWidth: CGFloat = self.filled ? min(self.frame.width, self.frame.height) / 2 : 7
        let fullCircle = 2 * CGFloat.pi
        var segments = self.segments
        let totalAmount = segments.reduce(0) { $0 + $1.value }
        if totalAmount < 1 {
            segments.append(circle_segment(value: Double(1-totalAmount), color: self.nonActiveSegmentColor.withAlphaComponent(0.5)))
        }
        
        let centerPoint = CGPoint(x: self.frame.width/2, y: self.frame.height/2)
        let radius = (min(self.frame.width, self.frame.height) - arcWidth) / 2
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        
        context.setLineWidth(arcWidth)
        context.setLineCap(.butt)
        
        let startAngle: CGFloat = CGFloat.pi/2
        var previousAngle = startAngle
        
        for segment in segments.reversed() {
            let currentAngle: CGFloat = previousAngle + (CGFloat(segment.value) * fullCircle)
            
            context.setStrokeColor(segment.color.cgColor)
            context.addArc(center: centerPoint, radius: radius, startAngle: previousAngle, endAngle: currentAngle, clockwise: false)
            context.strokePath()
            
            previousAngle = currentAngle
        }
        
        if let value = self.value, self.drawValue {
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 15, weight: .regular),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: NSMutableParagraphStyle()
            ]
            
            let percentage = "\(Int(value.rounded(toPlaces: 2) * 100))%"
            let width: CGFloat = percentage.widthOfString(usingFont: NSFont.systemFont(ofSize: 15))
            let rect = CGRect(x: (self.frame.width-width)/2, y: (self.frame.height-11)/2, width: width, height: 12)
            let str = NSAttributedString.init(string: percentage, attributes: stringAttributes)
            str.draw(with: rect)
        }
    }
    
    public func setValue(_ value: Double) {
        self.value = value
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public func setSegments(_ segments: [circle_segment]) {
        self.segments = segments
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public func setFrame(_ frame: NSRect) {
        var original = self.frame
        original = frame
        self.frame = original
    }
    
    public func setNonActiveSegmentColor(_ newColor: NSColor) {
        guard self.nonActiveSegmentColor != newColor else { return }
        self.nonActiveSegmentColor = newColor
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
}

public class HalfCircleGraphView: NSView {
    public var id: String = UUID().uuidString
    
    private var value: Double = 0.0
    private var text: String? = nil
    
    public var color: NSColor = NSColor.systemBlue
    
    public override func draw(_ rect: CGRect) {
        let arcWidth: CGFloat = 7.0
        let radius = (min(self.frame.width, self.frame.height) - arcWidth) / 2
        let centerPoint = CGPoint(x: self.frame.width/2, y: self.frame.height/2)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        
        context.setLineWidth(arcWidth)
        context.setLineCap(.butt)
        
        var segments: [circle_segment] = [
            circle_segment(value: self.value, color: self.color)
        ]
        if self.value < 1 {
            segments.append(circle_segment(value: Double(1-self.value), color: NSColor.lightGray.withAlphaComponent(0.5)))
        }
        
        let startAngle: CGFloat = -(1/4)*CGFloat.pi
        let endCircle: CGFloat = (7/4)*CGFloat.pi - (1/4)*CGFloat.pi
        var previousAngle = startAngle
        
        context.saveGState()
        context.translateBy(x: self.frame.width, y: 0)
        context.scaleBy(x: -1, y: 1)
        
        for segment in segments {
            let currentAngle: CGFloat = previousAngle + (CGFloat(segment.value) * endCircle)
            
            context.setStrokeColor(segment.color.cgColor)
            context.addArc(center: centerPoint, radius: radius, startAngle: previousAngle, endAngle: currentAngle, clockwise: false)
            context.strokePath()
            
            previousAngle = currentAngle
        }
        
        context.restoreGState()
        
        if let text = self.text {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 10, weight: .regular),
                NSAttributedString.Key.foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: style
            ]
            
            let width: CGFloat = text.widthOfString(usingFont: NSFont.systemFont(ofSize: 10))
            let rect = CGRect(x: ((self.frame.width-width)/2)-0.5, y: (self.frame.height-6)/2, width: width, height: 13)
            let str = NSAttributedString.init(string: text, attributes: stringAttributes)
            str.draw(with: rect)
        }
    }
    
    public func setValue(_ value: Double) {
        self.value = value > 1 ? value/100 : value
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public func setText(_ value: String) {
        self.text = value
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
}

public class TachometerGraphView: NSView {
    private var filled: Bool
    private var segments: [circle_segment]
    
    public init(frame: NSRect, segments: [circle_segment], filled: Bool = true) {
        self.filled = filled
        self.segments = segments
        
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ rect: CGRect) {
        let arcWidth: CGFloat = self.filled ? min(self.frame.width, self.frame.height) / 2 : 7
        var segments = self.segments
        let totalAmount = segments.reduce(0) { $0 + $1.value }
        if totalAmount < 1 {
            segments.append(circle_segment(value: Double(1-totalAmount), color: NSColor.lightGray.withAlphaComponent(0.5)))
        }
        
        let centerPoint = CGPoint(x: self.frame.width/2, y: self.frame.height/2)
        let radius = (min(self.frame.width, self.frame.height) - arcWidth) / 2
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)
        context.setLineWidth(arcWidth)
        context.setLineCap(.butt)
        
        context.translateBy(x: self.frame.width, y: -4)
        context.scaleBy(x: -1, y: 1)
        
        let startAngle: CGFloat = 0
        let endCircle: CGFloat = CGFloat.pi
        var previousAngle = startAngle
        
        for segment in segments {
            let currentAngle: CGFloat = previousAngle + (CGFloat(segment.value) * endCircle)
            
            context.setStrokeColor(segment.color.cgColor)
            context.addArc(center: centerPoint, radius: radius, startAngle: previousAngle, endAngle: currentAngle, clockwise: false)
            context.strokePath()
            
            previousAngle = currentAngle
        }
    }
    
    public func setSegments(_ segments: [circle_segment]) {
        self.segments = segments
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public func setFrame(_ frame: NSRect) {
        var original = self.frame
        original = frame
        self.frame = original
    }
}

public class BarChartView: NSView {
    private var values: [ColorValue] = []
    private var cursor: CGPoint? = nil
    
    public init(frame: NSRect = NSRect.zero, num: Int) {
        super.init(frame: frame)
        self.values = Array(repeating: ColorValue(0, color: .controlAccentColor), count: num)
        
        self.addTrackingArea(NSTrackingArea(
            rect: CGRect(x: 0, y: 0, width: self.frame.width, height: self.frame.height),
            options: [
                NSTrackingArea.Options.activeAlways,
                NSTrackingArea.Options.mouseEnteredAndExited,
                NSTrackingArea.Options.mouseMoved
            ],
            owner: self, userInfo: nil
        ))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        let blocks: Int = 16
        let spacing: CGFloat = 2
        let count: CGFloat = CGFloat(self.values.count)
        let partitionSize: CGSize = CGSize(width: (self.frame.width - (count*spacing)) / count, height: self.frame.height)
        let blockSize = CGSize(width: partitionSize.width-(spacing*2), height: ((partitionSize.height - spacing - 1)/CGFloat(blocks))-1)
        
        var list: [(value: Double, path: NSBezierPath)] = []
        var x: CGFloat = 0
        for i in 0..<self.values.count {
            let partition = NSBezierPath(
                roundedRect: NSRect(x: x, y: 0, width: partitionSize.width, height: partitionSize.height),
                xRadius: 3, yRadius: 3
            )
            NSColor.underPageBackgroundColor.withAlphaComponent(0.5).setFill()
            partition.fill()
            partition.close()
            
            let value = self.values[i]
            let color = value.color ?? .controlAccentColor
            let activeBlockNum = Int(round(value.value*Double(blocks)))
            let h = value.value*(partitionSize.height-spacing)
            
            if dirtyRect.height < 30 && h != 0 {
                let block = NSBezierPath(
                    roundedRect: NSRect(x: x+spacing, y: 1, width: partitionSize.width-(spacing*2), height: h),
                    xRadius: 1, yRadius: 1
                )
                color.setFill()
                block.fill()
                block.close()
            } else {
                var y: CGFloat = spacing
                for b in 0..<blocks {
                    let block = NSBezierPath(
                        roundedRect: NSRect(x: x+spacing, y: y, width: blockSize.width, height: blockSize.height),
                        xRadius: 1, yRadius: 1
                    )
                    (activeBlockNum <= b ? NSColor.controlBackgroundColor.withAlphaComponent(0.4) : color).setFill()
                    block.fill()
                    block.close()
                    y += blockSize.height + 1
                }
            }
            
            x += partitionSize.width + spacing
            list.append((value: value.value, path: partition))
        }
        
        if let p = self.cursor, let block = list.first(where: { $0.path.contains(p) }) {
            let value = "\(Int(block.value.rounded(toPlaces: 2) * 100))%"
            let width: CGFloat = block.value == 1 ? 38 : block.value > 0.1 ? 32 : 24
            drawToolTip(self.frame, CGPoint(x: p.x+4, y: p.y+4), CGSize(width: width, height: partitionSize.height), value: value)
        }
    }
    
    public func setValues(_ values: [ColorValue]) {
        self.values = values
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
    
    public override func mouseEntered(with event: NSEvent) {
        self.cursor = convert(event.locationInWindow, from: nil)
        self.display()
    }
    public override func mouseMoved(with event: NSEvent) {
        self.cursor = convert(event.locationInWindow, from: nil)
        self.display()
    }
    public override func mouseDragged(with event: NSEvent) {
        self.cursor = convert(event.locationInWindow, from: nil)
        self.display()
    }
    public override func mouseExited(with event: NSEvent) {
        self.cursor = nil
        self.display()
    }
}

public class GridChartView: NSView {
    private let okColor: NSColor = .systemGreen
    private let notOkColor: NSColor = .systemRed
    private let inactiveColor: NSColor = .underPageBackgroundColor.withAlphaComponent(0.4)
    
    private var values: [NSColor] = []
    private let grid: (rows: Int, columns: Int)
    
    public init(frame: NSRect, grid: (rows: Int, columns: Int)) {
        self.grid = grid
        super.init(frame: frame)
        self.values = Array(repeating: self.inactiveColor, count: grid.rows * grid.columns)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        let spacing: CGFloat = 2
        let size: CGSize = CGSize(
            width: (self.frame.width - ((CGFloat(self.grid.rows)-1) * spacing)) / CGFloat(self.grid.rows),
            height: (self.frame.height - ((CGFloat(self.grid.columns)-1) * spacing)) / CGFloat(self.grid.columns)
        )
        var origin: CGPoint = CGPoint(x: 0, y: (size.height + spacing) * CGFloat(self.grid.columns - 1))
        
        var i: Int = 0
        for _ in 0..<self.grid.columns {
            for _ in 0..<self.grid.rows {
                let box = NSBezierPath(roundedRect: NSRect(origin: origin, size: size), xRadius: 1, yRadius: 1)
                self.values[i].setFill()
                box.fill()
                box.close()
                i += 1
                origin.x += size.width + spacing
            }
            origin.x = 0
            origin.y -= size.height + spacing
        }
    }
    
    public func addValue(_ value: Bool) {
        self.values.remove(at: 0)
        self.values.append(value ? self.okColor : self.notOkColor)
        
        if self.window?.isVisible ?? false {
            self.display()
        }
    }
}
