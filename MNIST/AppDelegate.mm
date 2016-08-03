//
//  AppDelegate.m
//  MNIST
//
//  Created by Aaron Hillegass on 7/7/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

#import "AppDelegate.h"
#import "PixelView.h"
#import "MNISTDataSet.h"
#import <tensorflow/core/platform/env.h>
#import <tensorflow/core/public/session.h>
#import <tensorflow/core/framework/tensor.h>


@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet PixelView *pixelView;
@property (weak) IBOutlet NSButton *previousButton;
@property (weak) IBOutlet NSButton *nextButton;
@property (weak) IBOutlet NSTextField *infoField;
@end

using namespace tensorflow;

@implementation AppDelegate

- (instancetype)init
{
    self = [super init];
    dataSet = [[MNISTDataSet alloc] init];
    [self createGraphAndSession];
    return self;
}

- (void)createGraphAndSession
{
    // Find the graph def in the main bundle
    NSString *graphPath = [[NSBundle mainBundle] pathForResource:@"frozen" ofType:@"pb"];
    
    // Read it in
    Status status = ReadBinaryProto(Env::Default(), [graphPath cStringUsingEncoding:NSUTF8StringEncoding], &graph_def);
    if (!status.ok()) {
        NSLog(@"Model reading %@ failed: %s", graphPath, status.error_message().c_str());
        return;
    }
    
    // List out the nodes (just for fun)
    int nodeCount = graph_def.node_size();
    for (int i = 0; i < nodeCount; i++) {
        const ::tensorflow::NodeDef node = graph_def.node(i);
        std::string nodeName = node.name();
        std::string nodeOp = node.op();
        fprintf(stderr, "Node %d %s \'%s\'\n", i, nodeOp.c_str(), nodeName.c_str());
    }
    
    // Create a session
    tensorflow::SessionOptions options;
    session = tensorflow::NewSession(options);
    
    // Attached the graph to the session
    tensorflow::Status s = session->Create(graph_def);
    if (!s.ok()) {
        NSLog(@"Error:Couldn't add graph to session");
        return;
    }
}

- (void)getGuesses:(float *)guesses
          forImage:(const unsigned char *)im
{
    int pixelCount = dataSet.columns * dataSet.rows;
    TensorShape inShape;
    inShape.AddDim(1);  // A batch of exactly one image
    inShape.AddDim(pixelCount);// The image has 784 pixels
    Tensor inputTensor(DT_FLOAT, inShape); // Model expects floats
    
    // Copy the image data into the tensor
    auto mappedInput = inputTensor.tensor<float, 2>();
    for (int i = 0; i < pixelCount; i++) {
        mappedInput(0, i) = im[i]/255.0;
    }
    
    // Create a vector to hold the results
    std::vector<tensorflow::Tensor> outputs;
    
    // Run the data through the model
    Status s = session->Run({{"pix_in", inputTensor}}, {"normalized_guesses"}, {}, &outputs);
    if (!s.ok()) {
        NSLog(@"Error:Couldn't run model: %s", s.error_message().c_str());
        return;
    }
    
    // Get the only output
    Tensor outputTensor = outputs[0];
    
    // Copy the results into the guesses array
    auto mappedOutput = outputTensor.tensor<float, 2>();
    for (int i = 0; i < 10; i++) {
        guesses[i] = mappedOutput(0,i);
    }
}

- (void)showSelectedImage
{
    // Enable/disable previous button
    [self.previousButton setEnabled:(selectedImage != 0)];
    
    // Enable/disable next button
    unsigned imageCount = dataSet.imageCount;
    [self.nextButton setEnabled:(selectedImage != imageCount - 1)];
    
    // Which image?
    unsigned char *image = [dataSet imageDataForIndex:selectedImage];
    
    // Show it
    [self.pixelView copyBuffer:image];
    
    // Use tensorflow to get guesses
    float guesses[10];
    [self getGuesses:guesses
            forImage:image];
    
    // Put info in a string
    unsigned char label = [dataSet labelForIndex:selectedImage];
    NSMutableString *infoString = [NSMutableString stringWithFormat:@"Image %d is %d.\nGuesses: ", selectedImage, label];

    // Step through the guesses, appending significant ones
    BOOL writtenFirstGuess = NO;
    for (int i = 0; i < 10; i++ ) {
        
        // Is it more than noise?
        if (guesses[i] > 0.007) {
            
            // Comma separate the guesses
            if (writtenFirstGuess) {
                [infoString appendString:@", "];
            } else {
                writtenFirstGuess = YES;
            }
            
            // Put it in the string
            [infoString appendFormat:@"%d=%d%%", i, int(guesses[i] * 100.0)];
        }
    }

    // Display the string
    [self.infoField setStringValue:infoString];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [self.pixelView setWidth:dataSet.columns];
    [self.pixelView setHeight:dataSet.rows];
    [self showSelectedImage];
}

- (IBAction)showNext:(id)sender
{
    if (selectedImage < dataSet.imageCount - 1) {
        selectedImage++;
    }
    [self showSelectedImage];
}

- (IBAction)showPrevious:(id)sender
{
    if (selectedImage > 0) {
        selectedImage--;
    }
    [self showSelectedImage];
}

@end
