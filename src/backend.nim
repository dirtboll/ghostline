import libp2p
import libp2p/protocols/pubsub/rpc/messages
import libp2p/protocols/rendezvous
import libp2p/discovery/rendezvousinterface
import libp2p/discovery/discoverymngr
import chronos
import chronicles

import std/[strformat]

import ./types/[chat, user, channels]

const 
  AppNamespace = "ghostline"
  AppTopic = "chat"

proc createSwitch(rdv: RendezVous = RendezVous.new()): Switch =
  SwitchBuilder
    .new()
    .withRng(newRng())
    .withAddresses(@[MultiAddress.init("/ip4/0.0.0.0/tcp/0").tryGet()])
    .withTcpTransport()
    .withYamux()
    .withNoise()
    .withRendezVous(rdv)
    .build()

proc backendClient*(backendChan: ptr Channel[ChannelMsg], frontendChan: ptr Channel[ChannelMsg], initUser: InitUser) {.async.} = 
  # Create switch with Rendezveus peer discovery
  let 
    rdv = RendezVous.new()
    switch = createSwitch(rdv)
    dm = DiscoveryManager()
  dm.add(RendezVousInterface.new(rdv, ttr = 250.milliseconds))

  # Use GossipSub 
  var gossip = GossipSub.init(switch = switch, triggerSelf = true)
  switch.mount(gossip)
  gossip.addValidator(
    [AppTopic],
    proc(topic: string, message: Message): Future[ValidationResult] {.async.} =
      let decoded = Chat.decode(message.data)
      if decoded.isErr:
        debug "backend > decode reject"
        return ValidationResult.Reject
      debug "backend > decode accept"
      return ValidationResult.Accept
  )
  gossip.subscribe(
    AppTopic,
    proc(_: string, data: seq[byte]) {.async.} =
      let 
        chat = Chat.decode(data).tryGet()
        timestamp = chat.timestamp
        user = chat.user
        message = chat.message
        chatMessage = fmt"[{timestamp}] {user.username}: {message}"
      # TODO: Send Chat instead of string
      frontendChan[].send(ChannelMsg.new(ChannelMsgKind.cmkFeMsg, chatMessage))
  )

  # Start switch and connect to bootstrap
  await switch.start()
  await switch.connect(initUser.bootstrapPeerId, @[initUser.bootstrapPeerAddr])

  # Advertise self and connect with others
  dm.advertise(RdvNamespace(AppNamespace))
  let peerQuery = dm.request(RdvNamespace(AppNamespace))
  peerQuery.forEach:
    # TODO: fix this to use debug
    # frontendChan[].send(ChannelMsg.new(ChannelMsgKind.cmkFeMsg, "backend > got peer: " & $(peer[PeerId]) & " | " & $(peer.getAll(MultiAddress))))
    if peer[PeerId] != switch.peerInfo.peerId:
      await switch.connect(peer[PeerId], peer.getAll(MultiAddress))
  var username = initUser.username

  # Wait for messages
  while true:
    let (dataAvailable, msg) = backendChan[].tryRecv()
    if dataAvailable:
      case msg.kind:
      of ChannelMsgKind.cmkEnd:
        break
      of ChannelMsgKind.cmkChat:
        var chat = Chat.new(username, msg.content)
        discard gossip.publish(AppTopic, encode(chat).buffer)
      of ChannelMsgKind.cmkChangeUsername:
        username = msg.content
      else:
        discard
    await sleepAsync(50.milliseconds)

  # Clean up
  peerQuery.stop()
  dm.stop()
  await allFutures(switch.stop())

proc backendBootstrap() {.async.} =
  echo "Running as bootstrap node"
  let bootNode = createSwitch()
  await bootNode.start()
  for add in bootNode.peerInfo.fullAddrs().tryGet():
    echo  "address: " & $add
  while true:
    await sleepAsync(1.seconds)
  discard

proc startBackend*(args: tuple[backend, frontend: ptr Channel[ChannelMsg], initUser: InitUser]) {.thread.} =
  waitFor(backendClient(args.backend, args.frontend, args.initUser))

proc startBootstrap*() {.thread.} =
  waitFor(backendBootstrap())