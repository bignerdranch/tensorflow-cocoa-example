# tensorflow-cocoa-example
Using tensorflow inside a desktop Cocoa application

Google did an amazing thing by open-sourcing its tensorflow machine learning framework.  The framework's API is best used from Python, but if you are working in Cocoa, it is much easier to use the C++ API. The C++ API is incomplete and poorly documented. I suspect very few people have ever actually used it.

Inside Google, tensorflow is built with its internal build tool blaze. So, you will need to use its dumbed down brother bazel that Google has also open sourced. bazel uses your CPU like nothing you have ever used before. I can't listen to music on iTunes while bazel is building tensorflow.

All serialization is done using protocol buffers — the new 3.0 version.

First install lots of Python packages:

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

You will also want to build the library to link into your application:

	bazel build //tensorflow:libtensorflow.so

Headers for this library are in `/Library/Python/2.7/site-packages/tensorflow/include/tensorflow/core` but a few are missing, copy from source:

	cd tensorflow/core/public
	sudo cp session.h session_options.h tensor_c_api.h /Library/Python/2.7/site-packages/tensorflow/include/tensorflow/core/public/

Write python script that creates a model and write out as protobuf (NOT text)

	graph_def = tf.get_default_graph().as_graph_def()
	tf.train.write_graph(graph_def, '/tmp', 'graphdef.pb', False)

If you've trained it in python, also write out the parameter (In this example, I have two Variable tensors holding the weights and baises. They are called `W` and `b`
	saver = tf.train.Saver([W, b])
	# Train it
        …

	save_path = saver.save(sess, "/tmp/parameters.pb")

Now, I know you'd like to create the Variable tensors by reading in the model and then filling them with initial values from the parameters file.  That way, for example, you could keep training the model in your Cocoa application.  YOU CAN'T!

Instead, there is a tool (`freeze_graph`) that replaces the Variable tensors with Constant tensors filled with the data from the parameters file. Build that tool:

	bazel build tensorflow/python/tools:freeze_graph

Use that tool:

	bazel-bin/tensorflow/python/tools/freeze_graph --input_graph /tmp/graphdef.pb --input_checkpoint /tmp/parameters.pb --input_binary --output_node_names normalized_guesses --output_graph /tmp/frozen.pb

Copy the resulting model (`frozen.pb` in my case) into your project.

You'll need to include libtensorflow.so in your application.  It is a dynamic library, so you'll need to copy it into the app wrapper at compile time.  More importantly, the library has to tell the app where it can be found. I'd copy the libtensorflow.so into your project directory, then change its install path:

	install_name_tool -id @rpath/libtensorflow.so libtensorflow.so 

You can check it like this:

	otool -D libtensorflow.so

Add a new Copy Files Build Phase to copy `libtensorflow.so` into `Frameworks` directory in the app wrapper

FYI: TensorFlow in 0.10 does not use OpenCL for hardware acceleration (is on the roadmap)
