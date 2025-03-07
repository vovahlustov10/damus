//
//  ProfileView.swift
//  damus
//
//  Created by William Casarin on 2022-04-23.
//

import SwiftUI

enum FollowState {
    case follows
    case following
    case unfollowing
    case unfollows
}

func follow_btn_txt(_ fs: FollowState, follows_you: Bool) -> String {
    switch fs {
    case .follows:
        return NSLocalizedString("Unfollow", comment: "Button to unfollow a user.")
    case .following:
        return NSLocalizedString("Following...", comment: "Label to indicate that the user is in the process of following another user.")
    case .unfollowing:
        return NSLocalizedString("Unfollowing...", comment: "Label to indicate that the user is in the process of unfollowing another user.")
    case .unfollows:
        if follows_you {
            return NSLocalizedString("Follow Back", comment: "Button to follow a user back.")
        } else {
            return NSLocalizedString("Follow", comment: "Button to follow a user.")
        }
    }
}

func followersCountString(_ count: Int, locale: Locale = Locale.current) -> String {
    let format = localizedStringFormat(key: "followers_count", locale: locale)
    return String(format: format, locale: locale, count)
}

func followingCountString(_ count: Int, locale: Locale = Locale.current) -> String {
    let format = localizedStringFormat(key: "following_count", locale: locale)
    return String(format: format, locale: locale, count)
}

func relaysCountString(_ count: Int, locale: Locale = Locale.current) -> String {
    let format = localizedStringFormat(key: "relays_count", locale: locale)
    return String(format: format, locale: locale, count)
}

struct EditButton: View {
    let damus_state: DamusState
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationLink(destination: EditMetadataView(damus_state: damus_state)) {
            Text("Edit", comment: "Button to edit user's profile.")
                .frame(height: 30)
                .padding(.horizontal,25)
                .font(.caption.weight(.bold))
                .foregroundColor(fillColor())
                .cornerRadius(24)
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(borderColor(), lineWidth: 1)
                }
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
    }
    
    func fillColor() -> Color {
        colorScheme == .light ? DamusColors.black : DamusColors.white
    }
    
    func borderColor() -> Color {
        colorScheme == .light ? DamusColors.black : DamusColors.white
    }
}

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView {
        UIVisualEffectView()
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) {
        uiView.effect = effect
    }
}

struct ProfileView: View {
    let damus_state: DamusState
    let pfp_size: CGFloat = 90.0
    let bannerHeight: CGFloat = 150.0
    
    static let markdown = Markdown()
    
    @State var showing_select_wallet: Bool = false
    @State var is_zoomed: Bool = false
    @State var show_share_sheet: Bool = false
    @State var show_qr_code: Bool = false
    @State var action_sheet_presented: Bool = false
    @State var filter_state : FilterState = .posts
    @State var yOffset: CGFloat = 0
    
    @StateObject var profile: ProfileModel
    @StateObject var followers: FollowersModel
    @StateObject var zap_button_model: ZapButtonModel = ZapButtonModel()
    
    init(damus_state: DamusState, profile: ProfileModel, followers: FollowersModel) {
        self.damus_state = damus_state
        self._profile = StateObject(wrappedValue: profile)
        self._followers = StateObject(wrappedValue: followers)
    }
    
