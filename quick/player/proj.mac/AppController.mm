//
//  AppDelegate.m
//  quick-x-player
//

#import "AppController.h"

#import "CreateNewProjectDialogController.h"
#import "ProjectConfigDialogController.h"
#import "PlayerPreferencesDialogController.h"
#import "ConsoleWindowController.h"

#include "AppDelegate.h"
#include "AppControllerBridge.h"
#include "glfw3.h"
#include "glfw3native.h"

#include "cocos2d.h"
#include "native/CCNative.h"
#include "CCLuaEngine.h"
USING_NS_CC;
USING_NS_CC_EXTRA;

// player interface
#include "player_tolua.h"
#include "PlayerProtocol.h"

@implementation AppController

- (void) dealloc
{
    if (buildTask)
    {
        [buildTask interrupt];
        buildTask = nil;
    }
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    waitForRestart = NO;
    isAlwaysOnTop = NO;
    isMaximized = NO;
    hasPopupDialog = NO;
    debugLogFile = 0;

    buildTask = nil;
    isBuildingFinished = YES;
    
    // load QUICK_COCOS2DX_ROOT from ~/.QUICK_COCOS2DX_ROOT
    NSMutableString *path = [NSMutableString stringWithString:NSHomeDirectory()];
    [path appendString:@"/.QUICK_V3_ROOT"];
    NSError *error = nil;
    NSString *env = [NSString stringWithContentsOfFile:path
                                              encoding:NSUTF8StringEncoding
                                                 error:&error];
    if (error || env.length == 0)
    {
        [self showAlertWithoutSheet:@"Please run \"setup.app\", set quick-cocos2d-x root path." withTitle:@"quick player error"];
        [[NSApplication sharedApplication] terminate:self];
    }
    
    env = [env stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    env = [NSString stringWithFormat:@"%@/quick", env];
    SimulatorConfig::sharedDefaults()->setQuickCocos2dxRootPath([env cStringUsingEncoding:NSUTF8StringEncoding]);
    
    
    [self loadLuaConfig];
    [self updateProjectConfigFromCommandLineArgs:&projectConfig];
    [self createWindowAndGLView];
    [self initUI];
    [self updateOpenRect];
    [self updateUI];
    [self loadLuaPlayerCore];
    [self startup];
}

- (BOOL) windowShouldClose:(id)sender
{
    return YES;
}

- (void) windowWillClose:(NSNotification *)notification
{
    [[NSRunningApplication currentApplication] terminate];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)theApplication
{
    return YES;
}

- (void) updateOpenRect
{
    NSMutableArray *recents = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"recents"]];
    
    NSString *welcomeTitle = [NSString stringWithFormat:@"%splayer/welcome/", SimulatorConfig::sharedDefaults()->getQuickCocos2dxRootPath().c_str()];
    
    for (NSInteger i = [recents count] - 1; i >= 0; --i)
    {
        id recentItem = [recents objectAtIndex:i];
        if (![[recentItem class] isSubclassOfClass:[NSDictionary class]])
        {
            [recents removeObjectAtIndex:i];
            continue;
        }
        
        NSString *title = [recentItem objectForKey:@"title"];
        if (!title || [title length] == 0 || [welcomeTitle compare:title] == NSOrderedSame /*|| !CCFileUtils::sharedFileUtils()->isDirectoryExist([title cStringUsingEncoding:NSUTF8StringEncoding])*/)
        {
            [recents removeObjectAtIndex:i];
        }
    }
    
    NSString *title = [NSString stringWithCString:projectConfig.getProjectDir().c_str() encoding:NSUTF8StringEncoding];
    if ([title length] > 0 && [welcomeTitle compare:title] != NSOrderedSame)
    {
        for (NSInteger i = [recents count] - 1; i >= 0; --i)
        {
            id recentItem = [recents objectAtIndex:i];
            if ([title compare:[recentItem objectForKey:@"title"]] == NSOrderedSame)
            {
                [recents removeObjectAtIndex:i];
            }
        }
        
        NSMutableArray *args = [self makeCommandLineArgsFromProjectConfig:kProjectConfigOpenRecent];
        NSDictionary *item = [NSDictionary dictionaryWithObjectsAndKeys:title, @"title", args, @"args", nil];
        [recents insertObject:item atIndex:0];
    }
    [[NSUserDefaults standardUserDefaults] setObject:recents forKey:@"recents"];
}

