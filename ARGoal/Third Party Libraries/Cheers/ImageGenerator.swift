import UIKit

// Copyright (c) 2015 Hyper Interaktiv AS
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

class ImageGenerator {
  private let size = CGSize(width: 20, height: 20)

  private func generate(block: (CGContext?) -> Void) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
    let context = UIGraphicsGetCurrentContext()
    block(context)
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return image
  }

  func generate(size: CGSize, string: NSAttributedString) -> UIImage? {
    return generate { context in
      let rect = CGRect(origin: .zero, size: size)
      context?.clear(rect)
      string.draw(in: rect)
    }
  }

  func rectangle() -> UIImage? {
    return generate { context in
      let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height/2)
      let path = UIBezierPath(rect: rect)
      context?.setFillColor(UIColor.white.cgColor)
      context?.addPath(path.cgPath)
      context?.fillPath()
    }
  }

  func circle() -> UIImage? {
    return generate { context in
      let rect = CGRect(origin: .zero, size: size)
      let path = UIBezierPath(ovalIn: rect)
      context?.setFillColor(UIColor.white.cgColor)
      context?.addPath(path.cgPath)
      context?.fillPath()
    }
  }

  func triangle() -> UIImage? {
    return generate { context in
      let path = UIBezierPath()
      path.move(to: CGPoint(x: size.width/2, y: 0))
      path.addLine(to: CGPoint(x: size.width, y: size.height))
      path.addLine(to: CGPoint(x: 0, y: size.height))
      path.close()
      context?.setFillColor(UIColor.white.cgColor)
      context?.addPath(path.cgPath)
      context?.fillPath()
    }
  }

  func curvedQuadrilateral() -> UIImage? {
    return generate { context in
      let path = UIBezierPath()
      let rightPoint = CGPoint(x: size.width - 5, y: 5)
      let leftPoint = CGPoint(x: size.width * 0.5, y: size.height - 8)

      // top left
      path.move(to: CGPoint.zero)
      path.addLine(to: CGPoint(x: size.width * 0.3, y: 0))

      // bottom right
      path.addQuadCurve(to: CGPoint(x: size.width, y: size.height),
                        controlPoint: rightPoint)
      path.addLine(to: CGPoint(x: size.width * 0.7, y: size.height))

      // close to top left
      path.addQuadCurve(to: CGPoint.zero,
                        controlPoint: leftPoint)
      path.close()
      context?.setFillColor(UIColor.white.cgColor)
      context?.addPath(path.cgPath)
      context?.fillPath()
    }
  }
}
