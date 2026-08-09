# U-keyboard

<p align="center">
  <img src="assets/u-keyboard.gif" alt="U-keyboard demo" width="320">
</p>

Custom iOS keyboard for the Udmurt language.

U-keyboard is an iOS keyboard designed to make typing in Udmurt convenient while preserving the familiar Russian keyboard layout.

## Features

- Udmurt-specific letters via long press
- Familiar Russian-style keyboard layout
- Dictionary-based word suggestions
- Automatic capitalization
- Light and Dark Mode support
- Custom suggestion bar
- Native iOS-style interface

## Why I built it

Standard iOS keyboards do not provide a convenient native layout for the Udmurt language.

The goal of U-keyboard was to make Udmurt-specific characters easily accessible while keeping the keyboard familiar to users accustomed to the standard Russian iOS layout.

## Technologies

- Swift
- UIKit
- iOS Keyboard Extension
- Xcode

## Development challenges

Some of the main challenges included:

- implementing a custom iOS keyboard extension;
- adding Udmurt-specific characters without overcrowding the layout;
- implementing long-press alternatives;
- building dictionary-based suggestions;
- reproducing familiar iOS keyboard behaviour;
- adapting the interface for Light and Dark Mode.

## AI-assisted development

Large Language Models were actively used throughout development as a productivity and problem-solving tool.

They were used to:

- explore implementation approaches;
- debug Swift code and analyse errors;
- compare alternative technical solutions;
- iterate on UI behaviour;
- accelerate prototyping and testing.

The project involved iterative implementation, testing on a physical iPhone and refinement of both functionality and interface.

## Status

Working prototype successfully tested on a physical iPhone.

## Future development

- Improved autocorrection and word prediction
- Dictionary expansion
- Further UI refinements
- Distribution through TestFlight / App Store
