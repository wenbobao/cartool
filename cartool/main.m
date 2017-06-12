//
//  main.m
//  cartoolDemo
//
//  Created by bob on 2017/6/9.
//  Copyright © 2017年 wenbobao. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum _kCoreThemeIdiom {
    kCoreThemeIdiomUniversal,
    kCoreThemeIdiomPhone,
    kCoreThemeIdiomPad,
    kCoreThemeIdiomTV,
    kCoreThemeIdiomCar,
    kCoreThemeIdiomWatch,
    kCoreThemeIdiomMarketing
} kCoreThemeIdiom;

typedef NS_ENUM(NSInteger, UIUserInterfaceSizeClass) {
    UIUserInterfaceSizeClassUnspecified = 0,
    UIUserInterfaceSizeClassCompact     = 1,
    UIUserInterfaceSizeClassRegular     = 2,
};

NSString *idiomSuffixForCoreThemeIdiom(kCoreThemeIdiom idiom)
{
    switch (idiom) {
        case kCoreThemeIdiomUniversal:
            return @"";
            break;
        case kCoreThemeIdiomPhone:
            return @"~iphone";
            break;
        case kCoreThemeIdiomPad:
            return @"~ipad";
            break;
        case kCoreThemeIdiomTV:
            return @"~tv";
            break;
        case kCoreThemeIdiomCar:
            return @"~carplay";
            break;
        case kCoreThemeIdiomWatch:
            return @"~watch";
            break;
        case kCoreThemeIdiomMarketing:
            return @"~marketing";
            break;
        default:
            break;
    }
    
    return @"";
}

NSString *sizeClassSuffixForSizeClass(UIUserInterfaceSizeClass sizeClass)
{
    switch (sizeClass)
    {
        case UIUserInterfaceSizeClassCompact:
            return @"C";
            break;
        case UIUserInterfaceSizeClassRegular:
            return @"R";
            break;
        default:
            return @"A";
    }
}

@interface CUICommonAssetStorage : NSObject

- (NSArray *)allAssetKeys;
- (NSArray *)allRenditionNames;
- (NSString *)versionString;

- (id)catalogGlobalData;
- (id)initWithPath:(NSString *)p;

@end

@interface CUINamedData : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, readonly, copy) NSData *data;
@property (nonatomic, readonly, copy) NSString *utiType;

- (id)renditionKey;
- (id)renditionName;

@end

@interface CUINamedImage : NSObject

@property(readonly) CGSize size;
@property(readonly) CGFloat scale;
@property(readonly) kCoreThemeIdiom idiom;
@property(readonly) UIUserInterfaceSizeClass sizeClassHorizontal;
@property(readonly) UIUserInterfaceSizeClass sizeClassVertical;

- (CGImageRef)image;

@end

@interface CUIRenditionKey : NSObject
@end

@interface CUIThemeFacet : NSObject

+ (CUIThemeFacet *)themeWithContentsOfURL:(NSURL *)u error:(NSError **)e;

@end

@interface CUICatalog : NSObject

@property(readonly) bool isVectorBased;

- (id)initWithName:(NSString *)n fromBundle:(NSBundle *)b;
- (id)allKeys;
- (id)allImageNames;
- (CUINamedImage *)imageWithName:(NSString *)n scaleFactor:(CGFloat)s;
- (CUINamedImage *)imageWithName:(NSString *)n scaleFactor:(CGFloat)s deviceIdiom:(int)idiom;
- (NSArray *)imagesWithName:(NSString *)n;

- (CUINamedData *)dataWithName:(NSString *)arg1;

@end

void CGImageWriteToFile(CGImageRef image, NSString *path)
{
    CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:path];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, NULL);
    CGImageDestinationAddImage(destination, image, nil);
    
    if (!CGImageDestinationFinalize(destination)) {
        NSLog(@"Failed to write image to %@", path);
    }
    
    CFRelease(destination);
}

void DataWriteToFile(CUINamedData *assetData, NSString *path)
{
    NSError *error;
    NSString *filePath = [path stringByAppendingPathComponent:[assetData renditionName]];
    BOOL result = [assetData.data writeToFile:filePath options:0 error:&error];
    
    if (result) {
        NSLog(@"write %@ success", [assetData renditionName]);
    } else {
        NSLog(@"write %@ failure", [assetData renditionName]);
    }
}