- (void) initUI
{
    NSMenu *submenu = [[[window menu] itemWithTitle:@"Screen"] submenu];
    
    SimulatorConfig *config = SimulatorConfig::sharedDefaults();
    int current = config->checkScreenSize(projectConfig.getFrameSize());
    for (int i = config->getScreenSizeCount() - 1; i >= 0; --i)
    {
        SimulatorScreenSize size = config->getScreenSize(i);
        NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:[NSString stringWithCString:size.title.c_str() encoding:NSUTF8StringEncoding]
                                                       action:@selector(onScreenChangeFrameSize:)
                                                keyEquivalent:@""] autorelease];
        [item setTag:i];
        
        if (i == current)
        {
            [item setState:NSOnState];
        }
        [submenu insertItem:item atIndex:0];
    }
    
    NSArray *recents = [[NSUserDefaults standardUserDefaults] arrayForKey:@"recents"];
    submenu = [[[[[window menu] itemWithTitle:@"File"] submenu] itemWithTitle:@"Open Recent"] submenu];
    for (NSInteger i = [recents count] - 1; i >= 0; --i)
    {
        NSDictionary *recentItem = [recents objectAtIndex:i];
        NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:[recentItem objectForKey:@"title"]
                                                       action:@selector(onFileOpenRecent:)
                                                keyEquivalent:@""] autorelease];
        [submenu insertItem:item atIndex:0];
    }
}

- (void) updateUI
{
    NSMenu *menuPlayer = [[[window menu] itemWithTitle:@"Player"] submenu];
    NSMenuItem *itemWriteDebugLogToFile = [menuPlayer itemWithTitle:@"Write Debug Log to File"];
    [itemWriteDebugLogToFile setState:projectConfig.isWriteDebugLogToFile() ? NSOnState : NSOffState];
    
    NSMenu *menuScreen = [[[window menu] itemWithTitle:@"Screen"] submenu];
    NSMenuItem *itemPortait = [menuScreen itemWithTitle:@"Portait"];
    NSMenuItem *itemLandscape = [menuScreen itemWithTitle:@"Landscape"];
    if (projectConfig.isLandscapeFrame())
    {
        [itemPortait setState:NSOffState];
        [itemLandscape setState:NSOnState];
    }
    else
    {
        [itemPortait setState:NSOnState];
        [itemLandscape setState:NSOffState];
    }
    
    int scale = projectConfig.getFrameScale() * 100;
    
    NSMenuItem *itemZoom100 = [menuScreen itemWithTitle:@"Actual (100%)"];
    NSMenuItem *itemZoom75 = [menuScreen itemWithTitle:@"Zoom Out (75%)"];
    NSMenuItem *itemZoom50 = [menuScreen itemWithTitle:@"Zoom Out (50%)"];
    NSMenuItem *itemZoom25 = [menuScreen itemWithTitle:@"Zoom Out (25%)"];
    [itemZoom100 setState:NSOffState];
    [itemZoom75 setState:NSOffState];
    [itemZoom50 setState:NSOffState];
    [itemZoom25 setState:NSOffState];
    if (scale == 100)
    {
        [itemZoom100 setState:NSOnState];
    }
    else if (scale == 75)
    {
        [itemZoom75 setState:NSOnState];
    }
    else if (scale == 50)
    {
        [itemZoom50 setState:NSOnState];
    }
    else if (scale == 25)
    {
        [itemZoom25 setState:NSOnState];
    }
    
    NSArray *recents = [[NSUserDefaults standardUserDefaults] arrayForKey:@"recents"];
    NSMenu *menuRecents = [[[[[window menu] itemWithTitle:@"File"] submenu] itemWithTitle:@"Open Recent"] submenu];
    while (true)
    {
        NSMenuItem *item = [menuRecents itemAtIndex:0];
        if ([item isSeparatorItem]) break;
        [menuRecents removeItemAtIndex:0];
    }
    
    for (NSInteger i = [recents count] - 1; i >= 0; --i)
    {
        NSDictionary *recentItem = [recents objectAtIndex:i];
        NSMenuItem *item = [[[NSMenuItem alloc] initWithTitle:[recentItem objectForKey:@"title"]
                                                       action:@selector(onFileOpenRecent:)
                                                keyEquivalent:@""] autorelease];
        [menuRecents insertItem:item atIndex:0];
    }
    
    [window setTitle:[NSString stringWithFormat:@"quick-x-player (%0.0f%%)", projectConfig.getFrameScale() * 100]];
}


