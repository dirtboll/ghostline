import tui_widget
import libp2p
import chronicles
import chronicles/options as chronicles_options
import strutils, os
import ./[backend, frontend]
import ./types/[channels, user]

if paramCount() < 1:
  when defined(chronicles_sinks):
    if chronicles_sinks.contains("dynamic"):
      defaultChroniclesStream.output.writer =
        proc (logLevel: LogLevel, msg: LogOutputStr) {.gcsafe.} =
          echo msg
  startBootstrap()
  quit()

if paramCount() != 2:
  stderr.writeLine("Please specify username and bootstrap address")
  quit(1)

let 
  username = paramStr(1)
  param = paramStr(2)
  peerAddrRes = parseFullAddress(param)
if peerAddrRes.isErr:
  stderr.writeLine("bootstrap node address invalid: " & peerAddrRes.error())
  quit(1)
let 
  (bootstrapPeerId, bootstrapPeerAddr) = peerAddrRes.tryGet()
  initUser = InitUser(
    username: username,
    bootstrapPeerId: bootstrapPeerId,
    bootstrapPeerAddr: bootstrapPeerAddr
  )

var 
  backendChan: Channel[ChannelMsg]
  frontendChan: Channel[ChannelMsg]
  backendThread: Thread[tuple[backend, frontend: ptr Channel[ChannelMsg], initUser: InitUser]]
  frontendThread: Thread[tuple[backend, frontend: ptr Channel[ChannelMsg], termApp: ptr TerminalApp]]
  termDisplay = newDisplay(1, 1, consoleWidth(), consoleHeight()-3, id="chat", title="message")
  termInput = newInputBox(1, consoleHeight()-2, consoleWidth(), consoleHeight(), title="chat")
  termApp = newTerminalApp(title="Ghostline", border=false)

when defined(chronicles_sinks):
  if chronicles_sinks.contains("dynamic"):
    defaultChroniclesStream.output.writer =
      proc (logLevel: LogLevel, msg: LogOutputStr) {.gcsafe.} =
        frontendChan.send(ChannelMsg.new(ChannelMsgKind.cmkFeMsg, msg))

backendChan.open()
frontendChan.open()
createThread(backendThread, startBackend, (addr backendChan, addr frontendChan, initUser))
createThread(frontendThread, startFrontend, (addr backendChan, addr frontendChan, addr termApp))

termDisplay.on("display", proc(dp: Display, args: varargs[string]) =
  dp.text = args[0]
)

let termInputOnEnter = proc(ib: InputBox, arg: varargs[string]) =
  let cmd = termInput.value.split(" ")
  if cmd.len < 1:
    return
  case cmd[0]:
  of "/connect":
    backendChan.send(ChannelMsg.new(ChannelMsgKind.cmkSwitchConnect, cmd[1]))
  of "/username":
    backendChan.send(ChannelMsg.new(ChannelMsgKind.cmkChangeUsername, cmd[1]))
  else:
    backendChan.send(ChannelMsg.new(ChannelMsgKind.cmkChat, termInput.value))
  termInput.value("")
termInput.onEnter = termInputOnEnter
termInput.focus = true
termApp.addWidget(termInput)
termApp.addWidget(termDisplay)
# TODO: attach ctrl+c hook for graceful shutdown
termApp.run(nonBlocking = true)

