/**
 * downloadmanager-ios
 *
 * Module developed by Napp ApS
 * www.napp.dk
 * Mads Møller
 *
 * Updated and modified by Kosso
 *
 * Appcelerator Titanium is Copyright (c) 2009-2010 by Appcelerator, Inc.
 * and licensed under the Apache Public License (version 2)
 */

#import "DkNappDownloadmanagerModule.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiUtils.h"

@interface DkNappDownloadmanagerModule()
{
    Downloader* downloader;
}

-(NSMutableDictionary*)createDict:(DownloadInformation*)di;

@end

@implementation DkNappDownloadmanagerModule

#pragma mark Internal

// this is generated for your module, please do not change it
-(id)moduleGUID
{
	return @"d88ca63f-337b-4fb5-8721-93e73407e99d";
}

// this is generated for your module, please do not change it
-(NSString*)moduleId
{
	return @"dk.napp.downloadmanager";
}

#pragma mark Lifecycle

-(void)startup
{
    // [self cleanUpQueues];
    // NSLog(@"[INFO] NUKED EVERYTHING!");
    // Now called using cleanUp() when desired.
    
    downloader = [[Downloader alloc] init];
    [downloader setDelegate:self];
    [downloader setMaximumSimultaneousDownloads:4];

    [super startup];

	NSLog(@"[INFO] %@ loaded",self);
}

-(void)shutdown:(id)sender
{
	
    [downloader stop];
    
    [super shutdown:sender];
}

#pragma mark Cleanup

-(void)dealloc
{
    RELEASE_TO_NIL(downloader);
    
    [super dealloc];
}

#pragma mark Internal Memory Management

-(void)didReceiveMemoryWarning:(NSNotification*)notification
{
	// optionally release any resources that can be dynamically
	// reloaded once memory is available - such as caches
	[super didReceiveMemoryWarning:notification];
}

#pragma mark Listener Notifications

-(void)_listenerAdded:(NSString *)type count:(int)count
{
	if (count == 1 && [type isEqualToString:@"my_event"])
	{
		// the first (of potentially many) listener is being added
		// for event named 'my_event'
	}
}

-(void)_listenerRemoved:(NSString *)type count:(int)count
{
	if (count == 0 && [type isEqualToString:@"my_event"])
	{
		// the last listener called for event named 'my_event' has
		// been removed, we can optionally clean up any resources
		// since no body is listening at this point for that event
	}
}

#pragma Public APIs

MAKE_SYSTEM_PROP(NETWORK_TYPE_WIFI, 0)
MAKE_SYSTEM_PROP(NETWORK_TYPE_MOBILE, 1)
MAKE_SYSTEM_PROP(NETWORK_TYPE_ANY, 2)
MAKE_SYSTEM_PROP_DBL(DOWNLOAD_PRIORITY_LOW, 0.1)
MAKE_SYSTEM_PROP_DBL(DOWNLOAD_PRIORITY_NORMAL, 0.2)
MAKE_SYSTEM_PROP_DBL(DOWNLOAD_PRIORITY_HIGH, 0.3)

