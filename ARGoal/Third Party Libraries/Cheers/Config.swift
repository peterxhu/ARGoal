import UIKit

// Copyright (c) 2015 Hyper Interaktiv AS
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

/// The shape of particles
///
/// - confetti: A built in mix of basic shapes
/// - image: An array of images
/// - text: An array of texts
public enum Particle {
  case confetti
  case image([UIImage])
  case text(CGSize, [NSAttributedString])
}

/// Used to configure CheerView
public struct Config {
  /// Specify the particle shapes
  public var particle: Particle = .confetti

  /// The list of available colors. This will be shuffled
  public var colors: [UIColor] = [
    UIColor.red,
    UIColor.green,
    UIColor.blue,
    UIColor.yellow,
    UIColor.purple,
    UIColor.orange,
    UIColor.cyan
  ]

  /// Customize the cells
  public var customize: (([CAEmitterCell]) -> Void)?

  public init() {
    
  }
}
