//
//  NSObject_ExtensionExample.m
//  iOS Example
//
//  Created by Catalina Turlea on 2/4/16.
//  Copyright © 2016 Alamofire. All rights reserved.
//

#import "ExtensionExample.h"
@import Alamofire;

@interface ExtensionExample()

@end

@implementation ExtensionExample

- (void)downloadSampleFile {
    [AlamofireWrapper request:RequestMethodGET URLString:@"http://something.com" parameters:nil encoding:RequestParameterEncodingURL headers:nil success:^(NSURLRequest * _Nullable request, NSHTTPURLResponse * _Nullable response, NSDictionary * _Nullable json) {
        NSLog(@"Success");
    } failure:^(NSURLRequest * _Nullable request, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"Failure");
    }];
    
    
    [AlamofireWrapper upload:RequestMethodPOST :@"http://myaddress.com" headers:nil multipartFormData:^NSArray<BodyPart *> * _Nonnull {
        return @[[[BodyPart alloc] initWithData:[NSData dataWithContentsOfFile:@"myVeryLargeFile.jpg"] name:@"picture"]];
    } success:^(NSURLRequest * _Nullable request, NSHTTPURLResponse * _Nullable response, NSDictionary * _Nullable json) {
        NSLog(@"Success");
    } failure:^(NSURLRequest * _Nullable request, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"Failure");
    }];
    

    [AlamofireWrapper downloadFileWithProgress:@"http://myaddress.com" progressBlock:^(float progress) {
        NSLog(@"Progress %f", progress);
    } destination:@"outputfile.something" success:^(NSURLRequest * _Nullable request, NSHTTPURLResponse * _Nullable response, NSDictionary * _Nullable json) {
        NSLog(@"Success");
    } failure:^(NSURLRequest * _Nullable request, NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"Failure");
    }];
}


@end
