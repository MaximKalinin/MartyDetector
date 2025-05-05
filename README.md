# Marty Detector (work in progress)

This is a macOS application that detects Marty using a webcam and sends a video
to specified Telegram channel whenever it moves.

Marty is a dog, and he is a very good boy. Even though, the main purpose of the
application is to detect him moving, it can be used to record and send any kind
of motion detected.

It is written in Swift, uses OpenCV for image processing and Telegram HTTP API
for sending the videos.

There are currently no prebuilt app binaries, so you have to build it from
source. Read more in the next section.

## How to build the app locally

Currently, it only supports macOS 14 and above. In order to have the app, you
need to build it from source.

### Prerequisites

- Tuist to generate the Xcode project from a configuration file(can be installed
  via Homebrew: `brew install tuist`)
- Xcode or Xcode Command Line Tools (can be installed via shell: `xcode-select --install`)
- OpenCV (needs to be built from [source](https://github.com/opencv/opencv.git))

### Building OpenCV

OpenCV does not provide pre-built binaries for macOS (but they do provide
binaries for iOS), thus, you have to build it yourself. Luckily, it is not that
complicated, even though you might need to install additional tools, such as
Python. Download [the official repository](https://github.com/opencv/opencv.git)
and build XCFramework using python script:

```bash
git clone https://github.com/opencv/opencv.git
cd opencv
mkdir framework
python ./platforms/apple/build_xcframework.py -o frameworks --macos_archs=x86_64,arm64 --build_only_specified_archs
```

The script will take a while, and in the end you will have a
`frameworks/opencv2.xcframework` directory with the Universal fat framework
(that contains both x86_64 and arm64 architectures in one file). Move that to
the marty-detector directory:

```bash
mv frameworks/opencv2.xcframework ../marty-detector/vendor/frameworks/
```

#### Note

Currently, the opencv Universal framework header file has an issue that prevents
it from compiling the Universal projects. In order to fix it you have to
manually edit the header file:
vendor/frameworks/opencv2.xcframework/macos-arm64_x86_64/opencv2.framework/Versions/A/Headers/opencv2-Swift.h

The following line must be replaced:

```diff
- #elif defined(__x86_64__) && __x86_64__

+ #elif (defined(__x86_64__) && __x86_64__) || (defined(__arm64__) && __arm64__)
```

Explanation: when compiling for Universal architecture, the compiler will go
through the source files twice: once with `__x86_64__` defined and once with
`__arm64__` defined. In both cases it needs to be able to read the file.

### Building the app

From the root directory:

```bash
tuist generate # this will create .xcodeproj and all the other files required for Xcode
xcodebuild \
  -scheme MartyDetector \
  -configuration Release \ # or Debug
  -derivedDataPath build

```

This will create a `MartyDetector.app` application in the build directory. You
can run it from there:

```bash
./build/Build/Products/Release/MartyDetector.app/Contents/MacOS/MartyDetector
```

Or move it to the `Applications` directory and run as a normal app.

## Getting started with development

- Have the same prerequisites as for building the app
- Run `tuist generate` to generate the Xcode project
- Open the project in Xcode and run it
