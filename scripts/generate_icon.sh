#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_PATH="${1:-$ROOT_DIR/outputs/EyeRest.app/Contents/Resources/AppIcon.icns}"
ICONSET_DIR="$ROOT_DIR/.build/AppIcon.iconset"
GENERATOR_SOURCE="$ROOT_DIR/.build/generate_icon.m"
GENERATOR_BIN="$ROOT_DIR/.build/generate_icon"

mkdir -p "$ROOT_DIR/.build" "$(dirname "$OUTPUT_PATH")"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

cat > "$GENERATOR_SOURCE" <<'OBJC'
#import <Cocoa/Cocoa.h>

static NSColor *ERIconColor(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha) {
    return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
}

static NSBezierPath *ERRoundedRect(NSRect rect, CGFloat radius) {
    return [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];
}

static void ERDrawIcon(CGFloat size) {
    NSRect canvas = NSMakeRect(0, 0, size, size);
    [[NSColor clearColor] setFill];
    NSRectFill(canvas);

    NSRect tile = NSInsetRect(canvas, size * 0.045, size * 0.045);
    NSBezierPath *tilePath = ERRoundedRect(tile, size * 0.22);
    [NSGraphicsContext saveGraphicsState];
    [tilePath addClip];

    NSGradient *background = [[NSGradient alloc] initWithStartingColor:ERIconColor(0.10, 0.56, 0.67, 1)
                                                           endingColor:ERIconColor(0.58, 0.88, 0.70, 1)];
    [background drawInRect:canvas angle:135];

    [ERIconColor(1.00, 0.95, 0.55, 0.28) setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(size * 0.62, size * 0.62, size * 0.26, size * 0.26)] fill];

    NSBezierPath *horizon = [NSBezierPath bezierPath];
    [horizon moveToPoint:NSMakePoint(size * 0.14, size * 0.30)];
    [horizon curveToPoint:NSMakePoint(size * 0.86, size * 0.30)
            controlPoint1:NSMakePoint(size * 0.34, size * 0.39)
            controlPoint2:NSMakePoint(size * 0.62, size * 0.22)];
    [horizon setLineWidth:MAX(1.0, size * 0.032)];
    [horizon setLineCapStyle:NSLineCapStyleRound];
    [ERIconColor(1.0, 1.0, 1.0, 0.28) setStroke];
    [horizon stroke];

    [NSGraphicsContext restoreGraphicsState];

    NSBezierPath *eye = [NSBezierPath bezierPath];
    [eye moveToPoint:NSMakePoint(size * 0.15, size * 0.52)];
    [eye curveToPoint:NSMakePoint(size * 0.50, size * 0.73)
        controlPoint1:NSMakePoint(size * 0.24, size * 0.66)
        controlPoint2:NSMakePoint(size * 0.37, size * 0.73)];
    [eye curveToPoint:NSMakePoint(size * 0.85, size * 0.52)
        controlPoint1:NSMakePoint(size * 0.63, size * 0.73)
        controlPoint2:NSMakePoint(size * 0.76, size * 0.66)];
    [eye curveToPoint:NSMakePoint(size * 0.50, size * 0.31)
        controlPoint1:NSMakePoint(size * 0.76, size * 0.38)
        controlPoint2:NSMakePoint(size * 0.63, size * 0.31)];
    [eye curveToPoint:NSMakePoint(size * 0.15, size * 0.52)
        controlPoint1:NSMakePoint(size * 0.37, size * 0.31)
        controlPoint2:NSMakePoint(size * 0.24, size * 0.38)];
    [eye closePath];

    NSShadow *eyeShadow = [[NSShadow alloc] init];
    eyeShadow.shadowOffset = NSMakeSize(0, -size * 0.018);
    eyeShadow.shadowBlurRadius = size * 0.040;
    eyeShadow.shadowColor = ERIconColor(0.03, 0.20, 0.24, 0.24);
    [NSGraphicsContext saveGraphicsState];
    [eyeShadow set];
    [ERIconColor(1.0, 1.0, 1.0, 0.94) setFill];
    [eye fill];
    [NSGraphicsContext restoreGraphicsState];

    [ERIconColor(0.07, 0.34, 0.42, 1) setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(size * 0.39, size * 0.41, size * 0.22, size * 0.22)] fill];

    [ERIconColor(0.58, 0.88, 0.70, 1) setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(size * 0.44, size * 0.46, size * 0.12, size * 0.12)] fill];

    [ERIconColor(1.0, 1.0, 1.0, 0.80) setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(size * 0.48, size * 0.54, size * 0.035, size * 0.035)] fill];

    NSBezierPath *rim = ERRoundedRect(tile, size * 0.22);
    [rim setLineWidth:MAX(1.0, size * 0.018)];
    [ERIconColor(1.0, 1.0, 1.0, 0.42) setStroke];
    [rim stroke];
}

static BOOL ERWriteIcon(NSString *path, NSInteger pixels) {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                    pixelsWide:pixels
                                                                    pixelsHigh:pixels
                                                                 bitsPerSample:8
                                                               samplesPerPixel:4
                                                                      hasAlpha:YES
                                                                      isPlanar:NO
                                                                colorSpaceName:NSDeviceRGBColorSpace
                                                                  bytesPerRow:0
                                                                 bitsPerPixel:0];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    context.imageInterpolation = NSImageInterpolationHigh;
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    ERDrawIcon((CGFloat)pixels);
    [NSGraphicsContext restoreGraphicsState];

    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return [png writeToFile:path atomically:YES];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 2) return 64;
        NSString *iconsetPath = [NSString stringWithUTF8String:argv[1]];
        NSArray<NSArray *> *icons = @[
            @[@"icon_16x16.png", @16],
            @[@"icon_16x16@2x.png", @32],
            @[@"icon_32x32.png", @32],
            @[@"icon_32x32@2x.png", @64],
            @[@"icon_128x128.png", @128],
            @[@"icon_128x128@2x.png", @256],
            @[@"icon_256x256.png", @256],
            @[@"icon_256x256@2x.png", @512],
            @[@"icon_512x512.png", @512],
            @[@"icon_512x512@2x.png", @1024]
        ];
        for (NSArray *entry in icons) {
            NSString *fileName = entry[0];
            NSInteger pixels = [entry[1] integerValue];
            NSString *path = [iconsetPath stringByAppendingPathComponent:fileName];
            if (!ERWriteIcon(path, pixels)) return 1;
        }
    }
    return 0;
}
OBJC

clang -fobjc-arc -framework Cocoa "$GENERATOR_SOURCE" -o "$GENERATOR_BIN"
"$GENERATOR_BIN" "$ICONSET_DIR"
/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_PATH"

echo "$OUTPUT_PATH"
