// nowplaying: read and control the system "Now Playing" session on macOS.
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
//   NP_ART_DIR  get: folder the artwork is written to (only the current file is kept)
//
// Output: one line of JSON on stdout. `get` prints null when nothing is playing.

#import <AppKit/AppKit.h>
#import <CommonCrypto/CommonDigest.h>
#import <Foundation/Foundation.h>
#include <dlfcn.h>

typedef void (*GetInfoFn)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*GetPidFn)(dispatch_queue_t, void (^)(int));
typedef Boolean (*SendFn)(int, NSDictionary *);

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

// Writes the artwork under a content-derived name, so a new picture is a new
// path (no stale image cache), and removes the previous one. Returns the file name.
static NSString *saveArtwork(NSData *art, NSString *mime) {
    const char *dir = getenv("NP_ART_DIR");
    if (!art.length || !dir || !*dir) return nil;
    NSString *folder = [NSString stringWithUTF8String:dir];
    NSFileManager *fm = NSFileManager.defaultManager;
    [fm createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *ext = [mime isEqualToString:@"image/png"] ? @"png" : @"jpg";
    NSString *name = [NSString stringWithFormat:@"%@.%@", sha1Prefix(art), ext];
    NSString *path = [folder stringByAppendingPathComponent:name];
    if (![fm fileExistsAtPath:path]) {
        if (![art writeToFile:path atomically:YES]) return nil;
        for (NSString *other in [fm contentsOfDirectoryAtPath:folder error:nil]) {
            if (![other isEqualToString:name])
                [fm removeItemAtPath:[folder stringByAppendingPathComponent:other] error:nil];
        }
    }
    return name;
}

static void np_get(void) {
    ((GetInfoFn)mr("MRMediaRemoteGetNowPlayingInfo"))(dispatch_get_main_queue(), ^(NSDictionary *info) {
        if (!info.count || !info[@"kMRMediaRemoteNowPlayingInfoTitle"]) {
            emit(nil);
            exit(0);
        }
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
        NSString *art = saveArtwork(info[@"kMRMediaRemoteNowPlayingInfoArtworkData"],
                                    info[@"kMRMediaRemoteNowPlayingInfoArtworkMIMEType"]);
        if (art) out[@"art"] = art;

        ((GetPidFn)mr("MRMediaRemoteGetNowPlayingApplicationPID"))(dispatch_get_main_queue(), ^(int pid) {
            NSRunningApplication *app = pid > 0 ? [NSRunningApplication runningApplicationWithProcessIdentifier:pid] : nil;
            if (app.bundleIdentifier) out[@"bundle"] = app.bundleIdentifier;
            if (app.localizedName) out[@"app"] = app.localizedName;
            emit(out);
            exit(0);
        });
    });
}

static void np_send(void) {
    const char *arg = getenv("NP_ARG");
    if (!arg || !*arg) {
        fprintf(stderr, "send needs a command id\n");
        exit(2);
    }
    Boolean ok = ((SendFn)mr("MRMediaRemoteSendCommand"))(atoi(arg), nil);
    emit(@(ok));
    // Give MediaRemote a moment to deliver the command before the process ends.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        exit(ok ? 0 : 1);
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
