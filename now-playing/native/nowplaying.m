// nowplaying: read and control the system "Now Playing" sessions on macOS.
//
// Since macOS 15.4 the private MediaRemote framework only answers processes
// Apple has entitled. /usr/bin/perl is one of them, so this library is loaded
// into perl (see nowplaying.pl) and does its MediaRemote calls from there.
// Technique from https://github.com/ungive/mediaremote-adapter (BSD-3-Clause).
//
// Arguments come in through environment variables so the XSUB entry point
// never has to touch perl's calling convention:
//   NP_CMD      get | send
//   NP_ARG      send: MRCommand id (0 play, 1 pause, 2 toggle, 4 next, 5 previous)
//   NP_BUNDLE   send: the client to target; empty sends to whatever macOS elected
//   NP_ART_DIR  get: folder the artwork is written to, one file per session
//
// Output: one line of JSON on stdout.
//   get   { "elected": bundle | null, "sessions": [Track, ...] }, one Track per client with a title;
//         controllable says whether the client has an active player, the only kind send can target
//   send  true | false

#import <AppKit/AppKit.h>
#import <CommonCrypto/CommonDigest.h>
#import <Foundation/Foundation.h>
#include <dlfcn.h>

typedef void (*GetClientsFn)(dispatch_queue_t, void (^)(NSArray *));
typedef id (*ClientGetFn)(id);
typedef int (*ClientGetPidFn)(id);
typedef id (*GetOriginFn)(void);
typedef id (*PathCreateFn)(id origin, id client, id player);
typedef void (*GetInfoForPlayerFn)(id path, BOOL wantArtwork, dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*GetActivePathsFn)(id origin, dispatch_queue_t, void (^)(NSArray *));
typedef void (*GetPidFn)(dispatch_queue_t, void (^)(int));
typedef Boolean (*SendFn)(int, NSDictionary *);
typedef void (*SendToPlayerFn)(unsigned cmd, NSDictionary *options, id path, unsigned appOptions,
                               dispatch_queue_t, void (^)(unsigned err, NSArray *statuses));

static void *mr(const char *symbol) {
    static void *handle;
    if (!handle)
        handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    void *fn = handle ? dlsym(handle, symbol) : NULL;
    if (!fn) {
        fprintf(stderr, "MediaRemote symbol missing: %s\n", symbol);
        exit(3);
    }
    return fn;
}

