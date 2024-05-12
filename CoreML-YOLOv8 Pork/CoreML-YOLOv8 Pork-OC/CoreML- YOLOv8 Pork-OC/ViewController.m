//
//  ViewController.m
//  CoreML- YOLOv8 Pork-OC
//
//  Created by 杨帆 on 2024/5/12.
//

#import "ViewController.h"

@interface ViewController ()

@property (nonatomic) CGSize bufferSize;
@property (nonatomic) AVCaptureSession *session;
@property (nonatomic) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic) NSMutableArray<VNRequest *> *requests;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)setup {
    [self setupAVCapture];
    [self setupLayers];
    [self setupModels];
    [self startCaptureSession];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self setup];
}

- (void)startCaptureSession {
    [self.session startRunning];
}

- (void)teardownAVCapture {
    [self.previewLayer removeFromSuperlayer];
    self.previewLayer = nil;
}

- (void)setupAVCapture {
    AVCaptureDeviceInput *deviceInput = nil;
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if (error) {
        NSLog(@"Could not create video device input: %@", error);
        return;
    }
    
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPreset640x480;
    
    if ([self.session canAddInput:deviceInput]) {
        [self.session addInput:deviceInput];
    } else {
        NSLog(@"Could not add video device input to the session");
        return;
    }
    
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    if ([self.session canAddOutput:self.videoDataOutput]) {
        [self.session addOutput:self.videoDataOutput];
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = YES;
        NSDictionary *videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
        [self.videoDataOutput setVideoSettings:videoSettings];
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        [self.videoDataOutput setSampleBufferDelegate:self queue:queue];
    } else {
        NSLog(@"Could not add video data output to the session");
        return;
    }
    
    AVCaptureConnection *captureConnection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    captureConnection.enabled = YES;
    
    [videoDevice lockForConfiguration:nil];
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(videoDevice.activeFormat.formatDescription);
    self.bufferSize = CGSizeMake(dimensions.width, dimensions.height);
    [videoDevice unlockForConfiguration];
    
    [self.session commitConfiguration];
}

- (void)setupLayers {
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.frame = self.view.layer.bounds;
    [self.view.layer addSublayer:self.previewLayer];
}

- (void)setupModels {
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"best100" withExtension:@"mlmodelc"];
    if (!modelURL) {
        return;
    }
    
    VNCoreMLModel *visionModel = nil;
    NSError *error = nil;
    MLModel *mlModel = [MLModel modelWithContentsOfURL:modelURL error:&error];
    if (!error) {
        visionModel = [VNCoreMLModel modelForMLModel:mlModel error:&error];
    }
    
    if (error) {
        NSLog(@"Model loading went wrong: %@", error);
        return;
    }
    
    VNCoreMLRequest *objectRecognition = [[VNCoreMLRequest alloc] initWithModel:visionModel completionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSArray *results = request.results;
            if (results) {
                [self drawVisionRequestResults:results];
            }
        });
    }];
    
    self.requests = [NSMutableArray arrayWithObject:objectRecognition];
}

- (void)drawVisionRequestResults:(NSArray *)results {
    for (id observation in results) {
        if ([observation isKindOfClass:[VNRecognizedObjectObservation class]]) {
            VNRecognizedObjectObservation *objectObservation = (VNRecognizedObjectObservation *)observation;
            VNClassificationObservation *topLabelObservation = objectObservation.labels.firstObject;
            CGRect objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, (int)self.bufferSize.width, (int)self.bufferSize.height);
            NSLog(@"位置信息： %@", NSStringFromCGRect(objectBounds));
            NSLog(@"标签： %@", topLabelObservation.identifier);
            NSLog(@"置信度： %f", topLabelObservation.confidence);
        }
    }
}

@end

@implementation ViewController (Utilities)

- (CGImagePropertyOrientation)exifOrientationFromDeviceOrientation {
    UIDeviceOrientation curDeviceOrientation = UIDevice.currentDevice.orientation;
    CGImagePropertyOrientation exifOrientation;
    switch (curDeviceOrientation) {
        case UIDeviceOrientationPortraitUpsideDown:
            exifOrientation = kCGImagePropertyOrientationLeft;
            break;
        case UIDeviceOrientationLandscapeLeft:
            exifOrientation = kCGImagePropertyOrientationUpMirrored;
            break;
        case UIDeviceOrientationLandscapeRight:
            exifOrientation = kCGImagePropertyOrientationDown;
            break;
        case UIDeviceOrientationPortrait:
            exifOrientation = kCGImagePropertyOrientationUp;
            break;
        default:
            exifOrientation = kCGImagePropertyOrientationUp;
            break;
    }
    return exifOrientation;
}


- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pixelBuffer) {
        return;
    }
    
    CGImagePropertyOrientation exifOrientation = [self exifOrientationFromDeviceOrientation];
    VNImageRequestHandler *imageRequestHandler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer orientation:exifOrientation options:@{}];
    NSError *error = nil;
    [imageRequestHandler performRequests:self.requests error:&error];
    if (error) {
        NSLog(@"%@", error);
    }
}


@end

