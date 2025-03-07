//
//  ProfileModel.swift
//  damus
//
//  Created by William Casarin on 2022-04-27.
//

import Foundation

class ProfileModel: ObservableObject, Equatable {
    @Published var contacts: NostrEvent? = nil
    @Published var following: Int = 0
    @Published var relays: [String: RelayInfo]? = nil
    @Published var progress: Int = 0
    
    var events: EventHolder
    let pubkey: String
    let damus: DamusState
    
    var seen_event: Set<String> = Set()
    var sub_id = UUID().description
    var prof_subid = UUID().description
    
    init(pubkey: String, damus: DamusState) {
        self.pubkey = pubkey
        self.damus = damus
        self.events = EventHolder(on_queue: { ev in
            preload_events(state: damus, events: [ev])
        })
    }
    
    func follows(pubkey: String) -> Bool {
        guard let contacts = self.contacts else {
            return false
        }
        
        for tag in contacts.tags {
            guard tag.count >= 2 && tag[0] == "p" else {
                continue
            }
            
            if tag[1] == pubkey {
                return true
            }
        }
        
        return false
    }
    
    func get_follow_target() -> FollowTarget {
        if let contacts = contacts {
            return .contact(contacts)
        }
        return .pubkey(pubkey)
    }
    
    static func == (lhs: ProfileModel, rhs: ProfileModel) -> Bool {
        return lhs.pubkey == rhs.pubkey
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(pubkey)
    }
    
    func unsubscribe() {
        print("unsubscribing from profile \(pubkey) with sub_id \(sub_id)")
        damus.pool.unsubscribe(sub_id: sub_id)
        damus.pool.unsubscribe(sub_id: prof_subid)
    }
    
    func subscribe() {
        var text_filter = NostrFilter(kinds: [.text, .chat])
        
        var profile_filter = NostrFilter(kinds: [.contacts, .metadata, .boost])
        
        profile_filter.authors = [pubkey]
        
        text_filter.authors = [pubkey]
        text_filter.limit = 500
        
        print("subscribing to profile \(pubkey) with sub_id \(sub_id)")
        print_filters(relay_id: "profile", filters: [[text_filter], [profile_filter]])
        damus.pool.subscribe(sub_id: sub_id, filters: [text_filter], handler: handle_event)
        damus.pool.subscribe(sub_id: prof_subid, filters: [profile_filter], handler: handle_event)
    }
    
    func handle_profile_contact_event(_ ev: NostrEvent) {
        process_contact_event(state: damus, ev: ev)
        
        // only use new stuff
        if let current_ev = self.contacts {
            guard ev.created_at > current_ev.created_at else {
                return
            }
        }
        
        self.contacts = ev
        self.following = count_pubkeys(ev.tags)
        self.relays = decode_json_relays(ev.content)
    }
    
    func add_event(_ ev: NostrEvent) {
        guard ev.should_show_event else {
            return
        }

        if seen_event.contains(ev.id) {
            return
        }
        if ev.is_textlike || ev.known_kind == .boost {
            if self.events.insert(ev) {
                self.objectWillChange.send()
            }
        } else if ev.known_kind == .contacts {
            handle_profile_contact_event(ev)
        } else if ev.known_kind == .metadata {
            process_metadata_event(events: damus.events, our_pubkey: damus.pubkey, profiles: damus.profiles, ev: ev)
        }
        seen_event.insert(ev.id)
    }
    
    private func handle_event(relay_id: String, ev: NostrConnectionEvent) {
        switch ev {
        case .ws_event:
            return
        case .nostr_event(let resp):
            guard resp.subid == self.sub_id || resp.subid == self.prof_subid else {
                return
            }
            switch resp {
            case .ok:
                break
            case .event(_, let ev):
                add_event(ev)
            case .notice(let notice):
                notify(.notice, notice)
            case .eose:
                if resp.subid == sub_id {
                    load_profiles(profiles_subid: prof_subid, relay_id: relay_id, load: .from_events(events.events), damus_state: damus)
                }
                progress += 1
                break
            }
        }
    }
}


func count_pubkeys(_ tags: [[String]]) -> Int {
    var c: Int = 0
    for tag in tags {
        if tag.count >= 2 && tag[0] == "p" {
            c += 1
        }
    }
    
    return c
}
