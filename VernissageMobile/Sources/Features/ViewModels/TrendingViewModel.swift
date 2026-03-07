//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation
import Observation

@MainActor
@Observable
final class TrendingViewModel {
    private(set) var photoStatuses: [Status] = []
    private(set) var isPhotosLoading = false
    private(set) var isPhotosLoadingMore = false
    var photosErrorMessage: String?

    private(set) var artists: [User] = []
    private(set) var isArtistsLoading = false
    private(set) var isArtistsLoadingMore = false
    var artistsErrorMessage: String?

    private(set) var hashtags: [Hashtag] = []
    private(set) var isTagsLoading = false
    private(set) var isTagsLoadingMore = false
    var tagsErrorMessage: String?

    private(set) var artistStatusesByKey: [String: [Status]] = [:]
    private(set) var loadingArtistKeys: Set<String> = []
    private(set) var tagStatusesByName: [String: [Status]] = [:]
    private(set) var loadingTagNames: Set<String> = []
    private(set) var artistsRefreshToken = 0
    private(set) var tagsRefreshToken = 0
    var errorMessage: String?

    private var loadedPhotosPeriod: TrendingPeriodSelection?
    private var nextPhotosMaxId: String?
    private var canLoadMorePhotos = true
    private var isFetchingPhotosFirstPage = false

    private var loadedArtistsPeriod: TrendingPeriodSelection?
    private var nextArtistsMaxId: String?
    private var canLoadMoreArtists = true
    private var isFetchingArtistsFirstPage = false

    private var loadedTagsPeriod: TrendingPeriodSelection?
    private var nextTagsMaxId: String?
    private var canLoadMoreTags = true
    private var isFetchingTagsFirstPage = false

    func reset() {
        photoStatuses = []
        isPhotosLoading = false
        isPhotosLoadingMore = false
        photosErrorMessage = nil
        loadedPhotosPeriod = nil
        nextPhotosMaxId = nil
        canLoadMorePhotos = true
        isFetchingPhotosFirstPage = false

        artists = []
        isArtistsLoading = false
        isArtistsLoadingMore = false
        artistsErrorMessage = nil
        loadedArtistsPeriod = nil
        nextArtistsMaxId = nil
        canLoadMoreArtists = true
        isFetchingArtistsFirstPage = false
        artistStatusesByKey = [:]
        loadingArtistKeys = []

        hashtags = []
        isTagsLoading = false
        isTagsLoadingMore = false
        tagsErrorMessage = nil
        loadedTagsPeriod = nil
        nextTagsMaxId = nil
        canLoadMoreTags = true
        isFetchingTagsFirstPage = false
        tagStatusesByName = [:]
        loadingTagNames = []
    }

    func loadPhotos(using appState: AppState, period: TrendingPeriodSelection, forceRefresh: Bool = false) async {
        if !forceRefresh, loadedPhotosPeriod == period {
            return
        }

        guard !isFetchingPhotosFirstPage, !isPhotosLoadingMore else {
            return
        }

        isFetchingPhotosFirstPage = true
        defer { isFetchingPhotosFirstPage = false }

        let shouldShowLoader = photoStatuses.isEmpty
        if shouldShowLoader {
            isPhotosLoading = true
        }
        defer {
            if shouldShowLoader {
                isPhotosLoading = false
            }
        }

        do {
            let cachePolicy: URLRequest.CachePolicy = forceRefresh
            ? .reloadIgnoringLocalCacheData
            : .useProtocolCachePolicy
            let requestNonce = forceRefresh ? String(Int(Date().timeIntervalSince1970 * 1000)) : nil

            let page = try await appState.fetchTrendingStatuses(period: period,
                                                                maxId: nil,
                                                                cachePolicy: cachePolicy,
                                                                requestNonce: requestNonce)
            photoStatuses = page.data.filter(\.hasAttachment)
            nextPhotosMaxId = page.maxId
            canLoadMorePhotos = page.maxId != nil && !page.data.isEmpty
            loadedPhotosPeriod = period
            photosErrorMessage = nil
        } catch {
            if error.isCancellationLike {
                return
            }

            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            photosErrorMessage = message
            errorMessage = message
        }
    }

