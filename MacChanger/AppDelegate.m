//
//  AppDelegate.m
//  MacAddress
//
//  Created by Jakey on 14/10/31.
//  Copyright (c) 2014年 www.skyfox.org. All rights reserved.
//

#import "AppDelegate.h"
#import "STPrivilegedTask.h"
#import <ServiceManagement/ServiceManagement.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#define kSMJobHelperBunldeID @"SMJobHelper"

#include <stdlib.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <ifaddrs.h>
#include <mach/mach.h>
#include <netdb.h>

@implementation AppDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    [self reloadData];
    
}
- (void)reloadData{
    _deviceList = [self getDeviceList];
    _interfaceList = [self interfaceList];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    for(int i = 0; i < [_deviceList count]; i++)
    {
        NSDictionary *device = [_deviceList objectAtIndex:i];
        [self.macListPopUpButton addItemWithTitle:[device objectForKey:@"name"]];
        if ([[device objectForKey:@"name"] isEqualToString:@"en0"]) {
            [self.macListPopUpButton selectItemAtIndex:i];
            self.ipAddressTextField.stringValue = [_interfaceList objectForKey:[device objectForKey:@"name"]]?:@"";
            self.oldMacAddress.stringValue = [device objectForKey:@"address"]?:@"";
        }
        if ([[defaults objectForKey:[device objectForKey:@"name"]] description].length<=0) {
            [defaults setObject:[device objectForKey:@"address"]?:@"" forKey:[device objectForKey:@"name"]];
            [defaults synchronize];
        }
    }
}
- (IBAction)macListPopAction:(NSPopUpButton*)sender
{
    [sender setTitle:[sender titleOfSelectedItem]];
    NSInteger i = [sender indexOfSelectedItem];
    NSDictionary *device = [_deviceList objectAtIndex:i];
    _interfaceList = [self interfaceList];
    self.ipAddressTextField.stringValue = [_interfaceList objectForKey:[device objectForKey:@"name"]]?:@"";
    self.oldMacAddress.stringValue = [device objectForKey:@"address"]?:@"";
    self.freshMacAddress.stringValue = @"";
    
}
- (IBAction)resetTouched:(id)sender {
    //system("sudo ifconfig en0 ether 0c-4d-e9-a7-32-e7");
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([[defaults objectForKey:self.macListPopUpButton.title] description].length>0) {
        [STPrivilegedTask launchedPrivilegedTaskWithLaunchPath:@"/sbin/ifconfig" arguments:@[@"en0",@"ether",[defaults objectForKey:self.macListPopUpButton.title]]];
        [self reloadData];
    }
}

- (IBAction)modifyTouched:(id)sender {
    //system("sudo ifconfig en0 ether 10-dd-b1-d2-64-4c");
    //runSystemCommand(@"sudo ifconfig en0 ether 10-dd-b1-d2-64-4c");
//    NSString *newMAC = self.freshMacAddress.stringValue;
//    if ([[newMAC componentsSeparatedByString:@":"] count] == 4)
//     {
//         newMAC = [newMAC stringByReplacingOccurrencesOfString:@":" withString:@"-"];
//    }
    [STPrivilegedTask launchedPrivilegedTaskWithLaunchPath:@"/sbin/ifconfig" arguments:@[@"en0",@"ether",self.freshMacAddress.stringValue]];
    [self reloadData];
}

- (IBAction)randomTouched:(id)sender {
    self.freshMacAddress.stringValue = [self randomMac];
}

void runls()
{
    [[NSTask launchedTaskWithLaunchPath:@"/bin/ls"
                              arguments:[NSArray array]] waitUntilExit];
}

void runSystemCommand(NSString *cmd)
{
    [[NSTask launchedTaskWithLaunchPath:@"/bin/sh"
                              arguments:[NSArray arrayWithObjects:@"-c", cmd, nil]]
     waitUntilExit];
}

//do shell script "sudo chmod 600 /System/Library/CoreServices/Search.bundle/Contents/MacOS/Search" with administrator privileges
//Write the below apple script using Apple Script Editor and save it in a .scpt file.
- (void) runEmbeddedScriptFile: (NSString*)fileName
{
    NSString* path = [[NSBundle mainBundle] pathForResource:fileName ofType:@"scpt"];
    NSURL* url = [NSURL fileURLWithPath:path];
    NSDictionary* errors = [NSDictionary dictionary];
    NSAppleScript* appleScript = [[NSAppleScript alloc] initWithContentsOfURL:url error:&errors];
    [appleScript executeAndReturnError:nil];
}