-(void)cleanUpQueues
{
    NSLog(@"[INFO] cleanUpQueues .... ");
    
    // Called in the startup method (above) before initialising the downloader.
    // Can also be called in JS with  module_name.cleanUp();
    
    // We want to clean up any partially dowloaded files which might be referenced from the
    // DownloadQueue.dat file. When developing an app, the stored UID will always change.
    // I believe this may be causing the segmentation faults and crashes which can occur when trying to clean up after a crash during a download.
    
    // So, we're going to look up the files in the queue [DownloadQueue.dat] at app launch and loop through the stored requests looking for the DownloadStatusInProgress [1] status.
    
    // Since the application UID may have changed we'll need to rebuild the path when trying to delete the old file.
    // We're just going to support the Documents folder for now, since the tempDirectory, cacheDataDirectory and applicationSupportDirectory are writable too.
    // Splitting the filePath by a UUID regex might be an idea. Bearing in mind the tempDirectory has a different root path than the others. eg:
    // All others     : /var/mobile/Containers/Data/Application/:UUID...
    // Temp Directory : /private/var/mobile/Containers/Data/Application/:UUID...
    
    // UUID regex:
    // NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" options:NSRegularExpressionCaseInsensitive error:nil];
    
    
    // After all this, we delete the old DownloadQueue.dat and DownloadItemCatalog.dat files then initialise the downloader as normal.
    // Here goes ...
    
    
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentsDirectory = [paths objectAtIndex:0];
    
    NSString* filePath = [documentsDirectory stringByAppendingPathComponent:@"/DownloadQueue.dat"];
    NSString* filePathCat = [documentsDirectory stringByAppendingPathComponent:@"/DownloadItemCatalog.dat"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath] == YES)
    {
        NSLog(@"[INFO] loading existing DownloadQueue.dat ");
        NSData *fileData = [[NSData alloc] initWithContentsOfFile:filePath];
        NSKeyedUnarchiver *decoder = [[NSKeyedUnarchiver alloc] initForReadingWithData:fileData];
        NSMutableArray *downloadInformation = [decoder decodeObjectForKey:@"downloadInformation"];
        NSLog(@"[INFO] downloadQueue length is %d", downloadInformation.count);
        for (DownloadRequest* request in downloadInformation) {
            // NSLog(@"[INFO] REQUEST STATUS  %d : URL: %@", request.status, request.url); // See DownloadStatus.h
            if(request.status == 1 || request.status == 0 || request.status == 2){ // request was in progress/paused. Or possibly set up but not registered in the queue data. Some zero byte files can be left behind in this case.
                // NSLog(@"[INFO] STORED filePath with download status: %d : %@", request.status, request.filePath);
                // Fix the location for a potentially new build.
                NSArray *storedAppRootPath = [request.filePath componentsSeparatedByString: @"/Documents"];
                NSString *storedFilePath = storedAppRootPath[1];
                NSString *actualPath = [documentsDirectory stringByAppendingString:storedFilePath];
                storedAppRootPath = nil;
                storedFilePath = nil;
                if([[NSFileManager defaultManager] fileExistsAtPath:actualPath] == YES){
                    NSLog(@"[INFO] DELETE file at:  %@", actualPath);
                    NSError *err = nil;
                    [[NSFileManager defaultManager] removeItemAtPath:actualPath error:&err];
                    if(err != nil){
                        NSLog(@"[INFO] Unable to delete old file.\n"
                              "Error: %@ %d %@", [err domain], [err code], [[err userInfo] description]);
                    }
                }
            }
            // remove it
            [downloader.downloadQueue remove:request.url];
            [downloader.downloadQueue.downloadRequests removeObject:request];
            
        }
        [decoder release];
        [fileData release];
        downloadInformation = nil;
        
        [downloader.downloadQueue persistToStorage];
        
        // Delete itself
        NSError *errc = nil;
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:&errc];
        if(errc!=nil){
            NSLog(@"Unable to delete DownloadQueue.dat file.\n"
                  "Error: %@ %d %@", [errc domain], [errc code], [[errc userInfo] description]);
        } else {
            NSLog(@"[INFO] DELETED OLD DownloadQueue.dat ");
        }
    }
    
    if([[NSFileManager defaultManager] fileExistsAtPath:filePathCat] == YES){
        NSLog(@"[INFO] loading existing DownloadItemCatalog.dat ");
        // Delete the catalog
        NSError *errcc = nil;
        [[NSFileManager defaultManager] removeItemAtPath:filePathCat error:&errcc];
        if(errcc!=nil){
            NSLog(@"Unable to delete DownloadItemCatalog.dat file.\n"
                  "Error: %@ %d %@", [errcc domain], [errcc code], [[errcc userInfo] description]);
        } else {
            NSLog(@"[INFO] DELETED OLD DownloadItemCatalog.dat ");
        }
    }
    // All done. Re-init empty data.
    // Might not even need to do this. or delete the data files now the queue should be empty. But hey.
    [downloader.downloadQueue loadFromStorage]; // should set downloadRequests to empty
    
}

-(void)cleanUp:(id)args
{
    [self cleanUpQueues];
}

-(void)setMaximumSimultaneousDownloads:(id)value
{
    NSLog(@"[INFO] Set Maximum Simultaneous Downloads to %@", value);
    [self replaceValue:value forKey:@"maximumSimulataneousDownloads" notification:NO];
    [downloader setMaximumSimultaneousDownloads:[TiUtils intValue:value]];
}

