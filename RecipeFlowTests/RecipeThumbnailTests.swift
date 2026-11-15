//
//  RecipeThumbnailTests.swift
//  RecipeFlowTests
//

import Testing
import UIKit
import SwiftData
@testable import RecipeFlow

struct RecipeThumbnailTests {
    private func photo(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @Test func aBigPhotoIsScaledDown() throws {
        let data = try #require(Recipe.thumbnailData(from: photo(width: 3000, height: 2000)))
        let image = try #require(UIImage(data: data))
        #expect(image.size.width == Recipe.thumbnailSide)
        #expect(abs(image.size.height - Recipe.thumbnailSide * 2 / 3) < 1)
    }

    @Test func aSmallPhotoIsNotEnlarged() throws {
        let data = try #require(Recipe.thumbnailData(from: photo(width: 200, height: 100)))
        let image = try #require(UIImage(data: data))
        #expect(image.size == CGSize(width: 200, height: 100))
    }

    @MainActor @Test func theThumbnailIsStoredOnTheRecipe() throws {
        let container = try ModelContainer(for: Recipe.self, Ingredient.self, Step.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let recipe = Recipe()
        container.mainContext.insert(recipe)
        #expect(recipe.thumbnailImage == nil)
        recipe.thumbnail = Recipe.thumbnailData(from: photo(width: 100, height: 100))
        #expect(recipe.thumbnailImage != nil)
    }
}
