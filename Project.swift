import ProjectDescription

let project = Project(
    name: "MartyDetector",
    targets: [
        .target(
            name: "MartyDetector",
            destinations: .macOS,
            product: .app,
            bundleId: "com.example.MartyDetector",
            deploymentTargets: .macOS("14.0"),
            infoPlist: .extendingDefault(
                with: [
                    "NSCameraUsageDescription": "We need access to your camera to detect Marty",
                    "NSMicrophoneUsageDescription": "We need access to your microphone to record Marty",
                ]
            ),
            sources: ["MartyDetector/Sources/**"],
            resources: ["MartyDetector/Resources/**"],
            dependencies: [
                .framework(path: "./vendor/frameworks/opencv2.framework"),
                .sdk(name: "c++", type: .library, status: .required),
                .sdk(name: "OpenCL", type: .framework, status: .required),
                .sdk(name: "Accelerate", type: .framework, status: .required)
            ],
        ),
    ]
)
