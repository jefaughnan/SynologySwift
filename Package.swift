// swift-tools-version:4.0
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
			name: "SynologySwift",
			dependencies: ["SynologySwift"]
		)
	]
)