static void emit(id obj) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:obj ?: [NSNull null]
                                                   options:NSJSONWritingFragmentsAllowed
                                                     error:nil];
    fwrite(data.bytes, 1, data.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

static NSString *sha1Prefix(NSData *data) {
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hex = [NSMutableString string];
    for (int i = 0; i < 8; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

static NSString *artFolder(void) {
    const char *dir = getenv("NP_ART_DIR");
    return dir && *dir ? [NSString stringWithUTF8String:dir] : nil;
}

// A content-derived name makes a new picture a new path, so image() never
// shows a stale cached file. The bundle prefix lets pruning keep a session's
// last picture while its next one is still on the way. Returns the file name.
static NSString *saveArtwork(NSString *bundle, NSData *art, NSString *mime) {
    NSString *folder = artFolder();
    if (!art.length || !folder) return nil;
    NSFileManager *fm = NSFileManager.defaultManager;
    [fm createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *ext = [mime isEqualToString:@"image/png"] ? @"png" : @"jpg";
    NSString *name = [NSString stringWithFormat:@"%@-%@.%@", bundle ?: @"unknown", sha1Prefix(art), ext];
    NSString *path = [folder stringByAppendingPathComponent:name];
    if (![fm fileExistsAtPath:path] && ![art writeToFile:path atomically:YES]) return nil;
    return name;
}

// Removes every picture no session shows, except those of a session whose
// artwork hasn't arrived yet: the UI keeps showing that session's last one.
static void pruneArtwork(NSArray<NSDictionary *> *sessions) {
    NSString *folder = artFolder();
    if (!folder) return;
    NSMutableSet *keep = [NSMutableSet set], *waiting = [NSMutableSet set];
    for (NSDictionary *s in sessions) {
        if (s[@"art"]) [keep addObject:s[@"art"]];
        else if (s[@"bundle"]) [waiting addObject:s[@"bundle"]];
    }
    NSFileManager *fm = NSFileManager.defaultManager;
    for (NSString *name in [fm contentsOfDirectoryAtPath:folder error:nil]) {
        NSRange dash = [name rangeOfString:@"-" options:NSBackwardsSearch];
        NSString *bundle = dash.location == NSNotFound ? nil : [name substringToIndex:dash.location];
        if ([keep containsObject:name] || (bundle && [waiting containsObject:bundle])) continue;
        [fm removeItemAtPath:[folder stringByAppendingPathComponent:name] error:nil];
    }
}

static NSMutableDictionary *track(NSDictionary *info, id client) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    NSDictionary *keys = @{
        @"title" : @"kMRMediaRemoteNowPlayingInfoTitle",
        @"artist" : @"kMRMediaRemoteNowPlayingInfoArtist",
        @"album" : @"kMRMediaRemoteNowPlayingInfoAlbum",
        @"duration" : @"kMRMediaRemoteNowPlayingInfoDuration",
        @"elapsed" : @"kMRMediaRemoteNowPlayingInfoElapsedTime",
        @"rate" : @"kMRMediaRemoteNowPlayingInfoPlaybackRate",
        @"id" : @"kMRMediaRemoteNowPlayingInfoContentItemIdentifier",
    };
    for (NSString *key in keys) {
        id value = info[keys[key]];
        if (value) out[key] = value;
    }
    // elapsed is a snapshot taken at timestamp; the reader extrapolates with rate.
    NSDate *timestamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
    if (timestamp) out[@"timestamp"] = @(timestamp.timeIntervalSince1970);
    NSString *bundle = ((ClientGetFn)mr("MRNowPlayingClientGetBundleIdentifier"))(client);
    NSString *art = saveArtwork(bundle, info[@"kMRMediaRemoteNowPlayingInfoArtworkData"],
                                info[@"kMRMediaRemoteNowPlayingInfoArtworkMIMEType"]);
    if (art) out[@"art"] = art;
    NSString *name = ((ClientGetFn)mr("MRNowPlayingClientGetDisplayName"))(client);
    if (!name) {
        int pid = ((ClientGetPidFn)mr("MRNowPlayingClientGetProcessIdentifier"))(client);
        name = pid > 0 ? [NSRunningApplication runningApplicationWithProcessIdentifier:pid].localizedName : nil;
    }
    if (bundle) out[@"bundle"] = bundle;
    if (name) out[@"app"] = name;
    return out;
}

static id pathFor(id client) {
    id origin = ((GetOriginFn)mr("MRMediaRemoteGetLocalOrigin"))();
    return ((PathCreateFn)mr("MRNowPlayingPlayerPathCreate"))(origin, client, nil);
}

static void np_get(void) {
    dispatch_queue_t q = dispatch_get_main_queue();
    ((GetClientsFn)mr("MRMediaRemoteGetNowPlayingClients"))(q, ^(NSArray *clients) {
        NSUInteger n = clients.count;
        NSMutableArray *slots = [NSMutableArray arrayWithCapacity:n];
        for (NSUInteger i = 0; i < n; i++) [slots addObject:[NSNull null]];
        __block id elected = [NSNull null];
        __block NSSet *active = [NSSet set];
        __block NSUInteger pending = n + 2;

        void (^finish)(void) = ^{
            if (--pending) return;
            NSMutableArray *sessions = [NSMutableArray array];
            for (NSMutableDictionary *slot in slots) {
                if ((id)slot == [NSNull null]) continue;
                slot[@"controllable"] = @([active containsObject:slot[@"bundle"] ?: @""]);
                [sessions addObject:slot];
            }
            pruneArtwork(sessions);
            emit(@{@"elected" : elected, @"sessions" : sessions});
            exit(0);
        };

        ((GetPidFn)mr("MRMediaRemoteGetNowPlayingApplicationPID"))(q, ^(int pid) {
            for (id client in clients) {
                if (((ClientGetPidFn)mr("MRNowPlayingClientGetProcessIdentifier"))(client) == pid)
                    elected = ((ClientGetFn)mr("MRNowPlayingClientGetBundleIdentifier"))(client) ?: elected;
            }
            if (elected == [NSNull null] && pid > 0)
                elected = [NSRunningApplication runningApplicationWithProcessIdentifier:pid].bundleIdentifier ?: elected;
            finish();
        });

        // Only these take a targeted command (see np_send).
        ((GetActivePathsFn)mr("MRMediaRemoteGetActivePlayerPathsForOrigin"))(((GetOriginFn)mr("MRMediaRemoteGetLocalOrigin"))(), q, ^(NSArray *paths) {
            NSMutableSet *bundles = [NSMutableSet set];
            for (id path in paths) {
                id bundle = ((ClientGetFn)mr("MRNowPlayingClientGetBundleIdentifier"))(((ClientGetFn)mr("MRNowPlayingPlayerPathGetClient"))(path));
                if (bundle) [bundles addObject:bundle];
            }
            active = bundles;
            finish();
        });

        [clients enumerateObjectsUsingBlock:^(id client, NSUInteger i, BOOL *stop) {
            ((GetInfoForPlayerFn)mr("MRMediaRemoteGetNowPlayingInfoForPlayer"))(pathFor(client), YES, q, ^(NSDictionary *info) {
                if (info[@"kMRMediaRemoteNowPlayingInfoTitle"]) slots[i] = track(info, client);
                finish();
            });
        }];
    });
}

static void exitSoon(BOOL ok) {
    // Give MediaRemote a moment to deliver the command before the process ends.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        exit(ok ? 0 : 1);
    });
}

static void np_send(void) {
    const char *arg = getenv("NP_ARG");
    const char *bundle = getenv("NP_BUNDLE");
    if (!arg || !*arg) {
        fprintf(stderr, "send needs a command id\n");
        exit(2);
    }
    unsigned command = (unsigned)atoi(arg);
    if (!bundle || !*bundle) {
        Boolean ok = ((SendFn)mr("MRMediaRemoteSendCommand"))(command, nil);
        emit(@(ok));
        exitSoon(ok);
        return;
    }
    NSString *want = [NSString stringWithUTF8String:bundle];
    dispatch_queue_t q = dispatch_get_main_queue();
    id origin = ((GetOriginFn)mr("MRMediaRemoteGetLocalOrigin"))();
    // Only active player paths take a targeted command. Sent to the path of a
    // listed but inactive client (a paused browser tab), MediaRemote quietly
    // delivers it to the elected player instead, so refuse rather than misfire.
    ((GetActivePathsFn)mr("MRMediaRemoteGetActivePlayerPathsForOrigin"))(origin, q, ^(NSArray *paths) {
        for (id path in paths) {
            id client = ((ClientGetFn)mr("MRNowPlayingPlayerPathGetClient"))(path);
            if (![((ClientGetFn)mr("MRNowPlayingClientGetBundleIdentifier"))(client) isEqual:want]) continue;
            ((SendToPlayerFn)mr("MRMediaRemoteSendCommandToPlayer"))(command, nil, path, 0, q, ^(unsigned err, NSArray *statuses) {
                emit(@(err == 0));
                exitSoon(err == 0);
            });
            return;
        }
        fprintf(stderr, "%s has no active player to send to\n", bundle);
        exit(4);
    });
}

// The entry point perl calls (installed as an XSUB; it takes and returns nothing).
void nowplaying_main(void) {
    const char *cmd = getenv("NP_CMD");
    if (cmd && strcmp(cmd, "get") == 0) np_get();
    else if (cmd && strcmp(cmd, "send") == 0) np_send();
    else {
        fprintf(stderr, "usage: NP_CMD=get|send\n");
        exit(2);
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        fprintf(stderr, "timed out waiting for MediaRemote\n");
        exit(1);
    });
    CFRunLoopRun();
}
