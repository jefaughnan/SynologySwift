// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "SynologySwift",
	products: [
		.library(
			name: "SynologySwift",
			targets: ["SynologySwift"]
		)
	],
	dependencies: [
	],
	targets: [
		.target(
			name: "SynologySwift",
			dependencies: []
		),
		.testTarget(
			name: "SynologySwiftTests",
			dependencies: ["SynologySwift"],
			path: "./Tests/"
		)
	]
)