- (void) showModelSheet
{
    hasPopupDialog = YES;
    if (app)
    {
        Director::getInstance()->pause();
        CocosDenshion::SimpleAudioEngine::getInstance()->pauseBackgroundMusic();
        CocosDenshion::SimpleAudioEngine::getInstance()->pauseAllEffects();
    }
}

- (void) stopModelSheet
{
    hasPopupDialog = NO;
    if (app)
    {
        Director::getInstance()->resume();
        CocosDenshion::SimpleAudioEngine::getInstance()->resumeBackgroundMusic();
        CocosDenshion::SimpleAudioEngine::getInstance()->resumeAllEffects();
    }
}

- (NSMutableArray*) makeCommandLineArgsFromProjectConfig
{
    return [self makeCommandLineArgsFromProjectConfig:kProjectConfigAll];
}

- (NSMutableArray*) makeCommandLineArgsFromProjectConfig:(unsigned int)mask
{
    projectConfig.setWindowOffset(Vec2(window.frame.origin.x, window.frame.origin.y));
    NSString *commandLine = [NSString stringWithCString:projectConfig.makeCommandLine(mask).c_str() encoding:NSUTF8StringEncoding];
    return [NSMutableArray arrayWithArray:[commandLine componentsSeparatedByString:@" "]];
}

- (void) updateProjectConfigFromCommandLineArgs:(ProjectConfig *)config
{
    NSArray *nsargs = [[NSProcessInfo processInfo] arguments];
    vector<string> args;
    for (int i = 0; i < [nsargs count]; ++i)
    {
        args.push_back([[nsargs objectAtIndex:i] cStringUsingEncoding:NSUTF8StringEncoding]);
    }
    config->parseCommandLine(args);
    
    if (config->getProjectDir().length() == 0)
    {
        config->resetToWelcome();
    }
}

- (void) launch:(NSArray*)args
{
    NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    NSMutableDictionary *configuration = [NSMutableDictionary dictionaryWithObject:args forKey:NSWorkspaceLaunchConfigurationArguments];
    NSError *error = [[[NSError alloc] init] autorelease];
    [[NSWorkspace sharedWorkspace] launchApplicationAtURL:url
                                                  options:NSWorkspaceLaunchNewInstance
                                            configuration:configuration error:&error];
}

- (void) relaunch:(NSArray*)args
{
    [self launch:args];
    [[NSApplication sharedApplication] terminate:self];
}

- (void) relaunch
{
    [self relaunch:[self makeCommandLineArgsFromProjectConfig]];
}

- (void) showAlertWithoutSheet:(NSString*)message withTitle:(NSString*)title
{
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:message];
	[alert setInformativeText:title];
	[alert setAlertStyle:NSWarningAlertStyle];
    [alert runModal];
}

- (void) showAlert:(NSString*)message withTitle:(NSString*)title
{
    
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
	[alert addButtonWithTitle:@"OK"];
	[alert setMessageText:message];
	[alert setInformativeText:title];
	[alert setAlertStyle:NSWarningAlertStyle];
    
	[alert beginSheetModalForWindow:window
					  modalDelegate:self
					 didEndSelector:nil
						contextInfo:nil];
}

- (void) loadLuaConfig
{
    LuaEngine* pEngine = LuaEngine::getInstance();
    ScriptEngineManager::getInstance()->setScriptEngine(pEngine);
    
    tolua_player_luabinding_open(pEngine->getLuaStack()->getLuaState());
    
    NSMutableString *path = [NSMutableString stringWithString:NSHomeDirectory()];
    [path appendString:@"/"];
    
    // set user home dir
    lua_pushstring(pEngine->getLuaStack()->getLuaState(), path.UTF8String);
    lua_setglobal(pEngine->getLuaStack()->getLuaState(), "__USER_HOME__");
    
    [path appendString:@".quick_player.lua"];
    

    NSString *luaCorePath = [[NSBundle mainBundle] pathForResource:@"player" ofType:@"lua"];
    pEngine->getLuaStack()->executeScriptFile(luaCorePath.UTF8String);
    
    player::PlayerSettings &settings = player::PlayerProtocol::getInstance()->getPlayerSettings();

    projectConfig.setWindowOffset(Vec2(settings.offsetX, settings.offsetY));
    projectConfig.setFrameSize(cocos2d::Size(settings.windowWidth, settings.windowHeight));
}

