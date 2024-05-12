//
//  CoreML__YOLOv8_Pork_OCUITestsLaunchTests.m
//  CoreML- YOLOv8 Pork-OCUITests
//
//  Created by 杨帆 on 2024/5/12.
//

#import <XCTest/XCTest.h>

@interface CoreML__YOLOv8_Pork_OCUITestsLaunchTests : XCTestCase

@end

@implementation CoreML__YOLOv8_Pork_OCUITestsLaunchTests

+ (BOOL)runsForEachTargetApplicationUIConfiguration {
    return YES;
}

- (void)setUp {
    self.continueAfterFailure = NO;
}

- (void)testLaunch {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];

    // Insert steps here to perform after app launch but before taking a screenshot,
    // such as logging into a test account or navigating somewhere in the app

    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];
    attachment.name = @"Launch Screen";
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

@end