    func loadMorePhotosIfNeeded(using appState: AppState, period: TrendingPeriodSelection, currentStatusID: String) async {
        guard loadedPhotosPeriod == period,
              !isFetchingPhotosFirstPage,
              !isPhotosLoadingMore,
              canLoadMorePhotos else {
            return
        }

        guard currentStatusID == photoStatuses.last?.id else {
            return
        }

        guard let cursor = nextPhotosMaxId?.nilIfEmpty else {
            canLoadMorePhotos = false
            return
        }

        isPhotosLoadingMore = true
        defer { isPhotosLoadingMore = false }

        do {
            let page = try await appState.fetchTrendingStatuses(period: period, maxId: cursor)
            appendUniqueStatuses(page.data.filter(\.hasAttachment), to: &photoStatuses)
            nextPhotosMaxId = page.maxId
            canLoadMorePhotos = page.maxId != nil && !page.data.isEmpty
            photosErrorMessage = nil
        } catch {
            if error.isCancellationLike {
                return
            }

            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            photosErrorMessage = message
            errorMessage = message
        }
    }

    func loadArtists(using appState: AppState, period: TrendingPeriodSelection, forceRefresh: Bool = false) async {
        if !forceRefresh, loadedArtistsPeriod == period {
            return
        }

        guard !isFetchingArtistsFirstPage, !isArtistsLoadingMore else {
            return
        }

        isFetchingArtistsFirstPage = true
        defer { isFetchingArtistsFirstPage = false }

        let shouldShowLoader = artists.isEmpty
        if shouldShowLoader {
            isArtistsLoading = true
        }
        defer {
            if shouldShowLoader {
                isArtistsLoading = false
            }
        }

        do {
            let page = try await appState.fetchTrendingUsers(period: period, maxId: nil)
            artists = page.data
            nextArtistsMaxId = page.maxId
            canLoadMoreArtists = page.maxId != nil && !page.data.isEmpty
            loadedArtistsPeriod = period
            artistsErrorMessage = nil
            artistStatusesByKey = [:]
            loadingArtistKeys = []
            artistsRefreshToken += 1
        } catch {
            if error.isCancellationLike {
                return
            }

            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            artistsErrorMessage = message
            errorMessage = message
        }
    }

    func loadMoreArtistsIfNeeded(using appState: AppState, period: TrendingPeriodSelection, currentUser: User) async {
        guard loadedArtistsPeriod == period,
              !isFetchingArtistsFirstPage,
              !isArtistsLoadingMore,
              canLoadMoreArtists else {
            return
        }

        guard currentUser.uniquenessKey == artists.last?.uniquenessKey else {
            return
        }

        guard let cursor = nextArtistsMaxId?.nilIfEmpty else {
            canLoadMoreArtists = false
            return
        }

        isArtistsLoadingMore = true
        defer { isArtistsLoadingMore = false }

        do {
            let page = try await appState.fetchTrendingUsers(period: period, maxId: cursor)
            appendUniqueUsers(page.data, to: &artists)
            nextArtistsMaxId = page.maxId
            canLoadMoreArtists = page.maxId != nil && !page.data.isEmpty
            artistsErrorMessage = nil
        } catch {
            if error.isCancellationLike {
                return
            }

            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            artistsErrorMessage = message
            errorMessage = message
        }
    }

    func loadArtistStatusesIfNeeded(using appState: AppState, user: User) async {
        let key = user.uniquenessKey
        guard !loadingArtistKeys.contains(key), artistStatusesByKey[key] == nil else {
            return
        }

        guard let userName = user.userName?.trimmingPrefix("@").nilIfEmpty else {
            artistStatusesByKey[key] = []
            return
        }

        loadingArtistKeys.insert(key)
        defer { loadingArtistKeys.remove(key) }

        do {
            let page = try await appState.fetchUserStatuses(userName: userName, maxId: nil, limit: 10)
            artistStatusesByKey[key] = page.data.filter(\.hasAttachment)
        } catch {
            if error.isCancellationLike {
                return
            }

            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
            artistStatusesByKey[key] = []
        }
    }