#pragma mark -
#pragma mark functions

- (void) createWindowAndGLView
{
    eglView = GLView::createWithRect("quick-x-player", cocos2d::Rect(0,0,projectConfig.getFrameSize().width, projectConfig.getFrameSize().height), projectConfig.getFrameScale());
    Director::getInstance()->setOpenGLView(eglView);
    
    window = glfwGetCocoaWindow(eglView->getWindow());
//    window.delegate = self;
    [NSApp setDelegate: self];
    
    // set window parameters
    [window center];
    
    if (projectConfig.getProjectDir().length())
    {
        [self setZoom:projectConfig.getFrameScale()];
        Vec2 pos = projectConfig.getWindowOffset();
        if (pos.x != 0 && pos.y != 0)
        {
            [window setFrameOrigin:NSMakePoint(pos.x, pos.y)];
        }
    }
    
//    [window becomeFirstResponder];
//    [window makeKeyAndOrderFront:self];
//    [window setAcceptsMouseMovedEvents:NO];
}

- (void) loadLuaPlayerCore
{
    LuaEngine* pEngine = LuaEngine::getInstance();
    
    // set quick-cocos2d-x root path
    std::string quickPath = SimulatorConfig::sharedDefaults()->getQuickCocos2dxRootPath();
    lua_pushstring(pEngine->getLuaStack()->getLuaState(), quickPath.c_str());
    lua_setglobal(pEngine->getLuaStack()->getLuaState(), "__G__QUICK_PATH__");
    
    std::string command = projectConfig.makeCommandLine();
    std::vector <std::string> fields;
    player::split(fields, command, ' ');
    
    LuaValueArray array;
    for (size_t i = 0; i < fields.size(); i++)
    {
        array.push_back(LuaValue::stringValue(fields.at(i)));
    }
    pEngine->getLuaStack()->pushFunctionByName("__PLAYER_OPEN__");
    pEngine->getLuaStack()->pushLuaValue(LuaValue::stringValue(projectConfig.getProjectDir()));
    pEngine->getLuaStack()->pushLuaValueArray(array);
    pEngine->getLuaStack()->executeFunction(2);

}

