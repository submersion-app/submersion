#if os(iOS)
import Flutter
import UIKit
#if canImport(NearbyInteraction)
import NearbyInteraction
#endif
#else
import FlutterMacOS
#endif
import MultipeerConnectivity

/// Apple's Multipeer Connectivity for buddy card swaps (issue #3728): the
/// Bluetooth plus direct Wi-Fi link between Apple devices, used only while
/// the swap screen is open. Dart owns the protocol; this moves bytes.
///
/// Methods (channel: app.submersion/multipeer):
///   - isSupported() -> Bool
///   - advertise(Bool), browse(Bool)
///   - connect({peerId}) completes once connected, or fails
///   - send({peerId, dir, bytes}), close({peerId, dir})
/// Events, as onEvent({type, peerId, ...}) calls into Dart:
///   found, lost, incoming {dir}, data {dir, bytes}, closed {dir},
///   proximity {meters}
///
/// A card link is a peer plus a direction: `out` for one this device
/// invited, `in` for one it accepted. Two divers who dial each other at
/// once hold two separate sessions rather than one each side tears down.
///
/// The advertised peer name is random per run, so nothing in range learns
/// who the device belongs to before the card session's own handshake. On
/// iPhone 11 and later, Nearby Interaction ranging runs on a separate
/// session per found peer that lasts until the peer is lost (card sessions
/// close within a second of a look); only the peer with the lower name
/// invites it, so the two never cross.
class MultipeerHandler: NSObject {
  private static let serviceType = "subm-card"

  /// The invitation context that asks for a ranging session.
  private static let rangingContext = Data("ni".utf8)

  /// Prefixes a Nearby Interaction token on a ranging session.
  private static let tokenMarker = Data("NI1:".utf8)

  private let channel: FlutterMethodChannel
  private let myPeer = MCPeerID(displayName: String(UUID().uuidString.prefix(12)))
  private var advertiser: MCNearbyServiceAdvertiser?
  private var browser: MCNearbyServiceBrowser?
  private var found: [String: MCPeerID] = [:]

  /// Card sessions, keyed "out|id" or "in|id".
  private var sessions: [String: MCSession] = [:]
  private var pendingConnects: [String: FlutterResult] = [:]

  /// Ranging sessions and their Nearby Interaction state, keyed by peer id.
  private var rangingSessions: [String: MCSession] = [:]
  private var ranging: [String: AnyObject] = [:]
  private var pendingTokens: [String: Data] = [:]

