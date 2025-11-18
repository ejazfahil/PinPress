# PinPress
A Pinterest clone app, but a better user interface and special image caching technique.
GitHub README for Your SwiftUI App (PinPress)

Below is a polished, industry-grade README designed for recruiters, developers, and hiring managers.

PinPress — A Pinterest-Style SwiftUI App

PinPress is a modern, high-performance Pinterest-inspired iOS application built with SwiftUI, async image loading, remote image caching, and infinite scrolling.
It demonstrates clean architecture, modular components, and scalable UI patterns suitable for production-grade apps.

Features
1. Pinterest-Style Feed

Masonry grid layout

Smooth scrolling

Adaptive tiles for all screen sizes

2. Remote Image Loading

Asynchronous image fetching

Intelligent caching using NSCache

Zero blocking on the main thread

Automatic fallback for slow networks

3. Image Swiping (Carousel)

Each pin can contain multiple images

Smooth swipe gestures using TabView

Page indicators

4. Infinite Scroll

Fetch new content as the user reaches the bottom

Supports API integration or mock data

5. Tab-Based Navigation

Home

Categories

Profile

Tech Stack

Swift 5+

SwiftUI

Combine

NSCache (image caching)

AsyncImage / CachedAsyncImage

MVVM Pattern

Xcode 16+

Project Architecture
PinPress
│── Models/
│── Views/
│── ViewModels/
│── Services/
│── Cache/
│── Extensions/
│── Resources/
│── Assets.xcassets
│── PinPressApp.swift

Key Components
1. ImageCache

A lightweight caching layer preventing unnecessary network calls.

2. CachedAsyncImage

Custom async image loader that:

checks cache first

fetches only when necessary

updates UI when loaded

3. Pin Model

Supports multiple images + categories for each tile.

Screenshots

(Add later—GitHub will auto-render images)

📱 Home Feed
📱 Category Layout
📱 Pin Detail View

Setup Instructions
Clone the Repository
git clone https://github.com/<your-username>/PinPress.git
cd PinPress

Open in Xcode

Launch PinPress.xcodeproj

Run on any iPhone simulator (iOS 17+ recommended)

Future Enhancements

Backend API integration (Node.js / Firebase)

User authentication

User-controlled Boards

Real-time notifications

Likes and save functionality

Offline mode + persistent storage

License

This project is released under the MIT License.

Author Fahil Ejaz
iOS Developer | Machine Learning Enthusiast | Mobile App Engineer
Contact: / GitHub / Email
