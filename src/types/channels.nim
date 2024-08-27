type 
  ChannelMsgKind* = enum
    cmkStart, cmkChat, cmkEnd, cmkKey, cmkChangeUsername, cmkSwitchConnect, 
    cmkFeMsg, cmkFeEnd
  # TODO: user case-of property for sending chat message to frontend as Chat instead of string 
  ChannelMsg* = ref object of RootObj
    kind*: ChannelMsgKind
    content*: string 

proc new*(_: typedesc[ChannelMsg], kind: ChannelMsgKind, content: string): ChannelMsg =
  ChannelMsg(
    kind: kind,
    content: content
  )