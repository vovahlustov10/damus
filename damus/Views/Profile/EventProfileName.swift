//
//  EventProfileName.swift
//  damus
//
//  Created by William Casarin on 2023-03-14.
//

import SwiftUI

/// Profile Name used when displaying an event in the timeline
struct EventProfileName: View {
    let damus_state: DamusState
    let pubkey: String
    let profile: Profile?
    
    @State var display_name: DisplayName?
    @State var nip05: NIP05?
    @State var donation: Int?
    
    let size: EventViewKind
    
    init(pubkey: String, profile: Profile?, damus: DamusState, size: EventViewKind = .normal) {
        self.damus_state = damus
        self.pubkey = pubkey
        self.profile = profile
        self.size = size
        self._donation = State(wrappedValue: profile?.damus_donation)
    }
    
    var friend_type: FriendType? {
        return get_friend_type(contacts: damus_state.contacts, pubkey: self.pubkey)
    }
    
    var current_nip05: NIP05? {
        nip05 ?? damus_state.profiles.is_validated(pubkey)
    }
    
    var current_display_name: DisplayName {
        return display_name ?? Profile.displayName(profile: profile, pubkey: pubkey)
    }
    
    var onlyzapper: Bool {
        guard let profile else {
            return false
        }
        
        return profile.reactions == false
    }
    
    var supporter: Int? {
        guard let donation, donation > 0
        else {
            return nil
        }
        
        return donation
    }
    
    var body: some View {
        HStack(spacing: 2) {
            switch current_display_name {
            case .one(let one):
                Text(one)
                    .font(.body.weight(.bold))
                
            case .both(let both):
                Text(both.display_name)
                    .font(.body.weight(.bold))
                
                Text(verbatim: "@\(both.username)")
                    .foregroundColor(.gray)
                    .font(eventviewsize_to_font(size))
            }
            
            /*
            if let nip05 = current_nip05 {
                NIP05Badge(nip05: nip05, pubkey: pubkey, contacts: damus_state.contacts, show_domain: false, clickable: false)
            }
             */
            
             
            if let frend = friend_type {
                FriendIcon(friend: frend)
            }
            
            if onlyzapper {
                Image("zap-hashtag")
                    .frame(width: 14, height: 14)
            }
            
            if let supporter {
                SupporterBadge(percent: supporter)
            }
        }
        .onReceive(handle_notify(.profile_updated)) { notif in
            let update = notif.object as! ProfileUpdate
            if update.pubkey != pubkey {
                return
            }
            display_name = Profile.displayName(profile: update.profile, pubkey: pubkey)
            nip05 = damus_state.profiles.is_validated(pubkey)
            donation = update.profile.damus_donation
        }
    }
}


struct EventProfileName_Previews: PreviewProvider {
    static var previews: some View {
        EventProfileName(pubkey: "pk", profile: nil, damus: test_damus_state())
    }
}
