//
//  ListenItemsWorker.swift
//  Scout
//
//

import Foundation
import RxSwift

protocol ListenItemsWorker {

    var items: [Listen.Model.Item] { get }
    var loadingStatus: Listen.Model.LoadingStatus { get }

    func fetchItems()
    func removeItem(with itemId: Listen.Identifier)

    func observeItems() -> Observable<[Listen.Model.Item]>
    func observeLoadingStatus() -> Observable<Listen.Model.LoadingStatus>

    func setItemToPlayer(_ itemId: Listen.Identifier)
}

extension Listen {

    typealias ItemsWorker = ListenItemsWorker
}
