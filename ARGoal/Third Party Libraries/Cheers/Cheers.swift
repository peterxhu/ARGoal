import UIKit

// Copyright (c) 2015 Hyper Interaktiv AS
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

/// The view to show particles
public class CheerView: UIView {
  public var config = Config()
  var emitter: CAEmitterLayer?

  public override func didMoveToSuperview() {
    super.didMoveToSuperview()

    isUserInteractionEnabled = false
  }

  /// Start animation
  public func start() {
    stop()

    let emitter = CAEmitterLayer()
    emitter.emitterPosition = CGPoint(x: bounds.width / 2.0, y: 0)
    emitter.emitterShape = kCAEmitterLayerLine
    emitter.emitterSize = CGSize(width: bounds.width, height: 1)
    emitter.renderMode = kCAEmitterLayerAdditive

    let colors = config.colors.shuffled()
    var cells = [CAEmitterCell]()
    
    for (image, color) in zip(pickImages(), colors.shuffled()) {
        let cell = CAEmitterCell()
        cell.birthRate = 20
        cell.lifetime = 20.0
        cell.lifetimeRange = 10
        cell.velocity = 250
        cell.velocityRange = 50
        cell.emissionLongitude = CGFloat.pi
        cell.emissionRange = CGFloat.pi * 0.2
        cell.spinRange = 5
        cell.scale = 0.3
        cell.scaleRange = 0.2
        cell.color = color.cgColor
        cell.alphaSpeed = -0.1
        cell.contents = image.cgImage
        cell.xAcceleration = 20
        cell.yAcceleration = 50
        cell.redRange = 0.8
        cell.greenRange = 0.8
        cell.blueRange = 0.8
        cells.append(cell)
    }

    emitter.emitterCells = cells
    emitter.beginTime = CACurrentMediaTime()

    config.customize?(cells)

    layer.addSublayer(emitter)
    self.emitter = emitter
  }

  /// Stop animation
  public func stop() {
    emitter?.birthRate = 0
  }

  func pickImages() -> [UIImage] {
    let generator = ImageGenerator()

    switch config.particle {
    case .confetti:
      return [generator.rectangle(), generator.circle(),
              generator.triangle(), generator.curvedQuadrilateral()]
        .flatMap({ $0 })
    case .image(let images):
      return images
    case .text(let size, let strings):
      return strings.flatMap({ generator.generate(size: size, string: $0) })
    }
  }
}