- (void) startup
{
    std::string path = SimulatorConfig::sharedDefaults()->getQuickCocos2dxRootPath();
    if (path.length() <= 0)
    {
        [self showPreferences:YES];
    }
    
    const string projectDir = projectConfig.getProjectDir();
    if (projectDir.length())
    {
        FileUtils::getInstance()->setSearchRootPath(projectDir.c_str());
        if (projectConfig.isWriteDebugLogToFile())
        {
            [self writeDebugLogToFile:projectConfig.getDebugLogFilePath()];
        }
    }
    
    const string writablePath = projectConfig.getWritableRealPath();
    if (writablePath.length())
    {
        FileUtils::getInstance()->setWritablePath(writablePath.c_str());
    }
    
    if (projectConfig.isShowConsole())
    {
        [self openConsoleWindow];
    }
    
    app = new AppDelegate();
    bridge = new AppControllerBridge(self);
    
    
    EventListenerCustom *_listener = EventListenerCustom::create("WELCOME_OPEN_PROJECT_ARGS", [=](EventCustom* event){
        if (event->getDataString().length() > 0)
        {
            std::vector<std::string> args;
            player::split(args, event->getDataString(), ',');
            
            if (args.at(args.size()-1) == "-new")
            {
                ProjectConfig config;
                config.parseCommandLine(args);
                [self newPlayerWithArgs:config];
            }
            else
            {
                projectConfig.parseCommandLine(args);
                [self relaunch];
            }
        }
    });
    Director::getInstance()->getEventDispatcher()->addEventListenerWithFixedPriority(_listener, 1);
    
    EventListenerCustom *_listener2 = EventListenerCustom::create("WELCOME_OPEN_RECENT", [=](EventCustom* event){
        if (event->getDataString().length() > 0)
        {
            int index = atoi(event->getDataString().data());
            
            NSMutableArray *recents = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"recents"]];
            if (index < recents.count)
            {
                NSDictionary *recentItem = [recents objectAtIndex:index];
                [self relaunch: [recentItem objectForKey:@"args"]];
            }
        }
    });
    Director::getInstance()->getEventDispatcher()->addEventListenerWithFixedPriority(_listener2, 1);
    
    NotificationCenter::getInstance()->addObserver(bridge, callfuncO_selector(AppControllerBridge::onWelcomeNewProject), "WELCOME_NEW_PROJECT", NULL);
    NotificationCenter::getInstance()->addObserver(bridge, callfuncO_selector(AppControllerBridge::onWelcomeOpen), "WELCOME_OPEN_PROJECT", NULL);
    NotificationCenter::getInstance()->addObserver(bridge, callfuncO_selector(AppControllerBridge::onWelcomeSamples), "WELCOME_LIST_SAMPLES", NULL);
    NotificationCenter::getInstance()->addObserver(bridge, callfuncO_selector(AppControllerBridge::onWelcomeGetStarted), "WELCOME_OPEN_DOCUMENTS", NULL);
    NotificationCenter::getInstance()->addObserver(bridge, callfuncO_selector(AppControllerBridge::onWelcomeGetCommunity), "WELCOME_OPEN_COMMUNITY", NULL);
//    NotificationCenter::getInstance()->addObserver(bridge, callfuncO_selector(AppControllerBridge::onWelcomeOpenRecent), "WELCOME_OPEN_PROJECT_ARGS", NULL);
    
    
    
    // send recent to Lua
    LuaValueArray titleArray;
    NSArray *recents = [[NSUserDefaults standardUserDefaults] arrayForKey:@"recents"];
    for (NSInteger i = 0; i < [recents count]; i++)
    {
        NSDictionary *recentItem = [recents objectAtIndex:i];
        titleArray.push_back(LuaValue::stringValue([[recentItem objectForKey:@"title"] UTF8String]));
    }
    app->setOpenRecents(titleArray);
    
    app->setProjectConfig(projectConfig);
    app->run();
//    Application::getInstance()->run();
    
    // After run, application needs to be terminated immediately.
    [NSApp terminate: self];
}

- (void) openConsoleWindow
{
    if (!consoleController)
    {
        consoleController = [[ConsoleWindowController alloc] initWithWindowNibName:@"ConsoleWindow"];
    }
    [consoleController.window orderFrontRegardless];
    
    //set console pipe
    pipe = [NSPipe pipe] ;
    pipeReadHandle = [pipe fileHandleForReading] ;
    
    int outfd = [[pipe fileHandleForWriting] fileDescriptor];
    if (dup2(outfd, fileno(stderr)) != fileno(stderr) || dup2(outfd, fileno(stdout)) != fileno(stdout))
    {
        perror("Unable to redirect output");
//        [self showAlert:@"Unable to redirect output to console!" withTitle:@"quick-x-player error"];
    }
    else
    {
        [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(handleNotification:) name: NSFileHandleReadCompletionNotification object: pipeReadHandle] ;
        [pipeReadHandle readInBackgroundAndNotify] ;
    }
}

- (bool) writeDebugLogToFile:(const string)path
{
    if (debugLogFile) return true;
    //log to file
    if(fileHandle) return true;
    NSString *fPath = [NSString stringWithCString:path.c_str() encoding:[NSString defaultCStringEncoding]];
    [[NSFileManager defaultManager] createFileAtPath:fPath contents:nil attributes:nil] ;
    fileHandle = [NSFileHandle fileHandleForWritingAtPath:fPath];
    [fileHandle retain];
    return true;
}

