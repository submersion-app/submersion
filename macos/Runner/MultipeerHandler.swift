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
///   - send({peerId, bytes}), close({peerId})
/// Events, as onEvent({type, peerId, ...}) calls into Dart:
///   found, lost, incoming, data {bytes}, closed, proximity {meters}
///
/// The advertised peer name is random per run, so nothing in range learns
/// who the device belongs to before the card session's own handshake. On
/// iPhone 11 and later, Nearby Interaction ranging reports how close each
/// connected peer is, from discovery tokens exchanged over the session.
class MultipeerHandler: NSObject {
  private static let serviceType = "subm-card"

  /// Prefixes a Nearby Interaction token on the session. A nearby frame
  /// starts with its 4-byte length, and no frame is this long.
  private static let tokenMarker = Data("NI1:".utf8)

  private let channel: FlutterMethodChannel
  private let myPeer = MCPeerID(displayName: String(UUID().uuidString.prefix(12)))
  private var advertiser: MCNearbyServiceAdvertiser?
  private var browser: MCNearbyServiceBrowser?
  private var found: [String: MCPeerID] = [:]
  private var sessions: [String: MCSession] = [:]
  private var invited: Set<String> = []
  private var pendingConnects: [String: FlutterResult] = [:]
  private var ranging: [String: AnyObject] = [:]

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "app.submersion/multipeer",
      binaryMessenger: messenger
    )
    super.init()
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let peerId = args?["peerId"] as? String
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
      let session = newSession(for: id)
      pendingConnects[id] = result
      browser.invitePeer(peer, to: session, withContext: nil, timeout: 15)
    case "send":
      guard let id = peerId, let session = sessions[id],
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
      if let id = peerId { endSession(id, notify: false) }
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
    found.removeAll()
    guard on else { return }
    let b = MCNearbyServiceBrowser(peer: myPeer, serviceType: Self.serviceType)
    b.delegate = self
    b.startBrowsingForPeers()
    browser = b
  }

  private func newSession(for id: String) -> MCSession {
    endSession(id, notify: false)
    let session = MCSession(
      peer: myPeer, securityIdentity: nil, encryptionPreference: .required)
    session.delegate = self
    sessions[id] = session
    return session
  }

  private func endSession(_ id: String, notify: Bool) {
    ranging.removeValue(forKey: id)
    if let session = sessions.removeValue(forKey: id) {
      session.delegate = nil
      session.disconnect()
    }
    invited.remove(id)
    if let pending = pendingConnects.removeValue(forKey: id) {
      pending(FlutterError(code: "notConnected", message: "Connection failed", details: nil))
    }
    if notify { emit(["type": "closed", "peerId": id]) }
  }

  private func emit(_ event: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      self?.channel.invokeMethod("onEvent", arguments: event)
    }
  }

  private func startRanging(with id: String) {
    #if os(iOS) && canImport(NearbyInteraction)
    if #available(iOS 16.0, *) {
      guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement,
            let session = sessions[id] else { return }
      let ni = NISession()
      ni.delegate = self
      ranging[id] = ni
      guard let token = ni.discoveryToken,
            let tokenData = try? NSKeyedArchiver.archivedData(
              withRootObject: token, requiringSecureCoding: true) else { return }
      try? session.send(
        Self.tokenMarker + tokenData, toPeers: session.connectedPeers, with: .reliable)
    }
    #endif
  }

  private func receivedToken(_ data: Data, from id: String) {
    #if os(iOS) && canImport(NearbyInteraction)
    if #available(iOS 16.0, *) {
      guard let ni = ranging[id] as? NISession,
            let token = try? NSKeyedUnarchiver.unarchivedObject(
              ofClass: NIDiscoveryToken.self, from: data) else { return }
      ni.run(NINearbyPeerConfiguration(peerToken: token))
    }
    #endif
  }

  private func id(of session: MCSession) -> String? {
    sessions.first(where: { $0.value === session })?.key
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
    }
  }

  func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    DispatchQueue.main.async {
      self.found.removeValue(forKey: peerID.displayName)
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
      let session = self.newSession(for: id)
      self.invited.insert(id)
      invitationHandler(true, session)
    }
  }
}

extension MultipeerHandler: MCSessionDelegate {
  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    DispatchQueue.main.async {
      guard let id = self.id(of: session) else { return }
      switch state {
      case .connected:
        if let pending = self.pendingConnects.removeValue(forKey: id) {
          pending(nil)
        } else if self.invited.remove(id) != nil {
          self.emit(["type": "incoming", "peerId": id])
        }
        self.startRanging(with: id)
      case .notConnected:
        self.endSession(id, notify: true)
      default:
        break
      }
    }
  }

  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    DispatchQueue.main.async {
      guard let id = self.id(of: session) else { return }
      if data.starts(with: Self.tokenMarker) {
        self.receivedToken(data.dropFirst(Self.tokenMarker.count), from: id)
        return
      }
      self.emit([
        "type": "data", "peerId": id, "bytes": FlutterStandardTypedData(bytes: data),
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