  /// Ranging sessions that connected, so only a drop (not a declined
  /// invitation from a phone that cannot range) starts ranging again.
  private var rangingConnected: Set<String> = []

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "app.submersion/multipeer",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler(handle)
  }

  private static func key(_ id: String, _ dir: String) -> String { "\(dir)|\(id)" }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let peerId = args?["peerId"] as? String
    let dir = (args?["dir"] as? String) == "in" ? "in" : "out"
    switch call.method {
    case "isSupported":
      result(true)
    case "advertise":
      setAdvertising(call.arguments as? Bool ?? false)
      result(nil)
    case "browse":
      setBrowsing(call.arguments as? Bool ?? false)
      result(nil)
    case "connect":
      guard let id = peerId, let peer = found[id], let browser = browser else {
        result(FlutterError(code: "notFound", message: "Peer not in range", details: nil))
        return
      }
      let key = Self.key(id, "out")
      let session = newCardSession(key)
      pendingConnects[key] = result
      browser.invitePeer(peer, to: session, withContext: nil, timeout: 15)
    case "send":
      guard let id = peerId, let session = sessions[Self.key(id, dir)],
            let bytes = args?["bytes"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "closed", message: "No session", details: nil))
        return
      }
      do {
        try session.send(bytes.data, toPeers: session.connectedPeers, with: .reliable)
        result(nil)
      } catch {
        result(FlutterError(code: "sendFailed", message: error.localizedDescription, details: nil))
      }
    case "close":
      if let id = peerId { endCardSession(Self.key(id, dir), notify: false) }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setAdvertising(_ on: Bool) {
    advertiser?.stopAdvertisingPeer()
    advertiser = nil
    guard on else { return }
    let a = MCNearbyServiceAdvertiser(
      peer: myPeer, discoveryInfo: nil, serviceType: Self.serviceType)
    a.delegate = self
    a.startAdvertisingPeer()
    advertiser = a
  }

  private func setBrowsing(_ on: Bool) {
    browser?.stopBrowsingForPeers()
    browser = nil
    for id in found.keys { endRanging(id) }
    found.removeAll()
    guard on else { return }
    let b = MCNearbyServiceBrowser(peer: myPeer, serviceType: Self.serviceType)
    b.delegate = self
    b.startBrowsingForPeers()
    browser = b
  }

  private func newSession() -> MCSession {
    let session = MCSession(
      peer: myPeer, securityIdentity: nil, encryptionPreference: .required)
    session.delegate = self
    return session
  }

  private func newCardSession(_ key: String) -> MCSession {
    endCardSession(key, notify: false)
    let session = newSession()
    sessions[key] = session
    return session
  }

  private func endCardSession(_ key: String, notify: Bool) {
    if let session = sessions.removeValue(forKey: key) {
      session.delegate = nil
      session.disconnect()
    }
    if let pending = pendingConnects.removeValue(forKey: key) {
      pending(FlutterError(code: "notConnected", message: "Connection failed", details: nil))
    }
    if notify, let bar = key.firstIndex(of: "|") {
      emit([
        "type": "closed",
        "peerId": String(key[key.index(after: bar)...]),
        "dir": String(key[..<bar]),
      ])
    }
  }

  private func emit(_ event: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      self?.channel.invokeMethod("onEvent", arguments: event)
    }
  }

  private func cardKey(of session: MCSession) -> String? {
    sessions.first(where: { $0.value === session })?.key
  }

  private func rangingId(of session: MCSession) -> String? {
    rangingSessions.first(where: { $0.value === session })?.key
  }

  // MARK: Nearby Interaction

  private var supportsRanging: Bool {
    #if os(iOS) && canImport(NearbyInteraction)
    if #available(iOS 16.0, *) {
      return NISession.deviceCapabilities.supportsPreciseDistanceMeasurement
    }
    #endif
    return false
  }

  /// Opens the ranging session with a newly found peer, from the side with
  /// the lower name only; the other side accepts its invitation.
  private func startRanging(with peer: MCPeerID) {
    guard supportsRanging, let browser = browser,
          myPeer.displayName < peer.displayName,
          rangingSessions[peer.displayName] == nil else { return }
    let session = newSession()
    rangingSessions[peer.displayName] = session
    createNI(for: peer.displayName)
    browser.invitePeer(peer, to: session, withContext: Self.rangingContext, timeout: 15)
  }

  private func endRanging(_ id: String) {
    #if os(iOS) && canImport(NearbyInteraction)
    if #available(iOS 16.0, *) {
      (ranging[id] as? NISession)?.invalidate()
    }
    #endif
    ranging.removeValue(forKey: id)
    pendingTokens.removeValue(forKey: id)
    rangingConnected.remove(id)
    if let session = rangingSessions.removeValue(forKey: id) {
      session.delegate = nil
      session.disconnect()
    }
  }

  /// The Nearby Interaction session for [id], made before any token can
  /// arrive, so a token that beats this side's own connected callback is
  /// kept rather than dropped.
  private func createNI(for id: String) {
    #if os(iOS) && canImport(NearbyInteraction)
    if #available(iOS 16.0, *), ranging[id] == nil {
      let ni = NISession()
      ni.delegate = self
      ranging[id] = ni
    }
    #endif
  }

  private func sendToken(to id: String) {
    #if os(iOS) && canImport(NearbyInteraction)
    if #available(iOS 16.0, *) {
      guard let ni = ranging[id] as? NISession, let session = rangingSessions[id],
            let token = ni.discoveryToken,
            let tokenData = try? NSKeyedArchiver.archivedData(
              withRootObject: token, requiringSecureCoding: true) else { return }
      try? session.send(
        Self.tokenMarker + tokenData, toPeers: session.connectedPeers, with: .reliable)
      if let early = pendingTokens.removeValue(forKey: id) {
        receivedToken(early, from: id)
      }
    }
    #endif
  }

  private func receivedToken(_ data: Data, from id: String) {
    #if os(iOS) && canImport(NearbyInteraction)
    if #available(iOS 16.0, *) {
      guard let ni = ranging[id] as? NISession else {
        pendingTokens[id] = data
        return
      }
      guard let token = try? NSKeyedUnarchiver.unarchivedObject(
        ofClass: NIDiscoveryToken.self, from: data) else { return }
      ni.run(NINearbyPeerConfiguration(peerToken: token))
    }
    #endif
  }
}

