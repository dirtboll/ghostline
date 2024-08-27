import tui_widget
import strutils
import ./types/[channels]

proc renderChats*(msgs: var seq[string]): string =
  msgs.join("\n")

proc startFrontend*(arg: tuple[backend, frontend: ptr Channel[ChannelMsg], termApp: ptr TerminalApp]) {.thread.} =
  var chatMessages = newSeq[string]()
  while true:
    let msg = arg.frontend[].recv()
    case msg.kind:
    of ChannelMsgKind.cmkFeEnd:
      break
    of ChannelMsgKind.cmkFeMsg:
      chatMessages &= msg.content
      let renderedChat = renderChats(chatMessages)
      arg.termApp.notify("chat", "display", renderedChat)
    else:
      discard