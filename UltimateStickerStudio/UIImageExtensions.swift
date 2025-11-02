import UIKit

extension UIImage {
    func laundered() -> UIImage {

        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(in: CGRect(origin: .zero, size: self.size))
        let launderedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        // Return the clean image
        return launderedImage ?? self
    }
}