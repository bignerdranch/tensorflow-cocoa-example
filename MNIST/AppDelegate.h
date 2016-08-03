//
//  AppDelegate.h
//  MNIST
//
//  Created by Aaron Hillegass on 7/7/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <tensorflow/core/framework/graph.pb.h>
#import <tensorflow/core/public/session.h>

@class MNISTDataSet;

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    MNISTDataSet *dataSet;
    unsigned int selectedImage;
    tensorflow::GraphDef graph_def;
    tensorflow::Session *session;
}
- (IBAction)showNext:(id)sender;
- (IBAction)showPrevious:(id)sender;

@end