- (void)handleNotification:(NSNotification *)note
{
    //NSLog(@"Received notification: %@", note);
    [pipeReadHandle readInBackgroundAndNotify] ;
    NSData *data = [[note userInfo] objectForKey:NSFileHandleNotificationDataItem];
    NSString *str = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    
    //show log to console
    [consoleController trace:str];
    if(fileHandle!=nil){
        [fileHandle writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
}

- (void) closeDebugLogFile
{
    if(fileHandle){
        [fileHandle closeFile];
        [fileHandle release];
        fileHandle = nil;
    }
    if (debugLogFile)
    {
        close(debugLogFile);
        debugLogFile = 0;
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self];
    }
}

- (void) setZoom:(float)scale
{
    eglView->setFrameZoomFactor(scale);
//    Director::getInstance()->getOpenGLView()->setFrameZoomFactor(scale);
    projectConfig.setFrameScale(scale);
}

-(void) setAlwaysOnTop:(BOOL)alwaysOnTop
{
    NSMenuItem *windowMenu = [[window menu] itemWithTitle:@"Window"];
    NSMenuItem *menuItem = [[windowMenu submenu] itemWithTitle:@"Always On Top"];
    if (alwaysOnTop)
    {
        [window setLevel:NSFloatingWindowLevel];
        [menuItem setState:NSOnState];
    }
    else
    {
        [window setLevel:NSNormalWindowLevel];
        [menuItem setState:NSOffState];
    }
    isAlwaysOnTop = alwaysOnTop;
}

- (void) showPreferences:(BOOL)relaunch
{
    [self showModelSheet];
    PlayerPreferencesDialogController *controller = [[PlayerPreferencesDialogController alloc] initWithWindowNibName:@"PlayerPreferencesDialog"];
    [NSApp beginSheet:controller.window modalForWindow:window didEndBlock:^(NSInteger returnCode) {
        [self stopModelSheet];
        [controller release];
        
        NSString *path = [[NSUserDefaults standardUserDefaults] objectForKey:@"QUICK_COCOS2DX_ROOT"];
        SimulatorConfig::sharedDefaults()->setQuickCocos2dxRootPath([path cStringUsingEncoding:NSUTF8StringEncoding]);
        
        if (relaunch)
        {
            projectConfig.resetToWelcome();
            [self relaunch];
        }
    }];
}

- (void) buildAndroidInBackground:(NSString *) scriptAbsPath
{
    buildTask = [[NSTask alloc] init];
    [buildTask setLaunchPath: [NSString stringWithUTF8String:scriptAbsPath.UTF8String]];
    
    [buildTask setArguments: [NSArray array]];
    
    [buildTask launch];
    
    [buildTask waitUntilExit];

    int exitCode = [buildTask terminationStatus];
    [buildTask release];
    buildTask = nil;
    
    [self performSelectorOnMainThread:@selector(updateAlertUI:) withObject:@(exitCode) waitUntilDone:YES];
}

- (void) updateAlertUI:(NSString*) errCodeString
{
    if (!buildAlert) return;
    
    int errCode = [errCodeString intValue];
    NSString *message = (errCode == 0) ? @"Build finished, Congraturations!" : @"OPPS, please check your code or build env";
    BOOL hide = (errCode == 0) ? YES : NO;
    
    [buildAlert setMessageText:message];
    [[[buildAlert buttons] objectAtIndex:0] setTitle:@"Finish"];
    [[[buildAlert buttons] objectAtIndex:1] setHidden:hide];
}


#pragma mark -
#pragma mark interfaces

- (void) welcomeNewProject
{
    [self onFileNewProject:self];
}

- (void) welcomeOpen
{
    [self onFileOpen:self];
}

- (void) welcomeSamples
{
    string path = SimulatorConfig::sharedDefaults()->getQuickCocos2dxRootPath();
    if (path.length())
    {
        path.append("samples");
        [[NSWorkspace sharedWorkspace] openFile:[NSString stringWithCString:path.c_str() encoding:NSUTF8StringEncoding]];
    }
}

- (void) welcomeGetStarted
{
    Native::openURL("http://cn.cocos2d-x.org/tutorial/index?type=quick-cocos2d-x");
}

- (void) welcomeCommunity
{
    Native::openURL("http://www.cocoachina.com/bbs/thread.php?fid=56");
}

- (void) newPlayerWithArgs:(ProjectConfig&) config
{
    config.setWindowOffset(Vec2(window.frame.origin.x, window.frame.origin.y));
    NSString *commandLine = [NSString stringWithCString:config.makeCommandLine().c_str() encoding:NSUTF8StringEncoding];
    [self launch:[NSMutableArray arrayWithArray:[commandLine componentsSeparatedByString:@" "]]];
}

#pragma mark -
#pragma mark IB Actions

- (IBAction) onServicePreferences:(id)sender
{
    [self showPreferences:NO];
}

- (IBAction) onFileNewProject:(id)sender
{
//    [self showAlert:@"Coming soon :-)" withTitle:@"quick-x-player"];
    [self showModelSheet];
    CreateNewProjectDialogController *controller = [[CreateNewProjectDialogController alloc] initWithWindowNibName:@"CreateNewProjectDialog"];
    [NSApp beginSheet:controller.window modalForWindow:window didEndBlock:^(NSInteger returnCode) {
        [self stopModelSheet];
        [controller release];
    }];
}

- (IBAction) onFileNewPlayer:(id)sender
{
    NSMutableArray *args = [self makeCommandLineArgsFromProjectConfig];
    [args removeLastObject];
    [args removeLastObject];
    [self launch:args];
}

- (IBAction) onFileOpen:(id)sender
{
    [self showModelSheet];
    ProjectConfigDialogController *controller = [[ProjectConfigDialogController alloc] initWithWindowNibName:@"ProjectConfigDialog"];
    ProjectConfig newConfig;
    if (!projectConfig.isWelcome())
    {
        newConfig = projectConfig;
    }
    [controller setProjectConfig:newConfig];
    [NSApp beginSheet:controller.window modalForWindow:window didEndBlock:^(NSInteger returnCode) {
        [self stopModelSheet];
        if (returnCode == NSRunStoppedResponse)
        {
            projectConfig = controller.projectConfig;
            [self relaunch];
        }
        [controller release];
    }];
}

- (IBAction) onFileOpenRecent:(id)sender
{
    NSArray *recents = [[NSUserDefaults standardUserDefaults] objectForKey:@"recents"];
    NSDictionary *recentItem = nil;
    NSString *title = [sender title];
    for (NSInteger i = [recents count] - 1; i >= 0; --i)
    {
        recentItem = [recents objectAtIndex:i];
        if ([title compare:[recentItem objectForKey:@"title"]] == NSOrderedSame)
        {
            [self relaunch:[recentItem objectForKey:@"args"]];
            break;
        }
    }
}

- (IBAction) onFileOpenRecentClearMenu:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setObject:[NSArray array] forKey:@"recents"];
    LuaEngine::getInstance()->getLuaStack()->executeString("cc.player.clearMenu()");
    [self updateUI];
}