NSMutableArray *getImagesArray(CUICatalog *catalog, NSString *key)
{
    NSMutableArray *images = [[NSMutableArray alloc] initWithCapacity:5];
    
    for (NSNumber *scaleFactor in @[@1, @2, @3])
    {
        CUINamedImage *image = [catalog imageWithName:key scaleFactor:scaleFactor.doubleValue];
        
        if (image && image.scale == scaleFactor.floatValue)
        {
            [images addObject:image];
        }
    }
    
    return images;
}

void exportCarFileAtPath(NSString *carPath, NSString *outputDirectoryPath)
{
    outputDirectoryPath = [outputDirectoryPath stringByExpandingTildeInPath];
    
    CUICatalog *catalog = [[CUICatalog alloc] init];
    
    /* Override CUICatalog to point to a file rather than a bundle */
    NSError *error = nil;
    CUIThemeFacet *facet = [CUIThemeFacet themeWithContentsOfURL:[NSURL fileURLWithPath:carPath] error:&error];
    [catalog setValue:facet forKey:@"_storageRef"];
    
    /* CUICommonAssetStorage won't link */
    CUICommonAssetStorage *storage = [[NSClassFromString(@"CUICommonAssetStorage") alloc] initWithPath:carPath];
    NSLog(@"%@", [storage allRenditionNames]);
    
    for (NSString *key in [storage allRenditionNames])
    {
        printf("%s\n", [key UTF8String]);
        
        NSArray* pathComponents = [key pathComponents];
        if (pathComponents.count > 1)
        {
            // Create subdirectories for namespaced assets (those with names like "some/namespace/image-name")
            NSArray* subdirectoryComponents = [pathComponents subarrayWithRange:NSMakeRange(0, pathComponents.count - 1)];
            
            NSString* subdirectoryPath = [outputDirectoryPath copy];
            for (NSString* pathComponent in subdirectoryComponents)
            {
                subdirectoryPath = [subdirectoryPath stringByAppendingPathComponent:pathComponent];
            }
            
            [[NSFileManager defaultManager] createDirectoryAtPath:subdirectoryPath
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:&error];
        }
        
        CUINamedData *assetData = [catalog dataWithName:key];
        if (assetData) {
            DataWriteToFile(assetData, outputDirectoryPath);
        }
        else {
            NSMutableArray *images = getImagesArray(catalog, key);
            for(CUINamedImage *image in images)
            {
                if( CGSizeEqualToSize(image.size, CGSizeZero) )
                {
                    printf("\tnil image?\n");
                } else {
                    CGImageRef cgImage = [image image];
                    NSString *idiomSuffix = idiomSuffixForCoreThemeIdiom(image.idiom);
                    
                    NSString *sizeClassSuffix = @"";
                    
                    if (image.sizeClassHorizontal || image.sizeClassVertical)
                    {
                        sizeClassSuffix = [NSString stringWithFormat:@"-%@x%@", sizeClassSuffixForSizeClass(image.sizeClassHorizontal), sizeClassSuffixForSizeClass(image.sizeClassVertical)];
                    }
                    
                    NSString *scale = image.scale > 1.0 ? [NSString stringWithFormat:@"@%dx", (int)floor(image.scale)] : @"";
                    NSString *name = [NSString stringWithFormat:@"%@%@%@%@.png", key, idiomSuffix, sizeClassSuffix, scale];
                    printf("\t%s\n", [name UTF8String]);
                    if(outputDirectoryPath)
                    {
                        CGImageWriteToFile(cgImage, [outputDirectoryPath stringByAppendingPathComponent:name]);
                    }
                    
                }
            }
        }
        
    }
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // insert code here...
        
        //        NSString *carPath = @"/Users/bob/Desktop/ClassDump/Payload/ClassDumpDemo2.app/Assets.car";
        //        NSString *outputPath = @"/Users/bob/Desktop/ClassDump/Payload/ClassDumpDemo2.app/resource";
        //        exportCarFileAtPath(carPath, outputPath);
        
        if (argc < 2)
        {
            printf("Usage: cartool <path to Assets.car> [outputDirectory]\n");
            return -1;
        }
        
        exportCarFileAtPath([NSString stringWithUTF8String:argv[1]], argc > 2 ? [NSString stringWithUTF8String:argv[2]] : nil);
    }
    return 0;
}
