//
//  ImageSource.swift
//  jiji-purinto
//
//  Source from which the user selects an image.
//

import Foundation

/// Represents the source from which the user selects an image.
enum ImageSource: Equatable, Sendable {
    /// Select an existing photo from the photo library.
    case gallery
}
