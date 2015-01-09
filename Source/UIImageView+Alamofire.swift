// Alamofire.swift
//
// Copyright (c) 2014 Alamofire (http://alamofire.org)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit

@objc public protocol ImageCache : NSObjectProtocol {
    func cachedImageForRequest(request: NSURLRequest) -> UIImage?
    func cacheImage(image: UIImage, forRequest request: NSURLRequest)
    func removeAllCachedImages()
}

// MARK: -

public class ImageViewCache : NSCache, ImageCache {
    
    // MARK: - Lifecycle Methods
    
    override init() {
        super.init()
        
        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationDidReceiveMemoryWarningNotification,
            object: nil,
            queue: NSOperationQueue.mainQueue(),
            usingBlock: {[weak self] (notification) -> Void in
                if let strongSelf = self {
                    strongSelf.removeAllObjects()
                }
            }
        )
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: - Cache Methods
    
    public func cachedImageForRequest(request: NSURLRequest) -> UIImage? {
        switch request.cachePolicy {
        case .ReloadIgnoringLocalCacheData, .ReloadIgnoringLocalAndRemoteCacheData:
            return nil
        default:
            let key = ImageViewCache.imageCacheKeyFromURLRequest(request)
            return objectForKey(key) as? UIImage
        }
    }
    
    public func cacheImage(image: UIImage, forRequest request: NSURLRequest) {
        let key = ImageViewCache.imageCacheKeyFromURLRequest(request)
        setObject(image, forKey: key)
    }
    
    public func removeAllCachedImages() {
        removeAllObjects()
    }
    
    // MARK: - Private - Helper Methods
    
    private class func imageCacheKeyFromURLRequest(request: NSURLRequest) -> String {
        return request.URL.absoluteString!
    }
}

// MARK: -

public extension UIImageView {
    
    // MARK: - Image Cache Methods
    
    public class func sharedImageCache() -> ImageCache {
        struct Static { static let imageCache = ImageViewCache() }
        
        let userDefinedCache: AnyObject! = objc_getAssociatedObject(self, &sharedImageCacheKey)
        if let userDefinedCache = userDefinedCache as? ImageCache {
            return userDefinedCache
        }
        
        return Static.imageCache
    }
    
    public class func setSharedImageCache(imageCache: ImageCache) {
        objc_setAssociatedObject(self, &sharedImageCacheKey, imageCache, UInt(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
    }
    
    // MARK: - Remote Image Methods
    
    public func setImage(#URL: NSURL) {
        setImage(URL: URL, placeHolderImage: nil)
    }

    public func setImage(#URL: NSURL, placeHolderImage: UIImage?) {
        let mutableURLRequest = NSMutableURLRequest(URL: URL)
        mutableURLRequest.addValue("image/*", forHTTPHeaderField: "Accept")
        
        let URLRequest = mutableURLRequest.copy() as NSURLRequest
        
        setImage(URLRequest: URLRequest, placeholderImage: placeHolderImage, success: nil, failure: nil)
    }
    
    public func setImage(
        #URLRequest: NSURLRequest,
        placeholderImage: UIImage?,
        success: ((NSURLRequest?, NSHTTPURLResponse?, UIImage?) -> Void)?,
        failure: ((NSURLRequest?, NSHTTPURLResponse?, NSError?) -> Void)?)
    {
        cancelImageRequest()
        
        if let image = UIImageView.sharedImageCache().cachedImageForRequest(URLRequest) {
            if let success = success {
                success(URLRequest, nil, image)
            } else {
                self.image = image
            }
        } else {
            if let placeholderImage = placeholderImage {
                self.image = placeholderImage
            }
            
            let request = Alamofire.request(URLRequest)
            request.validate()
            request.responseImage {[weak self] (request, response, image, error) -> Void in
                if let strongSelf = self {
                    if error == nil && image is UIImage {
                        let image = image! as UIImage
                        
                        if let success = success {
                            success(request, response, image)
                        } else {
                            strongSelf.image = image
                        }
                        
                        UIImageView.sharedImageCache().cacheImage(image, forRequest: request)
                    } else {
                        failure?(request, response, error)
                    }
                    
                    strongSelf.setActiveTask(nil)
                }
            }
            
            setActiveTask(request.task)
        }
    }
    
    public func cancelImageRequest() {
        activeTask()?.cancel()
    }
    
    // MARK: - Private - Task Property Methods
    
    private func activeTask() -> NSURLSessionTask? {
        let userDefinedTask: AnyObject! = objc_getAssociatedObject(self, &activeTaskKey)
        if let userDefinedTask = userDefinedTask as? NSURLSessionTask {
            return userDefinedTask
        }
        
        return nil
    }
    
    private func setActiveTask(task: NSURLSessionTask?) {
        objc_setAssociatedObject(self, &activeTaskKey, task, UInt(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
    }
}

private var sharedImageCacheKey = "UIImageView.SharedImageCache"
private var activeTaskKey = "UIImageView.ActiveTask"
