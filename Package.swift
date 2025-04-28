// swift-tools-version:5.9
//
// this file is only used to provide intellisense for the project. Use CMake to
// build the project. 
import PackageDescription

let package = Package(
    name: "MartyDetector",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MartyDetector", targets: ["MartyDetector"])
    ],
    targets: [
        .executableTarget(
            name: "MartyDetector",
            dependencies: [
                "opencv2"
            ],
            path: ".",
            exclude: [
                "build",
                "vendor"
            ],
        ),
        .binaryTarget(name: "opencv2", path: "vendor/frameworks/opencv2.xcframework")
    ]
)
