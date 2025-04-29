cmake_minimum_required(VERSION 3.20)
project(MartyDetector LANGUAGES Swift)

set(CMAKE_SWIFT_COMPILER "swiftc")

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(OPENCV2_FRAMEWORK_PATH "${CMAKE_SOURCE_DIR}/vendor/frameworks")

# macOS app bundle
set(MACOSX_BUNDLE TRUE)
set(MACOSX_BUNDLE_GUI_IDENTIFIER "com.example.martydetector")
set(MACOSX_BUNDLE_BUNDLE_NAME "Marty Detector")

add_executable(MartyDetector MACOSX_BUNDLE
    Main.swift
    Gui.swift
    VideoCapture.swift
    TelegramAPI.swift
    Info.plist
)

target_compile_options(MartyDetector PRIVATE
    "-F${OPENCV2_FRAMEWORK_PATH}"
)

target_link_options(MartyDetector PRIVATE
    "-F${OPENCV2_FRAMEWORK_PATH}"
)

target_link_libraries(MartyDetector PRIVATE
    "-framework opencv2"
    # used in opencv
    "-framework OpenCL"
    # used in opencv
    "-framework Accelerate"
    # used in opencv
    c++
)

set_target_properties(MartyDetector PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST ${CMAKE_SOURCE_DIR}/Info.plist
    SWIFT_MODULE_NAME MartyDetector
)

add_custom_command(TARGET MartyDetector POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
        "$<TARGET_FILE_DIR:MartyDetector>/../Frameworks"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${OPENCV2_FRAMEWORK_PATH}/opencv2.framework"
        "$<TARGET_FILE_DIR:MartyDetector>/../Frameworks/opencv2.framework"
)