- (IBAction) onFileWelcome:(id)sender
{
    projectConfig.resetToWelcome();
    [self relaunch];
}

- (IBAction) onFileClose:(id)sender
{
    [[NSApplication sharedApplication] terminate:self];
}

- (IBAction) onPlayerWriteDebugLogToFile:(id)sender
{
    bool isWrite = projectConfig.isWriteDebugLogToFile();
    if (!isWrite)
    {
        if ([self writeDebugLogToFile:projectConfig.getDebugLogFilePath()])
        {
            projectConfig.setWriteDebugLogToFile(true);
            [(NSMenuItem*)sender setState:NSOnState];
        }
    }
    else
    {
        projectConfig.setWriteDebugLogToFile(false);
        [self closeDebugLogFile];
        [(NSMenuItem*)sender setState:NSOffState];
    }
}

- (IBAction) onPlayerOpenDebugLog:(id)sender
{
    const string path = projectConfig.getDebugLogFilePath();
    [[NSWorkspace sharedWorkspace] openFile:[NSString stringWithCString:path.c_str() encoding:NSUTF8StringEncoding]];
}

- (IBAction) onPlayerRelaunch:(id)sender
{
    [self relaunch];
}

- (IBAction) onPlayerShowProjectSandbox:(id)sender
{
    [[NSWorkspace sharedWorkspace] openFile:[NSString stringWithCString:CCFileUtils::sharedFileUtils()->getWritablePath().c_str() encoding:NSUTF8StringEncoding]];
}

- (IBAction) onPlayerShowProjectFiles:(id)sender
{
    [[NSWorkspace sharedWorkspace] openFile:[NSString stringWithCString:projectConfig.getProjectDir().c_str() encoding:NSUTF8StringEncoding]];
}

