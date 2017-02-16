//
//  AppDelegate.h
//  MacChanger
//
//  Created by Jakey on 14/10/31.
//  Copyright (c) 2014年 www.skyfox.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    NSArray *_deviceList;
    NSDictionary *_interfaceList;

}
@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *ipAddressTextField;
@property (weak) IBOutlet NSTextField *oldMacAddress;
@property (weak) IBOutlet NSTextField *freshMacAddress;
@property (weak) IBOutlet NSPopUpButton *macListPopUpButton;
- (IBAction)resetTouched:(id)sender;
- (IBAction)modifyTouched:(id)sender;
- (IBAction)randomTouched:(id)sender;
@end