-(id)maximumSimultaneousDownloads
{
    return [self valueForUndefinedKey:@"maximumSimulataneousDownloads"];;
}

-(void)setPermittedNetworkTypes:(id)value
{
    NSLog(@"[INFO] Set Permitted Network Types to %@", value);
    // NSInteger* number = NUMINT(value);
    
    [self replaceValue:value forKey:@"permittedNetworkTypes" notification:NO];
    if ([TiUtils intValue:value] == 0)
    {
        [downloader setPermittedNetworkTypes:NetworkTypeWireless80211];
    }
    else if ([TiUtils intValue:value] == 1)
    {
        [downloader setPermittedNetworkTypes:NetworkTypeMobile];
    }
    else if ([TiUtils intValue:value] == 2)
    {
        [downloader setPermittedNetworkTypes:NetworkTypeNetworkTypeAny];
    }
}

-(id)permittedNetworkTypes
{
    return [self valueForUndefinedKey:@"permittedNetworkTypes"];;
}

-(void)addDownload:(id)args
{
    ENSURE_SINGLE_ARG(args,NSDictionary);
    DownloadRequest* request = [[DownloadRequest alloc] init];
    [request setUrl:[args objectForKey:@"url"]];
    [request setName:[args objectForKey:@"name"]];
    [request setHeaders:[args objectForKey:@"headers"]];
    [request setLocale:@"eng"];
    
    NSURL* fileurl = [TiUtils toURL:[args objectForKey:@"filePath"] proxy:nil];
    [request setFilePath:[fileurl path]];
    
    [downloader downloadItem:request];
}

-(void)stopDownloader:(id)args
{
    [downloader stop];
}

-(void)restartDownloader:(id)args
{
    [downloader start];
}

-(void)pauseAll:(id)args
{
    [downloader pauseAll];
}
-(void)pauseItem:(id)args
{
    ENSURE_SINGLE_ARG(args,NSString);
    [downloader pauseItem:args];
}
-(void)resumeAll:(id)args
{
    [downloader resumeAll];
}
-(void)resumeItem:(id)args
{
    ENSURE_SINGLE_ARG(args,NSString);
    [downloader resumeItem:args];
}
-(void)cancelItem:(id)args
{
    ENSURE_SINGLE_ARG(args,NSString);
    [downloader cancelItem:args];
}
-(void)deleteItem:(id)args
{
    ENSURE_SINGLE_ARG(args,NSString);
    [downloader deleteItem:args];
}
-(id)getDownloadInfo:(id)args
{
    ENSURE_SINGLE_ARG(args,NSString);
    
    DownloadInformation* di = [downloader downloadInformationSingle:args];
    if (di == nil)
    {
        return nil;
    }
    
    return [self createDict:di];
}

-(id)getAllDownloadInfo:(id)args
{
    NSMutableArray* returnInfo = [[[NSMutableArray alloc]init]autorelease];
    NSArray* info = [downloader downloadInformationAll];
    for (DownloadInformation* di in info)
    {
        [returnInfo addObject: [self createDict:di]];
    }
    
    return returnInfo;
}

-(id)getAllFilePaths:(id)args
{
    NSMutableArray* returnInfo = [[[NSMutableArray alloc]init]autorelease];
    
    
    
}

-(void)itemPaused:(DownloadInformation*)downloadInformation
{
    if ([self _hasListeners:@"paused"])
    {
        [downloadInformation retain];
        ENSURE_UI_THREAD_1_ARG(downloadInformation);
        [self fireEvent:@"paused" withObject:[self createDict:downloadInformation]];
        [downloadInformation release];
    }
}


