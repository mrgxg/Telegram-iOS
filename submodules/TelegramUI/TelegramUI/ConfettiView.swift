import Foundation
import UIKit
import Display

private struct Vector2 {
    var x: Float
    var y: Float
}

private final class NullActionClass: NSObject, CAAction {
    @objc func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable : Any]?) {
    }
}

private let nullAction = NullActionClass()

private final class ParticleLayer: CALayer {
    let mass: Float
    var velocity: Vector2
    var angularVelocity: Float
    var rotationAngle: Float = 0.0
    
    init(image: CGImage, size: CGSize, position: CGPoint, mass: Float, velocity: Vector2, angularVelocity: Float) {
        self.mass = mass
        self.velocity = velocity
        self.angularVelocity = angularVelocity
        
        super.init()
        
        self.contents = image
        self.bounds = CGRect(origin: CGPoint(), size: size)
        self.position = position
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func action(forKey event: String) -> CAAction? {
        return nullAction
    }
}

final class ConfettiView: UIView {
    private var particles: [ParticleLayer] = []
    private var displayLink: ConstantDisplayLinkAnimator?
    
    private var localTime: Float = 0.0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.isUserInteractionEnabled = false
        
        let colors: [UIColor] = ([
            0x56CE6B,
            0xCD89D0,
            0x1E9AFF,
            0xFF8724
        ] as [UInt32]).map(UIColor.init(rgb:))
        let imageSize = CGSize(width: 8.0, height: 8.0)
        var images: [(CGImage, CGSize)] = []
        for imageType in 0 ..< 2 {
            for color in colors {
                if imageType == 0 {
                    images.append((generateFilledCircleImage(diameter: imageSize.width, color: color)!.cgImage!, imageSize))
                } else {
                    let spriteSize = CGSize(width: 2.0, height: 6.0)
                    images.append((generateImage(spriteSize, opaque: false, rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setFillColor(color.cgColor)
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.width)))
                        context.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: size.height - size.width), size: CGSize(width: size.width, height: size.width)))
                        context.fill(CGRect(origin: CGPoint(x: 0.0, y: size.width / 2.0), size: CGSize(width: size.width, height: size.height - size.width)))
                    })!.cgImage!, spriteSize))
                }
            }
        }
        let imageCount = images.count
        
        let originXRange = 0 ..< Int(frame.width)
        let originYRange = Int(-frame.height) ..< Int(0)
        let topMassRange: Range<Float> = 20.0 ..< 30.0
        let velocityYRange = Float(3.0) ..< Float(5.0)
        let angularVelocityRange = Float(1.0) ..< Float(6.0)
        let sizeVariation = Float(0.8) ..< Float(1.6)
        
        for i in 0 ..< 70 {
            let (image, size) = images[i % imageCount]
            let sizeScale = CGFloat(Float.random(in: sizeVariation))
            let particle = ParticleLayer(image: image, size: CGSize(width: size.width * sizeScale, height: size.height * sizeScale), position: CGPoint(x: CGFloat(Int.random(in: originXRange)), y: CGFloat(Int.random(in: originYRange))), mass: Float.random(in: topMassRange), velocity: Vector2(x: 0.0, y: Float.random(in: velocityYRange)), angularVelocity: Float.random(in: angularVelocityRange))
            self.particles.append(particle)
            self.layer.addSublayer(particle)
        }
        
        let sideMassRange: Range<Float> = 80.0 ..< 90.0
        let sideOriginYBase: Float = Float(frame.size.height * 8.5 / 10.0)
        let sideOriginYVariation: Float = Float(frame.size.height / 12.0)
        let sideOriginYRange = Float(sideOriginYBase - sideOriginYVariation) ..< Float(sideOriginYBase + sideOriginYVariation)
        let sideOriginXRange = Float(0.0) ..< Float(100.0)
        let sideOriginVelocityValueRange = Float(1.1) ..< Float(1.6)
        let sideOriginVelocityValueScaling: Float = 900.0
        let sideOriginVelocityBase: Float = Float.pi / 2.0 + atanf(Float(CGFloat(sideOriginYBase) / (frame.size.width * 0.5)))
        let sideOriginVelocityVariation: Float = 0.25
        let sideOriginVelocityAngleRange = Float(sideOriginVelocityBase - sideOriginVelocityVariation) ..< Float(sideOriginVelocityBase + sideOriginVelocityVariation)
        
        for sideIndex in 0 ..< 2 {
            let sideSign: Float = sideIndex == 0 ? 1.0 : -1.0
            let originX: CGFloat = sideIndex == 0 ? -5.0 : (frame.width + 5.0)
            for i in 0 ..< 40 {
                let offsetX = CGFloat(Float.random(in: sideOriginXRange) * (-sideSign))
                let velocityValue = Float.random(in: sideOriginVelocityValueRange) * sideOriginVelocityValueScaling
                let velocityAngle = Float.random(in: sideOriginVelocityAngleRange)
                let velocityX = sideSign * velocityValue * sinf(velocityAngle)
                let velocityY = velocityValue * cosf(velocityAngle)
                let (image, size) = images[i % imageCount]
                let sizeScale = CGFloat(Float.random(in: sizeVariation))
                let particle = ParticleLayer(image: image, size: CGSize(width: size.width * sizeScale, height: size.height * sizeScale), position: CGPoint(x: originX + offsetX, y: CGFloat(Float.random(in: sideOriginYRange))), mass: Float.random(in: sideMassRange), velocity: Vector2(x: velocityX, y: velocityY), angularVelocity: Float.random(in: angularVelocityRange))
                self.particles.append(particle)
                self.layer.addSublayer(particle)
            }
        }
        
        self.displayLink = ConstantDisplayLinkAnimator(update: { [weak self] in
            self?.step()
        })
        
        self.displayLink?.isPaused = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func step() {
        var haveParticlesAboveGround = false
        let minPositionY: CGFloat = 0.0
        let maxPositionY = self.bounds.height + 30.0
        let minDampingX: CGFloat = 40.0
        let maxDampingX: CGFloat = self.bounds.width - 40.0
        let centerX: CGFloat = self.bounds.width / 2.0
        let currentTime = self.localTime
        let dt: Float = 1.0 / 60.0
        let slowdownDt: Float
        let slowdownStart: Float = 0.2
        let slowdownDuration: Float = 1.0
        let damping: Float
        if currentTime >= slowdownStart && currentTime <= slowdownStart + slowdownDuration {
            let slowdownTimestamp: Float = currentTime - slowdownStart
            
            let slowdownRampInDuration: Float = 0.15
            let slowdownRampOutDuration: Float = 0.6
            let slowdownTransition: Float
            if slowdownTimestamp < slowdownRampInDuration {
                slowdownTransition = slowdownTimestamp / slowdownRampInDuration
            } else if slowdownTimestamp >= slowdownDuration - slowdownRampOutDuration {
                let reverseTransition = (slowdownTimestamp - (slowdownDuration - slowdownRampOutDuration)) / slowdownRampOutDuration
                slowdownTransition = 1.0 - reverseTransition
            } else {
                slowdownTransition = 1.0
            }
            
            let slowdownFactor: Float = 0.3 * slowdownTransition + 1.0 * (1.0 - slowdownTransition)
            slowdownDt = dt * slowdownFactor
            let dampingFactor: Float = 0.97 * slowdownTransition + 1.0 * (1.0 - slowdownTransition)
            damping = dampingFactor
        } else {
            slowdownDt = dt
            damping = 1.0
        }
        self.localTime += 1.0 / 60.0
        
        let g: Vector2 = Vector2(x: 0.0, y: 9.8)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        var turbulenceVariation: [Float] = []
        for _ in 0 ..< 20 {
            turbulenceVariation.append(Float.random(in: -9.0 ..< 9.0))
        }
        let turbulenceVariationCount = turbulenceVariation.count
        var index = 0
        for particle in self.particles {
            var position = particle.position
            
            let localDt: Float = slowdownDt
            
            position.x += CGFloat(particle.velocity.x * localDt)
            position.y += CGFloat(particle.velocity.y * localDt)
            particle.position = position
            
            particle.rotationAngle += particle.angularVelocity * localDt
            particle.transform = CATransform3DMakeRotation(CGFloat(particle.rotationAngle), 0.0, 0.0, 1.0)
            
            let acceleration = g
            
            var velocity = particle.velocity
            velocity.x += acceleration.x * particle.mass * localDt
            velocity.y += acceleration.y * particle.mass * localDt
            velocity.x += turbulenceVariation[index % turbulenceVariationCount]
            if position.y > minPositionY {
                velocity.x *= damping
                velocity.y *= damping
            }
            particle.velocity = velocity
            
            index += 1
            
            if position.y < maxPositionY {
                haveParticlesAboveGround = true
            }
        }
        CATransaction.commit()
        if !haveParticlesAboveGround {
            self.displayLink?.isPaused = true
            self.removeFromSuperview()
        }
    }
}