    init(damus_state: DamusState, pubkey: String) {
        self.damus_state = damus_state
        self._profile = StateObject(wrappedValue: ProfileModel(pubkey: pubkey, damus: damus_state))
        self._followers = StateObject(wrappedValue: FollowersModel(damus_state: damus_state, target: pubkey))
    }
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.presentationMode) var presentationMode
    
    func imageBorderColor() -> Color {
        colorScheme == .light ? DamusColors.white : DamusColors.black
    }
    
    func bannerBlurViewOpacity() -> Double  {
        let progress = -(yOffset + navbarHeight) / 100
        return Double(-yOffset > navbarHeight ? progress : 0)
    }
    
    var bannerSection: some View {
        GeometryReader { proxy -> AnyView in
                            
            let minY = proxy.frame(in: .global).minY
            
            DispatchQueue.main.async {
                self.yOffset = minY
            }
            
            return AnyView(
                VStack(spacing: 0) {
                    ZStack {
                        BannerImageView(pubkey: profile.pubkey, profiles: damus_state.profiles, disable_animation: damus_state.settings.disable_animation)
                            .aspectRatio(contentMode: .fill)
                            .frame(width: proxy.size.width, height: minY > 0 ? bannerHeight + minY : bannerHeight)
                            .clipped()
                        
                        VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial)).opacity(bannerBlurViewOpacity())
                    }
                    
                    Divider().opacity(bannerBlurViewOpacity())
                }
                .frame(height: minY > 0 ? bannerHeight + minY : nil)
                .offset(y: minY > 0 ? -minY : -minY < navbarHeight ? 0 : -minY - navbarHeight)
            )

        }
        .frame(height: bannerHeight)
        .allowsHitTesting(false)
    }
    
    var navbarHeight: CGFloat {
        return 100.0 - (Theme.safeAreaInsets?.top ?? 0)
    }
    
    @ViewBuilder
    func navImage(img: String) -> some View {
        Image(img)
            .frame(width: 33, height: 33)
            .background(Color.black.opacity(0.6))
            .clipShape(Circle())
    }
    
    var navBackButton: some View {
        Button {
            presentationMode.wrappedValue.dismiss()
        } label: {
            navImage(img: "chevron-left")
        }
    }
    
    var navActionSheetButton: some View {
        Button(action: {
            action_sheet_presented = true
        }) {
            navImage(img: "share3")
        }
        .confirmationDialog(NSLocalizedString("Actions", comment: "Title for confirmation dialog to either share, report, or mute a profile."), isPresented: $action_sheet_presented) {
            Button(NSLocalizedString("Share", comment: "Button to share the link to a profile.")) {
                show_share_sheet = true
            }
            
            Button(NSLocalizedString("QR Code", comment: "Button to view profile's qr code.")) {
                show_qr_code = true
            }

            // Only allow reporting if logged in with private key and the currently viewed profile is not the logged in profile.
            if profile.pubkey != damus_state.pubkey && damus_state.is_privkey_user {
                Button(NSLocalizedString("Report", comment: "Button to report a profile."), role: .destructive) {
                    let target: ReportTarget = .user(profile.pubkey)
                    notify(.report, target)
                }

                if damus_state.contacts.is_muted(profile.pubkey) {
                    Button(NSLocalizedString("Unmute", comment: "Button to unmute a profile.")) {
                        guard
                            let keypair = damus_state.keypair.to_full(),
                            let mutelist = damus_state.contacts.mutelist
                        else {
                            return
                        }
                        
                        guard let new_ev = remove_from_mutelist(keypair: keypair, prev: mutelist, to_remove: profile.pubkey) else {
                            return
                        }

                        damus_state.contacts.set_mutelist(new_ev)
                        damus_state.postbox.send(new_ev)
                    }
                } else {
                    Button(NSLocalizedString("Mute", comment: "Button to mute a profile."), role: .destructive) {
                        notify(.mute, profile.pubkey)
                    }
                }
            }
        }
    }
    
    var customNavbar: some View {
        HStack {
            navBackButton
            Spacer()
            navActionSheetButton
        }
        .padding(.top, 5)
        .padding(.horizontal)
        .accentColor(DamusColors.white)
    }
    
    func lnButton(lnurl: String, profile: Profile) -> some View {
        let button_img = profile.reactions == false ? "zap.fill" : "zap"
        return Button(action: {
            zap_button_model.showing_zap_customizer = true
        }) {
            Image(button_img)
                .foregroundColor(button_img == "zap.fill" ? .orange : Color.primary)
                .profile_button_style(scheme: colorScheme)
                .contextMenu {
                    if profile.reactions == false {
                        Text("OnlyZaps Enabled", comment: "Non-tappable text in context menu that shows up when the zap button on profile is long pressed to indicate that the user has enabled OnlyZaps, meaning that they would like to be only zapped and not accept reactions to their notes.")
                    }
                    
                    if let addr = profile.lud16 {
                        Button {
                            UIPasteboard.general.string = addr
                        } label: {
                            Label(addr, image: "copy2")
                        }
                    } else if let lnurl = profile.lnurl {
                        Button {
                            UIPasteboard.general.string = lnurl
                        } label: {
                            Label(NSLocalizedString("Copy LNURL", comment: "Context menu option for copying a user's Lightning URL."), image: "copy")
                        }
                    }
                }
            
        }
        .cornerRadius(24)
        .sheet(isPresented: $zap_button_model.showing_zap_customizer) {
            CustomizeZapView(state: damus_state, target: ZapTarget.profile(self.profile.pubkey), lnurl: lnurl)
        }
        .sheet(isPresented: $zap_button_model.showing_select_wallet, onDismiss: {zap_button_model.showing_select_wallet = false}) {
            SelectWalletView(default_wallet: damus_state.settings.default_wallet, showingSelectWallet: $zap_button_model.showing_select_wallet, our_pubkey: damus_state.pubkey, invoice: zap_button_model.invoice ?? "")
        }
        .onReceive(handle_notify(.zapping)) { notif in
            let zap_ev = notif.object as! ZappingEvent

            guard zap_ev.target.id == self.profile.pubkey else {
                return
            }

            guard !zap_ev.is_custom else {
                return
            }

            switch zap_ev.type {
            case .failed:
                break
            case .got_zap_invoice(let inv):
                if damus_state.settings.show_wallet_selector {
                    zap_button_model.invoice = inv
                    zap_button_model.showing_select_wallet = true
                } else {
                    let wallet = damus_state.settings.default_wallet.model
                    open_with_wallet(wallet: wallet, invoice: inv)
                }
            case .sent_from_nwc:
                break
            }
        }
    }
    
    var dmButton: some View {
        let dm_model = damus_state.dms.lookup_or_create(profile.pubkey)
        let dmview = DMChatView(damus_state: damus_state, dms: dm_model)
        return NavigationLink(destination: dmview) {
            Image("messages")
                .profile_button_style(scheme: colorScheme)
        }
    }
    
    func actionSection(profile_data: Profile?) -> some View {
        return Group {
            
            if let profile = profile_data {
                if let lnurl = profile.lnurl, lnurl != "" {
                    lnButton(lnurl: lnurl, profile: profile)
                }
            }
            
            dmButton
            
            if profile.pubkey != damus_state.pubkey {
                FollowButtonView(
                    target: profile.get_follow_target(),
                    follows_you: profile.follows(pubkey: damus_state.pubkey),
                    follow_state: damus_state.contacts.follow_state(profile.pubkey)
                )
            } else if damus_state.keypair.privkey != nil {
                NavigationLink(destination: EditMetadataView(damus_state: damus_state)) {
                    EditButton(damus_state: damus_state)
                }
            }
            
        }
    }
    
    func pfpOffset() -> CGFloat {
        let progress = -yOffset / navbarHeight
        let offset = (pfp_size / 4.0) * (progress < 1.0 ? progress : 1)
        return offset > 0 ? offset : 0
    }
    
    func pfpScale() -> CGFloat {
        let progress = -yOffset / navbarHeight
        let scale = 1.0 - (0.5 * (progress < 1.0 ? progress : 1))
        return scale < 1 ? scale : 1
    }
    
    func nameSection(profile_data: Profile?) -> some View {
        return Group {
            HStack(alignment: .center) {
                ProfilePicView(pubkey: profile.pubkey, size: pfp_size, highlight: .custom(imageBorderColor(), 4.0), profiles: damus_state.profiles, disable_animation: damus_state.settings.disable_animation)
                    .padding(.top, -(pfp_size / 2.0))
                    .offset(y: pfpOffset())
                    .scaleEffect(pfpScale())
                    .onTapGesture {
                        is_zoomed.toggle()
                    }
                    .fullScreenCover(isPresented: $is_zoomed) {
                        ProfilePicImageView(pubkey: profile.pubkey, profiles: damus_state.profiles, disable_animation: damus_state.settings.disable_animation)
                    }
                
                Spacer()
                
                actionSection(profile_data: profile_data)
            }
            
            let follows_you = profile.pubkey != damus_state.pubkey && profile.follows(pubkey: damus_state.pubkey)
            ProfileNameView(pubkey: profile.pubkey, profile: profile_data, follows_you: follows_you, damus: damus_state)
        }
    }
    
    var followersCount: some View {
        HStack {
            if followers.count == nil {
                Image("download")
                    .resizable()
                    .frame(width: 20, height: 20)
                Text("Followers", comment: "Label describing followers of a user.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                let followerCount = followers.count!
                let noun_text = Text(verbatim: followersCountString(followerCount)).font(.subheadline).foregroundColor(.gray)
                Text("\(Text(verbatim: followerCount.formatted()).font(.subheadline.weight(.medium))) \(noun_text)", comment: "Sentence composed of 2 variables to describe how many people are following a user. In source English, the first variable is the number of followers, and the second variable is 'Follower' or 'Followers'.")
            }
        }
    }
    
    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8.0) {
            let profile_data = damus_state.profiles.lookup(id: profile.pubkey)
            
            nameSection(profile_data: profile_data)

            if let about = profile_data?.about {
                AboutView(state: damus_state, about: about)
            }
            
            if let url = profile_data?.website_url {
                WebsiteLink(url: url)
            }
            
            HStack {
                if let contact = profile.contacts {
                    let contacts = contact.referenced_pubkeys.map { $0.ref_id }
                    let following_model = FollowingModel(damus_state: damus_state, contacts: contacts)
                    NavigationLink(destination: FollowingView(damus_state: damus_state, following: following_model, whos: profile.pubkey)) {
                        HStack {
                            let noun_text = Text(verbatim: "\(followingCountString(profile.following))").font(.subheadline).foregroundColor(.gray)
                            Text("\(Text(verbatim: profile.following.formatted()).font(.subheadline.weight(.medium))) \(noun_text)", comment: "Sentence composed of 2 variables to describe how many profiles a user is following. In source English, the first variable is the number of profiles being followed, and the second variable is 'Following'.")
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                let fview = FollowersView(damus_state: damus_state, whos: profile.pubkey)
                    .environmentObject(followers)
                if followers.contacts != nil {
                    NavigationLink(destination: fview) {
                        followersCount
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    followersCount
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            followers.contacts = []
                            followers.subscribe()
                        }
                }
                
                if let relays = profile.relays {
                    // Only open relay config view if the user is logged in with private key and they are looking at their own profile.
                    let noun_text = Text(verbatim: relaysCountString(relays.keys.count)).font(.subheadline).foregroundColor(.gray)
                    let relay_text = Text("\(Text(verbatim: relays.keys.count.formatted()).font(.subheadline.weight(.medium))) \(noun_text)", comment: "Sentence composed of 2 variables to describe how many relay servers a user is connected. In source English, the first variable is the number of relay servers, and the second variable is 'Relay' or 'Relays'.")
                    if profile.pubkey == damus_state.pubkey && damus_state.is_privkey_user {
                        NavigationLink(destination: RelayConfigView(state: damus_state)) {
                            relay_text
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        NavigationLink(destination: UserRelaysView(state: damus_state, relays: Array(relays.keys).sorted())) {
                            relay_text
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(.horizontal)
    }
        
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                bannerSection
                    .zIndex(1)
                
                VStack() {
                    aboutSection
                
                    VStack(spacing: 0) {
                        CustomPicker(selection: $filter_state, content: {
                            Text("Notes", comment: "Label for filter for seeing only your notes (instead of notes and replies).").tag(FilterState.posts)
                            Text("Notes & Replies", comment: "Label for filter for seeing your notes and replies (instead of only your notes).").tag(FilterState.posts_and_replies)
                        })
                        Divider()
                            .frame(height: 1)
                    }
                    .background(colorScheme == .dark ? Color.black : Color.white)
                    
                    if filter_state == FilterState.posts {
                        InnerTimelineView(events: profile.events, damus: damus_state, filter: FilterState.posts.filter)
                    }
                    if filter_state == FilterState.posts_and_replies {
                        InnerTimelineView(events: profile.events, damus: damus_state, filter: FilterState.posts_and_replies.filter)
                    }
                }
                .padding(.horizontal, Theme.safeAreaInsets?.left)
                .zIndex(-yOffset > navbarHeight ? 0 : 1)
            }
        }
        .ignoresSafeArea()
        .navigationTitle("")
        .navigationBarHidden(true)
        .overlay(customNavbar, alignment: .top)
        .onReceive(handle_notify(.switched_timeline)) { _ in
            dismiss()
        }
        .onAppear() {
            profile.subscribe()
            //followers.subscribe()
        }
        .onDisappear {
            profile.unsubscribe()
            followers.unsubscribe()
            // our profilemodel needs a bit more help
        }
        .sheet(isPresented: $show_share_sheet) {
            if let npub = bech32_pubkey(profile.pubkey) {
                if let url = URL(string: "https://damus.io/" + npub) {
                    ShareSheet(activityItems: [url])
                }
            }
        }
        .fullScreenCover(isPresented: $show_qr_code) {
            QRCodeView(damus_state: damus_state, pubkey: profile.pubkey)
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let ds = test_damus_state()
        ProfileView(damus_state: ds, pubkey: ds.pubkey)
    }
}

func test_damus_state() -> DamusState {
    let pubkey = "3efdaebb1d8923ebd99c9e7ace3b4194ab45512e2be79c1b7d68d9243e0d2681"
    let damus = DamusState.empty
    
    let prof = Profile(name: "damus", display_name: "damus", about: "iOS app!", picture: "https://damus.io/img/logo.png", banner: "", website: "https://damus.io", lud06: nil, lud16: "jb55@sendsats.lol", nip05: "damus.io", damus_donation: nil)
    let tsprof = TimestampedProfile(profile: prof, timestamp: 0, event: test_event)
    damus.profiles.add(id: pubkey, profile: tsprof)
    return damus
}

struct KeyView: View {
    let pubkey: String
    
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isCopied = false
    
    func keyColor() -> Color {
        colorScheme == .light ? DamusColors.black : DamusColors.white
    }
    
    private func copyPubkey(_ pubkey: String) {
        UIPasteboard.general.string = pubkey
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation {
            isCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isCopied = false
                }
            }
        }
    }
    
    var body: some View {
        let bech32 = bech32_pubkey(pubkey) ?? pubkey
        
        HStack {
            Text(verbatim: "\(abbrev_pubkey(bech32, amount: 16))")
                .font(.footnote)
                .foregroundColor(keyColor())
                .padding(5)
                .padding([.leading, .trailing], 5)
                .background(RoundedRectangle(cornerRadius: 11).foregroundColor(DamusColors.adaptableGrey))
                        
            if isCopied != true {
                Button {
                    copyPubkey(bech32)
                } label: {
                    Label {
                        Text("Public key", comment: "Label indicating that the text is a user's public account key.")
                    } icon: {
                        Image("copy2")
                            .resizable()
                            .contentShape(Rectangle())
                            .foregroundColor(.accentColor)
                            .frame(width: 20, height: 20)
                    }
                    .labelStyle(IconOnlyLabelStyle())
                    .symbolRenderingMode(.hierarchical)
                }
            } else {
                HStack {
                    Image("check-circle")
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text(NSLocalizedString("Copied", comment: "Label indicating that a user's key was copied."))
                        .font(.footnote)
                        .layoutPriority(1)
                }
                .foregroundColor(DamusColors.green)
            }
        }
    }
}

extension View {
    func profile_button_style(scheme: ColorScheme) -> some View {
        self.symbolRenderingMode(.palette)
            .font(.system(size: 32).weight(.thin))
            .foregroundStyle(scheme == .dark ? .white : .black, scheme == .dark ? .white : .black)
    }
}
