import CoreGraphics

struct CaptureRectAdjuster {
    private static let minimumSize = CGSize(width: 28, height: 28)
    private static let lineScrollScale: CGFloat = 4
    private static let preciseScrollScale: CGFloat = 10
    private static let maximumLineDelta: CGFloat = 3
    private static let maximumPreciseDelta: CGFloat = 0.9
    private static let maximumStep: CGFloat = 18

    static func resizedTarget(
        _ target: CaptureTarget,
        centeredAt point: CGPoint,
        deltaX: CGFloat,
        deltaY: CGFloat,
        axis: CaptureResizeAxis
    ) -> CaptureTarget {
        let size = adjustedSize(
            from: target.rect.size,
            deltaX: deltaX,
            deltaY: deltaY,
            axis: axis,
            screenFrame: target.screenFrame
        )

        return targetWithAdjustedRect(target, centeredAt: point, size: size)
    }

    static func targetWithAdjustedRect(
        _ target: CaptureTarget,
        centeredAt point: CGPoint,
        size: CGSize
    ) -> CaptureTarget {
        let rect = clampedRect(centeredAt: point, size: size, screenFrame: target.screenFrame)

        return CaptureTarget(
            point: point,
            screenFrame: target.screenFrame,
            rect: rect,
            sourceAppName: target.sourceAppName,
            sourceBundleID: target.sourceBundleID,
            axRole: target.axRole,
            axSubrole: target.axSubrole,
            axTitle: target.axTitle,
            confidence: .adjusted
        )
    }

    static func adjustedSize(
        from currentSize: CGSize,
        deltaX: CGFloat,
        deltaY: CGFloat,
        axis: CaptureResizeAxis,
        screenFrame: CGRect
    ) -> CGSize {
        let horizontalStep = scrollStep(for: deltaX)
        let verticalStep = scrollStep(for: deltaY)
        let dominantStep = abs(verticalStep) >= abs(horizontalStep) ? verticalStep : horizontalStep
        var width = currentSize.width
        var height = currentSize.height

        switch axis {
        case .both:
            width += dominantStep
            height += dominantStep
        case .width:
            width += horizontalStep != 0 ? horizontalStep : dominantStep
        case .height:
            height += verticalStep != 0 ? verticalStep : dominantStep
        }

        return CGSize(
            width: clamp(width, min: minimumSize.width, max: max(minimumSize.width, screenFrame.width)),
            height: clamp(height, min: minimumSize.height, max: max(minimumSize.height, screenFrame.height))
        )
    }

    private static func clampedRect(centeredAt point: CGPoint, size: CGSize, screenFrame: CGRect) -> CGRect {
        let width = clamp(size.width, min: minimumSize.width, max: max(minimumSize.width, screenFrame.width))
        let height = clamp(size.height, min: minimumSize.height, max: max(minimumSize.height, screenFrame.height))
        let originX = clamp(point.x - width / 2, min: screenFrame.minX, max: screenFrame.maxX - width)
        let originY = clamp(point.y - height / 2, min: screenFrame.minY, max: screenFrame.maxY - height)

        return CGRect(x: originX, y: originY, width: width, height: height).integral
    }

    static func scrollStep(for delta: CGFloat) -> CGFloat {
        guard delta != 0 else { return 0 }
        let isPrecise = abs(delta) < 1
        let maximumDelta = isPrecise ? maximumPreciseDelta : maximumLineDelta
        let scale = isPrecise ? preciseScrollScale : lineScrollScale
        let clampedDelta = clamp(delta, min: -maximumDelta, max: maximumDelta)
        let scaledStep = abs(clampedDelta * scale)
        let magnitude = clamp(scaledStep, min: 1, max: maximumStep)

        return delta > 0 ? magnitude : -magnitude
    }

    private static func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}
