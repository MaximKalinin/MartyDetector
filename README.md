# Marty Detector (work in progress)

This is a macOS application that detects Marty using a webcam and sends a video
to specified Telegram channel whenever it moves.

It is written in Swift, uses OpenCV for image processing, custom trained model
for object inference based on Ultralytics YOLOv11, and Telegram HTTP API for
sending the videos.

## How to run locally

Currently, it only supports ARM-based macOS 14 and above. In order to have the
app, you need to build it from source.

### Prerequisites

- CMake (can be downloaded from [here](https://cmake.org/download/))
- Ninja (can be installed via Homebrew: `brew install ninja`)
- Xcode or Xcode Command Line Tools (can be installed via shell: `xcode-select --install`)
- OpenCV (needs to be built from [source](https://github.com/opencv/opencv.git))

### Building OpenCV (work in progress)

OpenCV does not provide pre-built binaries for macOS (but they do provide
binaries for iOS), thus, you have to build it yourself. Luckily, it is not that
complicated, even though you might need to install additional tools, such as
Python. Download [the official repository](https://github.com/opencv/opencv.git)
and build XCFramework using python script:

```bash
git clone https://github.com/opencv/opencv.git
cd opencv
mkdir framework
python ./platforms/apple/build_xcframework.py -o frameworks --macos_archs=arm64 --build_only_specified_archs
```

The script will take a while, and in the end you will have a
`frameworks/opencv2.xcframework` directory with the framework. Move that to the
marty-detector directory:

```bash
mv frameworks/opencv2.xcframework ../marty-detector/vendor/frameworks/
```

### Building the app

From the root directory:

```bash
mkdir build
cd build
cmake -G Ninja ..
cmake --build .
```

This will create a `MartyDetector.app` directory in the build directory. You can
run it from there:

```bash
./MartyDetector.app/Contents/MacOS/MartyDetector
```

Or move it to the `Applications` directory and run as a normal app.
