# tensorflow-cocoa-example

Google did an amazing thing by open-sourcing its tensorflow machine learning framework.  The framework's API is best used from Python, but if you are working in Cocoa, it is much easier to use the C++ API. The C++ API is incomplete and poorly documented. I suspect very few people have ever actually used it.

Inside Google, tensorflow is built with its internal build tool blaze. So, you will need to use its dumbed down brother bazel that Google has also open sourced. bazel uses your CPU like nothing you have ever used before. I can't listen to music on iTunes while bazel is building tensorflow.

All serialization is done using protocol buffers — the new 3.0 version.

I think that if you have Xcode installed, you can build and run this project.  If you 

## Building tensorflow

You must have Xcode installed.

Install [bazel](https://github.com/bazelbuild/bazel/releases) and [swig](http://www.swig.org/download.html)

Install lots of Python packages:

	sudo easy_install -U six
	sudo easy_install -U numpy
	sudo easy_install wheel
	sudo easy_install mock

Then clone the tensorflow source and build it:

	git clone git@github.com:tensorflow/tensorflow.git
	cd tensorflow
	./configure
	Please specify the location of python. [Default is /usr/bin/python]: 
	Do you wish to build TensorFlow with Google Cloud Platform support? [y/N] N
	No Google Cloud Platform support will be enabled for TensorFlow
	Do you wish to build TensorFlow with GPU support? [y/N] N
	No GPU support will be enabled for TensorFlow
	Configuration finished

	bazel build -c opt //tensorflow/tools/pip_package:build_pip_package
	bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg
	sudo pip install /tmp/tensorflow_pkg/tensorflow-0.10.0rc0-py2-none-any.whl

(That last file name will depend on a lot of stuff, but it is something like that.)

You will also want to build the library to link into your application:

	bazel build //tensorflow:libtensorflow.so

Headers for this library are in `/Library/Python/2.7/site-packages/tensorflow/include/tensorflow/core` but I think a few are missing. Copy them from the source tree:

	cd tensorflow/core/public
	sudo cp session.h session_options.h tensor_c_api.h /Library/Python/2.7/site-packages/tensorflow/include/tensorflow/core/public/

## Saving tensorflow data from your Python script

Write python script that creates a model and write out as protobuf (NOT text)

	graph_def = tf.get_default_graph().as_graph_def()
	tf.train.write_graph(graph_def, '/tmp', 'graphdef.pb', False)

If you've trained it in python, also write out the parameter (In this example, I have two Variable tensors holding the weights and baises. They are called `W` and `b`

	saver = tf.train.Saver([W, b])
	# Train it
        …

	save_path = saver.save(sess, "/tmp/parameters.pb")

(I understand that this file is a key-value store where the key is the name of the tensor and the value is the protobuf for that tensor's data. I have not been able to parse this data yet, but there is some C++ API involving `TensorSliceRead` and `TensorSliceWritter` for doing this.)

Now, I know you'd like to create the Variable tensors by reading in the model and then filling them with initial values from the parameters file.  That way, for example, you could keep training the model in your Cocoa application.  YOU CAN'T! (This is an obvious flaw in the C++ API. I hope it will be fixed soon.)

Instead, there is a tool (`freeze_graph`) that replaces the Variable tensors with Constant tensors filled with the data from the parameters file. Build that tool:

	bazel build tensorflow/python/tools:freeze_graph

Use that tool:

	bazel-bin/tensorflow/python/tools/freeze_graph --input_graph /tmp/graphdef.pb --input_checkpoint /tmp/parameters.pb --input_binary --output_node_names normalized_guesses --output_graph /tmp/frozen.pb

Copy the resulting model (`frozen.pb` in my case) into your project.

## Using tensorflow from Cocoa

When you use `libtensorflow.so`, you will need to include `/Library/Python/2.7/site-packages/tensorflow/include` in your header search path.

If you copy libtensorflow.so into your project, you'll need to include need to include your project directory in the library search path (something like `$(PROJECT_DIR)/MyApp`) in the library search path.  If you don't copy it in you'll need to include `tensorflow/bazel-bin/tensorflow` (inside the tensor source directory) in your library search path.

In your Cocoa application, read in the graph def and create a new session:

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

When you want to use the model, pack the data correctly, run the model, and then unpack it:

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
    float guesses[10];
    for (int i = 0; i < 10; i++) {
        guesses[i] = mappedOutput(0,i);
    }

## Before you ship your Cocoa app

You'll need to include `libtensorflow.so` in your application.  It is a dynamic library, so you'll need to copy it into the app wrapper at compile time.  More importantly, the library has to tell the app where it can be found. I'd copy the libtensorflow.so into your project directory, then change its install path:

	install_name_tool -id @rpath/libtensorflow.so libtensorflow.so 

You can check it like this:

	otool -D libtensorflow.so

Add a new Copy Files Build Phase to copy `libtensorflow.so` into `Frameworks` directory in the app wrapper

Now build your final release.

FYI: TensorFlow in 0.10 does not use OpenCL for hardware acceleration (is on the roadmap)