    func loadTags(using appState: AppState, period: TrendingPeriodSelection, forceRefresh: Bool = false) async {
        if !forceRefresh, loadedTagsPeriod == period {
            return
        }

        guard !isFetchingTagsFirstPage, !isTagsLoadingMore else {
            return
        }

        isFetchingTagsFirstPage = true
        defer { isFetchingTagsFirstPage = false }

        let shouldShowLoader = hashtags.isEmpty
        if shouldShowLoader {
            isTagsLoading = true
        }
        defer {
            if shouldShowLoader {
                isTagsLoading = false
            }
        }

        do {
            let page = try await appState.fetchTrendingHashtags(period: period, maxId: nil)
            hashtags = page.data
            nextTagsMaxId = page.maxId
            canLoadMoreTags = page.maxId != nil && !page.data.isEmpty
            loadedTagsPeriod = period
            tagsErrorMessage = nil
            tagStatusesByName = [:]
            loadingTagNames = []
            tagsRefreshToken += 1
        } catch {
            if error.isCancellationLike {
                return
            }

            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            tagsErrorMessage = message
            errorMessage = message
        }
    }

    func loadMoreTagsIfNeeded(using appState: AppState, period: TrendingPeriodSelection, currentHashtag: Hashtag) async {
        guard loadedTagsPeriod == period,
              !isFetchingTagsFirstPage,
              !isTagsLoadingMore,
              canLoadMoreTags else {
            return
        }

        guard currentHashtag.name.lowercased() == hashtags.last?.name.lowercased() else {
            return
        }

        guard let cursor = nextTagsMaxId?.nilIfEmpty else {
            canLoadMoreTags = false
            return
        }

        isTagsLoadingMore = true
        defer { isTagsLoadingMore = false }

        do {
            let page = try await appState.fetchTrendingHashtags(period: period, maxId: cursor)
            appendUniqueHashtags(page.data, to: &hashtags)
            nextTagsMaxId = page.maxId
            canLoadMoreTags = page.maxId != nil && !page.data.isEmpty
            tagsErrorMessage = nil
        } catch {
            if error.isCancellationLike {
                return
            }

            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            tagsErrorMessage = message
            errorMessage = message
        }
    }

    func loadTagStatusesIfNeeded(using appState: AppState, hashtag: Hashtag) async {
        let key = hashtag.name.lowercased()
        guard !loadingTagNames.contains(key), tagStatusesByName[key] == nil else {
            return
        }

        loadingTagNames.insert(key)
        defer { loadingTagNames.remove(key) }

        do {
            let page = try await appState.fetchHashtagStatuses(hashtag: hashtag.name, maxId: nil, limit: 10)
            tagStatusesByName[key] = page.data.filter(\.hasAttachment)
        } catch {
            if error.isCancellationLike {
                return
            }

            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            errorMessage = message
            tagStatusesByName[key] = []
        }
    }

    private func appendUniqueStatuses(_ incoming: [Status], to destination: inout [Status]) {
        guard !incoming.isEmpty else {
            return
        }

        let existingIds = Set(destination.map(\.id))
        let uniqueIncoming = incoming.filter { !existingIds.contains($0.id) }
        destination.append(contentsOf: uniqueIncoming)
    }

    private func appendUniqueUsers(_ incoming: [User], to destination: inout [User]) {
        guard !incoming.isEmpty else {
            return
        }

        var existingKeys = Set(destination.map(\.uniquenessKey))
        let uniqueIncoming = incoming.filter { existingKeys.insert($0.uniquenessKey).inserted }
        destination.append(contentsOf: uniqueIncoming)
    }

    private func appendUniqueHashtags(_ incoming: [Hashtag], to destination: inout [Hashtag]) {
        guard !incoming.isEmpty else {
            return
        }

        var existingNames = Set(destination.map { $0.name.lowercased() })
        let uniqueIncoming = incoming.filter { existingNames.insert($0.name.lowercased()).inserted }
        destination.append(contentsOf: uniqueIncoming)
    }
}