- (NSArray *)getDeviceList
{
    kern_return_t kr;
    CFMutableDictionaryRef matchDict;
    io_iterator_t iterator;
    io_registry_entry_t entry;
    
    matchDict = IOServiceMatching("IOEthernetInterface");
    kr = IOServiceGetMatchingServices(kIOMasterPortDefault, matchDict, &iterator);
    
    NSMutableArray *devices = [NSMutableArray array];
    NSDictionary *resultInfo = nil;
    
    while ((entry = IOIteratorNext(iterator)) != 0)
    {
        CFMutableDictionaryRef properties=NULL;
        kr = IORegistryEntryCreateCFProperties(entry,
                                               &properties,
                                               kCFAllocatorDefault,
                                               kNilOptions);
        if (properties)
        {
            resultInfo = (__bridge_transfer NSDictionary *)properties;
            NSString *bsdName = [resultInfo objectForKey:@"BSD Name"];
            NSData *macData = [resultInfo objectForKey:@"IOMACAddress"];
            if (!macData)
            {
                continue;
            }
            
            NSMutableString *macAddress = [[NSMutableString alloc] init];
            const UInt8 *bytes = [macData bytes];
            for (int i=0; i<macData.length; i++)
            {
                if (i < macData.length-1) {
                    [macAddress appendFormat:@"%02x-",*(bytes+i)];
                }else{
                    [macAddress appendFormat:@"%02x",*(bytes+i)];
                }
            }
            
            //打印Mac地址
            if (bsdName && macAddress)
            {
                NSLog(@"网卡:%@\nMac地址:%@\n",bsdName,macAddress);
            }
            [devices addObject:@{@"name":bsdName,@"address":macAddress}];
        }
    }
    
    
    IOObjectRelease(iterator);
    return devices;
}
- (NSMutableDictionary *)interfaceList
{
    NSMutableDictionary *dictOfAllInterfaces = [NSMutableDictionary dictionary];
    
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if( temp_addr->ifa_addr->sa_family == AF_INET) {
                NSString* name = [NSString stringWithUTF8String:temp_addr->ifa_name];
                NSString* address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                
                // NSLog(@"if: %@ %@", name, address);
                [dictOfAllInterfaces setObject:address forKey:name];
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    // return arrayOfAllInterfaces;
    return dictOfAllInterfaces;
}


- (NSString *)MacAddressWithInterface:(NSString *)interface
{
    int mib[6];
    size_t len;
    char *buf;
    unsigned char *mac;
    struct if_msghdr *ifm;
    struct sockaddr_dl *sdl;
    
    mib[0] = CTL_NET;
    mib[1] = AF_ROUTE;
    mib[2] = 0;
    mib[3] = AF_LINK;
    mib[4] = NET_RT_IFLIST;
    if (!(mib[5] = if_nametoindex(interface.UTF8String)))
        return nil;
    if (0 > sysctl(mib, 6, NULL, &len, NULL, 0))
        return nil;
    buf = malloc(len);
    if (0 > sysctl(mib, 6, buf, &len, NULL, 0))
    {
        free(buf);
        return nil;
    }
    ifm = (struct if_msghdr *)buf;
    sdl = (struct sockaddr_dl *)(ifm + 1);
    mac = (unsigned char *)LLADDR(sdl);
    NSString *ret = [NSString.alloc initWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]];
    
    free(buf);
    return ret;
}

-(NSString*)randomMac{
    NSMutableString *mac =  [NSMutableString string];
    for(int i=1; i<=6; i++) {
        NSString *one = [self getStringRandom:1];
        NSString *two = [self getStringRandom:1];
        [mac appendString:one];
        [mac appendString:two];
        if(i != 6) {[mac appendString:@"-"];}
    }
    return [mac lowercaseString];
}
-(NSString*)getStringRandom:(int)length {
    char chars[] = "1234567890abcdef";
    char codes[length];
    
    for(int i=0;i<length; i++){
        codes[i]= chars[arc4random()%16];
    }
    NSString *text = [[NSString alloc] initWithBytes:codes
                                              length:length encoding:NSUTF8StringEncoding];
    return text;
}
@end
