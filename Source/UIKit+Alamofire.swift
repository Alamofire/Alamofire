//
//  UIKit+Alamofire.swift
//  Alamofire
//
//  Created by Martin Conte Mac Donell (Reflejo@gmail.com) on 2/3/15.
//  Copyright (c) 2013-2015 Lyft (http://lyft.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Alamofire
import UIKit

/**
By implementing this protocol, one could extend different UIKit elements to support Alamofire integration,
the main motivation for this is DRY. And having only one function with the logic for setting/getting images.
*/
private protocol ImageDownloadable {
    func imageRequest(forKey key: UInt?) -> Request?
    func setImageRequest(request: Request?, forKey key: UInt?)
    func setImage(image: UIImage?, forKey key: UInt?)
}


/**
This is the shared function in charge of requesting the image and by using the ImageDownloadable protocol,
it'd set the image to the instance in the most appropiated way (UIButton will use setImage(..,forState), 
UIImageView will use .image = .., etc)
*/
private func loadImage(on instance: ImageDownloadable, #request: NSURLRequest, #placeholderImage: UIImage?,
    forKey key: UInt? = nil, #completion: (UIImage? -> Void)?)
{
    instance.imageRequest(forKey: key)?.cancel()
    instance.setImageRequest(nil, forKey: key)

    if let cachedImage = ImageCache.cachedImage(forRequest: request) {
        if completion == nil {
            instance.setImage(cachedImage, forKey: key)
        }

        completion?(cachedImage)
    }

    if placeholderImage != nil {
        instance.setImage(placeholderImage, forKey: key)
    }

    let imageRequest = Alamofire.request(request).responseImage { (request, _, image) -> Void in
        let imageRequest = instance.imageRequest(forKey: key)
        if request.URL == imageRequest?.request.URL {
            if completion == nil {
                instance.setImage(image, forKey: key)
            }

            completion?(image)
            if request.URLRequest === imageRequest?.request {
                instance.setImageRequest(nil, forKey: key)
            }
        }

        if let image = image {
            ImageCache.cacheImage(image, forRequest: request)
        }
    }

    instance.setImageRequest(imageRequest, forKey: key)
}

// A global var to produce a unique address for the assoc object handle
private var AssociatedRequestHandle: UInt8 = 0

// MARK: - UIImageView extension

/**
This category adds methods to the UIKit framework’s UIImageView class. The methods in this
category provide support for loading remote images asynchronously from a URL.
*/
extension UIImageView: ImageDownloadable {

    /**
    Asynchronously downloads an image from the specified URL, and sets it once the request is finished. 
    Any previous image request for the receiver will be cancelled.

    If the image is cached locally, the image is set immediately, otherwise the specified placeholder image 
    will be set immediately, and then the remote image will be set once the request is finished.

    By default, URL requests have a cache policy of NSURLCacheStorageAllowed and a timeout interval of 30 
    seconds, and are set not handle cookies. To configure URL requests differently, use
    `setImage(request, placeholderImage, completion)`

    :param: URL              The URL used for the image request
    :param: placeholderImage The image to be set initially, until the image request finishes. If nil, 
                             the image view will not change its image until the image request finishes.
    */
    public func setImage(#URL: NSURL, placeholderImage: UIImage? = nil) {
        let request = NSMutableURLRequest(URL: URL)
        request.addValue("image/*", forHTTPHeaderField: "Accept")

        self.setImage(request: request, placeholderImage: placeholderImage, completion: nil)
    }

    /**
    Asynchronously downloads an image from the specified URL request, and sets it once the request is 
    finished. Any previous image request for the receiver will be cancelled.

    If the image is cached locally, the image is set immediately, otherwise the specified placeholder 
    image will be set immediately, and then the remote image will be set once the request is finished.

    If a completion closure is specified, it is the responsibility of the closure to set the image of the 
    image view before returning. If no completion closure is specified, the default behavior of setting 
    the image with self.image = image is applied.

    :param: URL              The URL request used for the image request.
    :param: placeholderImage The image to be set initially, until the image request finishes. If nil,
                             the image view will not change its image until the image request finishes.
    :param: completion       A block to be executed when the image request operation finishes. This block has 
                             no return value and takes one arguments: the image created from the response 
                             data of request.
    */
    public func setImage(#request: NSURLRequest, placeholderImage: UIImage?, completion: (UIImage? -> Void)?) {
        loadImage(on: self, request: request, placeholderImage: placeholderImage, completion: completion)
    }

    // MARK: ImageDownloadable implementation

    private func imageRequest(forKey key: UInt?) -> Request? {
        return objc_getAssociatedObject(self, &AssociatedRequestHandle) as? Request
    }

    private func setImageRequest(request: Request?, forKey key: UInt?) {
        objc_setAssociatedObject(self, &AssociatedRequestHandle, request,
            objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
    }

    private func setImage(image: UIImage?, forKey: UInt?) {
        self.image = image
    }
}

// MARK: - UIButton extension

/**
This category adds methods to the UIKit framework’s UIButton class. The methods in this category provide 
support for loading remote images and background images asynchronously from a URL.
*/
extension UIButton: ImageDownloadable {

    /// Used for masking the state key and support both image and backgroundImage.
    private var ControlStateBackground: UIControlState { return UIControlState.Application }

    /**
    Asynchronously downloads an image from the specified URL, and sets it as the image for the specified 
    state once the request is finished. Any previous image request for the receiver will be cancelled.

    If the image is cached locally, the image is set immediately, otherwise the specified placeholder image
    will be set immediately, and then the remote image will be set once the request is finished.

    :param: URL              The URL used for the image request
    :param: state            The control state
    :param: placeholderImage The image to be set initially, until the image request finishes. If nil, 
                             the button will not change its image until the image request finishes
    */
    public func setImage(#URL: NSURL, forState state: UIControlState, placeholderImage: UIImage? = nil) {
        let request = NSMutableURLRequest(URL: URL)
        request.addValue("image/*", forHTTPHeaderField: "Accept")

        self.setImage(request: request, forState: state, placeholderImage: placeholderImage, completion: nil)
    }

    /**
    Asynchronously downloads an image from the specified URL request, and sets it as the image for the 
    specified state once the request is finished. Any previous image request for the receiver will be
    cancelled.

    If the image is cached locally, the image is set immediately, otherwise the specified placeholder image 
    will be set immediately, and then the remote image will be set once the request is finished.

    If a completion closure is specified, it is the responsibility of the closure to set the image of 
    the button before returning. If no success block is specified, the default behavior of setting the image 
    with setImage(.., forState:..) is applied.

    :param: request          The URL request used for the image request
    :param: state            The control state
    :param: placeholderImage The image to be set initially, until the image request finishes. If nil, the 
                             button will not change its image until the image request finishes.
    :param: completion       A block to be executed when the image request operation finishes. This block has
                             no return value and takes one arguments: the image created from the response 
                             data of request.
    */
    public func setImage(#request: NSURLRequest, forState state: UIControlState,
        placeholderImage: UIImage? = nil, completion: (UIImage? -> Void)?)
    {
        loadImage(on: self, request: request, placeholderImage: placeholderImage, forKey: state.rawValue,
            completion: completion)
    }

    /**
    Asynchronously downloads an image from the specified URL, and sets it as the image for the specified 
    state once the request is finished. Any previous image request for the receiver will be cancelled.

    If the image is cached locally, the image is set immediately, otherwise the specified placeholder image
    will be set immediately, and then the remote image will be set once the request is finished.

    :param: URL              The URL used for the image request
    :param: state            The control state
    :param: placeholderImage The background image to be set initially, until the image request finishes. If 
                             nil, the button will not change its image until the image request finishes
    */
    public func setBackgroundImage(#URL: NSURL, forState state: UIControlState,
        placeholderImage: UIImage? = nil)
    {
        let request = NSMutableURLRequest(URL: URL)
        request.addValue("image/*", forHTTPHeaderField: "Accept")

        self.setBackgroundImage(request: request, forState: state, placeholderImage: placeholderImage,
            completion: nil)
    }

    /**
    Asynchronously downloads an image from the specified URL request, and sets it as the image for the 
    specified state once the request is finished. Any previous image request for the receiver will be
    cancelled.

    If the image is cached locally, the image is set immediately, otherwise the specified placeholder image 
    will be set immediately, and then the remote image will be set once the request is finished.

    If a completion closure is specified, it is the responsibility of the closure to set the image of 
    the button before returning. If no success block is specified, the default behavior of setting the image 
    with setImage(.., forState:..) is applied.

    :param: request          The URL request used for the image request
    :param: state            The control state
    :param: placeholderImage The background image to be set initially, until the image request finishes. 
                             If nil, the button will not change its image until the image request finishes.
    :param: completion       A block to be executed when the image request operation finishes. This block has
                             no return value and takes one arguments: the image created from the response 
                             data of request.
    */
    public func setBackgroundImage(#request: NSURLRequest, forState state: UIControlState,
        placeholderImage: UIImage? = nil, completion: (UIImage? -> Void)?)
    {
        let state = state & ControlStateBackground
        loadImage(on: self, request: request, placeholderImage: placeholderImage, forKey: state.rawValue,
            completion: completion)
    }

    // MARK: ImageDownloadable implementation

    private func imageRequest(forKey key: UInt?) -> Request? {
        let requestMap = objc_getAssociatedObject(self, &AssociatedRequestHandle) as? [UInt: Request]
        return requestMap?[key ?? 0]
    }

    private func setImageRequest(request: Request?, forKey key: UInt?) {
        var requestMap = objc_getAssociatedObject(self, &AssociatedRequestHandle) as? [UInt: Request] ?? [:]
        requestMap[key ?? 0] = request
        objc_setAssociatedObject(self, &AssociatedRequestHandle, requestMap,
            objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
    }

    private func setImage(image: UIImage?, forKey key: UInt?) {
        let state = UIControlState(rawValue: key ?? 0) ?? UIControlState.Normal
        if state & ControlStateBackground != UIControlState.allZeros {
            self.setBackgroundImage(image, forState: state)
        } else {
            self.setImage(image, forState: state)
        }
    }

}

// MARK: - Image Cache

private struct ImageCache {
    private static var cache: NSCache = NSCache()

    static func cachedImage(forRequest request: NSURLRequest) -> UIImage? {
        switch request.cachePolicy {
            case .ReloadIgnoringLocalCacheData, .ReloadIgnoringLocalAndRemoteCacheData:
                return nil

            default:
                break
        }

        return self.cache.objectForKey(request.URL) as? UIImage
    }

    static func cacheImage(image: UIImage, forRequest request: NSURLRequest) {
        self.cache.setObject(image, forKey: request.URL)
    }
}

// MARK: - Image Response Serializer

extension Request {

    /**
    Creates a response serializer that returns an image constructed from the response data. The returned image
    will be decompressed if the decompressImage arguemnt is true.

    :param: decompressImage  Whether to automatically inflate response image data for compressed formats 
                             (such as PNG or JPEG). Enabling this can significantly improve drawing 
                             performance on iOS, as it allows a bitmap representation to be constructed in the 
                             background rather than on the main thread. `true` by default.

    :returns: An image response serializer.
    */
    class func ImageResponseSerializer(decompressImage: Bool = true) -> Serializer {
        return { request, response, data in
            if data == nil || response == nil {
                return (nil, nil)
            }

            if decompressImage {
                return (self.decompressImage(response! as NSHTTPURLResponse, data: data!), nil)
            } else {
                return (UIImage(data: data!, scale: UIScreen.mainScreen().scale), nil)
            }
        }
    }

    /**
    Adds a handler to be called once the request has finished.

    :param: completionHandler A closure to be executed once the request has finished. The closure takes 3
                              arguments: the URL request, the URL response, if one was received, the image, 
                              if one could be created from the response and data.

    :returns: The request.
    */

    func responseImage(completion: (NSURLRequest, NSHTTPURLResponse?, UIImage?) -> Void) -> Self {
        let serializer = Request.ImageResponseSerializer()
        return response(serializer: serializer, completionHandler: { request, response, image, error in
            completion(request, response, image as? UIImage)
        })
    }

    // MARK: Private methods

    private class func decompressImage(response: NSHTTPURLResponse, data: NSData) -> UIImage? {
        if data.length == 0 {
            return nil
        }

        let dataProvider = CGDataProviderCreateWithCFData(data)

        var imageRef: CGImageRef?
        if response.MIMEType == "image/png" {
            imageRef = CGImageCreateWithPNGDataProvider(dataProvider, nil, true, kCGRenderingIntentDefault)

        } else if response.MIMEType == "image/jpeg" {
            imageRef = CGImageCreateWithJPEGDataProvider(dataProvider, nil, true, kCGRenderingIntentDefault)

            // CGImageCreateWithJPEGDataProvider does not properly handle CMKY, so if so,
            // fall back to AFImageWithDataAtScale
            if imageRef != nil {
                let imageColorSpace = CGImageGetColorSpace(imageRef)
                let imageColorSpaceModel = CGColorSpaceGetModel(imageColorSpace)
                if imageColorSpaceModel.value == kCGColorSpaceModelCMYK.value {
                    imageRef = nil
                }
            }
        }

        let scale = UIScreen.mainScreen().scale
        let image = UIImage(data: data, scale: scale)
        if imageRef == nil || image == nil {
            if image == nil || image?.images != nil {
                return image
            }

            imageRef = CGImageCreateCopy(image!.CGImage)
            if imageRef == nil {
                return nil
            }
        }

        let width = CGImageGetWidth(imageRef)
        let height = CGImageGetHeight(imageRef)
        let bitsPerComponent = CGImageGetBitsPerComponent(imageRef)

        if width * height > 1024 * 1024 || bitsPerComponent > 8 {
            return image
        }

        let bytesPerRow = CGImageGetBytesPerRow(imageRef)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colorSpaceModel = CGColorSpaceGetModel(colorSpace)
        let alphaInfo = CGImageGetAlphaInfo(imageRef)
        var bitmapInfo = CGImageGetBitmapInfo(imageRef)
        if colorSpaceModel.value == kCGColorSpaceModelRGB.value {
            if alphaInfo == .None {
                bitmapInfo &= ~CGBitmapInfo.AlphaInfoMask
                bitmapInfo |= CGBitmapInfo(CGImageAlphaInfo.NoneSkipFirst.rawValue)
            } else if (!(alphaInfo == .NoneSkipFirst || alphaInfo == .NoneSkipLast)) {
                bitmapInfo &= ~CGBitmapInfo.AlphaInfoMask
                bitmapInfo |= CGBitmapInfo(CGImageAlphaInfo.PremultipliedFirst.rawValue)
            }
        }

        let context = CGBitmapContextCreate(nil, width, height, bitsPerComponent, bytesPerRow,
            colorSpace, bitmapInfo)
        if context == nil {
            return image
        }

        let drawRect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        CGContextDrawImage(context, drawRect, imageRef)
        let inflatedImageRef = CGBitmapContextCreateImage(context)
        return UIImage(CGImage: inflatedImageRef, scale: scale, orientation: image!.imageOrientation)
    }
}