-(void)failed:(DownloadInformation*)downloadInformation
{
    
    if ([self _hasListeners:@"failed"])
    {
        NSLog(@"[INFO] >>>>>>> FAILED! ");
        
        [downloadInformation retain];
        ENSURE_UI_THREAD_1_ARG(downloadInformation);
        [self fireEvent:@"failed" withObject:[self createDict:downloadInformation]];
        [downloadInformation release];
    }
}
-(void)progress:(DownloadInformation*)downloadInformation
{
    if ([self _hasListeners:@"progress"])
    {
        [downloadInformation retain];
        ENSURE_UI_THREAD_1_ARG(downloadInformation);
        // NSLog(@"[INFO] >>>>>>> PROGRESS! ");
        [self fireEvent:@"progress" withObject:[self createDict:downloadInformation]];
        [downloadInformation release];
    }
    
    // calc the overall progress
    if ([self _hasListeners:@"overallprogress"])
    {
        int downloadedBytes = 0;
        int totalBytes = 0;
        int totalBps = 0;
        int averageBps = 0;
        int procentage = 0;
        
        // get all items from the queue
        NSArray* items = [downloader downloadInformationAll];
        for (DownloadInformation* item in items)
        {
            downloadedBytes += [[NSNumber numberWithUnsignedInteger:[item availableLength]] intValue];
            totalBytes += [[NSNumber numberWithUnsignedInteger:[item length]] intValue];
            totalBps += [[NSNumber numberWithUnsignedInteger:[item lastDownloadBitsPerSecond]] intValue];
        }
        
        // we only want to send the event - if downloads are in progress
        if([items count] > 0){
            
            // calc average and progress procentage
            averageBps = [[items valueForKeyPath:@"@avg.lastDownloadBitsPerSecond"] intValue];
            procentage = downloadedBytes * 100 / totalBytes;
            
            NSMutableDictionary* dict = [[[NSMutableDictionary alloc] init] autorelease];
            [dict setValue:NUMINT(downloadedBytes)  forKey:@"downloadedBytes"];
            [dict setValue:NUMINT(totalBytes)  forKey:@"totalBytes"];
            [dict setValue:NUMINT(procentage)  forKey:@"procentage"];
            [dict setValue:NUMINT(averageBps)  forKey:@"averageBps"];
            [dict setValue:NUMINT(totalBps)  forKey:@"bps"];
            
            [self fireEvent:@"overallprogress" withObject:dict];
        }
    }
}
-(void)completed:(DownloadInformation*)downloadInformation
{
    if ([self _hasListeners:@"completed"])
    {
        // NSLog(@"[INFO] >>>>>>> COMPLETED! ");
        
        
        [downloadInformation retain];
        ENSURE_UI_THREAD_1_ARG(downloadInformation);
        [self fireEvent:@"completed" withObject:[self createDict:downloadInformation]];
        [downloadInformation release];
    }
}
-(void)cancelled:(DownloadInformation*)downloadInformation
{
    if ([self _hasListeners:@"cancelled"])
    {
        // NSLog(@"[INFO] >>>>>>> CANCELLED! ");
        
        [downloadInformation retain];
        ENSURE_UI_THREAD_1_ARG(downloadInformation);
        [self fireEvent:@"cancelled" withObject:[self createDict:downloadInformation]];
        [downloadInformation release];
    }
}
-(void)started:(DownloadInformation *)downloadInformation
{
    
    if ([self _hasListeners:@"started"])
    {
        // NSLog(@"[INFO] >>>>>>> STARTED! ");
        
        [downloadInformation retain];
        ENSURE_UI_THREAD_1_ARG(downloadInformation);
        NSMutableDictionary* dict = [self createDict:downloadInformation];
        [dict setValue:downloadInformation.message forKey:@"reason"];
        [self fireEvent:@"started" withObject:dict];
        [downloadInformation release];
    }
}



-(NSMutableDictionary*)createDict:(DownloadInformation*)di
{
    NSMutableDictionary* dict = [[[NSMutableDictionary alloc] init] autorelease];
    [dict setValue:[di name]  forKey:@"name"];
    [dict setValue:[di url]  forKey:@"url"];
    [dict setValue:NUMINT([di availableLength])  forKey:@"downloadedBytes"];
    [dict setValue:NUMINT([di length])  forKey:@"totalBytes"];
    [dict setValue:NUMINT([di lastDownloadBitsPerSecond])  forKey:@"bps"];
    [dict setValue:[di filePath]  forKey:@"filePath"];
    [dict setValue:[di creationUtc] forKey:@"createdDate"];
    [dict setValue:NUMDOUBLE([di downloadPriority]) forKey:@"priority"];
    
    return dict;
}


@end
