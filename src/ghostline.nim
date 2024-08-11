import chronos
import std/[os, strformat, strutils]

import libp2p
import libp2p/protocols/pubsub/rpc/messages
import libp2p/protocols/rendezvous
import libp2p/discovery/rendezvousinterface
import libp2p/discovery/discoverymngr

import ./chat, ./utils

const 
  AppNamespace = "stargate"
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

proc inputLoop(gossip: GossipSub, username: string) {.async.} =
  var inp: string
  while true:
    inp = await stdin.readLineAsync()
    inp = inp.strip()
    case inp:
      of "/exit":
        break
      of "":
        continue
      else:
        let chat = Chat.new(username, inp)
        discard gossip.publish(AppTopic, encode(chat).buffer)

    stdout.write("> ")

proc main() {.async.} = 
  if paramCount() < 1:
    echo "Running as bootstrap node"
    let bootNode = createSwitch()
    await bootNode.start()
    for add in bootNode.peerInfo.fullAddrs().tryGet():
      echo  "address: " & $add
    while true:
      await sleepAsync(1.seconds)

  # Parse params
  if paramCount() != 2:
    stderr.writeLine("Please specify username and bootstrap address")
    quit(1)

  let username = paramStr(1)
  let param = paramStr(2)
  let peerAddrRes = parseFullAddress(param)
  if peerAddrRes.isErr:
    stderr.writeLine("bootstrap node address invalid: " & peerAddrRes.error())
    quit(1)
  let (peerId, peerAddr) = peerAddrRes.tryGet()

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
        echo "decode reject"
        return ValidationResult.Reject
      echo "decode accept"
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
      echo &"[{timestamp}] {user}: {message}"
  )

  # Start switch and connect to bootstrap
  await switch.start()
  await switch.connect(peerId, @[peerAddr])

  # Advertise self and connect with others
  dm.advertise(RdvNamespace(AppNamespace))
  let peerQuery = dm.request(RdvNamespace(AppNamespace))
  peerQuery.forEach:
    echo "Got peer: " & $(peer[PeerId]) & " | " & $(peer.getAll(MultiAddress))
    if peer[PeerId] != switch.peerInfo.peerId:
      await switch.connect(peer[PeerId], peer.getAll(MultiAddress))

  # Wait for ctrl+c
  await inputLoop(gossip, username)

  # Clean up
  peerQuery.stop()
  dm.stop()
  await allFutures(switch.stop())
  

waitFor(main())