extension MultipeerHandler: MCNearbyServiceBrowserDelegate {
  func browser(
    _ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
    withDiscoveryInfo info: [String: String]?
  ) {
    DispatchQueue.main.async {
      self.found[peerID.displayName] = peerID
      self.emit(["type": "found", "peerId": peerID.displayName])
      self.startRanging(with: peerID)
    }
  }

  func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    DispatchQueue.main.async {
      self.found.removeValue(forKey: peerID.displayName)
      self.endRanging(peerID.displayName)
      self.emit(["type": "lost", "peerId": peerID.displayName])
    }
  }
}

extension MultipeerHandler: MCNearbyServiceAdvertiserDelegate {
  func advertiser(
    _ advertiser: MCNearbyServiceAdvertiser,
    didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?,
    invitationHandler: @escaping (Bool, MCSession?) -> Void
  ) {
    DispatchQueue.main.async {
      let id = peerID.displayName
      if context == Self.rangingContext {
        guard self.supportsRanging else {
          invitationHandler(false, nil)
          return
        }
        self.endRanging(id)
        let session = self.newSession()
        self.rangingSessions[id] = session
        self.createNI(for: id)
        invitationHandler(true, session)
        return
      }
      invitationHandler(true, self.newCardSession(Self.key(id, "in")))
    }
  }
}

extension MultipeerHandler: MCSessionDelegate {
  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    DispatchQueue.main.async {
      if let id = self.rangingId(of: session) {
        switch state {
        case .connected:
          self.rangingConnected.insert(id)
          self.sendToken(to: id)
        case .notConnected:
          let dropped = self.rangingConnected.contains(id)
          self.endRanging(id)
          // A dropped link to a diver still in range ranges again, or
          // hold-together stops for them until Multipeer loses and finds
          // them. A declined invitation is not retried.
          if dropped, let peer = self.found[id] { self.startRanging(with: peer) }
        default: break
        }
        return
      }
      guard let key = self.cardKey(of: session), let bar = key.firstIndex(of: "|") else {
        return
      }
      let dir = String(key[..<bar])
      let id = String(key[key.index(after: bar)...])
      switch state {
      case .connected:
        if let pending = self.pendingConnects.removeValue(forKey: key) {
          pending(nil)
        } else if dir == "in" {
          self.emit(["type": "incoming", "peerId": id, "dir": "in"])
        }
      case .notConnected:
        self.endCardSession(key, notify: true)
      default:
        break
      }
    }
  }

  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    DispatchQueue.main.async {
      if let id = self.rangingId(of: session) {
        if data.starts(with: Self.tokenMarker) {
          self.receivedToken(data.dropFirst(Self.tokenMarker.count), from: id)
        }
        return
      }
      guard let key = self.cardKey(of: session), let bar = key.firstIndex(of: "|") else {
        return
      }
      self.emit([
        "type": "data",
        "peerId": String(key[key.index(after: bar)...]),
        "dir": String(key[..<bar]),
        "bytes": FlutterStandardTypedData(bytes: data),
      ])
    }
  }

  func session(
    _ session: MCSession, didReceive stream: InputStream, withName streamName: String,
    fromPeer peerID: MCPeerID
  ) {}

  func session(
    _ session: MCSession, didStartReceivingResourceWithName resourceName: String,
    fromPeer peerID: MCPeerID, with progress: Progress
  ) {}

  func session(
    _ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
    fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?
  ) {}
}

#if os(iOS) && canImport(NearbyInteraction)
@available(iOS 16.0, *)
extension MultipeerHandler: NISessionDelegate {
  func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
    guard let distance = nearbyObjects.first?.distance else { return }
    DispatchQueue.main.async {
      guard let id = self.ranging.first(where: { $0.value === session })?.key else {
        return
      }
      self.emit(["type": "proximity", "peerId": id, "meters": Double(distance)])
    }
  }
}
#endif