- (IBAction) onScreenChangeFrameSize:(id)sender
{
    NSInteger i = [sender tag];
    if (i >= 0 && i < SimulatorConfig::sharedDefaults()->getScreenSizeCount())
    {
        SimulatorScreenSize size = SimulatorConfig::sharedDefaults()->getScreenSize((int)i);
        projectConfig.setFrameSize(projectConfig.isLandscapeFrame() ? CCSize(size.height, size.width) : CCSize(size.width, size.height));
        projectConfig.setFrameScale(1.0f);
        [self relaunch];
    }
}

- (IBAction) onScreenPortait:(id)sender
{
    if ([sender state] == NSOnState) return;
    [sender setState:NSOnState];
    [[[[[window menu] itemWithTitle:@"Screen"] submenu] itemWithTitle:@"Landscape"] setState:NSOffState];
    projectConfig.changeFrameOrientationToPortait();
    [self relaunch];
}

- (IBAction) onScreenLandscape:(id)sender
{
    if ([sender state] == NSOnState) return;
    [sender setState:NSOnState];
    [[[[[window menu] itemWithTitle:@"Screen"] submenu] itemWithTitle:@"Portait"] setState:NSOffState];
    projectConfig.changeFrameOrientationToLandscape();
    [self relaunch];
}

- (IBAction) onScreenZoomOut:(id)sender
{
    if ([sender state] == NSOnState) return;
    float scale = (float)[sender tag] / 100.0f;
    [self setZoom:scale];
    [self updateView];
    [self updateUI];
    [self updateOpenRect];

}

- (void) updateView
{
    auto policy = eglView->getResolutionPolicy();
    auto designSize = eglView->getDesignResolutionSize();
    
    cocos2d::Size frameSize = projectConfig.getFrameSize();
    eglView->setFrameSize(frameSize.width, frameSize.height);
    
    eglView->setDesignResolutionSize(designSize.width, designSize.height, policy);
}

-(IBAction) onWindowAlwaysOnTop:(id)sender
{
    [self setAlwaysOnTop:!isAlwaysOnTop];
}

-(IBAction)fileBuildAndroid:(id)sender
{
    if (!isBuildingFinished) return;
        
    if (projectConfig.isWelcome())
    {
        [self showAlert:@"Welcome app is not for android" withTitle:@""];
    }
    else
    {
        std::string scriptPath = projectConfig.getProjectDir() + "proj.android/build_native.sh";
        if (!FileUtils::getInstance()->isFileExist(scriptPath))
        {
            [self showAlert:[NSString stringWithFormat:@"%s isn't exist", scriptPath.c_str()] withTitle:@""];
        }
        else
        {
            isBuildingFinished = NO;
            NSString *tmpPath = [NSString stringWithUTF8String:scriptPath.c_str()];
            
            [self performSelectorInBackground:@selector(buildAndroidInBackground:)
                                   withObject:tmpPath];
            
            
            
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert addButtonWithTitle:@"Cancel"];
            [[alert addButtonWithTitle:@"How to setup android ENV"] setHidden:YES];
            [alert setMessageText:@"Building android target, view console :-)"];
            [alert setAlertStyle:NSWarningAlertStyle];

            buildAlert = alert;
            [alert beginSheetModalForWindow:window
                          completionHandler:^(NSModalResponse returnCode) {
                              
                              isBuildingFinished = YES;
                              if (returnCode == NSAlertFirstButtonReturn)
                              {
                                  if (buildTask && [buildTask isRunning])
                                  {
                                      [NSObject cancelPreviousPerformRequestsWithTarget:self];
                                      [buildTask interrupt];
                                  }
                              }
                              else if (returnCode == NSAlertSecondButtonReturn)
                              {
                                  Native::openURL("http://quick.cocos.org/?p=415");
                              }
                          }];
        }
    }
}

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)anItem
{
    return (isBuildingFinished);
}

- (IBAction) fileBuildIOS:(id)sender
{
    if (projectConfig.isWelcome())
    {
        [self showAlert:@"Welcome app " withTitle:@""];
    }
    else
    {
        [self showAlert:@"Coming soon :-)" withTitle:@""];
    }
}
@end
